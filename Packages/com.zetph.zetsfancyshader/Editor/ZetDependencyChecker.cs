// ZetDependencyChecker.cs
// Notes which optional packages are missing. Console only.
//
//   LTCGI            - adds area light support when present.
//   VRC LightVolumes - adds voxel probe support when present, 2.1.3+.
//
// AudioLink and VRSL GI are not checked: both read globals the
// WORLD publishes, with the sampling code embedded in the shader, so there is
// nothing for the user to install.
//
// Reflection only, so this compiles with or without either package.
// Must live inside an "Editor" folder.

using System.Linq;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class ZetDependencyChecker
{
    const string SessionKey = "ZetsFancyShader_DepsChecked";

    // Listing pages, not GitHub repos: they carry an Add to VCC button.
    const string LtcgiUrl        = "https://vpm.pimaker.at/";
    const string LightVolumesUrl = "https://redsim.github.io/vpmlisting/";

    const string LightVolumesPackage = "red.sim.lightvolumes";
    const string LightVolumesMinimum = "2.1.3";

    static ZetDependencyChecker()
    {
        // Delayed so all assemblies are loaded before probing for types.
        EditorApplication.delayCall += Check;
    }

    static void Check()
    {
        if (SessionState.GetBool(SessionKey, false)) return;
        SessionState.SetBool(SessionKey, true);

        bool ltcgi = LtcgiPresent();
        bool volumes = LightVolumesPresent();

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
            // Warning, not info: too old is a compile error, not a lost feature.
            string version = PackageVersion(LightVolumesPackage);
            if (version != null && IsOlderThan(version, LightVolumesMinimum))
                Debug.LogWarning(
                    "[ZetsFancyShader] VRC Light Volumes " + version + " is older than " +
                    LightVolumesMinimum + ". Light Volume speculars will fail to compile - " +
                    "update the package via VCC. " + LightVolumesUrl);
        }
    }

    // --- presence probes -----------------------------------------------------
    // Type reflection: true only once the package's assembly has compiled

    static bool TypeExists(params string[] typeNames)
    {
        foreach (var asm in System.AppDomain.CurrentDomain.GetAssemblies())
            foreach (var t in typeNames)
                if (asm.GetType(t) != null) return true;
        return false;
    }

    static bool LtcgiPresent()
    {
        return TypeExists("pi.LTCGI.LTCGI_Controller", "pi.LTCGI.LTCGI");
    }

    static bool LightVolumesPresent()
    {
        return TypeExists(
            "VRCLightVolumes.LightVolumeManager",
            "VRCLightVolumes.LightVolume",
            "LightVolumeManager");
    }

    // --- version -------------------------------------------------------------

    /// <summary>
    /// Installed version, or null. Wrapped: the package-manager query is
    /// unavailable in some editor states, and this must never throw.
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
    /// Numeric-segment compare. Prerelease suffixes are ignored, so "2.1.3-beta"
    /// counts as 2.1.3 - errs toward staying quiet.
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
