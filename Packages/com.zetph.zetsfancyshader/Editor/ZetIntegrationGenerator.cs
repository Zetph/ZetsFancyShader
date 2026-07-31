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

[InitializeOnLoad]
public static class ZetIntegrationGenerator
{
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

    static readonly Integration[] Integrations =
    {
        new Integration("Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc",
                        "ZET_LTCGI", "LTCGI"),

        new Integration("Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc",
                        "ZET_LV_OK", "VRC Light Volumes"),
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
    }

    /// <summary>
    /// Whether the package behind an integration symbol is present. Single source
    /// of truth with the generated cginc - both read the same Integrations table,
    /// so the inspector can never disagree with what the shader compiled.
    /// </summary>
    public static bool IsAvailable(string symbol)
    {
        if (string.IsNullOrEmpty(symbol)) return true;

        foreach (var it in Integrations)
            if (it.Symbol == symbol) return File.Exists(it.Include);

        // Unknown symbol: show the group rather than hide it on a typo.
        return true;
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
