// ZetContextMenu.cs
// Poiyomi-style right-click menu for the Project window: an "Assets/Zetph"
// submenu operating on the current selection.
//
//   Zetph
//     Lock Materials
//     Unlock Materials
//     Repair Render Mode & Tags
//     ---------------------------
//     Convert Copy to ZFS
//     ---------------------------
//     Create ZFS Material
//     Create ZFS Eye Material
//
// INSTALL: place inside any folder named "Editor".
//
// Selection handling uses SelectionMode.DeepAssets, so right-clicking a FOLDER
// applies the action to every material inside it recursively - lock a whole
// avatar's Materials folder in one click. Non-ZFS materials in the selection
// are ignored, never errored on.

using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

namespace Zetph.FancyShader.EditorUI
{
    public static class ZetContextMenu
    {
        // ---- Lock / Unlock -----------------------------------------------------

        [MenuItem("Assets/Zetph/Lock Materials", priority = 1000)]
        static void LockMaterials()
        {
            var targets = SelectedZfsMaterials(wantLocked: false);
            var notes = new List<string>();
            int done = ZetShaderLocker.LockMany(targets, notes);
            AssetDatabase.SaveAssets();
            Report("Locked " + done + " material(s)", notes);
        }

        [MenuItem("Assets/Zetph/Unlock Materials", priority = 1001)]
        static void UnlockMaterials()
        {
            int done = 0;
            var notes = new List<string>();
            foreach (var m in SelectedZfsMaterials(wantLocked: true))
            {
                string msg;
                if (ZetShaderLocker.Unlock(m, out msg)) done++;
                else notes.Add(m.name + ": " + msg);
            }
            AssetDatabase.SaveAssets();
            Report("Unlocked " + done + " material(s)", notes);
        }

        [MenuItem("Assets/Zetph/Lock Materials", true)]
        static bool ValidateLock() { return SelectedZfsMaterials(wantLocked: false).Count > 0; }

        [MenuItem("Assets/Zetph/Unlock Materials", true)]
        static bool ValidateUnlock() { return SelectedZfsMaterials(wantLocked: true).Count > 0; }

        // ---- Repair ------------------------------------------------------------

        // Re-stamps blend state, render queue, and the RenderType / VRCFallback
        // tags from each material's current Transparency Mode. This is the bulk
        // version of the inspector's self-heal: the fix for materials that were
        // created or edited while an older drawer was installed (stale blend
        // state), or that lost their override tags. Safe to run any time - a
        // correct material is left byte-identical.
        [MenuItem("Assets/Zetph/Repair Render Mode + Tags", priority = 1002)]
        static void RepairRenderMode()
        {
            int done = 0;
            foreach (var m in SelectedZfsMaterials(includeLocked: true))
            {
                if (!m.HasProperty("_AlphaMode")) continue;
                int mode = Mathf.Clamp(Mathf.RoundToInt(m.GetFloat("_AlphaMode")), 0, 2);
                ZetRenderModeDrawer.Apply(m, mode);
                done++;
            }
            AssetDatabase.SaveAssets();
            Report("Repaired render state on " + done + " material(s)", null);
        }

        [MenuItem("Assets/Zetph/Repair Render Mode + Tags", true)]
        static bool ValidateRepair() { return SelectedZfsMaterials(includeLocked: true).Count > 0; }

        // ---- Convert -----------------------------------------------------------

        // The reverse of Poiyomi's "Translate Copy to Poiyomi": clones each
        // selected non-ZFS material as "<name>_ZFS" beside the original, on the
        // ZFS body shader, translating what the shaders share. The original is
        // never touched. Same-name properties (_MainTex, _Color, _BumpMap,
        // _BumpScale, _Metallic, _Cutoff, _EmissionMap/Color, ...) carry over
        // automatically; the mappings below cover the cross-name conventions.
        [MenuItem("Assets/Zetph/Convert Copy to ZFS", priority = 1020)]
        static void ConvertCopyToZfs()
        {
            var shader = Shader.Find("Zetph/ZetsFancyShader");
            if (shader == null) { Debug.LogError("[ZetsFancyShader] Shader Zetph/ZetsFancyShader not found."); return; }

            int done = 0;
            var notes = new List<string>();
            Material last = null;

            foreach (var src in SelectedConvertibleMaterials())
            {
                string srcPath = AssetDatabase.GetAssetPath(src);
                if (string.IsNullOrEmpty(srcPath)) { notes.Add(src.name + ": not an on-disk asset"); continue; }
                string dir = System.IO.Path.GetDirectoryName(srcPath).Replace("\\", "/");
                // Materials inside installed packages are immutable; put their
                // converted copies in the project instead.
                if (dir.StartsWith("Packages/")) dir = "Assets";
                string dstPath = AssetDatabase.GenerateUniqueAssetPath(dir + "/" + src.name + "_ZFS.mat");

                var mat = new Material(shader);
                // Engine-state quarantine: Poi shares these property NAMES, so the
                // bulk copy below would import its blend, stencil, depth, polygon
                // offset, and Thry's lock flag onto a fresh material - a converted
                // copy of a locked Poi material would even claim to be locked.
                // Snapshot pristine ZFS defaults now, restore them after the copy;
                // ZetRenderModeDrawer.Apply then stamps the blend set it owns.
                var engineDefaults = new Dictionary<string, float>();
                foreach (string ep in EngineStateProps)
                    if (mat.HasProperty(ep)) engineDefaults[ep] = mat.GetFloat(ep);

                mat.CopyPropertiesFromMaterial(src);          // same-name/type properties
                mat.shaderKeywords = new string[0];           // foreign keywords are noise here
                foreach (var kv in engineDefaults) mat.SetFloat(kv.Key, kv.Value);
                Translate(src, mat, notes);
                AssetDatabase.CreateAsset(mat, dstPath);
                last = mat; done++;
            }

            AssetDatabase.SaveAssets();
            if (last != null) EditorGUIUtility.PingObject(last);
            Report("Converted " + done + " material(s) to ZFS copies", notes);
        }

        [MenuItem("Assets/Zetph/Convert Copy to ZFS", true)]
        static bool ValidateConvert() { return SelectedConvertibleMaterials().Count > 0; }

        static List<Material> SelectedConvertibleMaterials()
        {
            var found = new List<Material>();
            foreach (var m in SelectedMaterialAssets())
            {
                if (m == null || m.shader == null) continue;
                if (m.shader.name.StartsWith("Zetph/") || ZetShaderLocker.IsLocked(m)) continue;
                found.Add(m);
            }
            return found;
        }

        static readonly string[] EngineStateProps = {
            "_SrcBlend", "_DstBlend", "_ZWrite", "_ZTest", "_ColorMask",
            "_OffsetFactor", "_OffsetUnits",
            "_StencilRef", "_StencilReadMask", "_StencilWriteMask",
            "_StencilComp", "_StencilPass", "_StencilFail", "_StencilZFail",
            "_ShaderOptimizerEnabled", "_AlphaToMask"
        };

        static void Translate(Material src, Material dst, List<string> notes)
        {
            // ---- Standard-convention sources (Standard, liltoon-ish) ----------
            // Standard / older shaders call smoothness _Glossiness.
            if (src.HasProperty("_Glossiness") && dst.HasProperty("_Smoothness"))
                dst.SetFloat("_Smoothness", src.GetFloat("_Glossiness"));

            // Standard's metallic-smoothness map (R = metallic, A = smoothness):
            // ZFS reads that layout natively as Packed Map Format = Unity
            // MetalSmooth, so the map slots straight in.
            if (src.HasProperty("_MetallicGlossMap") && src.GetTexture("_MetallicGlossMap") != null
                && dst.HasProperty("_PackedMap"))
            {
                dst.SetTexture("_PackedMap", src.GetTexture("_MetallicGlossMap"));
                dst.SetFloat("_PackMode", 1f);
                dst.SetFloat("_Metallic", 1f);   // with a map, Standard lets the map drive it
                dst.SetFloat("_Smoothness", src.HasProperty("_GlossMapScale") ? src.GetFloat("_GlossMapScale") : 1f);
            }

            // ---- Poiyomi sources ----------------------------------------------
            // Lighting: direct concept matches, verified against Poi's property set.
            CopyColor(src, "_LightingShadowColor", dst, "_ShadowTint");
            CopyFloat(src, "_LightingMinLightBrightness", dst, "_MinBrightness");
            CopyFloat(src, "_LightingMonochromatic", dst, "_GrayscaleLighting");
            if (src.HasProperty("_LightingCapEnabled") && src.HasProperty("_LightingCap")
                && src.GetFloat("_LightingCapEnabled") > 0.5f && dst.HasProperty("_MaxBrightness"))
                dst.SetFloat("_MaxBrightness", src.GetFloat("_LightingCap"));

            // Mochie PBR module (Poi Pro reflections):
            if (src.HasProperty("_MochieBRDF") && dst.HasProperty("_ReflectionsEnable"))
                dst.SetFloat("_ReflectionsEnable", src.GetFloat("_MochieBRDF") > 0.5f ? 1f : 0f);
            CopyFloat(src, "_MochieMetallicMultiplier", dst, "_Metallic");
            CopyFloat(src, "_MochieReflectionStrength", dst, "_ReflStrength");
            if (src.HasProperty("_MochieReflectionTint") && dst.HasProperty("_ReflTint"))
            {
                Color t = src.GetColor("_MochieReflectionTint");
                dst.SetColor("_ReflTint", t);
                if (dst.HasProperty("_ReflTintOn") && (t.r < 0.999f || t.g < 0.999f || t.b < 0.999f))
                    dst.SetFloat("_ReflTintOn", 1f);
            }
            if (src.HasProperty("_MochieSpecularTint") && dst.HasProperty("_SpecTint"))
            {
                Color t = src.GetColor("_MochieSpecularTint");
                dst.SetColor("_SpecTint", t);
                if (dst.HasProperty("_SpecTintOn") && (t.r < 0.999f || t.g < 0.999f || t.b < 0.999f))
                    dst.SetFloat("_SpecTintOn", 1f);
            }
            // Roughness multiplier only stands in for smoothness when no Mochie
            // map is driving roughness per-pixel.
            bool mochieMap = src.HasProperty("_MochieMetallicMaps") && src.GetTexture("_MochieMetallicMaps") != null;
            if (!mochieMap && src.HasProperty("_MochieRoughnessMultiplier") && dst.HasProperty("_Smoothness"))
                dst.SetFloat("_Smoothness", Mathf.Clamp01(1f - src.GetFloat("_MochieRoughnessMultiplier")));

            // NEVER auto-slot the Mochie packed map: its channel layout is
            // user-configured per material, and ZFS reads G as AO - a wrong
            // channel there crushes lighting (the classic bad-AO failure).
            if (mochieMap)
                notes.Add(src.name + ": Poi PBR map not carried (its channel layout is configurable) - repack via the Map Packer. Poi had metallic on channel "
                    + ChannelName(src, "_MochieMetallicMapsMetallicChannel") + ", roughness on "
                    + ChannelName(src, "_MochieMetallicMapsRoughnessChannel") + ".");
            if (src.HasProperty("_LightingAOMaps") && src.GetTexture("_LightingAOMaps") != null)
                notes.Add(src.name + ": Poi AO map not carried - pack it into the ZFS Packed G channel with the Map Packer.");
            if (src.HasProperty("_GlitterEnable") && src.GetFloat("_GlitterEnable") > 0.5f)
                notes.Add(src.name + ": glitter toggle and basics carried, but Poi and ZFS glitter parameters use different scales - review the Glitter section.");

            // Emission: Standard gates by keyword, Poi by _EnableEmission, ZFS by
            // its own toggle float.
            bool emissive = src.IsKeywordEnabled("_EMISSION");
            if (!emissive && src.HasProperty("_EnableEmission"))
                emissive = src.GetFloat("_EnableEmission") > 0.5f;
            if (!emissive && src.HasProperty("_EmissionColor") && src.HasProperty("_EmissionMap"))
            {
                Color e = src.GetColor("_EmissionColor");
                emissive = (e.r + e.g + e.b) > 0.001f && src.GetTexture("_EmissionMap") != null;
            }
            if (dst.HasProperty("_EmissionEnable")) dst.SetFloat("_EmissionEnable", emissive ? 1f : 0f);

            // Transparency intent from the source's queue / RenderType tag, then
            // stamp blend state + RenderType / VRCFallback tags for that mode.
            int mode = 0;
            string rt = src.GetTag("RenderType", false, "");
            if (src.renderQueue >= 3000 || rt == "Transparent") mode = 2;
            else if (src.renderQueue >= 2450 || rt == "TransparentCutout") mode = 1;
            if (dst.HasProperty("_AlphaMode")) dst.SetFloat("_AlphaMode", mode);
            ZetRenderModeDrawer.Apply(dst, mode);

            // ZFS has no standalone AO slot - AO lives in the packed G channel.
            if (src.HasProperty("_OcclusionMap") && src.GetTexture("_OcclusionMap") != null)
                notes.Add(src.name + ": standalone AO map not carried - pack it into the G channel with the Map Packer.");
        }

        static void CopyFloat(Material src, string sp, Material dst, string dp)
        {
            if (src.HasProperty(sp) && dst.HasProperty(dp)) dst.SetFloat(dp, src.GetFloat(sp));
        }

        static void CopyColor(Material src, string sp, Material dst, string dp)
        {
            if (src.HasProperty(sp) && dst.HasProperty(dp)) dst.SetColor(dp, src.GetColor(sp));
        }

        static string ChannelName(Material m, string prop)
        {
            if (!m.HasProperty(prop)) return "?";
            int c = Mathf.RoundToInt(m.GetFloat(prop));
            return c == 0 ? "R" : c == 1 ? "G" : c == 2 ? "B" : c == 3 ? "A" : c.ToString();
        }

        // ---- Create (separator before this group via the priority gap) ---------

        [MenuItem("Assets/Zetph/Create ZFS Material", priority = 1040)]
        static void CreateBody() { ZetCreateMenu.CreateBody(); }

        [MenuItem("Assets/Zetph/Create ZFS Eye Material", priority = 1041)]
        static void CreateEye() { ZetCreateMenu.CreateEye(); }

        // ---- Helpers -----------------------------------------------------------

        // SelectionMode.DeepAssets ALONE is a folder-expansion modifier - by
        // itself it can omit the directly right-clicked asset, which greyed the
        // menu out on single materials. Assets | DeepAssets covers both, and the
        // Selection.objects sweep catches any direct click the filter misses.
        static List<Material> SelectedMaterialAssets()
        {
            var seen = new List<Material>();
            foreach (var m in Selection.GetFiltered<Material>(SelectionMode.Assets | SelectionMode.DeepAssets))
                if (m != null && !seen.Contains(m)) seen.Add(m);
            foreach (var o in Selection.objects)
            {
                var m = o as Material;
                if (m != null && !seen.Contains(m)) seen.Add(m);
            }
            return seen;
        }

        /// wantLocked: null = both, true = locked only, false = unlocked only.
        static List<Material> SelectedZfsMaterials(bool? wantLocked = null, bool includeLocked = false)
        {
            var found = new List<Material>();
            foreach (var m in SelectedMaterialAssets())
            {
                if (m == null || m.shader == null) continue;
                bool locked = ZetShaderLocker.IsLocked(m);
                bool zfs = locked || m.shader.name.StartsWith("Zetph/");
                if (!zfs) continue;
                if (wantLocked.HasValue && locked != wantLocked.Value) continue;
                if (!wantLocked.HasValue && locked && !includeLocked) continue;
                found.Add(m);
            }
            return found;
        }

        static void Report(string summary, List<string> notes)
        {
            if (notes != null && notes.Count > 0)
                summary += ", " + notes.Count + " skipped:\n  " + string.Join("\n  ", notes.ToArray());
            Debug.Log("[ZetsFancyShader] " + summary);
        }
    }
}
