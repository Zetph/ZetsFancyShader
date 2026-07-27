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
        public const string LockedKeyTag = "ZetLockedKey";

        private const string OutputFolder = "Assets/ZetsFancyShader/Locked";

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

        public static bool Lock(Material material, out string message)
        {
            message = null;

            Shader previous = null;

            if (IsLocked(material))
            {
                // Relock: bake the current values rather than refusing. The old
                // generated copy is swept below once nothing points at it.
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

            Shader locked = AssetDatabase.LoadAssetAtPath<Shader>(outPath);

            if (locked == null)
            {
                Directory.CreateDirectory(OutputFolder);
                File.WriteAllText(outPath, Generate(plan, lockedName, literals, material));

                AssetDatabase.ImportAsset(outPath, ImportAssetOptions.ForceSynchronousImport);
                locked = AssetDatabase.LoadAssetAtPath<Shader>(outPath);
            }

            if (locked == null)
            {
                message = "Generated shader failed to import: " + outPath;
                return false;
            }

            Undo.RecordObject(material, "Lock Material");

            // Record where to come back to before swapping, so an interrupted
            // lock still leaves the material recoverable.
            material.SetOverrideTag(LockedFromTag, plan.SourcePath);
            material.SetOverrideTag(LockedKeyTag, plan.Key);

            // Capture before the swap and restore after. Assigning a shader can
            // drop keywords the new shader does not appear to declare, and a
            // dependency like LTCGI gates its own internals on its keyword - so
            // losing it leaves the code compiled in and doing nothing.
            string[] keywords = material.shaderKeywords;
            material.shader = locked;
            material.shaderKeywords = keywords;

            EditorUtility.SetDirty(material);

            // Orphaned the instant the material stopped pointing at it. Sweeping
            // here means cleanup happens when the orphan is created rather than
            // whenever someone remembers the menu item.
            if (previous != null && previous != locked)
                DeleteIfOrphaned(previous);

            message = "Locked: removed " + plan.LinesRemoved + " lines, baked " +
                      literals.Count + " properties.";
            return true;
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
            material.SetOverrideTag(LockedKeyTag, string.Empty);

            EditorUtility.SetDirty(material);

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

            foreach (UnityEngine.Object o in Selection.objects)
            {
                var m = o as Material;
                if (m == null) continue;

                string msg;
                bool ok = lockThem ? Lock(m, out msg) : Unlock(m, out msg);

                if (ok) done++;
                else { failed++; notes.Add(m.name + ": " + msg); }
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
