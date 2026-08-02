// ZetsFancyShader inspector - revision 31 (Thry-compatible animated tags)
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Marks properties as animated, so a future locker knows to leave them as
    /// live uniforms instead of baking their value into the generated shader.
    ///
    /// State lives in material override tags rather than in the shader or the
    /// companion JSON, because it is a per-material decision: one avatar animates
    /// emission colour, another does not, and both use the same shader. This is
    /// the same type of storage system ThryEditor used in the original test build.
    ///
    /// Records intent so the information exists when the locker lands, and so the 
    /// inspector can warn about choices.
    /// </summary>
    public static class ZetAnimatedProperties
    {
        private const string TagPrefix = "ZetAnimated_";

        /// <summary>
        /// ThryEditor's convention was preseved: a tag named "&lt;property&gt;Animated".
        ///
        /// This was written alongside my own so external tooling can see the flag.
        /// VRCFury identifies these materials as Poiyomi; due to the _ShaderOptimizerEnabled property
        /// and warns when it animates a property that is not marked. This is intentional, so the tag
        /// it looks for is emitted rather than suppressed.
        /// </summary>
        private static string ThryTag(string propertyName)
        {
            return propertyName + "Animated";
        }

        public static bool IsAnimated(Material material, string propertyName)
        {
            if (material == null || string.IsNullOrEmpty(propertyName)) return false;

            // Either tag counts, so a material flagged by Thry-based tooling is
            // honoured without being re-marked here.
            return material.GetTag(TagPrefix + propertyName, false, string.Empty) == "1"
                || material.GetTag(ThryTag(propertyName), false, string.Empty) == "1";
        }

        /// <summary>True when every target agrees the property is animated.</summary>
        public static bool IsAnimated(UnityEngine.Object[] targets, string propertyName)
        {
            if (targets == null || targets.Length == 0) return false;

            foreach (UnityEngine.Object o in targets)
            {
                var m = o as Material;
                if (m == null) continue;
                if (!IsAnimated(m, propertyName)) return false;
            }
            return true;
        }

        public static void SetAnimated(UnityEngine.Object[] targets, string propertyName, bool animated)
        {
            if (targets == null) return;

            foreach (UnityEngine.Object o in targets)
            {
                var m = o as Material;
                if (m == null) continue;

                Undo.RecordObject(m, animated ? "Mark Property Animated" : "Unmark Property Animated");

                // An empty value removes the tag rather than leaving "0" behind,
                // material carries tags only for properties actually marked.
                m.SetOverrideTag(TagPrefix + propertyName, animated ? "1" : string.Empty);
                m.SetOverrideTag(ThryTag(propertyName), animated ? "1" : string.Empty);
                EditorUtility.SetDirty(m);
            }
        }

        /// <summary>Every property currently marked animated on a material.</summary>
        public static List<string> ListAnimated(Material material)
        {
            var found = new List<string>();
            if (material == null || material.shader == null) return found;

            Shader shader = material.shader;
            int count = shader.GetPropertyCount();
            for (int i = 0; i < count; i++)
            {
                string name = shader.GetPropertyName(i);
                if (IsAnimated(material, name)) found.Add(name);
            }

            return found;
        }

        /// <summary>
        /// Animating a property that gates an //ifex block means the block can
        /// never be removed, because its value is no longer knowable at lock time.
        /// The feature keeps working; the cost it was supposed to shed does too.
        /// </summary>
        public static string LockWarning(string propertyName)
        {
            switch (propertyName)
            {
                case "_RefractEnable":
                    return "Animating Enable Refraction keeps the GrabPass in the locked shader " +
                           "even when refraction is off. That is a full-screen copy every frame, " +
                           "on every material using this shader.";
                case "_LTCGI":
                    return "Animating LTCGI keeps its include compiled into the locked shader.";
                case "_LightVolumes":
                    return "Animating Light Volumes keeps its include compiled into the locked shader.";
                case "_OutlineStdEnable":
                    return "Animating Standard Outline keeps the outline pass in the locked shader, " +
                           "so every mesh using it draws twice.";
                default:
                    return "This property gates a block that is stripped at lock time. " +
                           "Animating it means the block is always compiled in.";
            }
        }

        /// <summary>
        /// Rewrites both tags for everything already marked. Materials flagged
        /// before the Thry-compatible tag existed only carry the old one, which
        /// leaves external tooling unable to see them.
        /// </summary>
        [MenuItem("Tools/ZetsFancyShader/Resync Animated Tags")]
        private static void ResyncTags()
        {
            int materials = 0, flags = 0;

            foreach (UnityEngine.Object o in Selection.objects)
            {
                var m = o as Material;
                if (m == null || m.shader == null) continue;

                List<string> animated = ListAnimated(m);
                if (animated.Count == 0) continue;

                Undo.RecordObject(m, "Resync Animated Tags");

                foreach (string name in animated)
                {
                    m.SetOverrideTag(TagPrefix + name, "1");
                    m.SetOverrideTag(ThryTag(name), "1");
                    flags++;
                }

                EditorUtility.SetDirty(m);
                materials++;
            }

            AssetDatabase.SaveAssets();
            Debug.Log("[ZetsFancyShader] Resynced " + flags + " animated flag(s) across " +
                      materials + " material(s).");
        }

        [MenuItem("Tools/ZetsFancyShader/List Animated Properties")]
        private static void ListForSelection()
        {
            var material = Selection.activeObject as Material;
            if (material == null)
            {
                Debug.LogError("[ZetsFancyShader] Select a material first.");
                return;
            }

            List<string> animated = ListAnimated(material);
            if (animated.Count == 0)
            {
                Debug.Log("[ZetsFancyShader] " + material.name + " has no animated properties.");
                return;
            }

            Debug.Log("[ZetsFancyShader] " + material.name + " animated properties (" +
                      animated.Count + "):\n  " + string.Join("\n  ", animated.ToArray()));
        }
    }
}
