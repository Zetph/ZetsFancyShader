// ZetsFancyShader inspector - revision 34 (renamed animated properties)
using System;
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

        // UV Tile Discard's sixteen tile toggles exist to be animated - outfit
        // toggles are the whole feature - so while UV Tile Discard is on they
        // count as animated without being marked. Otherwise locking bakes each tile
        // to its current state and every outfit toggle silently stops working.
        // Unmarking any of them (right-click > Animated on the grid) records an
        // explicit "0", which is the only thing that turns the default off.
        //
        // Tiles use Poi's names, _UDIMDiscardRow<v>_<u>, which VRCFury's "Poiyomi
        // UV Tile" action animates. The pre-0.8 names _UVTileRow<v>_<u> are still
        // read by the shader for older clips, so they are covered by the same rule.
        private const string TilePrefix = "_UDIMDiscardRow";
        private const string LegacyTilePrefix = "_UVTileRow";
        private const string TileEnable = "_UVTileDiscardEnable";

        private static readonly string[] TileNames = BuildTileNames();

        private static string[] BuildTileNames()
        {
            var names = new List<string>();
            foreach (string prefix in new[] { TilePrefix, LegacyTilePrefix })
                for (int v = 0; v < 4; v++)
                    for (int u = 0; u < 4; u++)
                        names.Add(prefix + v + "_" + u);
            return names.ToArray();
        }

        private static bool IsTile(string propertyName)
        {
            return propertyName.StartsWith(TilePrefix, StringComparison.Ordinal)
                || propertyName.StartsWith(LegacyTilePrefix, StringComparison.Ordinal);
        }

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

            string ours = material.GetTag(TagPrefix + propertyName, false, string.Empty);

            if (IsTile(propertyName))
            {
                if (ours == "0") return false;   // explicitly unmarked
                if (material.HasProperty(TileEnable) && material.GetFloat(TileEnable) > 0.5f) return true;
            }

            // Either tag counts, so a material flagged by Thry-based tooling is
            // honoured without being re-marked here. "2" is Thry's "animated and
            // renamed", which is animated too.
            string thry = material.GetTag(ThryTag(propertyName), false, string.Empty);
            return ours == "1" || ours == "2" || thry == "1" || thry == "2";
        }

        // ------------------------------------------------------- renamed

        // Thry's own tag for a custom suffix; without it the suffix is the
        // material's name. Same rule as Poi, so the name typed into VRCFury's
        // "Renamed Material" field for a Poi material works for ZFS too.
        public const string RenameSuffixTag = "thry_rename_suffix";

        /// <summary>
        /// True when the property is animated AND renamed in the locked shader to
        /// &lt;name&gt;_&lt;suffix&gt;, so a toggle can single out this material on a
        /// renderer that carries several. Same "2" tag Thry uses.
        /// </summary>
        public static bool IsRenamed(Material material, string propertyName)
        {
            if (material == null || string.IsNullOrEmpty(propertyName)) return false;
            return material.GetTag(TagPrefix + propertyName, false, string.Empty) == "2"
                || material.GetTag(ThryTag(propertyName), false, string.Empty) == "2";
        }

        /// <summary>
        /// The suffix renamed properties get: the custom tag if set, else the
        /// material's name, cleaned exactly the way Thry cleans it (spaces and
        /// anything but letters, digits and underscore removed).
        /// </summary>
        public static string RenameSuffix(Material material)
        {
            if (material == null) return string.Empty;
            return CleanSuffix(material.GetTag(RenameSuffixTag, false, material.name));
        }

        public static string CleanSuffix(string s)
        {
            if (string.IsNullOrEmpty(s)) return string.Empty;
            var sb = new System.Text.StringBuilder();
            foreach (char c in s.Trim())
            {
                bool letter = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
                bool digit = c >= '0' && c <= '9';
                if (letter || digit || c == '_') sb.Append(c);
            }
            return sb.ToString();
        }

        /// <summary>
        /// Marks one property renamed (or back to plain animated). Per property,
        /// never grouped: renaming follows what animations actually target.
        /// </summary>
        public static void SetRenamed(Material m, string propertyName, bool renamed)
        {
            if (m == null || string.IsNullOrEmpty(propertyName)) return;
            m.SetOverrideTag(TagPrefix + propertyName, renamed ? "2" : "1");
            m.SetOverrideTag(ThryTag(propertyName), renamed ? "2" : "1");
            EditorUtility.SetDirty(m);
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

            // The tile grid is one control, so its toggles move together (old names too):
            // a mix of live and baked tiles is never what anyone means.
            string[] names = IsTile(propertyName) ? TileNames : new[] { propertyName };

            foreach (UnityEngine.Object o in targets)
            {
                var m = o as Material;
                if (m == null) continue;

                Undo.RecordObject(m, animated ? "Mark Property Animated" : "Unmark Property Animated");

                foreach (string name in names)
                {
                    // An empty value removes the tag rather than leaving "0" behind,
                    // material carries tags only for properties actually marked. Tiles
                    // are the exception: for them "0" is the record of an opt-out from
                    // the animated-by-default rule above.
                    string off = IsTile(name) ? "0" : string.Empty;
                    m.SetOverrideTag(TagPrefix + name, animated ? "1" : off);
                    m.SetOverrideTag(ThryTag(name), animated ? "1" : string.Empty);
                }
                EditorUtility.SetDirty(m);
            }
        }

        /// <summary>
        /// Writes the tags for tiles that are animated by default but not yet tagged,
        /// so tools that read the tags directly (VRCFury) see them as animated too.
        /// Only writes on change, never on a locked material, and never over an
        /// opt-out. Returns true if anything was written.
        /// </summary>
        public static bool ApplyTileDefault(Material m)
        {
            if (m == null || !m.HasProperty(TileEnable) || m.GetFloat(TileEnable) < 0.5f) return false;
            if (ZetShaderLocker.IsLocked(m)) return false;

            // Opted out: leave every tile alone. Checked up front so an opt-out can
            // never end up half overwritten.
            foreach (string name in TileNames)
                if (m.GetTag(TagPrefix + name, false, string.Empty) == "0") return false;

            bool changed = false;
            foreach (string name in TileNames)
            {
                // "2" is animated-and-renamed: already animated, and must not be
                // knocked back to plain "1".
                if (IsRenamed(m, name)) continue;
                if (m.GetTag(TagPrefix + name, false, string.Empty) == "1" &&
                    m.GetTag(ThryTag(name), false, string.Empty) == "1") continue;

                m.SetOverrideTag(TagPrefix + name, "1");
                m.SetOverrideTag(ThryTag(name), "1");
                changed = true;
            }

            if (changed) EditorUtility.SetDirty(m);
            return changed;
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
        /// <summary>
        /// Marks every section enable toggle on the selected materials as animated.
        ///
        /// These are the properties people drive from a menu - Scan / Sweep, Blinking,
        /// Light Based, the AudioLink switches - and unmarked they get baked to a
        /// constant at lock time, so the toggle silently stops working. Marking them
        /// through the inspector means right-clicking each header one at a time, which
        /// is tedious across a dozen materials and impossible if the row does not
        /// answer the click. This does the lot in one action.
        /// </summary>
        [MenuItem("Tools/ZetsFancyShader/Mark Section Toggles Animated")]
        private static void MarkSectionToggles()
        {
            int materials = 0, flags = 0;

            foreach (UnityEngine.Object o in Selection.objects)
            {
                var m = o as Material;
                if (m == null || m.shader == null) continue;

                var data = ZetUIData.Load(ZetShaderLocker.ResolveSourceShader(m) ?? m.shader);
                if (data == null || data.groups == null) continue;

                var names = new List<string>();
                foreach (GroupDef g in data.groups)
                {
                    if (string.IsNullOrEmpty(g.toggle)) continue;
                    if (!m.HasProperty(g.toggle)) continue;
                    if (IsAnimated(m, g.toggle)) continue;
                    names.Add(g.toggle);
                }

                if (names.Count == 0) continue;

                Undo.RecordObject(m, "Mark Section Toggles Animated");

                foreach (string name in names)
                {
                    m.SetOverrideTag(TagPrefix + name, "1");
                    m.SetOverrideTag(ThryTag(name), "1");
                    flags++;
                }

                EditorUtility.SetDirty(m);
                materials++;
            }

            AssetDatabase.SaveAssets();
            Debug.Log("[ZetsFancyShader] Marked " + flags + " section toggle(s) animated across "
                      + materials + " material(s). Relock affected materials for it to take effect.");
        }

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
