// ZetIntegrationGenerator.cs
// Writes Runtime/Generated/ZetIntegrations.cginc based on which optional world
// lighting packages are actually present in the project.
//
// THE PROBLEM THIS SOLVES
// The shader used to #include LTCGI and Light Volumes directly, inside //ifex
// blocks. ifex only strips at LOCK time, so an unlocked material compiled both
// includes unconditionally - meaning a project without those packages could not
// compile the shader at all. That forced them to be hard dependencies, which
// forced every user to add two third-party VPM repos before installing anything.
//
// Neither of the in-shader alternatives worked (both documented in the shader):
// __has_include was silently eaten in locked copies, and keyword-guarding the
// include died at lock because the optimizer does not carry enabled keywords
// into the locked shader as preprocessor defines.
//
// THE FIX
// Resolve availability in C#, where the answer is knowable, and write it to a
// file the shader can always include. The shader's include list becomes fixed
// and always valid; only the CONTENTS of this one generated file vary. That
// works identically locked and unlocked, because by lock time the file is just
// an ordinary include that either does or does not define a symbol.
//
// The generated file is committed to the repo in its neutral form (nothing
// available), so a fresh install compiles before this script has ever run. A
// VPM update overwrites it with the neutral version again; the next domain
// reload regenerates it. That costs one shader reimport after an update.
//
// Must live inside an "Editor" folder.
using System.IO;
using UnityEditor;
using UnityEngine;
// ZetShaderLocker lives in this namespace; the generator itself stays in the
// global one so the shaders' own tooling can reach it without a using.
using Zetph.FancyShader.EditorUI;

[InitializeOnLoad]
public static class ZetIntegrationGenerator
{
    // Shader-side symbols each integration enables. Public so other editor
    // tooling (the dependency checker) can ask about presence by the same name
    // the generator writes, instead of repeating the string.
    public const string SymbolLtcgi = "ZET_LTCGI";
    public const string SymbolLightVolumes = "ZET_LV_OK";

    // Include paths, and the symbol each one enables in the shader.
    struct Integration
    {
        public string Include;   // path the shader would #include
        public string Symbol;    // define the shader gates its usage on
        public string Label;     // for the console line

        public Integration(string include, string symbol, string label)
        {
            Include = include; Symbol = symbol; Label = label;
        }
    }

    static readonly Integration[] Integrations = {
        new Integration("Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc",
                        SymbolLtcgi, "LTCGI"),

        new Integration("Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc",
                        SymbolLightVolumes, "VRC Light Volumes"),
    };

    // Resolved from the shader's own location rather than hardcoded. A VPM
    // install puts the package under Packages/<id>/, a .unitypackage install puts
    // it under Assets/ wherever the user dropped it, and an embedded copy can be
    // anywhere at all. Hardcoding either root means the generator writes to a
    // path the shader is not reading from - and the failure is silent, because
    // the file it creates is perfectly valid, just in the wrong place.
    const string ShaderFile = "ZetsFancyShader.shader";
    const string RelativeOutput = "Generated/ZetIntegrations.cginc";

    static string ResolveOutputPath()
    {
        foreach (var guid in AssetDatabase.FindAssets("ZetsFancyShader t:Shader"))
        {
            string path = AssetDatabase.GUIDToAssetPath(guid).Replace("\\", "/");
            if (!path.EndsWith("/" + ShaderFile)) continue;

            return path.Substring(0, path.Length - ShaderFile.Length) + RelativeOutput;
        }
        return null;
    }

    static ZetIntegrationGenerator()
    {
        // Domain reload covers script recompiles and project open. Package
        // add/remove triggers a reload too, so this is enough on its own.
        EditorApplication.delayCall += () => Generate(false);
    }

    [MenuItem("Tools/ZetsFancyShader/Regenerate Integrations")]
    static void ForceGenerate() { Generate(true); }

    static void Generate(bool verbose)
    {
        string OutputPath = ResolveOutputPath();
        if (OutputPath == null)
        {
            if (verbose)
                Debug.LogWarning("[ZetsFancyShader] Could not locate " + ShaderFile +
                                 " - integrations not generated.");
            return;
        }

        string contents = Build();

        // Only write when something changed. Writing unconditionally would
        // reimport the shaders on every domain reload, which on a shader this
        // size is a noticeable stall.
        //
        // Line endings are normalised before comparing. Git can be configured to
        // convert LF to CRLF on checkout, so the shipped file arrives as CRLF
        // while Build() emits LF - a raw compare then reports a difference on
        // every fresh clone, rewrites an identical file, and forces a pointless
        // shader reimport. Whether the content matches should not depend on how
        // the file happened to land on disk.
        if (File.Exists(OutputPath) &&
            Normalise(File.ReadAllText(OutputPath)) == Normalise(contents))
        {
            if (verbose) Debug.Log("[ZetsFancyShader] Integrations already up to date: " + OutputPath);
            return;
        }

        string dir = Path.GetDirectoryName(OutputPath);
        if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            Directory.CreateDirectory(dir);

        File.WriteAllText(OutputPath, contents);
        AssetDatabase.ImportAsset(OutputPath, ImportAssetOptions.ForceUpdate);

        // The shaders cache their resolved includes, so they need reimporting
        // for the new defines to take effect.
        ReimportShaders();

        Debug.Log("[ZetsFancyShader] Integrations regenerated: " + Summary());

        WarnAboutStaleLocks();
    }

    /// <summary>
    /// Locked shaders have their integrations inlined, so they do not follow a
    /// package change - and if a package was REMOVED, the inlined #include now
    /// points at nothing and the shader fails to compile. Materials are not
    /// re-locked automatically: locking is a deliberate, destructive-ish action
    /// and doing it silently to every material in a project on a package change
    /// would be worse than the problem. Name them instead and let the inspector
    /// offer the fix.
    /// </summary>
    static void WarnAboutStaleLocks()
    {
        var stale = new System.Collections.Generic.List<string>();

        // Locked materials live wherever the user keeps them, so there is no folder
        // to scope to - but every one of them points at a generated shader in the
        // locked output folder. If that folder does not exist, nothing in the
        // project is locked and the whole sweep can be skipped. That is the common
        // case for anyone who has not locked anything yet.
        if (!ZetShaderLocker.HasLockedShaders()) return;

        // Otherwise this does walk every material. FindAssets returns GUIDs
        // cheaply; the cost is LoadAssetAtPath deserialising each one, so bail as
        // soon as there are enough examples to report rather than loading the lot.
        foreach (var guid in AssetDatabase.FindAssets("t:Material"))
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);

            if (ZetShaderLocker.IsStale(mat)) stale.Add(path);
            if (stale.Count >= 20) break;   // enough to make the point
        }

        if (stale.Count == 0) return;

        Debug.LogWarning(
            "[ZetsFancyShader] " + stale.Count + " locked material(s) were locked against a " +
            "different set of packages and will not reflect this change until re-locked. " +
            "Select one and use Re-lock in the inspector.\n  " +
            string.Join("\n  ", stale.ToArray()));
    }

    /// <summary>
    /// Whether the package behind an integration symbol is present. Single source
    /// of truth with the generated cginc - both read the same Integrations table,
    /// so the inspector can never disagree with what the shader compiled.
    /// </summary>
    // File.Exists results, cached for the lifetime of the domain. This is called
    // from OnGUI - once per gated group, per repaint, per selected material - so
    // an uncached syscall here is a steady drip of disk access while an inspector
    // is merely open. Package installs trigger a domain reload, which clears it.
    static System.Collections.Generic.Dictionary<string, bool> _availability;

    public static bool IsAvailable(string symbol)
    {
        if (string.IsNullOrEmpty(symbol)) return true;

        if (_availability == null)
        {
            _availability = new System.Collections.Generic.Dictionary<string, bool>();
            foreach (var it in Integrations)
                _availability[it.Symbol] = File.Exists(it.Include);
        }

        // Unknown symbol: show the group rather than hide it on a typo.
        return !_availability.TryGetValue(symbol, out bool present) || present;
    }

    static string Normalise(string text)
    {
        return text.Replace("\r\n", "\n").Replace("\r", "\n");
    }

    static string Build()
    {
        var sb = new System.Text.StringBuilder();

        sb.AppendLine("// AUTO-GENERATED by ZetIntegrationGenerator.cs - do not edit.");
        sb.AppendLine("// Regenerated whenever the set of installed packages changes.");
        sb.AppendLine("// Tools > ZetsFancyShader > Regenerate Integrations forces a rebuild.");
        sb.AppendLine();
        sb.AppendLine("#ifndef ZET_INTEGRATIONS_INCLUDED");
        sb.AppendLine("#define ZET_INTEGRATIONS_INCLUDED");
        sb.AppendLine();

        foreach (var it in Integrations)
        {
            if (File.Exists(it.Include))
            {
                sb.AppendLine("// " + it.Label + ": present");
                sb.AppendLine("#include \"" + it.Include + "\"");
                sb.AppendLine("#define " + it.Symbol + " 1");
            }
            else
            {
                sb.AppendLine("// " + it.Label + ": not installed - " + it.Symbol + " stays undefined");
            }
            sb.AppendLine();
        }

        sb.AppendLine("#endif // ZET_INTEGRATIONS_INCLUDED");
        return sb.ToString();
    }

    static string Summary()
    {
        var parts = new System.Collections.Generic.List<string>();
        foreach (var it in Integrations)
            parts.Add(it.Label + (File.Exists(it.Include) ? " on" : " off"));
        return string.Join(", ", parts.ToArray());
    }

    static void ReimportShaders()
    {
        // Reimport every shader that sits beside the generated file, so this works
        // regardless of which root the package was installed into.
        string root = Path.GetDirectoryName(Path.GetDirectoryName(ResolveOutputPath()));
        if (string.IsNullOrEmpty(root)) return;

        foreach (var guid in AssetDatabase.FindAssets("t:Shader", new[] { root.Replace("\\", "/") }))
        {
            AssetDatabase.ImportAsset(AssetDatabase.GUIDToAssetPath(guid),
                                      ImportAssetOptions.ForceUpdate);
        }
    }
}
