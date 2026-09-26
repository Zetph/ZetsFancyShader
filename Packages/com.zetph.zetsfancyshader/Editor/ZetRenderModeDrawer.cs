using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Zetph.FancyShader.EditorUI
{
    // Draws the _AlphaMode property as a 3-way dropdown (Opaque / Cutout / Transparent)
    // and, when changed, reconfigures the material's render state so the right blending,
    // depth write, alpha-to-coverage, render queue, and override tags are applied.
    //
    // Usage in the shader Properties block:
    //     [ZetRenderMode] _AlphaMode ("Transparency Mode", Float) = 0
    // paired with the hidden drawer-managed properties (_SrcBlend/_DstBlend/_ZWrite/
    // _AlphaToMask) and the matching pass render-state hooks.
    //
    // v2 additions:
    //  - Sets the RenderType override tag per mode (Opaque / TransparentCutout /
    //    Transparent) so replacement-shader systems classify the material correctly.
    //  - Sets the VRCFallback override tag per mode (Toon / ToonCutout /
    //    ToonTransparent) so users who block the shader see a fallback that matches
    //    the material's transparency instead of an opaque Toon over cutout hair.
    //  - GrabPass ordering fix: when _RefractEnable is on, the render queue is
    //    forced above 2500 so the named GrabPass captures the skybox and other
    //    geometry; at Geometry queue it grabs an incomplete frame (black skybox).
    //    NOTE: the section toggle flips _RefractEnable, not this drawer, so the
    //    queue only re-asserts when the user touches Transparency Mode. The
    //    Refraction info box in the shader should tell users to re-pick the mode
    //    once after enabling refraction on an Opaque/Cutout material.
    //  - Undo support.
    //
    // v3 additions:
    //  - PREMULTIPLIED transparency for the eye shader. Any material whose shader
    //    carries _AlphaGlint (glass glints - eye shader only) gets
    //    Blend One OneMinusSrcAlpha in Transparent mode instead of
    //    SrcAlpha OneMinusSrcAlpha. The eye fragment applies alpha in-shader
    //    (col.rgb *= col.a) - bit-identical to straight alpha for the shaded
    //    base - and then adds environment reflections UNMULTIPLIED, so they
    //    survive base alpha 0. That is the Standard-shader "Transparent vs Fade"
    //    distinction, and it is what makes a glass cornea work as "transparency
    //    on, smoothness up" with no alpha-boost hack. Keyed off the property
    //    EXISTING, not the glint toggle being on, so flipping glints never has
    //    to touch material blend state.
    //  - Self-heal: OnGUI re-asserts the derived blend state whenever the stored
    //    _SrcBlend/_DstBlend disagree with what the current mode implies. This
    //    silently migrates materials saved before v3 (straight-alpha Transparent)
    //    the first time they are viewed in the inspector - without it, the new
    //    premultiplying shader over an old SrcAlpha material would fade alpha
    //    twice.
    //
    // IMPORTANT: this file must live inside an "Editor" folder.
    public class ZetRenderModeDrawer : MaterialPropertyDrawer
    {
        static readonly string[] s_Modes = { "Opaque", "Cutout", "Transparent" };

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return EditorGUIUtility.singleLineHeight;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            // Self-heal pass (v3): if a material's stored blend state disagrees with
            // what its mode implies (old material meeting the premultiplied eye
            // shader, or hand-edited state), re-assert. One-shot per material -
            // once Apply has run, the state matches and this no-ops.
            if (!prop.hasMixedValue)
            {
                int cur = Mathf.Clamp(Mathf.RoundToInt(prop.floatValue), 0, 2);
                foreach (Object o in prop.targets)
                {
                    Material tm = o as Material;
                    if (tm != null && BlendStateDrifted(tm, cur)) Apply(tm, cur);
                }
            }

            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = prop.hasMixedValue;
            int mode = Mathf.Clamp(Mathf.RoundToInt(prop.floatValue), 0, 2);
            mode = EditorGUI.Popup(position, label.text, mode, s_Modes);
            EditorGUI.showMixedValue = false;

            if (EditorGUI.EndChangeCheck())
            {
                prop.floatValue = mode;
                foreach (Object o in prop.targets)
                {
                    Material m = o as Material;
                    if (m != null) Apply(m, mode);
                }
            }
        }

        // Premultiplied path marker: the eye shader is the only one that declares
        // _AlphaGlint, and its transparent fragment premultiplies in-shader.
        static bool WantsPremultiply(Material m)
        {
            return m.HasProperty("_AlphaGlint");
        }

        static BlendMode ExpectedSrc(Material m, int mode)
        {
            if (mode == 2) return WantsPremultiply(m) ? BlendMode.One : BlendMode.SrcAlpha;
            return BlendMode.One;
        }

        static BlendMode ExpectedDst(int mode)
        {
            return mode == 2 ? BlendMode.OneMinusSrcAlpha : BlendMode.Zero;
        }

        static bool BlendStateDrifted(Material m, int mode)
        {
            // Blend factors only. Queue is deliberately excluded: the refraction
            // bump (below) and any user queue override are legitimate departures
            // this check must not fight.
            if (!m.HasProperty("_SrcBlend") || !m.HasProperty("_DstBlend")) return false;
            return Mathf.RoundToInt(m.GetFloat("_SrcBlend")) != (int)ExpectedSrc(m, mode)
                || Mathf.RoundToInt(m.GetFloat("_DstBlend")) != (int)ExpectedDst(mode);
        }

        // Public so it can be called from validation/import hooks to re-assert state.
        public static void Apply(Material m, int mode)
        {
            Undo.RecordObject(m, "Change Render Mode");
            switch (mode)
            {
                case 0: // Opaque: solid, writes depth, no blending
                    SetState(m, BlendMode.One, BlendMode.Zero, zWrite: 1, a2c: 0, queue: 2000,
                             renderType: "Opaque", vrcFallback: "Toon");
                    break;
                case 1: // Cutout: alpha-to-coverage (MSAA), still depth-writing
                    SetState(m, BlendMode.One, BlendMode.Zero, zWrite: 1, a2c: 1, queue: 2450,
                             renderType: "TransparentCutout", vrcFallback: "ToonCutout");
                    break;
                default: // Transparent: alpha blend, no depth write. Straight alpha for
                         // the main shader; premultiplied for the eye shader (see v3
                         // notes above) so glass reflections survive base alpha 0.
                    SetState(m, ExpectedSrc(m, 2), BlendMode.OneMinusSrcAlpha, zWrite: 0, a2c: 0, queue: 3000,
                             renderType: "Transparent", vrcFallback: "ToonTransparent");
                    break;
            }

            // GrabPass ordering: refraction must render after the skybox (2500) or
            // the grab captures an incomplete frame. Bump Opaque/Cutout queues.
            bool refract = m.HasProperty("_RefractEnable") && m.GetFloat("_RefractEnable") > 0.5f;
            if (refract && m.renderQueue <= 2500)
                m.renderQueue = 2501;
        }

        static void SetState(Material m, BlendMode src, BlendMode dst, int zWrite, int a2c, int queue,
                             string renderType, string vrcFallback)
        {
            if (m.HasProperty("_SrcBlend")) m.SetFloat("_SrcBlend", (float)src);
            if (m.HasProperty("_DstBlend")) m.SetFloat("_DstBlend", (float)dst);
            if (m.HasProperty("_ZWrite")) m.SetFloat("_ZWrite", zWrite);
            if (m.HasProperty("_AlphaToMask")) m.SetFloat("_AlphaToMask", a2c);
            m.SetOverrideTag("RenderType", renderType);
            m.SetOverrideTag("VRCFallback", vrcFallback);
            m.renderQueue = queue;
            EditorUtility.SetDirty(m);
        }
    }
}
