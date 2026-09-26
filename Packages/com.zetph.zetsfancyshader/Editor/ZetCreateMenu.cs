// ZetCreateMenu.cs
// Adds right-click > Create menu entries that make a new material with the
// ZFS shaders pre-selected, matching Unity's native Create > Material flow
// (created in the clicked folder, name immediately editable).
//
// INSTALL: place inside any folder named "Editor".
//
// Why not just `new Material(shader)` and save: materials only receive their
// RenderType / VRCFallback override tags when ZetRenderModeDrawer.Apply runs,
// which normally happens the first time someone touches Transparency Mode.
// A menu-created material would otherwise upload with no VRCFallback tag, so
// blocked-shader viewers would see Unity's default fallback instead of Toon.
// Apply(mat, 0) at creation stamps the correct Opaque state and tags up front.

using UnityEngine;
using UnityEditor;

namespace Zetph.FancyShader.EditorUI
{
    public static class ZetCreateMenu
    {
        const string BodyShader = "Zetph/ZetsFancyShader";
        const string EyeShader  = "Zetph/ZetsFancyEyeShader";

        // Priority 301 groups these beside Unity's own Assets/Create/Material entry.
        [MenuItem("Assets/Create/ZFS Material", priority = 301)]
        static void CreateBodyMaterial() { CreateBody(); }

        [MenuItem("Assets/Create/ZFS Eye Material", priority = 302)]
        static void CreateEyeMaterial() { CreateEye(); }

        // Grey the entries out instead of failing if the package's shaders are
        // missing (half-imported project, compile errors).
        [MenuItem("Assets/Create/ZFS Material", true)]
        static bool ValidateBody() { return Shader.Find(BodyShader) != null; }

        [MenuItem("Assets/Create/ZFS Eye Material", true)]
        static bool ValidateEye() { return Shader.Find(EyeShader) != null; }

        // Public so the Assets/Zetph context menu (ZetContextMenu.cs) can reuse
        // the same creation path instead of duplicating it.
        public static void CreateBody() { Create(BodyShader, "New ZFS Material"); }
        public static void CreateEye()  { Create(EyeShader, "New ZFS Eye Material"); }

        static void Create(string shaderName, string assetName)
        {
            var shader = Shader.Find(shaderName);
            if (shader == null)
            {
                Debug.LogError("[ZFS] Shader not found: " + shaderName);
                return;
            }

            var mat = new Material(shader);
            // Stamp render state + RenderType / VRCFallback tags for the default
            // Opaque mode. Without this the tags stay unset until the user touches
            // the Transparency Mode dropdown (see file header).
            ZetRenderModeDrawer.Apply(mat, 0);

            // Creates the asset in the folder that was right-clicked, with the
            // name field open for typing - identical UX to Create > Material.
            ProjectWindowUtil.CreateAsset(mat, assetName + ".mat");
        }
    }
}
