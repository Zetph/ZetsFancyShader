#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    // Draws a Vector property as a clickable hue / saturation colour wheel.
    //
    // Usage in the shader Properties block:
    //     [ZetColorWheel] _ColorWheel ("Colour Wheel", Vector) = (1, 0, 0, 0)
    //
    // The value lives in X and Y (Z and W are unused): the angle is the hue (red
    // at +X, counter-clockwise through green and blue) and the distance from the
    // centre is the saturation - white in the middle, full colour at the rim.
    // That is the same layout as a VRChat 2D-axis puppet, so an expressions-menu
    // colour wheel can drive _ColorWheel.x / _ColorWheel.y directly: the puppet's
    // horizontal axis to X, vertical to Y. The shader converts the wheel colour
    // from sRGB, so what you click here is what you get on the avatar.
    public class ZetColorWheelDrawer : MaterialPropertyDrawer
    {
        private const float WheelSize = 120f;
        private const int TexSize = 128;
        private static Texture2D _wheel;

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return WheelSize + EditorGUIUtility.singleLineHeight + 6f;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            if (prop.type != MaterialProperty.PropType.Vector)
            {
                EditorGUI.LabelField(position, label.text, "[ZetColorWheel] needs a Vector property");
                return;
            }

            EnsureTexture();

            Vector4 value = prop.vectorValue;
            Vector2 xy = new Vector2(value.x, value.y);

            // Label row, with numeric X / Y beside it for exact values.
            Rect labelRow = new Rect(position.x, position.y, position.width, EditorGUIUtility.singleLineHeight);
            Rect fields = EditorGUI.PrefixLabel(labelRow, label);

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            Vector2 typed = EditorGUI.Vector2Field(fields, GUIContent.none, xy);
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
                Write(prop, editor, ClampToDisc(typed), value);

            // Wheel, indented to line up with the fields.
            float left = fields.x;
            Rect wheel = new Rect(left, labelRow.yMax + 4f, WheelSize, WheelSize);
            Rect swatch = new Rect(wheel.xMax + 10f, wheel.y + WheelSize * 0.5f - 14f, 40f, 28f);

            if (Event.current.type == EventType.Repaint)
            {
                GUI.DrawTexture(wheel, _wheel, ScaleMode.StretchToFill, true);

                // Knob at the current value. GUI y runs down, the wheel's y up.
                Vector2 c = wheel.center;
                Vector2 knob = c + new Vector2(xy.x, -xy.y) * (WheelSize * 0.5f);
                Rect k = new Rect(knob.x - 5f, knob.y - 5f, 10f, 10f);
                EditorGUI.DrawRect(new Rect(k.x - 1f, k.y - 1f, k.width + 2f, k.height + 2f), Color.black);
                EditorGUI.DrawRect(k, Color.white);
                EditorGUI.DrawRect(new Rect(k.x + 2f, k.y + 2f, k.width - 4f, k.height - 4f), WheelColor(xy));

                EditorGUI.DrawRect(new Rect(swatch.x - 1f, swatch.y - 1f, swatch.width + 2f, swatch.height + 2f), Color.black);
                EditorGUI.DrawRect(swatch, WheelColor(xy));
            }

            // Click or drag anywhere on the wheel. A hot control keeps the drag
            // alive when the cursor leaves the wheel, as a slider would.
            int id = GUIUtility.GetControlID(FocusType.Passive, wheel);
            Event e = Event.current;
            switch (e.GetTypeForControl(id))
            {
                case EventType.MouseDown:
                    if (e.button == 0 && wheel.Contains(e.mousePosition) && GUI.enabled)
                    {
                        GUIUtility.hotControl = id;
                        Write(prop, editor, FromMouse(wheel, e.mousePosition), value);
                        e.Use();
                    }
                    break;
                case EventType.MouseDrag:
                    if (GUIUtility.hotControl == id)
                    {
                        Write(prop, editor, FromMouse(wheel, e.mousePosition), value);
                        e.Use();
                    }
                    break;
                case EventType.MouseUp:
                    if (GUIUtility.hotControl == id)
                    {
                        GUIUtility.hotControl = 0;
                        e.Use();
                    }
                    break;
            }
        }

        private static void Write(MaterialProperty prop, MaterialEditor editor, Vector2 xy, Vector4 old)
        {
            editor.RegisterPropertyChangeUndo(prop.displayName);
            prop.vectorValue = new Vector4(xy.x, xy.y, old.z, old.w);
            GUI.changed = true;
        }

        private static Vector2 FromMouse(Rect wheel, Vector2 mouse)
        {
            Vector2 d = (mouse - wheel.center) / (wheel.width * 0.5f);
            return ClampToDisc(new Vector2(d.x, -d.y));
        }

        private static Vector2 ClampToDisc(Vector2 v)
        {
            return v.sqrMagnitude > 1f ? v.normalized : v;
        }

        // Same mapping as the shader: hue = angle / 2pi (red at +X), saturation =
        // distance, value 1. Color.HSVToRGB returns display (sRGB) values, which is
        // what the shader's wheel colour is defined in before it converts.
        private static Color WheelColor(Vector2 xy)
        {
            float s = Mathf.Clamp01(xy.magnitude);
            float h = s > 1e-4f ? Mathf.Repeat(Mathf.Atan2(xy.y, xy.x) / (2f * Mathf.PI), 1f) : 0f;
            return Color.HSVToRGB(h, s, 1f);
        }

        private static void EnsureTexture()
        {
            if (_wheel != null) return;

            _wheel = new Texture2D(TexSize, TexSize, TextureFormat.RGBA32, false)
            {
                hideFlags = HideFlags.HideAndDontSave,
                wrapMode = TextureWrapMode.Clamp,
                filterMode = FilterMode.Bilinear
            };

            var px = new Color[TexSize * TexSize];
            float r = TexSize * 0.5f;
            for (int y = 0; y < TexSize; y++)
            {
                for (int x = 0; x < TexSize; x++)
                {
                    // Texture row 0 is the bottom, so y here already runs up.
                    Vector2 d = new Vector2((x + 0.5f - r) / r, (y + 0.5f - r) / r);
                    float len = d.magnitude;
                    Color c = WheelColor(d);
                    // One-pixel soft rim so the disc edge is not jagged.
                    c.a = Mathf.Clamp01((1f - len) * r);
                    px[y * TexSize + x] = c;
                }
            }
            _wheel.SetPixels(px);
            _wheel.Apply(false);
        }
    }
}
#endif
