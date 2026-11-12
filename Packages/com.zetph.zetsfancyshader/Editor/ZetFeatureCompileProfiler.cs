#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.Rendering;
using UnityEngine;
using Debug = UnityEngine.Debug;

namespace Zetph.FancyShader.EditorUI
{
    // Times how long the shader compiler takes for each ZFS feature.
    //
    // Switching a keyword feature on in the inspector makes Unity compile a new
    // variant of every lit pass before the material can draw it, so the wait is
    // (cost of the always-compiled code) + (cost of that feature). This measures
    // both with the same compiler Unity uses for a Windows upload (D3D11 / FXC):
    //
    //   - baseline: the ForwardBase pass with no feature keywords, every stage
    //   - each feature keyword on its own, ForwardBase fragment stage, as extra
    //     seconds and extra compiled size over the baseline
    //   - the ForwardAdd and ShadowCaster baselines
    //
    // Synchronous, and blocks the editor for a few minutes (cancellable). The
    // results go to the Console and the clipboard.
    public static class ZetFeatureCompileProfiler
    {
        private const string ShaderName = "Zetph/ZetsFancyShader";

        private static readonly string[] BaseLighting = { "DIRECTIONAL", "LIGHTPROBE_SH", "SHADOWS_SCREEN" };
        private static readonly string[] AddLighting = { "POINT", "SHADOWS_CUBE" };
        private static readonly string[] CasterLighting = { "SHADOWS_DEPTH" };

        private static readonly Regex FeaturePragma = new Regex(
            @"^\s*#pragma\s+shader_feature\w*\s+(?<k>.+?)\s*$", RegexOptions.Compiled);

        private struct Result
        {
            public string Label;
            public double Seconds;
            public int Bytes;
            public bool Ok;
            public string Error;
        }

        [MenuItem("Tools/ZetsFancyShader/Profile Feature Compile Times", priority = 2002)]
        private static void Run()
        {
            Shader shader = Shader.Find(ShaderName);
            if (shader == null) { Debug.LogWarning("[ZFS] " + ShaderName + " not found."); return; }

            string path = AssetDatabase.GetAssetPath(shader);
            if (string.IsNullOrEmpty(path) || !File.Exists(path))
            {
                Debug.LogWarning("[ZFS] Shader source not found on disk.");
                return;
            }

            if (!EditorUtility.DisplayDialog("Profile feature compile times",
                    "This compiles the shader about 40 times, one feature at a time, and blocks the editor " +
                    "for several minutes. You can cancel from the progress bar.", "Run", "Cancel"))
                return;

            string[] lines = File.ReadAllLines(path);
            List<string> baseFeatures = FeaturesOfPass(lines, "fragBase");

            ShaderData data = ShaderUtil.GetShaderData(shader);
            ShaderData.Subshader sub = data.ActiveSubshader ?? data.GetSubshader(0);

            int basePass = FindPass(sub, "fragBase");
            int addPass = FindPass(sub, "fragAdd");
            int casterPass = FindPass(sub, "fragShadow");
            if (basePass < 0)
            {
                Debug.LogWarning("[ZFS] Could not find the ForwardBase pass (fragBase).");
                return;
            }

            var sb = new StringBuilder();
            var features = new List<Result>();
            int steps = 9 + baseFeatures.Count, step = 0;

            try
            {
                ShaderData.Pass bp = sub.GetPass(basePass);

                // Warm-up: the first compile pays for starting the compiler process
                // and parsing the includes, which would otherwise be billed to
                // whatever ran first.
                if (Progress(ref step, steps, "Warming up the compiler")) return;
                Compile(bp, ShaderType.Fragment, BaseLighting, "warm-up");

                if (Progress(ref step, steps, "Baseline fragment")) return;
                Result baseFrag = Compile(bp, ShaderType.Fragment, BaseLighting, "fragment");
                if (!baseFrag.Ok)
                {
                    Debug.LogWarning("[ZFS] Baseline compile failed: " + baseFrag.Error);
                    return;
                }

                var stages = new List<Result> { baseFrag };
                foreach (ShaderType st in new[] { ShaderType.Vertex, ShaderType.Hull, ShaderType.Domain, ShaderType.Geometry })
                {
                    if (Progress(ref step, steps, "Baseline " + st)) return;
                    if (bp.HasShaderStage(st)) stages.Add(Compile(bp, st, BaseLighting, st.ToString().ToLowerInvariant()));
                }

                Result add = default(Result), caster = default(Result);
                if (Progress(ref step, steps, "ForwardAdd baseline")) return;
                if (addPass >= 0) add = Compile(sub.GetPass(addPass), ShaderType.Fragment, AddLighting, "ForwardAdd fragment");
                if (Progress(ref step, steps, "ShadowCaster baseline")) return;
                if (casterPass >= 0) caster = Compile(sub.GetPass(casterPass), ShaderType.Fragment, CasterLighting, "ShadowCaster fragment");

                foreach (string kw in baseFeatures)
                {
                    if (Progress(ref step, steps, kw)) return;
                    var keys = new List<string>(BaseLighting) { kw };
                    features.Add(Compile(bp, ShaderType.Fragment, keys.ToArray(), kw));
                }

                // ---- report ---------------------------------------------------
                double stageTotal = 0;
                foreach (Result r in stages) stageTotal += r.Seconds;

                sb.AppendLine("ZFS feature compile profile (D3D11, one variant each)");
                sb.AppendLine();
                sb.AppendLine("Baseline: ForwardBase with no feature keywords - paid by every feature toggle:");
                foreach (Result r in stages)
                    sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                        "  {0,7:F2}s  {1,6:F0} KB  {2}", r.Seconds, r.Bytes / 1024.0, r.Label));
                sb.AppendLine(string.Format(CultureInfo.InvariantCulture, "  {0,7:F2}s  total", stageTotal));
                if (add.Ok)
                    sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                        "  {0,7:F2}s  {1,6:F0} KB  {2}", add.Seconds, add.Bytes / 1024.0, add.Label));
                if (caster.Ok)
                    sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                        "  {0,7:F2}s  {1,6:F0} KB  {2}", caster.Seconds, caster.Bytes / 1024.0, caster.Label));

                sb.AppendLine();
                sb.AppendLine("Each feature on its own, ForwardBase fragment, extra over the baseline (largest first):");
                features.Sort((a, b) => b.Seconds.CompareTo(a.Seconds));
                foreach (Result r in features)
                {
                    if (!r.Ok)
                    {
                        sb.AppendLine("  FAILED  " + r.Label + ": " + r.Error);
                        continue;
                    }
                    sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                        "  {0,7:+0.00;-0.00}s  {1,7:+0;-0} KB  {2}",
                        r.Seconds - baseFrag.Seconds, (r.Bytes - baseFrag.Bytes) / 1024.0, r.Label));
                }
                sb.AppendLine();
                sb.AppendLine("Timings vary by a few tenths of a second between runs; small deltas are noise.");
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }

            string text = sb.ToString();
            EditorGUIUtility.systemCopyBuffer = text;
            Debug.Log(text + "\n(Copied to the clipboard.)");
        }

        private static bool Progress(ref int step, int steps, string what)
        {
            step++;
            return EditorUtility.DisplayCancelableProgressBar("Profiling ZFS compile times",
                what, Mathf.Clamp01((float)step / steps));
        }

        private static Result Compile(ShaderData.Pass pass, ShaderType stage, string[] keywords, string label)
        {
            var sw = Stopwatch.StartNew();
            ShaderData.VariantCompileInfo info = pass.CompileVariant(stage, keywords,
                ShaderCompilerPlatform.D3D, BuildTarget.StandaloneWindows64);
            sw.Stop();

            var r = new Result
            {
                Label = label,
                Seconds = sw.Elapsed.TotalSeconds,
                Bytes = info.ShaderData != null ? info.ShaderData.Length : 0,
                Ok = info.Success
            };

            if (!info.Success && info.Messages != null)
            {
                foreach (ShaderMessage m in info.Messages)
                    if (m.severity == ShaderCompilerMessageSeverity.Error) { r.Error = m.message; break; }
            }
            return r;
        }

        // The pass whose program declares the given fragment entry point.
        private static int FindPass(ShaderData.Subshader sub, string fragEntry)
        {
            var re = new Regex(@"#pragma\s+fragment\s+" + fragEntry + @"\b");
            for (int i = 0; i < sub.PassCount; i++)
            {
                ShaderData.Pass p = sub.GetPass(i);
                string src = p.SourceCode;
                if (!string.IsNullOrEmpty(src) && re.IsMatch(src)) return i;
            }
            return -1;
        }

        // Feature keywords declared in the CGPROGRAM block that uses this entry point.
        private static List<string> FeaturesOfPass(string[] lines, string fragEntry)
        {
            var result = new List<string>();
            var re = new Regex(@"#pragma\s+fragment\s+" + fragEntry + @"\b");
            int start = -1;

            for (int i = 0; i < lines.Length; i++)
            {
                string t = lines[i].TrimStart();
                if (t.StartsWith("CGPROGRAM", StringComparison.Ordinal)) start = i;
                if (start < 0 || !re.IsMatch(lines[i])) continue;

                for (int j = start; j < lines.Length && !lines[j].TrimStart().StartsWith("ENDCG", StringComparison.Ordinal); j++)
                {
                    Match m = FeaturePragma.Match(lines[j]);
                    if (!m.Success) continue;
                    foreach (string k in m.Groups["k"].Value.Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries))
                        if (k != "_" && !k.StartsWith("//", StringComparison.Ordinal) && !result.Contains(k)) result.Add(k);
                }
                break;
            }
            return result;
        }
    }
}
#endif
