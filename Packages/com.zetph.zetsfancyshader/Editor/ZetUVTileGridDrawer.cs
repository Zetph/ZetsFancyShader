#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// UV Tile Discard grid, laid out like Poiyomi's so the same tiles are ticked
    /// in the same places: Row 3 (top) down to Row 0, Column 0..3 left to right.
    /// Row is the UV tile's V, Column its U - the same Row / Column VRCFury's
    /// "Poiyomi UV Tile" action asks for, so the labels map across directly.
    ///
    ///     [ZetUVTileGrid] _UDIMDiscardRow3_0 ("Discard Tiles", Float) = 0
    ///     [HideInInspector] _UDIMDiscardRow3_1 ... _UDIMDiscardRow0_3
    ///
    /// The tiles carry Poi's names because VRCFury's "Poiyomi UV Tile" toggle
    /// action animates exactly those (Row = v, Column = u). Materials from before
    /// the rename stored their tiles as _UVTileRow<v>_<u>; the grid moves those
    /// values onto the new names the first time it draws them.
    ///
    /// Attached to one tile property; the other fifteen are hidden from the
    /// regular list and drawn here. Each tile stays its own float, so it can be
    /// animated on its own.
    ///
    /// The tiles count as animated by default while UV Tile Discard is on (see
    /// ZetAnimatedProperties), so locking keeps them live and outfit toggles keep
    /// working. Right-click the grid > Animated turns that off for all sixteen.
    /// </summary>
    public class ZetUVTileGridDrawer : MaterialPropertyDrawer
    {
        private const string Prefix = "_UDIMDiscardRow";
        private const string LegacyPrefix = "_UVTileRow";
        private const float Gap = 2f;

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            // Column header, four tile rows, Show Hidden Tiles While Editing.
            return 6f * (EditorGUIUtility.singleLineHeight + Gap);
        }

        public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor)
        {
            Object[] targets = editor.targets;
            var first = targets.Length > 0 ? targets[0] as Material : null;
            if (first == null) return;

            // Tiles are animated by default; write the tags so tools that read them
            // directly (VRCFury) agree. No-op once written, or after an opt-out.
            if (Event.current.type == EventType.Layout)
                foreach (Object o in targets)
                {
                    MigrateLegacy(o as Material);
                    ZetAnimatedProperties.ApplyTileDefault(o as Material);
                }

            // What VRCFury's Renamed Material field needs to say for this material.
            string suffix = ZetAnimatedProperties.RenameSuffix(first);

            float line = EditorGUIUtility.singleLineHeight;
            var row = new Rect(position.x, position.y, position.width, line);

            // Column header, aligned to the tick boxes below it. Measured with a
            // blank (not empty) label: PrefixLabel only reserves the label column
            // for a label with content, so GUIContent.none left the header starting
            // at the far left while the rows start after their labels.
            {
                Rect field = EditorGUI.PrefixLabel(row, new GUIContent(" "));
                int indent = EditorGUI.indentLevel;
                EditorGUI.indentLevel = 0;
                float colW = field.width / 4f;
                for (int u = 0; u < 4; u++)
                    EditorGUI.LabelField(new Rect(field.x + u * colW, field.y, colW, line),
                        new GUIContent("Column " + u, "UV tile U from " + u + " to " + (u + 1) + "."),
                        EditorStyles.miniLabel);
                EditorGUI.indentLevel = indent;
                row.y += line + Gap;
            }

            for (int v = 3; v >= 0; v--)
            {
                Rect field = EditorGUI.PrefixLabel(row,
                    new GUIContent("Row " + v, "UV tile V from " + v + " to " + (v + 1) + "."));

                // PrefixLabel has already placed the field column; indenting the
                // toggles again would push the grid off its labels.
                int indent = EditorGUI.indentLevel;
                EditorGUI.indentLevel = 0;

                float colW = field.width / 4f;
                for (int u = 0; u < 4; u++)
                {
                    string name = Prefix + v + "_" + u;
                    if (!first.HasProperty(name)) continue;

                    MaterialProperty p = MaterialEditor.GetMaterialProperty(targets, name);
                    var cell = new Rect(field.x + u * colW, field.y, Mathf.Min(colW, 18f), line);

                    // Red/blue tint and keyframing in Animation-window record
                    // mode, per tile, same as any standard material field.
                    editor.BeginAnimatedCheck(cell, p);
                    EditorGUI.showMixedValue = p.hasMixedValue;
                    EditorGUI.BeginChangeCheck();
                    bool on = EditorGUI.Toggle(cell, p.floatValue > 0.001f);
                    if (EditorGUI.EndChangeCheck())
                    {
                        editor.RegisterPropertyChangeUndo("UV Tile (" + u + ", " + v + ")");
                        p.floatValue = on ? 1f : 0f;
                    }
                    EditorGUI.showMixedValue = false;
                    editor.EndAnimatedCheck();

                    // Tooltip names the property, for anyone wiring an animation
                    // or a VRCFury / Modular Avatar toggle by hand.
                    GUI.Label(cell, new GUIContent(string.Empty,
                        "Row " + v + ", Column " + u + "   " + name +
                        "\nVRCFury Poiyomi UV Tile: Row " + v + ", Column " + u + "." +
                        "\nRenamed Material: leave empty, or \"" + suffix + "\" to switch only this material " +
                        "when another ZFS material on the same mesh uses this tile too."));
                }

                EditorGUI.indentLevel = indent;
                row.y += line + Gap;
            }

            DrawShowWhileEditing(row);
        }

        /// <summary>
        /// Moves tile values saved under the pre-0.8 names onto the new ones, then
        /// clears the old ones, so the grid shows what the material actually does.
        /// The shader still reads the old names, so clips that animate them keep
        /// working; only the stored values move. Never touches a locked material,
        /// whose values are baked.
        /// </summary>
        private static void MigrateLegacy(Material m)
        {
            if (m == null || ZetShaderLocker.IsLocked(m)) return;

            bool recorded = false;
            for (int v = 0; v < 4; v++)
                for (int u = 0; u < 4; u++)
                {
                    string oldName = LegacyPrefix + v + "_" + u;
                    string newName = Prefix + v + "_" + u;
                    if (!m.HasProperty(oldName) || !m.HasProperty(newName)) continue;

                    float old = m.GetFloat(oldName);
                    if (old <= 0.001f) continue;

                    if (!recorded) { Undo.RecordObject(m, "Update UV Tile Discard"); recorded = true; }
                    m.SetFloat(newName, Mathf.Max(m.GetFloat(newName), old));
                    m.SetFloat(oldName, 0f);
                }

            if (recorded) EditorUtility.SetDirty(m);
        }

        private static void DrawShowWhileEditing(Rect row)
        {
            // An editor preference, not a material setting, so it stays clickable on
            // a locked material (whose baked rows are greyed out) and never travels
            // with one. GUI.enabled is forced rather than a DisabledScope(false),
            // which cannot re-enable inside an enclosing disabled scope.
            bool wasEnabled = GUI.enabled;
            GUI.enabled = true;

            EditorGUI.BeginChangeCheck();
            bool show = EditorGUI.Toggle(row, new GUIContent("Show Hidden Tiles While Editing",
                "Keeps hidden tiles drawn in the editor so you can see the whole mesh while setting " +
                "up. Untick to preview what will be hidden. Play mode and VRChat always hide them - " +
                "this switch lives in the editor only and is never part of an upload."),
                ZetUVTilePreview.ShowWhileEditing);
            if (EditorGUI.EndChangeCheck())
                ZetUVTilePreview.ShowWhileEditing = show;

            GUI.enabled = wasEnabled;
        }
    }

    /// <summary>
    /// Drives the shader global _ZetUVTileShowAll, which keeps hidden UV tiles
    /// drawn while editing.
    ///
    /// A global rather than a material property on purpose: material values are
    /// saved into the material and so into every upload, while shader globals
    /// exist only in the running editor. Nothing in VRChat sets this one, so
    /// in-game it reads 0 and tiles hide as normal whatever the switch says.
    ///
    /// Play mode hides tiles too, so outfit toggles behave there exactly as they
    /// will in VRChat. The switch only applies in edit mode.
    /// </summary>
    [InitializeOnLoad]
    public static class ZetUVTilePreview
    {
        private const string Key = "Zetph.FancyShader.UVTileShowWhileEditing";
        private static readonly int GlobalId = Shader.PropertyToID("_ZetUVTileShowAll");

        static ZetUVTilePreview()
        {
            // Covers both play-mode setups: with domain reload this constructor
            // runs again on entering play mode; without it, the event does.
            EditorApplication.playModeStateChanged += state => Apply();
            Apply();
        }

        public static bool ShowWhileEditing
        {
            get { return EditorPrefs.GetBool(Key, true); }
            set
            {
                EditorPrefs.SetBool(Key, value);
                Apply();
            }
        }

        public static void Apply()
        {
            bool show = ShowWhileEditing && !EditorApplication.isPlayingOrWillChangePlaymode;
            Shader.SetGlobalFloat(GlobalId, show ? 1f : 0f);
            UnityEditorInternal.InternalEditorUtility.RepaintAllViews();
        }
    }
}
#endif
