// ZetsFancyShader inspector - revision 21 (content rule fix)
#if VRC_SDK_VRCSDK3

using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using VRC.SDKBase.Editor.BuildPipeline;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Locks every ZetsFancyShader material on an avatar just before upload.
    ///
    /// This is the point of the whole locker: a material somebody forgot to lock
    /// ships with a live GrabPass and 148 uniform branches that could have been
    /// constants. Relying on people to remember loses that most of the time.
    ///
    /// The whole file compiles out without the VRChat SDK, so the package still
    /// works in a plain Unity project.
    /// </summary>
    public class ZetLockOnUpload : IVRCSDKPreprocessAvatarCallback
    {
        private const string EnabledKey = "Zetph.FancyShader.LockOnUpload";

        public static bool Enabled
        {
            get { return EditorPrefs.GetBool(EnabledKey, true); }
            set { EditorPrefs.SetBool(EnabledKey, value); }
        }

        // Ahead of most SDK work but not first: anything that swaps or generates
        // materials should get to run before locking bakes their values in.
        public int callbackOrder { get { return -1000; } }

        public bool OnPreprocessAvatar(GameObject avatar)
        {
            if (!Enabled || avatar == null) return true;

            var seen = new HashSet<Material>();
            var failures = new List<string>();
            int locked = 0;

            foreach (Renderer r in avatar.GetComponentsInChildren<Renderer>(true))
            {
                // sharedMaterials, not materials: the latter instantiates copies
                // that are thrown away, so nothing would actually be locked.
                foreach (Material m in r.sharedMaterials)
                {
                    if (m == null || !seen.Add(m)) continue;
                    if (!IsOurs(m)) continue;
                    if (ZetShaderLocker.IsLocked(m)) continue;

                    string message;
                    if (ZetShaderLocker.Lock(m, out message)) locked++;
                    else failures.Add(m.name + ": " + message);
                }
            }

            if (locked > 0)
            {
                AssetDatabase.SaveAssets();
                Debug.Log("[ZetsFancyShader] Locked " + locked + " material(s) before upload.");

                // Upload is the one moment the whole project is guaranteed to be
                // in its final state, so it is the right place to sweep copies
                // nothing points at any more.
                int removed = ZetShaderLocker.CleanUnused();
                if (removed > 0)
                    Debug.Log("[ZetsFancyShader] Removed " + removed + " unused locked shader(s).");
            }

            // Never block the upload. A material that could not be locked still
            // renders correctly - it is only slower - and failing the build over
            // an optimisation would be a worse outcome than shipping unoptimised.
            foreach (string f in failures)
                Debug.LogWarning("[ZetsFancyShader] Skipped during pre-upload lock - " + f);

            return true;
        }

        private static bool IsOurs(Material m)
        {
            if (m.shader == null) return false;

            // Match on the lock-button property rather than the shader name, so
            // renamed or forked variants are still recognised.
            return m.HasProperty("_ShaderOptimizerEnabled");
        }

        [MenuItem("Tools/ZetsFancyShader/Lock On Upload")]
        private static void Toggle() { Enabled = !Enabled; }

        [MenuItem("Tools/ZetsFancyShader/Lock On Upload", true)]
        private static void ToggleValidate()
        {
            Menu.SetChecked("Tools/ZetsFancyShader/Lock On Upload", Enabled);
        }
    }
}

#endif
