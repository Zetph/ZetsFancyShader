// ZetsFancyShader inspector - revision 27 (data map import check)
using System.Collections.Generic;
using System.Text;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Select a material (or a shader) and run
    /// Tools > ZetsFancyShader > Dump Shader UI Binding.
    ///
    /// Writes a report to the Console and to a text file, showing for every
    /// property exactly what Unity's GetPropertyAttributes returned, what group
    /// path the inspector resolved from it, and whether that path exists in the
    /// companion JSON. That answers, without guessing, whether a flat inspector
    /// is an attribute problem or a JSON problem.
    /// </summary>
    public static class ZetShaderUIDiagnostic
    {
        [MenuItem("Tools/ZetsFancyShader/Dump Shader UI Binding")]
        private static void Dump()
        {
            Shader shader = ResolveShader();
            if (shader == null)
            {
                Debug.LogError("[ZetsFancyShader] Select a material or a shader first.");
                return;
            }

            ZetUIData data = ZetUIData.Load(shader);

            var jsonPaths = new HashSet<string>();
            if (data.groups != null)
                foreach (GroupDef g in data.groups)
                    if (!string.IsNullOrEmpty(g.path))
                        jsonPaths.Add(g.path);

            var sb = new StringBuilder();
            sb.AppendLine("Shader: " + shader.name);
            sb.AppendLine("Asset:  " + AssetDatabase.GetAssetPath(shader));
            sb.AppendLine("JSON groups: " + jsonPaths.Count);
            sb.AppendLine();

            int noAttributes = 0, noGroup = 0, unmatched = 0;
            int count = shader.GetPropertyCount();

            for (int i = 0; i < count; i++)
            {
                string name = shader.GetPropertyName(i);
                string[] attributes = shader.GetPropertyAttributes(i);

                string raw = (attributes == null || attributes.Length == 0)
                    ? "(none)"
                    : "[" + string.Join("] [", attributes) + "]";

                string path = FindArgument(attributes, "Group(");
                string togglePath = FindArgument(attributes, "GroupToggle(");

                string verdict;
                if (attributes == null || attributes.Length == 0)
                {
                    verdict = "NO ATTRIBUTES RETURNED";
                    noAttributes++;
                }
                else if (path == null && togglePath == null)
                {
                    verdict = "no Group attribute";
                    noGroup++;
                }
                else
                {
                    string p = path ?? togglePath;
                    if (jsonPaths.Contains(p))
                    {
                        verdict = "ok -> " + p;
                    }
                    else
                    {
                        verdict = "PATH NOT IN JSON -> " + p;
                        unmatched++;
                    }
                }

                sb.AppendLine(string.Format("{0,-32} {1,-28} {2}", name, verdict, raw));
            }

            sb.AppendLine();
            sb.AppendLine("properties                  " + count);
            sb.AppendLine("with no attributes at all   " + noAttributes);
            sb.AppendLine("with no Group attribute     " + noGroup);
            sb.AppendLine("Group path missing in JSON  " + unmatched);
            sb.AppendLine();
            sb.AppendLine("Reading it:");
            sb.AppendLine("  many 'NO ATTRIBUTES RETURNED'  -> Unity is not surfacing attributes at all");
            sb.AppendLine("  many 'no Group attribute'      -> the attribute is being dropped or renamed");
            sb.AppendLine("  many 'PATH NOT IN JSON'        -> attribute and JSON paths disagree");

            string report = sb.ToString();
            string outPath = "Assets/ZetShaderUIBinding.txt";
            System.IO.File.WriteAllText(outPath, report);
            AssetDatabase.Refresh();

            Debug.Log(report);
            Debug.Log("[ZetsFancyShader] Report written to " + outPath);
        }

        /// <summary>
        /// Reports exactly what a locked material carries: keywords, and whether
        /// the generated file actually contains the include, the defines and the
        /// call site. Mechanical checks only - it says whether generation was
        /// correct, which is the half worth ruling out before blaming a package.
        /// </summary>
        [MenuItem("Tools/ZetsFancyShader/Verify Locked Material")]
        private static void VerifyLocked()
        {
            var material = Selection.activeObject as Material;
            if (material == null)
            {
                Debug.LogError("[ZetsFancyShader] Select a material first.");
                return;
            }

            var sb = new StringBuilder();
            sb.AppendLine("Material: " + material.name);
            sb.AppendLine("Shader:   " + (material.shader != null ? material.shader.name : "(none)"));

            bool locked = ZetShaderLocker.IsLocked(material);
            sb.AppendLine("Locked:   " + locked);

            string[] keywords = material.shaderKeywords;
            sb.AppendLine("Keywords (" + keywords.Length + "): " +
                          (keywords.Length == 0 ? "(none)" : string.Join(", ", keywords)));
            sb.AppendLine();

            // Property values that gate the feature, read from the material.
            foreach (string p in new[] { "_LTCGI", "_LTCGIStrength", "_LTCGIOcclusion",
                                         "_LightVolumes", "_LightVolumesStrength" })
            {
                sb.AppendLine(material.HasProperty(p)
                    ? string.Format("  {0,-24} {1}", p, material.GetFloat(p))
                    : string.Format("  {0,-24} (absent)", p));
            }
            sb.AppendLine();

            if (!locked)
            {
                sb.AppendLine("Not locked, so there is no generated file to inspect.");
                Debug.Log(sb.ToString());
                return;
            }

            string path = AssetDatabase.GetAssetPath(material.shader);
            sb.AppendLine("Generated: " + path);

            if (!System.IO.File.Exists(path))
            {
                sb.AppendLine("  MISSING ON DISK");
                Debug.LogError(sb.ToString());
                return;
            }

            string text = System.IO.File.ReadAllText(path);

            foreach (var check in new[]
            {
                new[] { "#define LTCGI",          "baked LTCGI keyword" },
                new[] { "#define ZET_LIGHT_VOLUMES", "baked Light Volumes keyword" },
                new[] { "#define ZET_LTCGI",      "LTCGI include survived //ifex" },
                new[] { "#define ZET_LV_OK",      "Light Volumes include survived //ifex" },
                new[] { "at.pimaker.ltcgi",       "LTCGI include line present" },
                new[] { "red.sim.lightvolumes",   "Light Volumes include line present" },
                new[] { "LTCGI_Contribution",     "LTCGI call site present" },
                new[] { "LightVolumeSH",          "Light Volumes call site present" },
                new[] { "shader_feature",         "shader_feature pragmas remaining (should be none)" },
                new[] { "//ifex (",               "MANGLED ifex directive (should be none)" }
            })
            {
                int n = CountOccurrences(text, check[0]);
                sb.AppendLine(string.Format("  {0,-3} {1,-46} {2}", n, check[1], check[0]));
            }

            Debug.Log(sb.ToString());
        }

        private static int CountOccurrences(string text, string needle)
        {
            int n = 0, i = 0;
            while ((i = text.IndexOf(needle, i, System.StringComparison.Ordinal)) >= 0)
            {
                n++;
                i += needle.Length;
            }
            return n;
        }

        /// <summary>
        /// Lists every property that differs from the shader's own default, and
        /// separately flags settings that cancel each other out.
        ///
        /// With 705 properties, a value nudged months ago is invisible. Metallic
        /// Min and Max both landing on 0.5 pins every pixel at half-metal and
        /// ignores the packed map completely - no error, no warning, just a
        /// slightly wrong-looking avatar.
        /// </summary>
        [MenuItem("Tools/ZetsFancyShader/Report Non-Default Properties")]
        private static void ReportNonDefault()
        {
            var material = Selection.activeObject as Material;
            if (material == null)
            {
                Debug.LogError("[ZetsFancyShader] Select a material first.");
                return;
            }

            Shader shader = ZetShaderLocker.ResolveSourceShader(material);
            if (shader == null)
            {
                Debug.LogError("[ZetsFancyShader] Could not resolve the source shader.");
                return;
            }

            var sb = new StringBuilder();
            sb.AppendLine(material.name + " - properties changed from shader defaults");
            sb.AppendLine();

            int changed = 0;
            int count = shader.GetPropertyCount();

            for (int i = 0; i < count; i++)
            {
                string name = shader.GetPropertyName(i);
                if (!material.HasProperty(name)) continue;

                string was, now;
                switch (shader.GetPropertyType(i))
                {
                    case ShaderPropertyType.Float:
                    case ShaderPropertyType.Range:
                    case ShaderPropertyType.Int:
                    {
                        float d = shader.GetPropertyDefaultFloatValue(i);
                        float v = material.GetFloat(name);
                        if (Mathf.Abs(v - d) < 0.0001f) continue;
                        was = d.ToString(); now = v.ToString();
                        break;
                    }

                    case ShaderPropertyType.Color:
                    case ShaderPropertyType.Vector:
                    {
                        Vector4 d = shader.GetPropertyDefaultVectorValue(i);
                        Vector4 v = material.GetVector(name);
                        if ((v - d).sqrMagnitude < 1e-8f) continue;
                        was = d.ToString("F3"); now = v.ToString("F3");
                        break;
                    }

                    case ShaderPropertyType.Texture:
                    {
                        Texture t = material.GetTexture(name);
                        string path = t == null ? null : AssetDatabase.GetAssetPath(t);
                        bool assigned = !string.IsNullOrEmpty(path) &&
                            (path.StartsWith("Assets/", System.StringComparison.Ordinal) ||
                             path.StartsWith("Packages/", System.StringComparison.Ordinal));
                        if (!assigned) continue;
                        was = "(none)"; now = t.name;
                        break;
                    }

                    default: continue;
                }

                changed++;
                sb.AppendLine(string.Format("  {0,-28} {1,-14} -> {2}",
                    name, was, now));
            }

            sb.AppendLine();
            sb.AppendLine(changed + " of " + count + " properties differ from default.");

            // Combinations that silently cancel out.
            sb.AppendLine();
            sb.AppendLine("Settings that neutralise each other:");
            int warned = 0;

            warned += Warn(sb, material, "_MetallicMin", "_Metallic",
                "Metallic Min equals Max, so the packed map's metallic channel is ignored " +
                "and every pixel is fixed at that value.");

            warned += Warn(sb, material, "_SmoothnessMin", "_Smoothness",
                "Smoothness Min equals Max, so the packed map's smoothness channel is ignored.");

            if (material.HasProperty("_PackMode") && material.GetFloat("_PackMode") > 0.5f)
            {
                sb.AppendLine("  Packed Map Format is Unity MetalSmooth: smoothness comes from " +
                              "alpha and ambient occlusion is forced to 1, so the map's green " +
                              "channel is unused. Choose ZFS Packed if the map is R/G/B.");
                warned++;
            }

            if (warned == 0) sb.AppendLine("  none found.");

            Debug.Log(sb.ToString());
        }

        private static int Warn(StringBuilder sb, Material m, string minName, string maxName, string message)
        {
            if (!m.HasProperty(minName) || !m.HasProperty(maxName)) return 0;
            if (Mathf.Abs(m.GetFloat(minName) - m.GetFloat(maxName)) > 0.0001f) return 0;

            sb.AppendLine("  " + message);
            return 1;
        }

        // Textures whose values are data, not colour. These must import as linear
        // and usually need their alpha kept; sRGB on any of them silently skews
        // every value the shader reads.
        private static readonly string[] DataMapHints =
        {
            "Packed", "Mask", "Height", "Thickness", "Flow", "Normal", "Bump", "Path"
        };

        /// <summary>
        /// Reports import settings for every texture on the material that carries
        /// data rather than colour. Two failures here are invisible in the
        /// inspector and look exactly like a badly tuned material: sRGB left on,
        /// which gamma-decodes values that were never colour, and a missing alpha
        /// channel, which makes Unity MetalSmooth read smoothness as a flat 1.
        /// </summary>
        [MenuItem("Tools/ZetsFancyShader/Inspect Data Map Imports")]
        private static void InspectDataMaps()
        {
            var material = Selection.activeObject as Material;
            if (material == null)
            {
                Debug.LogError("[ZetsFancyShader] Select a material first.");
                return;
            }

            Shader shader = ZetShaderLocker.ResolveSourceShader(material);
            if (shader == null) return;

            var sb = new StringBuilder();
            sb.AppendLine(material.name + " - data map import settings");
            sb.AppendLine();

            int problems = 0;
            int count = shader.GetPropertyCount();

            for (int i = 0; i < count; i++)
            {
                if (shader.GetPropertyType(i) != ShaderPropertyType.Texture) continue;

                string name = shader.GetPropertyName(i);
                if (!material.HasProperty(name)) continue;

                Texture tex = material.GetTexture(name);
                if (tex == null) continue;

                bool isData = false;
                foreach (string hint in DataMapHints)
                    if (name.IndexOf(hint, System.StringComparison.OrdinalIgnoreCase) >= 0)
                        isData = true;
                if (!isData) continue;

                string path = AssetDatabase.GetAssetPath(tex);
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) continue;

                var notes = new List<string>();

                // Normal maps are a special case: Unity handles their encoding, so
                // sRGB does not apply and the type must be NormalMap.
                bool isNormal = name.IndexOf("Normal", System.StringComparison.OrdinalIgnoreCase) >= 0
                             || name.IndexOf("Bump", System.StringComparison.OrdinalIgnoreCase) >= 0;

                if (isNormal)
                {
                    if (importer.textureType != TextureImporterType.NormalMap)
                        notes.Add("TYPE should be Normal Map");
                }
                else
                {
                    if (importer.sRGBTexture)
                        notes.Add("sRGB is ON - should be OFF for a data map");
                }

                bool hasAlpha = importer.DoesSourceTextureHaveAlpha();

                if (name == "_PackedMap")
                {
                    bool unityFormat = material.HasProperty("_PackMode") &&
                                       material.GetFloat("_PackMode") > 0.5f;

                    if (unityFormat && !hasAlpha)
                        notes.Add("Unity MetalSmooth reads smoothness from ALPHA, but this " +
                                  "texture has none - smoothness will read as a flat 1");

                    if (unityFormat && importer.alphaSource == TextureImporterAlphaSource.None)
                        notes.Add("Alpha Source is None, so alpha is discarded on import");
                }

                if (notes.Count > 0) problems++;

                sb.AppendLine(string.Format("{0,-22} {1}", name, tex.name));
                sb.AppendLine(string.Format("    sRGB {0,-6} alpha {1,-6} type {2}",
                    importer.sRGBTexture, hasAlpha, importer.textureType));

                foreach (string n in notes)
                    sb.AppendLine("    -> " + n);
            }

            sb.AppendLine();
            sb.AppendLine(problems == 0
                ? "No import problems found."
                : problems + " texture(s) with import settings worth changing.");

            Debug.Log(sb.ToString());
        }

        private static Shader ResolveShader()
        {
            UnityEngine.Object active = Selection.activeObject;

            var asShader = active as Shader;
            if (asShader != null) return asShader;

            var asMaterial = active as Material;
            return asMaterial != null ? asMaterial.shader : null;
        }

        private static string FindArgument(string[] attributes, string prefix)
        {
            if (attributes == null) return null;
            foreach (string a in attributes)
            {
                if (!a.StartsWith(prefix, System.StringComparison.Ordinal)) continue;
                int close = a.LastIndexOf(')');
                if (close < prefix.Length) continue;
                return a.Substring(prefix.Length, close - prefix.Length);
            }
            return null;
        }
    }
}
