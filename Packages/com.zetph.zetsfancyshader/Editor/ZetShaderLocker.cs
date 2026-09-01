// ZetsFancyShader inspector - revision 24 (comment-safe inlining, keyword restore)
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Generates a stripped copy of the shader with dead //ifex blocks removed,
    /// and points the material at it.
    ///
    /// Scope, deliberately: this removes blocks, it does not inline property
    /// values. ZetsFancyShader is PC-only, so its uniform branches are cheap and
    /// constant-folding them buys little. What it cannot do cheaply is skip a
    /// GrabPass or an extra Pass, and those are exactly what the //ifex blocks
    /// gate. Everything else stays a live uniform, which also means animation
    /// keeps working on properties nobody marked.
    ///
    /// Because the output depends only on the handful of //ifex decisions, two
    /// materials that agree on them share one generated shader rather than each
    /// spawning a copy.
    /// </summary>
    public static class ZetShaderLocker
    {
        public const string LockedFromTag = "ZetLockedFrom";

        // Which integrations were available when this material was locked. A
        // locked shader has them inlined, so it is frozen against that state: if
        // the packages change afterwards the locked copy is stale, and in the
        // case of a REMOVED package it no longer compiles at all. Recording the
        // state is what lets the inspector notice and say so.
        public const string LockedIntegrationsTag = "ZetLockedIntegrations";
        public const string LockedKeyTag = "ZetLockedKey";

        private const string OutputFolder = "Assets/ZetsFancyShader/Locked";

        // Relative include emitted by ZetIntegrationGenerator, resolved against
        // the SOURCE shader's folder.
        private const string GeneratedInclude = "Generated/ZetIntegrations.cginc";

        /// <summary>
        /// Contents of the integrations include that sits beside the source
        /// shader. Returns a comment rather than throwing if it is missing: a
        /// lock should not fail outright over an optional-feature header, and an
        /// absent file means no integrations, which is a valid state.
        /// </summary>
        private static string[] ReadGeneratedInclude(string sourcePath)
        {
            try
            {
                string dir = Path.GetDirectoryName(sourcePath);
                string full = Path.Combine(dir ?? string.Empty, GeneratedInclude)
                                  .Replace('\\', '/');

                if (File.Exists(full)) return File.ReadAllLines(full);

                return new[] { "// " + GeneratedInclude + " not found - no integrations active." };
            }
            catch (Exception e)
            {
                return new[] { "// Failed to read " + GeneratedInclude + ": " + e.Message };
            }
        }

        private static readonly Regex IfexOpen = new Regex(
            @"^\s*//ifex\s+(?<prop>_\w+)\s*(?<op>==|!=|>=|<=|>|<)\s*(?<val>-?[\d.]+)\s*$",
            RegexOptions.Compiled);

        private static readonly Regex IfexClose = new Regex(@"^\s*//endex\s*$", RegexOptions.Compiled);

        private static readonly Regex ShaderFeature = new Regex(
            @"^(?<indent>\s*)#pragma\s+shader_feature(_local)?\s+(?<keywords>.+?)\s*$",
            RegexOptions.Compiled);

        private static readonly Regex ShaderName = new Regex(
            "^(?<lead>\\s*Shader\\s+\")(?<name>[^\"]+)(?<tail>\".*)$", RegexOptions.Compiled);

        // ------------------------------------------------------------- model

        private class Block
        {
            public int Start;      // line index of //ifex
            public int End;        // line index of //endex
            public string Property;
            public string Op;
            public float Value;
        }

        public class Plan
        {
            public Shader Source;
            public string SourcePath;
            public string[] Lines;
            public List<string> Drivers = new List<string>();
            public Dictionary<string, bool> Strip = new Dictionary<string, bool>();
            public List<string> KeptBecauseAnimated = new List<string>();
            public int LinesRemoved;
            public int Inlined;
            public List<string> AnimatedKept = new List<string>();
            public string Key;
            public string Error;
        }

        // -------------------------------------------------------------- read

        private static List<Block> Parse(string[] lines, out string error)
        {
            var blocks = new List<Block>();
            var open = new Stack<Block>();
            error = null;

            for (int i = 0; i < lines.Length; i++)
            {
                Match m = IfexOpen.Match(lines[i]);
                if (m.Success)
                {
                    if (open.Count > 0)
                    {
                        // Nesting is not supported rather than silently mishandled:
                        // the result would compile and be subtly wrong.
                        error = "Nested //ifex at line " + (i + 1) + ".";
                        return blocks;
                    }

                    open.Push(new Block
                    {
                        Start = i,
                        Property = m.Groups["prop"].Value,
                        Op = m.Groups["op"].Value,
                        Value = float.Parse(m.Groups["val"].Value, CultureInfo.InvariantCulture)
                    });
                    continue;
                }

                if (!IfexClose.IsMatch(lines[i])) continue;

                if (open.Count == 0)
                {
                    error = "//endex without //ifex at line " + (i + 1) + ".";
                    return blocks;
                }

                Block b = open.Pop();
                b.End = i;
                blocks.Add(b);
            }

            if (open.Count > 0)
                error = "Unclosed //ifex at line " + (open.Peek().Start + 1) + ".";

            return blocks;
        }

        private static bool Test(string op, float actual, float expected)
        {
            const float E = 0.0001f;
            switch (op)
            {
                case "==": return Math.Abs(actual - expected) < E;
                case "!=": return Math.Abs(actual - expected) >= E;
                case ">":  return actual > expected;
                case "<":  return actual < expected;
                case ">=": return actual >= expected - E;
                case "<=": return actual <= expected + E;
                default:   return false;
            }
        }

        // -------------------------------------------------------------- plan

        /// <summary>
        /// Works out what would be stripped, without writing anything. Used by the
        /// inspector to describe the outcome before the user commits to it.
        /// </summary>
        public static Plan Build(Material material)
        {
            var plan = new Plan();

            Shader source = ResolveSourceShader(material);
            if (source == null)
            {
                plan.Error = "Could not resolve the source shader.";
                return plan;
            }

            plan.Source = source;
            plan.SourcePath = AssetDatabase.GetAssetPath(source);

            if (string.IsNullOrEmpty(plan.SourcePath) || !File.Exists(plan.SourcePath))
            {
                plan.Error = "Shader source file not found on disk.";
                return plan;
            }

            plan.Lines = File.ReadAllLines(plan.SourcePath);

            string parseError;
            List<Block> blocks = Parse(plan.Lines, out parseError);
            if (parseError != null)
            {
                plan.Error = parseError;
                return plan;
            }

            foreach (Block b in blocks)
            {
                if (!plan.Drivers.Contains(b.Property))
                    plan.Drivers.Add(b.Property);

                bool strip;

                if (ZetAnimatedProperties.IsAnimated(material, b.Property))
                {
                    // An animated driver has no single value at lock time, so the
                    // block has to survive. This is the trade the user accepted
                    // when they marked it.
                    strip = false;
                    if (!plan.KeptBecauseAnimated.Contains(b.Property))
                        plan.KeptBecauseAnimated.Add(b.Property);
                }
                else if (!material.HasProperty(b.Property))
                {
                    strip = false;
                }
                else
                {
                    strip = Test(b.Op, material.GetFloat(b.Property), b.Value);
                }

                // Several blocks share a driver; if any says keep, all keep.
                bool existing;
                plan.Strip[b.Property] = plan.Strip.TryGetValue(b.Property, out existing)
                    ? existing && strip
                    : strip;
            }

            foreach (Block b in blocks)
                if (plan.Strip[b.Property])
                    plan.LinesRemoved += b.End - b.Start + 1;

            plan.Key = BuildKey(plan, material);

            var probe = new Dictionary<string, string>();
            BuildLiteralTable(plan, material, probe);
            plan.Inlined = probe.Count;

            return plan;
        }

        private static string BuildKey(Plan plan, Material material)
        {
            var sb = new StringBuilder();

            // Source content is part of the key, so editing the shader produces a
            // new generated file rather than silently reusing a stale one.
            sb.Append(Hash(string.Join("\n", plan.Lines)));
            sb.Append('-');

            // So is the integration state, because Generate() INLINES the
            // generated include. Without this, a locked file produced under a
            // different set of installed packages has the same key and gets
            // reused wholesale - the generated shader is only written when the
            // path does not already exist. That is how a pre-fix locked copy
            // survives a re-lock and keeps failing on an include that is no
            // longer there.
            sb.Append(Hash(IntegrationStamp()));
            sb.Append('-');

            plan.Drivers.Sort(StringComparer.Ordinal);
            foreach (string d in plan.Drivers)
                sb.Append(plan.Strip[d] ? '1' : '0');

            // Baked values are part of the output, so two materials share a
            // generated shader only when every baked value matches. In practice
            // that is roughly one shader per distinct material - the price of
            // actually baking rather than merely stripping.
            sb.Append('-');
            sb.Append(Hash(BuildLiteralTable(plan, material, null)));

            // Keywords are baked to defines, so they are part of the output too.
            var keywords = new List<string>(material.shaderKeywords);
            keywords.Sort(StringComparer.Ordinal);
            sb.Append('-');
            sb.Append(Hash(string.Join(",", keywords.ToArray())));

            return sb.ToString();
        }

        /// <summary>
        /// Maps each bakeable property to its HLSL literal. Animated properties
        /// are excluded and stay live uniforms - that is exactly what the flag
        /// buys. Textures cannot be inlined. Auto-generated companions such as
        /// _MainTex_ST are not shader properties, so they never appear here and
        /// stay live, which keeps UV scrolling animatable for free.
        /// </summary>
        private static string BuildLiteralTable(Plan plan, Material material,
                                                Dictionary<string, string> into)
        {
            var sb = new StringBuilder();
            Shader shader = plan.Source;
            int count = shader.GetPropertyCount();

            for (int i = 0; i < count; i++)
            {
                string name = shader.GetPropertyName(i);

                if (name == "_ShaderOptimizerEnabled") continue;
                if (!material.HasProperty(name)) continue;

                if (ZetAnimatedProperties.IsAnimated(material, name))
                {
                    if (into != null && !plan.AnimatedKept.Contains(name))
                        plan.AnimatedKept.Add(name);
                    continue;
                }

                string literal;
                switch (shader.GetPropertyType(i))
                {
                    case ShaderPropertyType.Float:
                    case ShaderPropertyType.Range:
                        literal = "(" + F(material.GetFloat(name)) + ")";
                        break;

                    case ShaderPropertyType.Int:
                        literal = "(" + F(material.GetInt(name)) + ")";
                        break;

                    case ShaderPropertyType.Color:
                    case ShaderPropertyType.Vector:
                        Vector4 v = material.GetVector(name);
                        literal = "float4(" + F(v.x) + ", " + F(v.y) + ", " +
                                  F(v.z) + ", " + F(v.w) + ")";
                        break;

                    default:
                        continue;   // textures, and anything added later
                }

                if (into != null) into[name] = literal;
                sb.Append(name).Append('=').Append(literal).Append(';');
            }

            return sb.ToString();
        }

        /// <summary>
        /// HLSL literal. Always carries a decimal point so it types as float. The
        /// caller parenthesises it so a negative value cannot meet a preceding
        /// minus and produce "a--1.0".
        /// </summary>
        private static string F(float v)
        {
            if (float.IsNaN(v) || float.IsInfinity(v)) v = 0f;

            string s = v.ToString("R", CultureInfo.InvariantCulture);
            if (s.IndexOf('.') < 0 && s.IndexOf('E') < 0 && s.IndexOf('e') < 0)
                s += ".0";
            return s;
        }

        private static string Hash(string text)
        {
            using (var md5 = System.Security.Cryptography.MD5.Create())
            {
                byte[] bytes = md5.ComputeHash(Encoding.UTF8.GetBytes(text));
                var sb = new StringBuilder();
                for (int i = 0; i < 6; i++) sb.Append(bytes[i].ToString("x2"));
                return sb.ToString();
            }
        }

        // -------------------------------------------------------------- lock

        /// <summary>
        /// Locks many materials in one pass. Use this instead of calling Lock in
        /// a loop whenever more than one material is involved.
        ///
        /// Lock() imports its generated shader with ForceSynchronousImport, which
        /// blocks until Unity has compiled it. That is correct for a single
        /// material - the caller wants the result immediately - but locking an
        /// avatar one material at a time means one blocking compile per material,
        /// serially, and each one also triggered a full-project orphan sweep.
        /// That is the bulk of the pre-upload stall.
        ///
        /// So this splits the work: write every generated shader to disk first
        /// with asset importing suspended, let Unity compile the whole batch in
        /// one go, then assign them. Cleanup runs once at the end rather than per
        /// material. Same output, one compile round trip.
        /// </summary>
        /// <returns>Number of materials locked. Failures are reported per material.</returns>
        public static int LockMany(IEnumerable<Material> materials, List<string> failures = null)
        {
            var pending = new List<PendingLock>();

            // --- phase 1: generate, with importing suspended -------------------
            // Nothing inside here may call LoadAssetAtPath on a file it just
            // wrote: while asset editing is paused the import has not happened
            // and the load returns null.
            AssetDatabase.StartAssetEditing();
            try
            {
                foreach (Material material in materials)
                {
                    if (material == null) continue;

                    string message;
                    PendingLock entry;

                    if (Prepare(material, out entry, out message)) pending.Add(entry);
                    else if (failures != null && message != null)
                        failures.Add(material.name + ": " + message);
                }
            }
            finally
            {
                // In a finally block on purpose: an exception mid-batch that left
                // asset editing suspended would leave the editor unable to import
                // anything at all, which looks like Unity itself has broken.
                AssetDatabase.StopAssetEditing();
            }

            if (pending.Count == 0) return 0;

            // Unity compiles the whole batch here.
            AssetDatabase.Refresh();

            // --- phase 2: assign ----------------------------------------------
            int locked = 0;
            var orphans = new List<Shader>();

            foreach (PendingLock entry in pending)
            {
                Shader generated = AssetDatabase.LoadAssetAtPath<Shader>(entry.OutputPath);
                if (generated == null)
                {
                    if (failures != null)
                        failures.Add(entry.Material.name + ": generated shader failed to import: " + entry.OutputPath);
                    continue;
                }

                if (entry.Previous != null && entry.Previous != generated)
                    orphans.Add(entry.Previous);

                Apply(entry, generated);
                locked++;
            }

            // One sweep for the batch. DeleteIfOrphaned walks every material in
            // the project, so calling it per material made locking an avatar
            // quadratic in project size.
            foreach (Shader orphan in orphans) DeleteIfOrphaned(orphan);

            // Flush to disk. SetDirty alone leaves the shader assignment in memory
            // only, so the next domain reload - entering play mode, recompiling a
            // script - reloads the material from disk and the assignment is gone,
            // leaving a material with no shader at all.
            if (locked > 0) AssetDatabase.SaveAssets();

            return locked;
        }

        /// <summary>Everything Lock does up to writing the generated file.</summary>
        private struct PendingLock
        {
            public Material Material;
            public Plan Plan;
            public string OutputPath;
            public Shader Previous;
            public Dictionary<string, string> Literals;
        }

        public static bool Lock(Material material, out string message)
        {
            // Never generate or assign shader assets during a play-mode transition.
            // AssetDatabase work there can be rolled back, which leaves the material
            // pointing at a shader that never imported.
            if (EditorApplication.isPlayingOrWillChangePlaymode)
            {
                message = "Cannot lock while entering or in play mode.";
                return false;
            }

            PendingLock entry;
            if (!Prepare(material, out entry, out message)) return false;

            // Single-material path: import now, because the caller wants the
            // result on this frame. LockMany defers this for the whole batch.
            AssetDatabase.ImportAsset(entry.OutputPath, ImportAssetOptions.ForceSynchronousImport);

            Shader generated = AssetDatabase.LoadAssetAtPath<Shader>(entry.OutputPath);
            if (generated == null)
            {
                message = "Generated shader failed to import: " + entry.OutputPath;
                return false;
            }

            Apply(entry, generated);

            // Persist immediately: without this the assignment is lost on the next
            // domain reload and the material comes back with no shader.
            AssetDatabase.SaveAssets();

            if (entry.Previous != null && entry.Previous != generated)
                DeleteIfOrphaned(entry.Previous);

            message = "Locked: removed " + entry.Plan.LinesRemoved + " lines, baked " +
                      entry.Literals.Count + " properties.";
            return true;
        }

        /// <summary>
        /// Builds the plan and writes the generated shader to disk. Deliberately
        /// does NOT import or load it: this runs inside StartAssetEditing during a
        /// batch, where the file exists but no asset does yet.
        /// </summary>
        private static bool Prepare(Material material, out PendingLock entry, out string message)
        {
            entry = default(PendingLock);
            message = null;

            Shader previous = null;

            if (IsLocked(material))
            {
                // Relock: bake the current values rather than refusing. The old
                // generated copy is swept once nothing points at it.
                previous = material.shader;

                string unlockMessage;
                if (!Unlock(material, out unlockMessage))
                {
                    message = "Could not unlock before relocking: " + unlockMessage;
                    return false;
                }
            }

            Plan plan = Build(material);
            if (plan.Error != null)
            {
                message = plan.Error;
                return false;
            }

            if (plan.LinesRemoved == 0 && plan.Inlined == 0)
            {
                // Nothing to strip. Generating an identical copy would only add an
                // asset and a round trip, so say so and stop.
                message = "Nothing to bake - every property is animated and no block is strippable.";
                return false;
            }

            string originalName = ReadShaderName(plan.Lines);
            if (originalName == null)
            {
                message = "Could not find the Shader \"...\" declaration.";
                return false;
            }

            string lockedName = "Hidden/Locked/" + originalName + "/" + plan.Key;
            string outPath = OutputFolder + "/" + SafeFileName(originalName) + "_" + plan.Key + ".shader";

            var literals = new Dictionary<string, string>();
            BuildLiteralTable(plan, material, literals);

            // File.Exists rather than LoadAssetAtPath: during a batch the asset
            // does not exist yet even though the file does, so an asset-level
            // check would regenerate every shader on every pass.
            if (!File.Exists(outPath))
            {
                Directory.CreateDirectory(OutputFolder);
                File.WriteAllText(outPath, Generate(plan, lockedName, literals, material));
            }

            entry = new PendingLock
            {
                Material = material,
                Plan = plan,
                OutputPath = outPath,
                Previous = previous,
                Literals = literals,
            };
            return true;
        }

        /// <summary>Points the material at its generated shader.</summary>
        private static void Apply(PendingLock entry, Shader generated)
        {
            Material material = entry.Material;

            Undo.RecordObject(material, "Lock Material");

            // Record where to come back to before swapping, so an interrupted
            // lock still leaves the material recoverable.
            material.SetOverrideTag(LockedFromTag, entry.Plan.SourcePath);
            material.SetOverrideTag(LockedIntegrationsTag, IntegrationStamp());
            material.SetOverrideTag(LockedKeyTag, entry.Plan.Key);

            // Capture before the swap and restore after. Assigning a shader can
            // drop keywords the new shader does not appear to declare, and a
            // dependency like LTCGI gates its own internals on its keyword - so
            // losing it leaves the code compiled in and doing nothing.
            string[] keywords = material.shaderKeywords;
            material.shader = generated;
            material.shaderKeywords = keywords;

            EditorUtility.SetDirty(material);
        }

        public static bool Unlock(Material material, out string message)
        {
            message = null;

            string path = material.GetTag(LockedFromTag, false, string.Empty);
            if (string.IsNullOrEmpty(path))
            {
                message = "Not locked.";
                return false;
            }

            var source = AssetDatabase.LoadAssetAtPath<Shader>(path);
            if (source == null)
            {
                message = "Original shader not found at " + path;
                return false;
            }

            Undo.RecordObject(material, "Unlock Material");

            Shader previous = material.shader;

            string[] keywords = material.shaderKeywords;
            material.shader = source;
            material.shaderKeywords = keywords;
            material.SetOverrideTag(LockedFromTag, string.Empty);
            material.SetOverrideTag(LockedIntegrationsTag, string.Empty);
            material.SetOverrideTag(LockedKeyTag, string.Empty);

            EditorUtility.SetDirty(material);
            AssetDatabase.SaveAssets();

            if (previous != source)
                DeleteIfOrphaned(previous);

            message = "Unlocked.";
            return true;
        }

        /// <summary>
        /// Removes a generated shader once no material references it. Only ever
        /// touches files under the generated folder, so a hand-written shader can
        /// never be deleted by this even if something goes wrong upstream.
        /// </summary>
        public static void DeleteIfOrphaned(Shader generated)
        {
            if (generated == null) return;

            string path = AssetDatabase.GetAssetPath(generated);
            if (string.IsNullOrEmpty(path)) return;
            if (!path.Replace('\\', '/').StartsWith(OutputFolder + "/", StringComparison.Ordinal)) return;

            foreach (string guid in AssetDatabase.FindAssets("t:Material"))
            {
                var m = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                if (m != null && m.shader == generated) return;   // still in use
            }

            AssetDatabase.DeleteAsset(path);
        }

        /// <summary>
        /// Snapshot of which integrations are currently installed, e.g.
        /// "ZET_LTCGI=1;ZET_LV_OK=0". Compared against the value stamped at lock
        /// time to detect a locked shader built against a different set.
        /// </summary>
        /// <summary>
        /// Whether this project contains any generated locked shaders. Cheap
        /// directory check used to skip work that only matters once something has
        /// actually been locked.
        /// </summary>
        public static bool HasLockedShaders()
        {
            return Directory.Exists(OutputFolder) &&
                   Directory.GetFiles(OutputFolder, "*.shader").Length > 0;
        }

        public static string IntegrationStamp()
        {
            return "ZET_LTCGI=" + (ZetIntegrationGenerator.IsAvailable("ZET_LTCGI") ? "1" : "0") +
                   ";ZET_LV_OK=" + (ZetIntegrationGenerator.IsAvailable("ZET_LV_OK") ? "1" : "0");
        }

        /// <summary>
        /// True when the material is locked against a different set of installed
        /// packages than the project has now. Unlocked materials are never stale;
        /// they resolve integrations fresh on every compile.
        /// </summary>
        public static bool IsStale(Material material)
        {
            if (material == null || !IsLocked(material)) return false;

            string stamped = material.GetTag(LockedIntegrationsTag, false, string.Empty);

            // Locked before this tag existed. Unknown rather than stale - saying
            // nothing beats crying wolf on every material locked by an older
            // version of the tool.
            if (string.IsNullOrEmpty(stamped)) return false;

            return stamped != IntegrationStamp();
        }

        public static bool IsLocked(Material material)
        {
            return material != null &&
                   !string.IsNullOrEmpty(material.GetTag(LockedFromTag, false, string.Empty));
        }

        /// <summary>The shader to read source from, whether or not it is locked.</summary>
        public static Shader ResolveSourceShader(Material material)
        {
            if (material == null) return null;

            string path = material.GetTag(LockedFromTag, false, string.Empty);
            if (!string.IsNullOrEmpty(path))
            {
                var s = AssetDatabase.LoadAssetAtPath<Shader>(path);
                if (s != null) return s;
            }

            return material.shader;
        }

        // ---------------------------------------------------------- generate

        private static string Generate(Plan plan, string lockedName,
                                       Dictionary<string, string> literals,
                                       Material material)
        {
            string parseError;
            List<Block> blocks = Parse(plan.Lines, out parseError);

            var remove = new HashSet<int>();
            foreach (Block b in blocks)
            {
                if (!plan.Strip[b.Property]) continue;
                for (int i = b.Start; i <= b.End; i++) remove.Add(i);
            }

            var sb = new StringBuilder();
            sb.AppendLine("// GENERATED - do not edit.");
            sb.AppendLine("// Locked copy of " + plan.SourcePath);
            sb.AppendLine("// Key " + plan.Key);
            foreach (string d in plan.Drivers)
                sb.AppendLine("//   " + d + ": " + (plan.Strip[d] ? "stripped" : "kept"));
            foreach (string d in plan.KeptBecauseAnimated)
                sb.AppendLine("//   " + d + " kept because it is marked animated.");
            sb.AppendLine("// Baked " + literals.Count + " properties to literals.");
            foreach (string a in plan.AnimatedKept)
                sb.AppendLine("//   " + a + " left live (animated).");
            sb.AppendLine();

            // One alternation over every bakeable name, longest first. The
            // lookarounds make it whole-token: this shader has 71 names that
            // prefix another (_Em0Scan / _Em0ScanDir), and a naive replace
            // corrupts every one of them.
            _activeLiterals = literals;

            Regex inliner = null;
            if (literals.Count > 0)
            {
                var names = new List<string>(literals.Keys);
                names.Sort((a, b) => b.Length.CompareTo(a.Length));

                var alts = new StringBuilder();
                foreach (string n in names)
                {
                    if (alts.Length > 0) alts.Append('|');
                    alts.Append(Regex.Escape(n));
                }

                inliner = new Regex(@"(?<![\w])(" + alts + @")(?![\w])", RegexOptions.Compiled);
            }

            // A locked material's keyword state is fixed, so shader_feature has
            // nothing left to vary. Each enabled keyword becomes a #define and
            // the pragma is dropped, removing the keyword axis entirely.
            //
            // Placement is the whole trick. Unity prepends CGINCLUDE to every
            // CGPROGRAM, so a define emitted where the pragma sat - inside a Pass
            // - lands after the CGINCLUDE text it is meant to guard. That is
            // precisely why keyword-guarding the LTCGI include failed under
            // Thry's optimizer. Hoisting the defines to the top of CGINCLUDE puts
            // them ahead of everything in every pass.
            HashSet<string> enabled = null;
            if (material != null)
            {
                enabled = new HashSet<string>();
                foreach (string k in material.shaderKeywords) enabled.Add(k);
            }

            var defines = new List<string>();
            if (enabled != null)
            {
                for (int i = 0; i < plan.Lines.Length; i++)
                {
                    Match sf = ShaderFeature.Match(plan.Lines[i]);
                    if (!sf.Success) continue;

                    foreach (string kw in sf.Groups["keywords"].Value.Split(
                                 new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries))
                    {
                        // "_" is the off state and never becomes a define.
                        if (kw == "_" || !enabled.Contains(kw)) continue;
                        if (!defines.Contains(kw)) defines.Add(kw);
                    }
                }
            }

            bool definesEmitted = false;

            bool renamed = false;
            bool inHlsl = false;
            bool inCbuffer = false;

            for (int i = 0; i < plan.Lines.Length; i++)
            {
                if (remove.Contains(i)) continue;

                string line = plan.Lines[i];
                string trimmed = line.TrimStart();

                // The integrations include is written NEXT TO THE SOURCE shader,
                // and locked copies are emitted into OutputFolder instead - so a
                // relative #include resolves against the wrong directory and the
                // locked shader fails to compile. Inline the file's contents
                // rather than rewriting the path: a locked shader is a snapshot,
                // and a snapshot that still reaches out to a file which can be
                // regenerated underneath it is not really frozen.
                if (trimmed.StartsWith("#include", StringComparison.Ordinal) &&
                    trimmed.Contains(GeneratedInclude))
                {
                    sb.AppendLine("// --- inlined from " + GeneratedInclude + " at lock time ---");
                    foreach (string gl in ReadGeneratedInclude(plan.SourcePath))
                        sb.AppendLine(gl);
                    sb.AppendLine("// --- end inlined block ---");
                    continue;
                }

                // Pragmas are dropped wherever they sit; the defines went in at
                // the top of CGINCLUDE instead.
                if (enabled != null && ShaderFeature.IsMatch(line)) continue;

                if (trimmed.StartsWith("CGINCLUDE") || trimmed.StartsWith("CGPROGRAM"))
                    inHlsl = true;

                if (trimmed.StartsWith("CBUFFER_START")) inCbuffer = true;

                if (!renamed)
                {
                    Match m = ShaderName.Match(line);
                    if (m.Success)
                    {
                        line = m.Groups["lead"].Value + lockedName + m.Groups["tail"].Value;
                        renamed = true;
                    }
                }

                // Substitute only inside HLSL, and never inside the cbuffer: those
                // declarations must survive as declarations or they become
                // "float (0.0);". ShaderLab render state sits outside HLSL, so
                // `Cull [_CullMode]` is untouched - baking it would need a
                // number-to-keyword table and buys nothing at runtime.
                if (inliner != null && inHlsl && !inCbuffer)
                {
                    // Split the comment off first. //ifex is itself a comment, so
                    // substituting blind rewrote the locker's own directives to
                    // "//ifex (1.0)==0" - unparseable on any later pass - and
                    // turned every explanatory comment into noise.
                    int slash = line.IndexOf("//", StringComparison.Ordinal);
                    if (slash < 0)
                    {
                        line = inliner.Replace(line, Substitute);
                    }
                    else
                    {
                        line = inliner.Replace(line.Substring(0, slash), Substitute)
                             + line.Substring(slash);
                    }
                }

                sb.AppendLine(line);

                // CGINCLUDE first if the shader has one - it reaches every pass.
                // Otherwise fall back to each CGPROGRAM individually.
                if (defines.Count > 0 && !definesEmitted &&
                    (trimmed.StartsWith("CGINCLUDE") ||
                     (trimmed.StartsWith("CGPROGRAM") && !HasCgInclude(plan.Lines))))
                {
                    sb.AppendLine("            // Baked keyword state.");
                    foreach (string kw in defines)
                        sb.AppendLine("            #define " + kw + " 1");

                    definesEmitted = trimmed.StartsWith("CGINCLUDE");
                }

                if (trimmed.StartsWith("CBUFFER_END")) inCbuffer = false;
                if (trimmed.StartsWith("ENDCG")) inHlsl = false;
            }

            return sb.ToString();
        }

        [ThreadStatic] private static Dictionary<string, string> _activeLiterals;

        private static string Substitute(Match match)
        {
            return _activeLiterals[match.Groups[1].Value];
        }

        private static bool HasCgInclude(string[] lines)
        {
            foreach (string l in lines)
                if (l.TrimStart().StartsWith("CGINCLUDE")) return true;
            return false;
        }

        private static string ReadShaderName(string[] lines)
        {
            foreach (string l in lines)
            {
                Match m = ShaderName.Match(l);
                if (m.Success) return m.Groups["name"].Value;
            }
            return null;
        }

        private static string SafeFileName(string name)
        {
            var sb = new StringBuilder();
            foreach (char c in name)
                sb.Append(char.IsLetterOrDigit(c) ? c : '_');
            return sb.ToString();
        }

        // ------------------------------------------------------------- bulk

        [MenuItem("Tools/ZetsFancyShader/Lock Selected Materials")]
        private static void LockSelected()
        {
            RunOnSelection(true);
        }

        [MenuItem("Tools/ZetsFancyShader/Unlock Selected Materials")]
        private static void UnlockSelected()
        {
            RunOnSelection(false);
        }

        private static void RunOnSelection(bool lockThem)
        {
            int done = 0, failed = 0;
            var notes = new List<string>();

            var selected = new List<Material>();
            foreach (UnityEngine.Object o in Selection.objects)
            {
                var m = o as Material;
                if (m != null) selected.Add(m);
            }

            if (lockThem)
            {
                // Batched: one compile round trip for the whole selection rather
                // than one per material.
                done = LockMany(selected, notes);
                failed = notes.Count;
            }
            else
            {
                // Unlock only swaps the shader reference back - no generation, no
                // import - so there is nothing to batch.
                foreach (Material m in selected)
                {
                    string msg;
                    if (Unlock(m, out msg)) done++;
                    else { failed++; notes.Add(m.name + ": " + msg); }
                }
            }

            AssetDatabase.SaveAssets();

            string summary = (lockThem ? "Locked " : "Unlocked ") + done + " material(s)";
            if (failed > 0) summary += ", " + failed + " skipped:\n  " + string.Join("\n  ", notes.ToArray());
            Debug.Log("[ZetsFancyShader] " + summary);
        }

        /// <summary>
        /// Deletes generated shaders nothing points at any more. Safe to run at
        /// any time: a material still using one keeps it.
        /// </summary>
        [MenuItem("Tools/ZetsFancyShader/Clean Unused Locked Shaders")]
        private static void CleanUnusedMenu()
        {
            Debug.Log("[ZetsFancyShader] Removed " + CleanUnused() + " unused locked shader(s).");
        }

        /// <summary>
        /// Deletes generated shaders nothing points at. Safe at any time: a
        /// material still using one keeps it. Returns how many were removed.
        /// </summary>
        public static int CleanUnused()
        {
            if (!Directory.Exists(OutputFolder)) return 0;

            var inUse = new HashSet<string>();
            foreach (string guid in AssetDatabase.FindAssets("t:Material"))
            {
                var m = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                if (m != null && m.shader != null)
                    inUse.Add(AssetDatabase.GetAssetPath(m.shader));
            }

            int deleted = 0;
            foreach (string guid in AssetDatabase.FindAssets("t:Shader", new[] { OutputFolder }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (inUse.Contains(path)) continue;

                AssetDatabase.DeleteAsset(path);
                deleted++;
            }

            AssetDatabase.Refresh();
            return deleted;
        }
    }
}
