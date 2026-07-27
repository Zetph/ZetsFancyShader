// ZetDependencyChecker.cs
// Detects ZetsFancyShader's dependencies and guides the user to any that are
// missing. Severity is tiered so the checks that actually break compilation are
// the only modal - a popup per dependency trains users to dismiss the one that
// matters.
//
//   LTCGI            - HARD. The shader source has a bare #include for it.
//   VRC LightVolumes - HARD, 2.1.3+. Same, plus the specular signature.
//   AudioLink        - optional. The sampling layer is embedded in the shader,
//                      so reactive FX simply idle without it. Info line.
//
// Why LTCGI and Light Volumes are HARD rather than optional: both includes sit
// inside //ifex blocks, and ifex only strips at LOCK time. An unlocked material
// compiles the include unconditionally, so a project missing either package
// fails to compile the shader at all - pink materials, not a missing feature.
// Both are declared in vpmDependencies so VCC installs them automatically; this
// check exists for legacy folder installs and manual drag-and-drop, where
// nothing resolves dependencies on the user's behalf.
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

    const string LtcgiUrl        = "https://github.com/PiMaker/ltcgi";
    const string LightVolumesUrl = "https://github.com/REDSIM/VRCLightVolumes";
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

        // ---- Hard dependencies. One modal listing everything that is missing,
        //      rather than one per package. ----
        if (!ltcgi || !volumes)
        {
            string missing = string.Empty;
            if (!ltcgi) missing += "\n  - LTCGI (at.pimaker.ltcgi)";
            if (!volumes) missing += "\n  - VRC Light Volumes (red.sim.lightvolumes) " + LightVolumesMinimum + " or newer";

            bool open = EditorUtility.DisplayDialog(
                "ZetsFancyShader - required packages missing",
                "ZetsFancyShader cannot compile without:" + missing + "\n\n" +
                "The shader includes both directly. Those includes are only stripped " +
                "when a material is locked, so an unlocked material fails to compile " +
                "outright - materials will render pink until the packages are added.\n\n" +
                "Installing ZetsFancyShader through the VRChat Creator Companion pulls " +
                "both in automatically. If you installed by dragging a folder in, add " +
                "them yourself.",
                "Open download page",
                "Later");

            if (open) Application.OpenURL(!ltcgi ? LtcgiUrl : LightVolumesUrl);
        }
        else
        {
            // Present, but possibly too old to expose the signature the shader
            // calls. Warning rather than modal: it only bites on the specular path.
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
