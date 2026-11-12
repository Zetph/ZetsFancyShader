// ZetsFancyShader inspector - revision 24 (renamed animated properties, play mode renames)
#if VRC_SDK_VRCSDK3

using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
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
    /// It is also most of the upload time. An unlocked material makes the build
    /// compile the full uber shader, which costs several times more than every
    /// locked copy on the avatar put together. So "every material" has to mean
    /// every material the upload will contain, not only the ones currently on a
    /// renderer: material swaps (VRCFury / Modular Avatar toggles, hand-made FX
    /// clips) are reached only through animation clips.
    ///
    /// Materials locked from an older ZFS version are relocked too. A locked
    /// shader is a snapshot of the source it was made from, so without this a
    /// material locked months ago keeps shipping the old code - old bugs, old
    /// warnings, missing features - however many updates have landed since.
    ///
    /// The whole file compiles out without the VRChat SDK, so the package still
    /// works in a plain Unity project. It references no avatar-SDK types either,
    /// so a worlds project compiles it too.
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

            LockAvatar(avatar, false);
            return true;
        }

        /// <summary>
        /// Locks every unlocked ZFS material the avatar will upload. The late pass
        /// repeats this after every other tool has run, to catch materials that a
        /// tool ordered after -1000 swapped in or generated, and is the one that
        /// reports anything still left unlocked.
        /// </summary>
        internal static void LockAvatar(GameObject avatar, bool late)
        {
            // Entering play mode runs this too: VRCFury's PlayModeTrigger invokes the
            // whole VRChat preprocess pipeline so avatars behave in-editor. Locking
            // there is both pointless and destructive - it writes to the project's
            // shared materials rather than the play-mode clone, and creates shader
            // assets during a domain transition where AssetDatabase work can be rolled
            // back, leaving materials pointing at a shader that never imported.
            //
            // The one thing play mode does need is renamed properties (VRCFury's
            // "Renamed Material" field): with no locked shader declaring
            // <name>_<suffix>, those toggles do nothing at all. ZetRenames handles
            // that by locking COPIES of just the affected materials on the scene
            // avatar, once play mode has fully started - see ZetRenames.Schedule.
            if (EditorApplication.isPlayingOrWillChangePlaymode)
            {
                if (late) ZetRenames.Schedule(avatar);
                return;
            }

            // Renamed animated properties follow the avatar's own animations: what a
            // clip targets as <property>_<suffix> on a renderer is renamed in that
            // material's locked shader, and nothing else is. Synced before deciding
            // what to lock, so a change relocks below.
            ZetRenames.Sync(avatar);

            var targets = new List<Material>();
            var failures = new List<string>();
            var relocks = new List<string>();
            var currentSource = new Dictionary<string, string>();

            foreach (Material m in AvatarMaterials(avatar))
            {
                if (!IsOurs(m)) continue;

                if (ZetShaderLocker.IsLocked(m))
                {
                    // Already locked - but possibly from an older ZFS. That copy is a
                    // frozen snapshot of the old shader, so fixes made since never
                    // reach it, and it can bring back warnings and bugs that were
                    // already fixed. LockMany relocks a locked material in place.
                    if (IsOutdated(m, currentSource))
                    {
                        targets.Add(m);
                        relocks.Add(m.name);
                    }
                    else if (ZetRenames.Stale(m))
                    {
                        // Locked with a different set of renamed properties than the
                        // avatar's animations now target.
                        targets.Add(m);
                        relocks.Add(m.name + " (renamed properties changed)");
                    }
                    continue;
                }

                targets.Add(m);
            }

            if (relocks.Count > 0)
                Debug.Log("[ZetsFancyShader] Relocking " + relocks.Count + " material(s) locked from an older " +
                          "ZetsFancyShader version or a different set of integrations:\n  " +
                          string.Join("\n  ", relocks.ToArray()));

            // Collected first, then locked in one batch. Calling Lock in the loop
            // above forced a synchronous shader compile per material, serially,
            // plus a full-project orphan sweep each time - which is most of what
            // made a pre-upload lock feel like a hang on a twenty-material avatar.
            int locked = targets.Count > 0 ? ZetShaderLocker.LockMany(targets, failures) : 0;

            if (!late && targets.Count == 0)
                Debug.Log("[ZetsFancyShader] Lock On Upload: every material was already locked.");

            if (locked > 0)
            {
                // Deferred until nothing is compiling: saving mid-compile leaves
                // material thumbnails stuck on the old shader.
                if (!ShaderUtil.anythingCompiling) AssetDatabase.SaveAssets();
                else
                {
                    EditorApplication.update -= SaveWhenIdle;   // never hook twice
                    EditorApplication.update += SaveWhenIdle;
                }

                Debug.Log("[ZetsFancyShader] Locked " + locked + " material(s) before upload" +
                          (late ? " that only appeared after other build tools ran." : "."));

                // Upload is the one moment the whole project is guaranteed to be
                // in its final state, so it is the right place to sweep copies
                // nothing points at any more.
                //
                // Except when a build tool generated some of these materials. The
                // sweep only sees .mat files in the project, so a shader used by an
                // in-memory or sub-asset material looks unused and would be deleted
                // while that material is still being built with it. Skip the sweep
                // then; the next upload or the menu item catches up.
                if (AllProjectMaterials(targets))
                {
                    int removed = ZetShaderLocker.CleanUnused();
                    if (removed > 0)
                        Debug.Log("[ZetsFancyShader] Removed " + removed + " unused locked shader(s).");
                }
            }

            // Never block the upload. A material that could not be locked still
            // renders correctly - it is only slower - and failing the build over
            // an optimisation would be a worse outcome than shipping unoptimised.
            foreach (string f in failures)
                Debug.LogWarning("[ZetsFancyShader] Skipped during pre-upload lock - " + f);

            // Name what is going up unlocked. It is the single biggest cost in the
            // upload, and without this the only symptom is a slow build.
            if (late)
            {
                var unlocked = new List<string>();
                foreach (Material m in targets)
                    if (m != null && !ZetShaderLocker.IsLocked(m))
                        unlocked.Add(m.name + DescribePath(m));

                if (unlocked.Count > 0)
                    Debug.LogWarning("[ZetsFancyShader] " + unlocked.Count + " material(s) will upload UNLOCKED. " +
                                     "Each makes the build compile the full shader, which is the slowest part " +
                                     "of an upload:\n  " + string.Join("\n  ", unlocked.ToArray()));
            }
        }

        /// <summary>
        /// Every material the upload will contain: on renderers (including inactive
        /// ones), and keyed in animation clips on any controller the avatar uses -
        /// which is where material swaps live.
        /// </summary>
        private static List<Material> AvatarMaterials(GameObject avatar)
        {
            var result = new List<Material>();
            var seen = new HashSet<Material>();

            foreach (Renderer r in avatar.GetComponentsInChildren<Renderer>(true))
            {
                // sharedMaterials, not materials: the latter instantiates copies
                // that are thrown away, so nothing would actually be locked.
                foreach (Material m in r.sharedMaterials)
                    if (m != null && seen.Add(m)) result.Add(m);
            }

            var seenClips = new HashSet<AnimationClip>();
            foreach (RuntimeAnimatorController rac in Controllers(avatar))
            {
                // animationClips covers blend trees, sub-state machines and
                // override controllers, not just top-level states.
                foreach (AnimationClip clip in rac.animationClips)
                {
                    if (clip == null || !seenClips.Add(clip)) continue;

                    foreach (EditorCurveBinding b in AnimationUtility.GetObjectReferenceCurveBindings(clip))
                    {
                        ObjectReferenceKeyframe[] keys = AnimationUtility.GetObjectReferenceCurve(clip, b);
                        if (keys == null) continue;

                        foreach (ObjectReferenceKeyframe k in keys)
                        {
                            var m = k.value as Material;
                            if (m != null && seen.Add(m)) result.Add(m);
                        }
                    }
                }
            }

            return result;
        }

        /// <summary>
        /// Every controller with the transform its clips' binding paths are relative
        /// to: the Animator's own object, or the avatar root for the playable layers.
        /// </summary>
        internal static List<KeyValuePair<Transform, RuntimeAnimatorController>> ControllersWithRoots(GameObject avatar)
        {
            var result = new List<KeyValuePair<Transform, RuntimeAnimatorController>>();
            var seen = new HashSet<string>();

            foreach (Animator a in avatar.GetComponentsInChildren<Animator>(true))
                if (a.runtimeAnimatorController != null &&
                    seen.Add(a.transform.GetInstanceID() + "|" + a.runtimeAnimatorController.GetInstanceID()))
                    result.Add(new KeyValuePair<Transform, RuntimeAnimatorController>(a.transform, a.runtimeAnimatorController));

            foreach (RuntimeAnimatorController rac in Controllers(avatar))
                if (seen.Add(avatar.transform.GetInstanceID() + "|" + rac.GetInstanceID()))
                    result.Add(new KeyValuePair<Transform, RuntimeAnimatorController>(avatar.transform, rac));

            return result;
        }

        private static IEnumerable<RuntimeAnimatorController> Controllers(GameObject avatar)
        {
            var seen = new HashSet<RuntimeAnimatorController>();

            foreach (Animator a in avatar.GetComponentsInChildren<Animator>(true))
                if (a.runtimeAnimatorController != null && seen.Add(a.runtimeAnimatorController))
                    yield return a.runtimeAnimatorController;

            // The playable layers (FX and the rest) live on the avatar descriptor,
            // which by this point holds the controllers VRCFury / Modular Avatar
            // generated. Read through SerializedObject so this file needs none of
            // the avatar SDK's types and still compiles in a worlds project.
            foreach (Component c in avatar.GetComponents<Component>())
            {
                if (c == null || c.GetType().Name != "VRCAvatarDescriptor") continue;

                var so = new SerializedObject(c);
                foreach (string field in new[] { "baseAnimationLayers", "specialAnimationLayers" })
                {
                    SerializedProperty layers = so.FindProperty(field);
                    if (layers == null || !layers.isArray) continue;

                    for (int i = 0; i < layers.arraySize; i++)
                    {
                        SerializedProperty ctrl = layers.GetArrayElementAtIndex(i)
                                                        .FindPropertyRelative("animatorController");
                        var rac = ctrl != null ? ctrl.objectReferenceValue as RuntimeAnimatorController : null;
                        if (rac != null && seen.Add(rac)) yield return rac;
                    }
                }
            }
        }

        /// <summary>
        /// True when a locked material's generated shader was built from a different
        /// shader source than the one installed now, or against different
        /// integrations (LTCGI / Light Volumes added or removed).
        ///
        /// The lock key's first segment is a hash of the source file, so comparing
        /// that segment with a fresh key is exact: it changes when the shader file
        /// changes and for no other reason. The rest of the key (baked values,
        /// keywords) is deliberately ignored - a keyword set read back from a locked
        /// shader can differ from the one it was locked with, and treating that as
        /// outdated would relock the same material on every upload.
        /// </summary>
        private static bool IsOutdated(Material m, Dictionary<string, string> currentSource)
        {
            if (ZetShaderLocker.IsStale(m)) return true;

            string stored = m.GetTag(ZetShaderLocker.LockedKeyTag, false, string.Empty);
            if (string.IsNullOrEmpty(stored)) return false;   // locked before keys were recorded: unknown, leave it

            // One fresh key per source file is enough: the source hash does not
            // depend on the material.
            string src = m.GetTag(ZetShaderLocker.LockedFromTag, false, string.Empty);
            string now;
            if (!currentSource.TryGetValue(src, out now))
            {
                ZetShaderLocker.Plan plan = ZetShaderLocker.Build(m);
                now = (plan.Error == null && !string.IsNullOrEmpty(plan.Key)) ? SourcePart(plan.Key) : null;
                currentSource[src] = now;
            }

            // No fresh key (source missing, parse error): never relock blind.
            return now != null && SourcePart(stored) != now;
        }

        private static string SourcePart(string key)
        {
            int dash = key.IndexOf('-');
            return dash < 0 ? key : key.Substring(0, dash);
        }

        private static bool AllProjectMaterials(List<Material> materials)
        {
            foreach (Material m in materials)
                if (m != null && (!EditorUtility.IsPersistent(m) || !AssetDatabase.IsMainAsset(m)))
                    return false;
            return true;
        }

        private static string DescribePath(Material m)
        {
            string path = AssetDatabase.GetAssetPath(m);
            return string.IsNullOrEmpty(path) ? " (generated during the build)" : " (" + path + ")";
        }

        private static void SaveWhenIdle()
        {
            if (ShaderUtil.anythingCompiling) return;

            EditorApplication.update -= SaveWhenIdle;
            AssetDatabase.SaveAssets();
        }

        internal static bool IsOurs(Material m)
        {
            if (m == null || m.shader == null) return false;

            // The lock-button property, identified by its ATTRIBUTE, not just its
            // name: Poi declares the very same _ShaderOptimizerEnabled, tagged
            // [ThryShaderOptimizerLockButton], and matching on the name alone counted
            // every Poi material as ZFS - to be locked by the wrong locker. Locked ZFS
            // copies keep the Properties block, so they still match.
            int index = m.shader.FindPropertyIndex("_ShaderOptimizerEnabled");
            if (index < 0) return false;

            foreach (string attribute in m.shader.GetPropertyAttributes(index))
                if (attribute == "ZetLockButton") return true;
            return false;
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

    /// <summary>
    /// Second pass, after every other build tool. Some tools generate or swap
    /// materials late; this locks whatever they left unlocked and names anything
    /// that still could not be locked.
    /// </summary>
    public class ZetLockOnUploadLate : IVRCSDKPreprocessAvatarCallback
    {
        // Late, but not int.MaxValue: leave room for anything that must be last.
        public int callbackOrder { get { return 100000; } }

        public bool OnPreprocessAvatar(GameObject avatar)
        {
            if (avatar != null && ZetLockOnUpload.Enabled) ZetLockOnUpload.LockAvatar(avatar, true);
            return true;
        }
    }
    /// <summary>
    /// Renamed animated properties (Poi's "rename animated properties", VRCFury's
    /// "Renamed Material" field), driven by the avatar's own animations.
    ///
    /// An animation targets a renderer and a property name, and Unity applies it to
    /// every material slot on that renderer carrying that name. To single out one
    /// material, its locked shader renames the property to &lt;name&gt;_&lt;suffix&gt;.
    /// Nothing needs setting by hand: whatever a clip on the avatar targets as
    /// &lt;property&gt;_&lt;suffix&gt; on a renderer with a ZFS material is renamed in that
    /// material, with that suffix, and anything no longer targeted goes back to a
    /// plain name. With several ZFS materials on one renderer the suffix must be the
    /// material's own (its name with spaces and symbols removed, as Poi does); with
    /// one, any suffix is taken and recorded.
    ///
    /// Upload: the tags are synced on the project materials, and Lock On Upload
    /// relocks whatever changed. Play mode: project materials are never touched -
    /// copies of the affected materials are locked and swapped onto the scene avatar.
    /// </summary>
    internal static class ZetRenames
    {
        private const string Prefix = "material.";

        internal class Wanted
        {
            public readonly HashSet<string> Properties = new HashSet<string>();
            public string Suffix;
        }

        /// <summary>Upload path: sync rename tags on every ZFS material on a renderer.</summary>
        public static void Sync(GameObject avatar)
        {
            HashSet<Material> onRenderers;
            Dictionary<Material, Wanted> wanted = Scan(avatar, out onRenderers);

            var report = new List<string>();
            foreach (Material m in onRenderers)
            {
                Wanted w;
                wanted.TryGetValue(m, out w);
                if (Apply(m, w, true))
                    report.Add(m.name + ": " + (w == null || w.Properties.Count == 0
                        ? "no renamed properties"
                        : string.Join(", ", Renamed(w))));
            }

            if (report.Count > 0)
                Debug.Log("[ZetsFancyShader] Renamed animated properties updated from the avatar's animations:\n  " +
                          string.Join("\n  ", report.ToArray()));
        }

        /// <summary>
        /// Play mode: called while VRCFury processes the scene on the way into play
        /// mode, where asset work can be rolled back. So this only records what is
        /// needed, and the locking happens on the next editor tick, in play mode.
        /// </summary>
        public static void Schedule(GameObject avatar)
        {
            HashSet<Material> onRenderers;
            Dictionary<Material, Wanted> wanted = Scan(avatar, out onRenderers);
            if (wanted.Count == 0) return;

            Renderer[] renderers = avatar.GetComponentsInChildren<Renderer>(true);
            EditorApplication.delayCall += () => RunPlayMode(renderers, wanted);
        }

        private static void RunPlayMode(Renderer[] renderers, Dictionary<Material, Wanted> wanted)
        {
            if (!EditorApplication.isPlaying || EditorApplication.isCompiling) return;

            var copies = new Dictionary<Material, Material>();
            foreach (KeyValuePair<Material, Wanted> kv in wanted)
            {
                Material original = kv.Key;
                if (original == null || AlreadyRenamed(original, kv.Value)) continue;

                // Instantiate rather than new Material(...): a full copy, override
                // tags (lock state, animated flags) included.
                Material copy = UnityEngine.Object.Instantiate(original);
                copy.name = original.name + " (ZFS play mode)";
                Apply(copy, kv.Value, false);
                copies[original] = copy;
            }
            if (copies.Count == 0) return;

            var failures = new List<string>();
            ZetShaderLocker.LockMany(copies.Values, failures);
            foreach (string f in failures)
                Debug.LogWarning("[ZetsFancyShader] Play mode: could not lock a renamed copy - " + f);

            int swapped = 0;
            foreach (Renderer r in renderers)
            {
                if (r == null) continue;
                Material[] mats = r.sharedMaterials;
                bool changed = false;
                for (int i = 0; i < mats.Length; i++)
                {
                    Material copy;
                    if (mats[i] != null && copies.TryGetValue(mats[i], out copy) && ZetShaderLocker.IsLocked(copy))
                    {
                        mats[i] = copy;
                        changed = true;
                        swapped++;
                    }
                }
                if (changed) r.sharedMaterials = mats;
            }

            if (swapped > 0)
                Debug.Log("[ZetsFancyShader] Play mode: locked " + copies.Count + " material cop" +
                          (copies.Count == 1 ? "y" : "ies") + " with renamed properties so renamed toggles work. " +
                          "Your project materials are unchanged.");
        }

        /// <summary>A locked material whose shader already declares every renamed name.</summary>
        private static bool AlreadyRenamed(Material m, Wanted w)
        {
            if (!ZetShaderLocker.IsLocked(m) || m.shader == null) return false;
            foreach (string p in w.Properties)
                if (m.shader.FindPropertyIndex(p + "_" + w.Suffix) < 0) return false;
            return true;
        }

        /// <summary>
        /// Locked with a different set of renamed properties than its tags now ask
        /// for. Only builds a fresh key when renames are involved at all.
        /// </summary>
        public static bool Stale(Material m)
        {
            if (!ZetShaderLocker.IsLocked(m)) return false;

            string stored = m.GetTag(ZetShaderLocker.LockedKeyTag, false, string.Empty);
            if (string.IsNullOrEmpty(stored)) return false;

            if (ZetShaderLocker.RenamesPart(stored).Length == 0 && !HasAnyRenamed(m)) return false;

            ZetShaderLocker.Plan plan = ZetShaderLocker.Build(m);
            if (plan.Error != null || string.IsNullOrEmpty(plan.Key)) return false;

            return ZetShaderLocker.RenamesPart(plan.Key) != ZetShaderLocker.RenamesPart(stored);
        }

        // ------------------------------------------------------------- scan

        public static Dictionary<Material, Wanted> Scan(GameObject avatar, out HashSet<Material> onRenderers)
        {
            var wanted = new Dictionary<Material, Wanted>();
            onRenderers = new HashSet<Material>();

            foreach (Renderer r in avatar.GetComponentsInChildren<Renderer>(true))
                foreach (Material m in r.sharedMaterials)
                    if (ZetLockOnUpload.IsOurs(m)) onRenderers.Add(m);

            if (onRenderers.Count == 0) return wanted;

            var seen = new HashSet<string>();
            foreach (KeyValuePair<Transform, RuntimeAnimatorController> c in ZetLockOnUpload.ControllersWithRoots(avatar))
            {
                foreach (AnimationClip clip in c.Value.animationClips)
                {
                    if (clip == null) continue;

                    foreach (EditorCurveBinding b in AnimationUtility.GetCurveBindings(clip))
                    {
                        if (b.type == null || !typeof(Renderer).IsAssignableFrom(b.type)) continue;
                        if (!b.propertyName.StartsWith(Prefix, StringComparison.Ordinal)) continue;
                        if (!seen.Add(c.Key.GetInstanceID() + "|" + b.path + "|" + b.type.Name + "|" + b.propertyName))
                            continue;

                        string prop = b.propertyName.Substring(Prefix.Length);
                        int dot = prop.IndexOf('.');
                        if (dot >= 0) prop = prop.Substring(0, dot);   // vector / colour component

                        Transform t = string.IsNullOrEmpty(b.path) ? c.Key : c.Key.Find(b.path);
                        Renderer r = t != null ? t.GetComponent(b.type) as Renderer : null;
                        if (r != null) Match(r, prop, wanted);
                    }
                }
            }

            return wanted;
        }

        private static void Match(Renderer r, string prop, Dictionary<Material, Wanted> wanted)
        {
            var zfs = new List<Material>();
            foreach (Material m in r.sharedMaterials)
                if (ZetLockOnUpload.IsOurs(m) && !zfs.Contains(m)) zfs.Add(m);
            if (zfs.Count == 0) return;

            // The plain name exists: an ordinary binding, nothing to rename.
            foreach (Material m in zfs)
                if (SourceHas(m, prop)) return;

            // <property>_<suffix>, split at each underscore from the right so the
            // longest real property wins and a suffix may contain underscores itself.
            for (int i = prop.Length - 2; i > 1; i--)
            {
                if (prop[i] != '_') continue;

                string name = prop.Substring(0, i);
                string suffix = prop.Substring(i + 1);

                foreach (Material m in zfs)
                {
                    if (!SourceHas(m, name) || IsTexture(m, name)) continue;

                    // Several ZFS materials on one renderer: the suffix is what tells
                    // them apart, so it has to be this material's own.
                    if (zfs.Count > 1 && suffix != ZetAnimatedProperties.RenameSuffix(m)) continue;

                    Wanted w;
                    if (!wanted.TryGetValue(m, out w)) wanted[m] = w = new Wanted { Suffix = suffix };

                    if (w.Suffix != suffix)
                    {
                        Debug.LogWarning("[ZetsFancyShader] " + m.name + " is animated with two different renamed " +
                                         "suffixes (\"" + w.Suffix + "\" and \"" + suffix + "\"). A material has one " +
                                         "suffix; use the same Renamed Material on every toggle for it. Kept \"" +
                                         w.Suffix + "\".");
                        return;
                    }

                    w.Properties.Add(name);
                    return;
                }
            }
        }

        // ------------------------------------------------------------- tags

        /// <summary>Makes m's rename tags match w (null: nothing renamed). True if anything changed.</summary>
        private static bool Apply(Material m, Wanted w, bool undo)
        {
            Shader src = ZetShaderLocker.ResolveSourceShader(m);
            if (src == null) return false;

            bool changed = false;
            int count = src.GetPropertyCount();
            for (int i = 0; i < count; i++)
            {
                if (src.GetPropertyType(i) == ShaderPropertyType.Texture) continue;

                string name = src.GetPropertyName(i);
                bool want = w != null && w.Properties.Contains(name);
                if (want == ZetAnimatedProperties.IsRenamed(m, name)) continue;

                if (!changed && undo) Undo.RecordObject(m, "Sync Renamed Properties");
                ZetAnimatedProperties.SetRenamed(m, name, want);
                changed = true;
            }

            if (w != null && w.Properties.Count > 0 && w.Suffix != ZetAnimatedProperties.RenameSuffix(m))
            {
                if (!changed && undo) Undo.RecordObject(m, "Sync Renamed Properties");
                m.SetOverrideTag(ZetAnimatedProperties.RenameSuffixTag, w.Suffix);
                EditorUtility.SetDirty(m);
                changed = true;
            }

            return changed;
        }

        private static bool HasAnyRenamed(Material m)
        {
            Shader src = ZetShaderLocker.ResolveSourceShader(m);
            if (src == null) return false;
            int count = src.GetPropertyCount();
            for (int i = 0; i < count; i++)
                if (ZetAnimatedProperties.IsRenamed(m, src.GetPropertyName(i))) return true;
            return false;
        }

        private static bool SourceHas(Material m, string name)
        {
            Shader src = ZetShaderLocker.ResolveSourceShader(m);
            return src != null && src.FindPropertyIndex(name) >= 0;
        }

        private static bool IsTexture(Material m, string name)
        {
            Shader src = ZetShaderLocker.ResolveSourceShader(m);
            int i = src != null ? src.FindPropertyIndex(name) : -1;
            return i >= 0 && src.GetPropertyType(i) == ShaderPropertyType.Texture;
        }

        private static string[] Renamed(Wanted w)
        {
            var list = new List<string>();
            foreach (string p in w.Properties) list.Add(p + " -> " + p + "_" + w.Suffix);
            list.Sort(StringComparer.Ordinal);
            return list.ToArray();
        }
    }
}

#endif
