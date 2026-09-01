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
            if (avatar == null) return true;

            // Say so rather than silently doing nothing. This runs once per upload, and
            // the setting lives in EditorPrefs, so it survives restarts with nothing on
            // screen to say it is off - which is how an unlocked material reaches an
            // upload without anyone noticing until it renders wrong in-world.
            if (!Enabled)
            {
                Debug.LogWarning("[ZetsFancyShader] Lock On Upload is disabled, so materials were "
                                 + "uploaded unlocked. Re-enable it under Tools > ZetsFancyShader > "
                                 + "Lock On Upload.");
                return true;
            }

            // Entering play mode runs this too: VRCFury's PlayModeTrigger invokes the
            // whole VRChat preprocess pipeline so avatars behave in-editor. Locking
            // there is both pointless and destructive - it writes to the project's
            // shared materials rather than the play-mode clone, and creates shader
            // assets during a domain transition where AssetDatabase work can be rolled
            // back, leaving materials pointing at a shader that never imported.
            if (EditorApplication.isPlayingOrWillChangePlaymode) return true;

            var seen = new HashSet<Material>();
            var targets = new List<Material>();
            var failures = new List<string>();

            foreach (Renderer r in avatar.GetComponentsInChildren<Renderer>(true))
            {
                // sharedMaterials, not materials: the latter instantiates copies
                // that are thrown away, so nothing would actually be locked.
                foreach (Material m in r.sharedMaterials)
                {
                    if (m == null || !seen.Add(m)) continue;
                    if (!IsOurs(m)) continue;
                    if (ZetShaderLocker.IsLocked(m)) continue;

                    targets.Add(m);
                }
            }

            // Collected first, then locked in one batch. Calling Lock in the loop
            // above forced a synchronous shader compile per material, serially,
            // plus a full-project orphan sweep each time - which is most of what
            // made a pre-upload lock feel like a hang on a twenty-material avatar.
            int locked = ZetShaderLocker.LockMany(targets, failures);

            if (locked == 0 && targets.Count == 0)
                Debug.Log("[ZetsFancyShader] Lock On Upload: every material was already locked.");

            if (locked > 0)
            {
                // Deferred until nothing is compiling: saving mid-compile leaves
                // material thumbnails stuck on the old shader.
                if (!ShaderUtil.anythingCompiling) AssetDatabase.SaveAssets();
                else EditorApplication.update += SaveWhenIdle;
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

        private static void SaveWhenIdle()
        {
            if (ShaderUtil.anythingCompiling) return;

            EditorApplication.update -= SaveWhenIdle;
            AssetDatabase.SaveAssets();
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

        // A validate function must return bool: it tells Unity whether the item can be
        // clicked. Returning void left the item permanently greyed out, so the setting
        // could be read but never changed - which is how Lock On Upload could sit
        // switched off with no way to switch it back on.
        [MenuItem("Tools/ZetsFancyShader/Lock On Upload", true)]
        private static bool ToggleValidate()
        {
            Menu.SetChecked("Tools/ZetsFancyShader/Lock On Upload", Enabled);
            return true;
        }
    }
}

#endif
