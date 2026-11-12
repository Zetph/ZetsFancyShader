// ZetsFancyShader material migrations - revision 1 (2nd Specular -> Clear Coat)
#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Moves settings saved by an older ZFS onto the properties that replaced
    /// them, so a material looks the same after an update without anyone
    /// re-entering values.
    ///
    /// Runs from two places, which between them cover every way a material
    /// reaches the shader:
    ///   - the inspector, whenever it draws an unlocked material;
    ///   - the locker, after unlocking and before baking, so Lock On Upload and
    ///     relocking an old locked material migrate a material nobody opened.
    ///
    /// Never touches a locked material: its values are baked into its shader,
    /// and the locker unlocks before calling this anyway. Each step is
    /// idempotent - it clears what it migrated from, so a second run finds
    /// nothing to do.
    /// </summary>
    public static class ZetMigrations
    {
        /// <summary>Applies every pending migration. True when the material changed.</summary>
        public static bool Apply(Material m)
        {
            if (m == null || m.shader == null || ZetShaderLocker.IsLocked(m)) return false;

            bool changed = false;
            changed |= Spec2ToCoat(m);

            if (changed) EditorUtility.SetDirty(m);
            return changed;
        }

        /// <summary>
        /// 2nd Specular was retired into Clear Coat's slot. Highlight Style
        /// Classic is the old highlight's formula, and Reflections Visibility 0
        /// keeps the coat from reflecting or dimming anything, so the result is
        /// the old look exactly: same tint, smoothness and mask, mask on R.
        /// GSAA is switched off and Pixel Normal Mix left at 1 because the old
        /// highlight had neither.
        /// </summary>
        private static bool Spec2ToCoat(Material m)
        {
            if (!m.HasProperty("_Spec2Enable") || !m.HasProperty("_CoatEnable") ||
                !m.HasProperty("_CoatSpecMode")) return false;
            if (m.GetFloat("_Spec2Enable") < 0.5f) return false;

            Undo.RecordObject(m, "Move 2nd Specular to Clear Coat");

            if (m.GetFloat("_CoatEnable") > 0.5f)
            {
                // Both were on: only possible on a material set up while both
                // sections existed side by side. One slot cannot hold two
                // layers, and the coat is the one the user configured most
                // recently, so it stays and the old highlight goes.
                Debug.LogWarning("[ZFS] " + m.name + ": 2nd Specular has been merged into Clear Coat, " +
                                 "which this material already uses. Kept the Clear Coat settings; the " +
                                 "old 2nd Specular highlight is no longer drawn.", m);
            }
            else
            {
                m.SetFloat("_CoatEnable", 1f);
                m.EnableKeyword("ZET_COAT");

                m.SetColor("_CoatSpecTint", m.GetColor("_Spec2Color"));
                m.SetFloat("_CoatSmoothness", m.GetFloat("_Spec2Smoothness"));
                m.SetFloat("_CoatSpecMode", 1f);

                m.SetFloat("_CoatStrength", 1f);
                m.SetFloat("_CoatSpecStrength", 1f);
                m.SetFloat("_CoatReflStrength", 0f);
                m.SetFloat("_CoatNormalMix", 1f);
                m.SetFloat("_CoatGSAA", 0f);

                // The old mask sampled UV0 with its own Tiling / Offset, red channel.
                m.SetTexture("_CoatMaps", m.GetTexture("_Spec2Mask"));
                m.SetTextureScale("_CoatMaps", m.GetTextureScale("_Spec2Mask"));
                m.SetTextureOffset("_CoatMaps", m.GetTextureOffset("_Spec2Mask"));
                m.SetFloat("_CoatMapsUV", 0f);
                m.SetVector("_CoatMapsPan", Vector4.zero);
                m.SetFloat("_CoatMaskCh", 0f);   // R
                m.SetFloat("_CoatSmoothCh", 4f); // White
                m.SetFloat("_CoatReflCh", 4f);
                m.SetFloat("_CoatSpecCh", 4f);
                m.SetFloat("_CoatMaskInvert", 0f);
                m.SetFloat("_CoatSmoothInvert", 0f);
                m.SetFloat("_CoatReflInvert", 0f);
                m.SetFloat("_CoatSpecInvert", 0f);
            }

            m.SetFloat("_Spec2Enable", 0f);
            return true;
        }
    }
}
#endif
