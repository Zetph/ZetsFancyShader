#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    // Shader compile-time report, read from Unity's own Editor.log.
    //
    // During a build (a VRChat upload is one) Unity logs every shader pass and
    // stage it compiles: how many variants survived stripping, how many came from
    // the cache, how many were actually compiled and how much CPU time that took.
    // Nothing else in the editor surfaces this, so this tool collects it.
    //
    //   Tools > ZetsFancyShader > Start Compile Timing   - writes a marker into the log
    //   (upload / build as normal)
    //   Tools > ZetsFancyShader > Shader Compile Report  - summarises everything after the
    //                                            last marker (or the whole log)
    //
    // The summary goes to the Console and the clipboard, ready to paste.
    public static class ZetCompileReport
    {
        private const string Marker = "[ZFS] Compile timing marker";

        private static readonly Regex Header = new Regex(
            "^\\s*Compiling shader \"(?<shader>[^\"]+)\" pass \"(?<pass>[^\"]*)\" \\((?<stage>\\w+)\\)",
            RegexOptions.Compiled);
        private static readonly Regex Space = new Regex(
            "After scriptable stripping:\\s*(?<n>\\d+)", RegexOptions.Compiled);
        private static readonly Regex Full = new Regex(
            "Full variant space:\\s*(?<n>\\d+)", RegexOptions.Compiled);
        private static readonly Regex Finished = new Regex(
            "finished in (?<wall>[\\d.]+) seconds", RegexOptions.Compiled);
        private static readonly Regex Hits = new Regex(
            "Local cache hits (?<n>\\d+)", RegexOptions.Compiled);
        private static readonly Regex Compiled = new Regex(
            "compiled (?<n>\\d+) variants \\((?<cpu>[\\d.]+)s CPU time\\)", RegexOptions.Compiled);

        private class Entry
        {
            public string Shader, Pass, Stage;
            public long FullSpace, Variants, CacheHits, CompiledVariants;
            public double Wall, Cpu;
        }

        [MenuItem("Tools/ZetsFancyShader/Start Compile Timing", priority = 2000)]
        private static void StartTiming()
        {
            Debug.Log(Marker + " " + DateTime.Now.ToString("HH:mm:ss", CultureInfo.InvariantCulture) +
                      " - build or upload now, then run Tools > ZetsFancyShader > Shader Compile Report.");
        }

        [MenuItem("Tools/ZetsFancyShader/Shader Compile Report", priority = 2001)]
        private static void Report()
        {
            string path = Application.consoleLogPath;
            if (string.IsNullOrEmpty(path) || !File.Exists(path))
            {
                Debug.LogWarning("[ZFS] Editor.log not found at: " + path);
                return;
            }

            string[] lines;
            try
            {
                // Unity holds the log open for writing; share the handle.
                using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                using (var sr = new StreamReader(fs))
                    lines = sr.ReadToEnd().Split('\n');
            }
            catch (Exception e)
            {
                Debug.LogWarning("[ZFS] Could not read Editor.log: " + e.Message);
                return;
            }

            int start = 0;
            bool fromMarker = false;
            for (int i = lines.Length - 1; i >= 0; i--)
            {
                if (lines[i].Contains(Marker)) { start = i + 1; fromMarker = true; break; }
            }

            var entries = new List<Entry>();
            Entry cur = null;
            for (int i = start; i < lines.Length; i++)
            {
                string l = lines[i];
                Match m = Header.Match(l);
                if (m.Success)
                {
                    cur = new Entry
                    {
                        Shader = m.Groups["shader"].Value,
                        Pass = m.Groups["pass"].Value.Length > 0 ? m.Groups["pass"].Value : "(unnamed)",
                        Stage = m.Groups["stage"].Value
                    };
                    entries.Add(cur);
                    continue;
                }
                if (cur == null) continue;

                if ((m = Full.Match(l)).Success) cur.FullSpace = long.Parse(m.Groups["n"].Value, CultureInfo.InvariantCulture);
                if ((m = Space.Match(l)).Success) cur.Variants = long.Parse(m.Groups["n"].Value, CultureInfo.InvariantCulture);
                if ((m = Finished.Match(l)).Success)
                {
                    cur.Wall = double.Parse(m.Groups["wall"].Value, CultureInfo.InvariantCulture);
                    if ((m = Hits.Match(l)).Success) cur.CacheHits = long.Parse(m.Groups["n"].Value, CultureInfo.InvariantCulture);
                    if ((m = Compiled.Match(l)).Success)
                    {
                        cur.CompiledVariants = long.Parse(m.Groups["n"].Value, CultureInfo.InvariantCulture);
                        cur.Cpu = double.Parse(m.Groups["cpu"].Value, CultureInfo.InvariantCulture);
                    }
                    cur = null;   // block complete
                }
            }

            if (entries.Count == 0)
            {
                Debug.Log("[ZFS] No shader compilation found in Editor.log" +
                          (fromMarker ? " since the last timing marker." : ".") +
                          " Unity only logs this during builds and uploads.");
                return;
            }

            var sb = new StringBuilder();
            sb.AppendLine("ZFS shader compile report (" + (fromMarker ? "since last marker" : "whole Editor.log") + ")");

            // Per shader.
            var byShader = new Dictionary<string, Entry>();
            double totalWall = 0, totalCpu = 0;
            long totalCompiled = 0, totalHits = 0;
            foreach (Entry e in entries)
            {
                Entry s;
                if (!byShader.TryGetValue(e.Shader, out s)) byShader[e.Shader] = s = new Entry { Shader = e.Shader };
                s.Variants += e.Variants; s.CacheHits += e.CacheHits; s.CompiledVariants += e.CompiledVariants;
                s.Wall += e.Wall; s.Cpu += e.Cpu;
                totalWall += e.Wall; totalCpu += e.Cpu; totalCompiled += e.CompiledVariants; totalHits += e.CacheHits;
            }

            sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                "Total: {0} shaders, {1} variants compiled, {2} from cache, {3:F1}s wall, {4:F1}s CPU",
                byShader.Count, totalCompiled, totalHits, totalWall, totalCpu));

            // The unlocked shader in a build means a material skipped locking. It is
            // by far the most expensive thing ZFS can put in an upload, so say so.
            foreach (string name in new[] { "Zetph/ZetsFancyShader", "Zetph/ZetsFancyEyeShader" })
            {
                Entry u;
                if (byShader.TryGetValue(name, out u) && u.CompiledVariants > 0)
                    sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                        "WARNING: unlocked '{0}' was compiled ({1:F0}s wall, {2:P0} of CPU time). " +
                        "A material went into the upload unlocked - the Console lists which.",
                        name, u.Wall, totalCpu > 0 ? u.Cpu / totalCpu : 0));
            }
            sb.AppendLine();
            sb.AppendLine("Per shader (slowest first):");
            var shaders = new List<Entry>(byShader.Values);
            shaders.Sort((a, b) => b.Cpu.CompareTo(a.Cpu));
            foreach (Entry s in shaders)
                sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                    "  {0,8:F1}s CPU {1,7:F1}s wall  {2,5} compiled {3,5} cached  {4}",
                    s.Cpu, s.Wall, s.CompiledVariants, s.CacheHits, Shorten(s.Shader)));

            // Per pass + stage, across all shaders (locked copies share pass names).
            var byStage = new Dictionary<string, Entry>();
            foreach (Entry e in entries)
            {
                string k = e.Pass + " / " + e.Stage;
                Entry s;
                if (!byStage.TryGetValue(k, out s)) byStage[k] = s = new Entry { Pass = e.Pass, Stage = e.Stage };
                s.Variants += e.Variants; s.CompiledVariants += e.CompiledVariants; s.Cpu += e.Cpu; s.Wall += e.Wall;
                s.FullSpace = Math.Max(s.FullSpace, e.Variants);
            }
            sb.AppendLine();
            sb.AppendLine("Per pass / stage, all shaders (slowest first). 'per shader' = variants one copy compiles:");
            var stages = new List<Entry>(byStage.Values);
            stages.Sort((a, b) => b.Cpu.CompareTo(a.Cpu));
            int shown = 0;
            foreach (Entry s in stages)
            {
                if (shown++ >= 30) break;
                double perVariant = s.CompiledVariants > 0 ? s.Cpu / s.CompiledVariants : 0;
                sb.AppendLine(string.Format(CultureInfo.InvariantCulture,
                    "  {0,8:F1}s CPU  {1,5} compiled  {2,4} per shader  {3,6:F2}s/variant  {4} / {5}",
                    s.Cpu, s.CompiledVariants, s.FullSpace, perVariant, s.Pass, StageName(s.Stage)));
            }

            string text = sb.ToString();
            EditorGUIUtility.systemCopyBuffer = text;
            Debug.Log(text + "\n(Copied to the clipboard.)");
        }

        private static string StageName(string s)
        {
            switch (s)
            {
                case "vp": return "vertex";
                case "fp": return "fragment";
                case "gp": return "geometry";
                case "hp": return "hull";
                case "dp": return "domain";
                default: return s;
            }
        }

        // Locked copies are named Hidden/Locked/<name>/<key>, where the key is
        // "<source>-<integrations>-<strip bits>-<values>-<keywords>" hashes. Show the
        // source hash (which ZFS version it was locked from - copies with different
        // ones are locked against different shader versions) and the values hash
        // (which material it is), instead of the long key.
        private static string Shorten(string shader)
        {
            int k = shader.LastIndexOf('/');
            if (!shader.StartsWith("Hidden/Locked/", StringComparison.Ordinal) || k <= 0) return shader;

            string[] parts = shader.Substring(k + 1).Split('-');
            if (parts.Length < 5 || shader.IndexOf("Zets", StringComparison.Ordinal) < 0) return shader;

            return shader.Substring("Hidden/Locked/".Length, k - "Hidden/Locked/".Length) +
                   " [locked, version " + Head(parts[0]) + ", material " + Head(parts[3]) + "]";
        }

        private static string Head(string s) { return s.Length > 6 ? s.Substring(0, 6) : s; }
    }
}
#endif
