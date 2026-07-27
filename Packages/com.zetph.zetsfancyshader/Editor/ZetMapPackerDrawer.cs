// ZetMapPackerDrawer.cs
// Inline texture packer embedded in the ZetsFancyShader material inspector.
//
// Triggered by this line in the shader's Properties block:
//     [ZetMapPacker] _MapPackerUI ("Map Packer", Float) = 0
//
// INSTALL: place inside any folder named "Editor".
// Used by both ZetsFancyShader and ZetsFancyEyeShader - the eye variant
// declares the same _PackedMap / _PackMode / _InvSmooth / _OcclusionStrength
// properties, but names its smoothness slider _EyeSmoothness.
// Packs Metallic (R), AO (G), and Roughness/Smoothness (B) into one linear RGBA
// PNG matching the shader's _PackedMap layout, then assigns it to _PackedMap.
// Roughness sources are inverted to smoothness at pack time, so _InvSmooth is
// forced OFF on apply.
//
// NOTE: pack/apply on an UNLOCKED material - locking bakes these values.
//
// v2 fixes:
//  - Apply now targets the properties that actually exist in ZetsFancyShader
//    (_PackedMap / _InvSmooth). The previous version wrote to _MetallicMap /
//    _OcclusionMap / _SmoothnessMap etc., which the shader does not have, so
//    the HasProperty guards silently skipped the texture assignment while
//    still setting _Metallic/_Smoothness to 1 (material blew out, map unused).
//  - Removed the "Write To" channel dropdowns: the shader hard-codes
//    R = metallic, G = AO, B = smoothness, so exposing them only let users
//    pack a texture the shader would read wrong.
//  - sRGB compensation: in Linear color-space projects (VRChat), blitting a
//    source whose importer has sRGB enabled silently linearizes the values.
//    Data maps (roughness/AO) authored in grayscale would pack darkened.
//    We now detect the importer flag and convert back after readback.

using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections.Generic;

public class ZetMapPackerDrawer : MaterialPropertyDrawer
{
    enum ReadChannel { Grayscale, Red, Green, Blue, Alpha }

    class Role { public Texture2D source; public ReadChannel read = ReadChannel.Grayscale; }

    class State
    {
        public Role metallic = new Role();
        public Role ao = new Role();
        public Role rough = new Role();
        public bool sourceIsRoughness = true;
        public int resIndex = 3; // 2048
    }

    static readonly Dictionary<int, State> _states = new Dictionary<int, State>();
    static readonly int[] resOptions = { 256, 512, 1024, 2048, 4096 };
    static readonly string[] resLabels = { "256", "512", "1024", "2048", "4096" };

    const int UILines = 13; // header + res + 3 roles x 3 + toggle + button

    static State GetState(Material m)
    {
        int id = m.GetInstanceID();
        if (!_states.TryGetValue(id, out var s)) { s = new State(); _states[id] = s; }
        return s;
    }

    static float Line => EditorGUIUtility.singleLineHeight;

    public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
    {
        return (Line + 2f) * UILines + 10f;
    }

    public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
    {
        var mat = editor.target as Material;
        if (mat == null) return;
        var st = GetState(mat);

        float y = position.y;
        Rect Next(float h = -1f)
        {
            if (h < 0f) h = Line;
            var r = new Rect(position.x, y, position.width, h);
            y += h + 2f;
            return r;
        }

        void DrawRole(string name, Role r)
        {
            EditorGUI.LabelField(Next(), name, EditorStyles.miniBoldLabel);
            r.source = (Texture2D)EditorGUI.ObjectField(Next(), "Source", r.source, typeof(Texture2D), false);
            using (new EditorGUI.DisabledScope(r.source == null))
                r.read = (ReadChannel)EditorGUI.EnumPopup(Next(), "Read From", r.read);
        }

        EditorGUI.LabelField(Next(), "Map Packer  (R = Metallic, G = AO, B = Smoothness)", EditorStyles.boldLabel);
        st.resIndex = EditorGUI.Popup(Next(), "Resolution", st.resIndex, resLabels);
        DrawRole("Metallic  ->  R", st.metallic);
        DrawRole("Ambient Occlusion  ->  G", st.ao);
        DrawRole("Roughness / Smoothness  ->  B", st.rough);
        st.sourceIsRoughness = EditorGUI.Toggle(Next(), "Source is Roughness", st.sourceIsRoughness);

        bool any = st.metallic.source || st.ao.source || st.rough.source;
        using (new EditorGUI.DisabledScope(!any))
            if (GUI.Button(Next(Line + 6f), "Pack + Apply to this material"))
                Pack(editor, st);
    }

    static float Read(Color c, ReadChannel ch)
    {
        switch (ch)
        {
            case ReadChannel.Red:   return c.r;
            case ReadChannel.Green: return c.g;
            case ReadChannel.Blue:  return c.b;
            case ReadChannel.Alpha: return c.a;
            default:                return (c.r + c.g + c.b) / 3f;
        }
    }

    static Color[] ReadSource(Texture2D src, int w, int h)
    {
        // If the importer flags this texture as sRGB and the project is Linear
        // (VRChat projects are), the GPU converts sRGB->linear during the blit.
        // For data maps we want the values as authored, so convert back after.
        bool needsGammaRestore = false;
        var imp = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(src)) as TextureImporter;
        if (imp != null && imp.sRGBTexture && PlayerSettings.colorSpace == ColorSpace.Linear)
            needsGammaRestore = true;

        var rt = RenderTexture.GetTemporary(w, h, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        Graphics.Blit(src, rt);
        var prev = RenderTexture.active; RenderTexture.active = rt;
        var tmp = new Texture2D(w, h, TextureFormat.RGBA32, false, true);
        tmp.ReadPixels(new Rect(0, 0, w, h), 0, 0); tmp.Apply();
        RenderTexture.active = prev; RenderTexture.ReleaseTemporary(rt);
        var px = tmp.GetPixels(); UnityEngine.Object.DestroyImmediate(tmp);

        if (needsGammaRestore)
        {
            for (int i = 0; i < px.Length; i++)
            {
                px[i].r = Mathf.LinearToGammaSpace(px[i].r);
                px[i].g = Mathf.LinearToGammaSpace(px[i].g);
                px[i].b = Mathf.LinearToGammaSpace(px[i].b);
            }
        }
        return px;
    }

    static void WriteChannel(Color[] outPix, int channel, Color[] src, ReadChannel read, bool invert = false)
    {
        for (int p = 0; p < outPix.Length; p++)
        {
            float v = Mathf.Clamp01(Read(src[p], read));
            if (invert) v = 1f - v;          // roughness -> smoothness
            switch (channel)
            {
                case 0: outPix[p].r = v; break;
                case 1: outPix[p].g = v; break;
                case 2: outPix[p].b = v; break;
            }
        }
    }

    void Pack(MaterialEditor editor, State st)
    {
        int res = resOptions[st.resIndex];
        int w = res, h = res, n = w * h;
        var outPix = new Color[n];
        // Neutral defaults matching the shader's "white" fallback semantics for
        // unassigned slots: metallic 0, AO 1, smoothness 1 would be asymmetric;
        // we default unpacked channels to 0 (metallic), 1 (AO), 0.5 (smoothness)
        // only when that slot has no source. Simpler and predictable: start at
        // metallic 0, AO 1, smoothness 1, alpha 1.
        for (int p = 0; p < n; p++) outPix[p] = new Color(0f, 1f, 1f, 1f);

        try
        {
            EditorUtility.DisplayProgressBar("Map Packer", "Packing channels...", 0.3f);
            if (st.metallic.source) WriteChannel(outPix, 0, ReadSource(st.metallic.source, w, h), st.metallic.read);
            if (st.ao.source)       WriteChannel(outPix, 1, ReadSource(st.ao.source, w, h),       st.ao.read);
            if (st.rough.source)    WriteChannel(outPix, 2, ReadSource(st.rough.source, w, h),    st.rough.read, st.sourceIsRoughness);
        }
        finally { EditorUtility.ClearProgressBar(); }

        var outTex = new Texture2D(w, h, TextureFormat.RGBA32, false, true);
        outTex.SetPixels(outPix); outTex.Apply();

        var primary = editor.target as Material;
        string matPath = primary != null ? AssetDatabase.GetAssetPath(primary) : "Assets";
        string dir = string.IsNullOrEmpty(matPath) ? "Assets" : Path.GetDirectoryName(matPath);
        string suggested = (primary != null ? primary.name : "Material") + "_Packed";

        string path = (dir + "/" + suggested + ".png").Replace("\\", "/");
        File.WriteAllBytes(path, outTex.EncodeToPNG());
        UnityEngine.Object.DestroyImmediate(outTex);
        AssetDatabase.ImportAsset(path);

        var imp = AssetImporter.GetAtPath(path) as TextureImporter;
        if (imp != null)
        {
            imp.textureType = TextureImporterType.Default;
            imp.sRGBTexture = false;                                        // packed data is linear
            imp.mipmapEnabled = true;
            imp.mipmapFilter = TextureImporterMipFilter.KaiserFilter;
            imp.textureCompression = TextureImporterCompression.CompressedHQ; // BC7 on PC
            imp.compressionQuality = 100;
            imp.SaveAndReimport();
        }

        var packed = AssetDatabase.LoadAssetAtPath<Texture2D>(path);

        foreach (var o in editor.targets)
        {
            var m = o as Material;
            if (m == null) continue;
            Undo.RecordObject(m, "Apply Packed Map");
            SetTex(m, "_PackedMap", packed);
            // The packer always writes ZFS layout (R metallic, G AO, B smoothness).
            // Without this, packing onto a material sitting on Unity MetalSmooth
            // reads the new map from the wrong channels - smoothness from an alpha
            // that BC1/DXT1 does not even have, and AO silently forced to 1.
            SetFloat(m, "_PackMode", 0f);
            SetFloat(m, "_InvSmooth", 0f);          // B is smoothness after packing
            if (st.metallic.source) SetFloat(m, "_Metallic", 1f);   // let the map drive it
            // The eye shader calls its slider _EyeSmoothness. Writing only
            // _Smoothness leaves it silently skipped by the HasProperty guard -
            // the same failure the v2 notes above describe fixing once already.
            if (st.rough.source)  { SetFloat(m, "_Smoothness", 1f); SetFloat(m, "_EyeSmoothness", 1f); }
            if (st.ao.source)       SetFloat(m, "_OcclusionStrength", 1f);
            EditorUtility.SetDirty(m);
        }
        EditorGUIUtility.PingObject(packed);
        Debug.Log("ZetMapPacker: saved " + path + " and assigned to _PackedMap on the material(s).");
    }

    static void SetTex(Material m, string p, Texture t) { if (m.HasProperty(p)) m.SetTexture(p, t); }
    static void SetFloat(Material m, string p, float v) { if (m.HasProperty(p)) m.SetFloat(p, v); }
}
