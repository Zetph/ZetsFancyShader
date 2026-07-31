// ZetDependencyChecker.cs
// Detects ZetsFancyShader's dependencies and guides the user to any that are
// missing. Severity is tiered so the checks that actually break compilation are
// the only modal - a popup per dependency trains users to dismiss the one that
// matters.
//
//   LTCGI            - optional. Adds area light support when present.
//   VRC LightVolumes - optional, 2.1.3+. Adds voxel probe support when present.
//   AudioLink        - optional. The sampling layer is embedded in the shader,
//                      so reactive FX simply idle without it.
//
// All three are optional as of 0.3.0, so nothing here is modal any more.
// ZetIntegrationGenerator resolves LTCGI and Light Volumes availability in C#
// and writes it into Generated/ZetIntegrations.cginc, which means a project
// missing either one still compiles - the feature is simply inert. Before that,
// both includes sat inside //ifex blocks and ifex only strips at LOCK time, so
// an unlocked material compiled them unconditionally and a missing package meant
// pink materials rather than a missing feature. That was the reason for the
// modal, and the reason is gone.
//
// What is left is worth saying once per session and no louder: people who own an
// avatar built for LTCGI worlds should know why it looks flat, and a popup is
// the wrong way to tell them.
//
// ThryEditor was removed as a dependency in 0.2.0 - the package ships its own
// material inspector (ZetMaterialInspector), locker (ZetShaderLocker) and map
// packer, so there is no longer anything to detect or warn about.
//
// Uses reflection + package-manager queries only, so this compiles whether or
// not any dependency exists. Must live inside an "Editor" folder.
using System.Linq;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class ZetDependencyChecker
{
    const string SessionKey = "ZetsFancyShader_DepsChecked";

    // VPM listings, not GitHub repos. A listing page has an Add to VCC button on
    // it; a repo README leaves the user hunting for the VPM URL.
    const string LtcgiUrl        = "https://vpm.pimaker.at/";
    const string LightVolumesUrl = "https://redsim.github.io/vpmlisting/";

    // AudioLink is carried in VRChat's own curated listing, so there is no repo
    // to add - it appears in VCC's package list already. The project page is the
    // more useful link here.
    const string AudioLinkUrl    = "https://github.com/llealloo/audiolink";

    const string LightVolumesPackage = "red.sim.lightvolumes";
    const string LightVolumesMinimum = "2.1.3";

    static ZetDependencyChecker()
    {
        // Delay so all assemblies are loaded before we probe for types.
        EditorApplication.delayCall += Check;
    }

    static void Check()
    {
        if (SessionState.GetBool(SessionKey, false)) return;
        SessionState.SetBool(SessionKey, true);

        bool ltcgi = LtcgiPresent();
        bool volumes = LightVolumesPresent();

        // ---- Optional integrations. Info only - the shader compiles without them. ----
        if (!ltcgi)
            Debug.Log(
                "[ZetsFancyShader] LTCGI is not installed. Area light support stays " +
                "inactive; everything else works normally. " + LtcgiUrl);

        if (!volumes)
        {
            Debug.Log(
                "[ZetsFancyShader] VRC Light Volumes is not installed. The shader falls " +
                "back to Unity light probes, which will look flatter in worlds built " +
                "around volumes. " + LightVolumesUrl);
        }
        else
        {
            // Present, but possibly too old to expose the signature the shader
            // calls. Warning rather than info: this one is a compile error, not a
            // missing feature.
            string version = PackageVersion(LightVolumesPackage);
            if (version != null && IsOlderThan(version, LightVolumesMinimum))
                Debug.LogWarning(
                    "[ZetsFancyShader] VRC Light Volumes " + version + " is older than " +
                    LightVolumesMinimum + ". Light Volume speculars will fail to compile - " +
                    "update the package via VCC. " + LightVolumesUrl);
        }

        // ---- Fully optional: AudioLink. Reactive FX just idle. Info line. ----
        if (!AudioLinkPresent())
            Debug.Log(
                "[ZetsFancyShader] AudioLink is not installed. Audio-reactive features " +
                "will stay idle until an AudioLink object is present in the world. " +
                "This is fine - AudioLink is optional. " + AudioLinkUrl);
    }

    // --- presence probes -----------------------------------------------------
    // Type reflection is the most reliable signal: it is true only when the
    // package's assembly actually compiled into the project, which is exactly
    // the condition under which the shader's include of it will succeed.

    static bool TypeExists(params string[] typeNames)
    {
        foreach (var asm in System.AppDomain.CurrentDomain.GetAssemblies())
            foreach (var t in typeNames)
                if (asm.GetType(t) != null) return true;
        return false;
    }

    static bool LtcgiPresent()
    {
        // LTCGI's controller type; namespace is pi.LTCGI.
        return TypeExists("pi.LTCGI.LTCGI_Controller", "pi.LTCGI.LTCGI");
    }

    static bool LightVolumesPresent()
    {
        // VRC Light Volumes manager/component types (VRCLightVolumes namespace).
        return TypeExists(
            "VRCLightVolumes.LightVolumeManager",
            "VRCLightVolumes.LightVolume",
            "LightVolumeManager");
    }

    static bool AudioLinkPresent()
    {
        // AudioLink's core component; namespace VRCAudioLink (classic) or AudioLink.
        return TypeExists(
            "VRCAudioLink.AudioLink",
            "AudioLink.AudioLink",
            "VRCAudioLink.AudioLinkController");
    }

    // --- version -------------------------------------------------------------

    /// <summary>
    /// Installed version of a package, or null if it cannot be determined.
    /// Wrapped because the package-manager query is unavailable in some editor
    /// states, and a dependency check must never be the thing that throws.
    /// </summary>
    static string PackageVersion(string packageName)
    {
        try
        {
            var info = UnityEditor.PackageManager.PackageInfo
                .GetAllRegisteredPackages()
                .FirstOrDefault(p => p.name == packageName);

            return info != null ? info.version : null;
        }
        catch
        {
            return null;
        }
    }

    /// <summary>
    /// Numeric-segment comparison. Prerelease suffixes are ignored: "2.1.3-beta"
    /// compares equal to "2.1.3", which errs toward staying quiet.
    /// </summary>
    static bool IsOlderThan(string version, string minimum)
    {
        int[] a = ParseVersion(version);
        int[] b = ParseVersion(minimum);
        if (a == null || b == null) return false;

        for (int i = 0; i < 3; i++)
        {
            if (a[i] < b[i]) return true;
            if (a[i] > b[i]) return false;
        }
        return false;
    }

    static int[] ParseVersion(string version)
    {
        if (string.IsNullOrEmpty(version)) return null;

        int cut = version.IndexOfAny(new[] { '-', '+' });
        if (cut >= 0) version = version.Substring(0, cut);

        string[] parts = version.Split('.');
        var result = new int[3];

        for (int i = 0; i < 3; i++)
        {
            if (i >= parts.Length) { result[i] = 0; continue; }
            if (!int.TryParse(parts[i], out result[i])) return null;
        }
        return result;
    }
}
