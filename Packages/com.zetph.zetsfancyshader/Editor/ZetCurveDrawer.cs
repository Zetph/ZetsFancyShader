#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    // Draws a texture property as Unity's curve editor and bakes the curve to a ramp
    // texture automatically, so nobody has to author a gradient in an image editor to
    // shape a sweep. The curve's keyframes are stored in the generated texture's
    // import userData, so selecting the material later reopens the same editable
    // curve rather than an opaque baked image.
    //
    // Usage in the shader Properties block:
    //     [ZetCurve] [NoScaleOffset] _Em0ScanRamp ("Curve", 2D) = "white" {}
    //
    // The bake is 256x1, linear (sRGB off), clamped, no mips - sampled with a clamp
    // sampler by the shader, so the left edge is the band and the right edge is the
    // far end of the trail.
    public class ZetCurveDrawer : MaterialPropertyDrawer
    {
        private const string Folder = "Assets/ZetsFancyShader/Curves";
        private const int Width = 256;

        [Serializable]
        private class CurveData
        {
            public float[] t;
            public float[] v;
            public float[] i;
            public float[] o;
        }

        public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
        {
            return EditorGUIUtility.singleLineHeight;
        }

        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            AnimationCurve curve = LoadCurve(prop.textureValue)
                                   ?? new AnimationCurve(new Keyframe(0f, 1f), new Keyframe(1f, 0f));

            EditorGUI.BeginChangeCheck();
            curve = EditorGUI.CurveField(position, label.text, curve);
            if (EditorGUI.EndChangeCheck())
            {
                Texture2D baked = Bake(curve, BakeName(prop, editor));
                if (baked != null) prop.textureValue = baked;
            }
        }

        private static string BakeName(MaterialProperty prop, MaterialEditor editor)
        {
            var mat = editor.target as Material;
            string matName = mat != null ? mat.name : "material";
            foreach (char c in Path.GetInvalidFileNameChars()) matName = matName.Replace(c, '_');
            return matName + "_" + prop.name;
        }

        /// <summary>
        /// Rebuilds the editable curve from the keys stored in the texture's import
        /// userData. Null when the texture was not baked by this drawer (or was
        /// assigned by hand), in which case the field starts from a fresh default
        /// rather than pretending to know the image's shape.
        /// </summary>
        private static AnimationCurve LoadCurve(Texture tex)
        {
            if (tex == null) return null;
            string path = AssetDatabase.GetAssetPath(tex);
            if (string.IsNullOrEmpty(path)) return null;
            var importer = AssetImporter.GetAtPath(path) as TextureImporter;
            if (importer == null || string.IsNullOrEmpty(importer.userData)) return null;
            if (!importer.userData.StartsWith("{\"t\"", StringComparison.Ordinal)) return null;

            try
            {
                CurveData data = JsonUtility.FromJson<CurveData>(importer.userData);
                if (data == null || data.t == null || data.t.Length == 0) return null;
                var keys = new Keyframe[data.t.Length];
                for (int k = 0; k < keys.Length; k++)
                    keys[k] = new Keyframe(data.t[k], data.v[k], data.i[k], data.o[k]);
                return new AnimationCurve(keys);
            }
            catch { return null; }
        }

        private static Texture2D Bake(AnimationCurve curve, string name)
        {
            EnsureFolder();
            string path = Folder + "/" + name + ".png";

            var tex = new Texture2D(Width, 1, TextureFormat.RGBA32, false, true);
            var pixels = new Color[Width];
            for (int x = 0; x < Width; x++)
            {
                float v = Mathf.Clamp01(curve.Evaluate(x / (float)(Width - 1)));
                pixels[x] = new Color(v, v, v, 1f);
            }
            tex.SetPixels(pixels);
            tex.Apply(false);
            File.WriteAllBytes(path, tex.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(tex);

            AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceSynchronousImport);

            var importer = AssetImporter.GetAtPath(path) as TextureImporter;
            if (importer != null)
            {
                var keys = curve.keys;
                var data = new CurveData
                {
                    t = new float[keys.Length], v = new float[keys.Length],
                    i = new float[keys.Length], o = new float[keys.Length]
                };
                for (int k = 0; k < keys.Length; k++)
                {
                    data.t[k] = keys[k].time; data.v[k] = keys[k].value;
                    data.i[k] = keys[k].inTangent; data.o[k] = keys[k].outTangent;
                }

                importer.userData = JsonUtility.ToJson(data);
                importer.sRGBTexture = false;                  // profile data, not colour
                importer.mipmapEnabled = false;
                importer.wrapMode = TextureWrapMode.Clamp;
                importer.filterMode = FilterMode.Bilinear;
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                importer.SaveAndReimport();
            }

            return AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        }

        private static void EnsureFolder()
        {
            if (AssetDatabase.IsValidFolder(Folder)) return;
            if (!AssetDatabase.IsValidFolder("Assets/ZetsFancyShader"))
                AssetDatabase.CreateFolder("Assets", "ZetsFancyShader");
            AssetDatabase.CreateFolder("Assets/ZetsFancyShader", "Curves");
        }

    }
}
#endif
