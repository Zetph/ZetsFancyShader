// ZetsFancyShader inspector - revision 15 (single teal palette, picker removed)
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Colours and rounded-rect drawing for the material inspector.
    ///
    /// One palette, teal, applied everywhere. The multi-palette picker was removed
    /// in rev 15: five variants meant every colour decision had to work in five
    /// contexts, which is a lot of surface area for something nobody was switching.
    /// The rounded-corner toggle stays - that one is a rendering compatibility
    /// fallback, not a preference.
    /// </summary>
    public static class ZetUITheme
    {
        private const string RoundedKey = "Zetph.FancyShader.UI.Rounded";

        public const float Radius = 4f;

        private static bool? _rounded;

        /// <summary>
        /// Rounded drawing uses a GUI.DrawTexture overload that not every Unity
        /// version renders identically. If it looks wrong, turn it off and the
        /// inspector falls back to plain rectangles.
        /// </summary>
        public static bool Rounded
        {
            get
            {
                if (!_rounded.HasValue)
                    _rounded = EditorPrefs.GetBool(RoundedKey, true);
                return _rounded.Value;
            }
            set
            {
                _rounded = value;
                EditorPrefs.SetBool(RoundedKey, value);
            }
        }

        // ------------------------------------------------------------ colours

        /// <summary>The one accent hue. Everything tinted derives from this.</summary>
        private static Color AccentHue()
        {
            return new Color(0.35f, 0.80f, 0.78f);
        }

        private static bool Pro { get { return EditorGUIUtility.isProSkin; } }

        /// <summary>Header bar fill. Depth 1 is a top-level tab.</summary>
        public static Color HeaderFill(int depth, bool enabled)
        {
            Color accent = AccentHue();

            // Tinted headers read as structure; deeper levels fade toward the
            // background so nesting is legible without stacking frames.
            float alpha;
            if (depth <= 1) alpha = Pro ? 0.155f : 0.170f;
            else if (depth == 2) alpha = Pro ? 0.085f : 0.100f;
            else alpha = Pro ? 0.050f : 0.060f;

            if (!enabled) alpha *= 0.45f;

            // Lift the tint toward white on the dark skin, toward black on light,
            // so it stays a tint rather than a wash of pure hue.
            Color baseCol = Pro
                ? Color.Lerp(accent, Color.white, 0.15f)
                : Color.Lerp(accent, Color.black, 0.25f);

            baseCol.a = alpha;
            return baseCol;
        }

        /// <summary>Left accent stripe, used on top-level tabs only.</summary>
        public static Color HeaderStripe(bool enabled)
        {
            Color c = AccentHue();
            c.a = enabled ? 0.85f : 0.30f;
            return c;
        }

        /// <summary>
        /// Green marks animated state, deliberately a different hue from the
        /// accent so "this is animated" never reads as "this is a header".
        /// Teal and green sit closer together than violet and green did, so this
        /// one is pushed warmer than the old value to keep the two distinct.
        /// </summary>
        public static Color Animated(bool strong)
        {
            Color c = Pro ? new Color(0.55f, 0.88f, 0.36f) : new Color(0.24f, 0.56f, 0.12f);
            c.a = strong ? 1f : 0.75f;
            return c;
        }

        /// <summary>Outline around a section frame.</summary>
        public static Color FrameBorder(int depth, bool enabled)
        {
            float a = depth <= 1 ? 0.30f : 0.18f;
            if (!enabled) a *= 0.5f;

            return Pro ? new Color(0f, 0f, 0f, a) : new Color(0f, 0f, 0f, a * 0.6f);
        }

        // ------------------------------------------------------------ drawing

        /// <summary>Filled rounded rect. Corners are (topLeft, topRight, bottomRight, bottomLeft).</summary>
        public static void Fill(Rect rect, Color color, Vector4 corners)
        {
            if (Event.current.type != EventType.Repaint) return;

            if (!Rounded)
            {
                EditorGUI.DrawRect(rect, color);
                return;
            }

            GUI.DrawTexture(rect, Texture2D.whiteTexture, ScaleMode.StretchToFill,
                            false, 0f, color, Vector4.zero, corners);
        }

        /// <summary>Rounded outline, no fill.</summary>
        public static void Border(Rect rect, Color color, Vector4 corners, float width)
        {
            if (Event.current.type != EventType.Repaint) return;

            if (!Rounded)
            {
                // Four thin rects: cheap, and never worse than nothing.
                EditorGUI.DrawRect(new Rect(rect.x, rect.y, rect.width, width), color);
                EditorGUI.DrawRect(new Rect(rect.x, rect.yMax - width, rect.width, width), color);
                EditorGUI.DrawRect(new Rect(rect.x, rect.y, width, rect.height), color);
                EditorGUI.DrawRect(new Rect(rect.xMax - width, rect.y, width, rect.height), color);
                return;
            }

            GUI.DrawTexture(rect, Texture2D.whiteTexture, ScaleMode.StretchToFill,
                            false, 0f, color,
                            new Vector4(width, width, width, width), corners);
        }

        public static Vector4 Corners(float tl, float tr, float br, float bl)
        {
            return new Vector4(tl, tr, br, bl);
        }

        public static Vector4 AllCorners(float r) { return new Vector4(r, r, r, r); }
        public static Vector4 TopCorners(float r) { return new Vector4(r, r, 0f, 0f); }

        // -------------------------------------------------------------- menus

        [MenuItem("Tools/ZetsFancyShader/Rounded Corners")]
        private static void ToggleRounded() { Rounded = !Rounded; }

        [MenuItem("Tools/ZetsFancyShader/Rounded Corners", true)]
        private static bool RoundedOn()
        {
            Menu.SetChecked("Tools/ZetsFancyShader/Rounded Corners", Rounded);
            return true;
        }
    }
}
