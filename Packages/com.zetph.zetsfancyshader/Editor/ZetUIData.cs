// ZetsFancyShader inspector - revision 20 (banner, builtin texture fix)
using System;
using System.Collections.Generic;
using System.Globalization;
using UnityEditor;
using UnityEngine;

namespace Zetph.FancyShader.EditorUI
{
    // ---------------------------------------------------------- JSON schema
    // Arrays rather than maps so UnityEngine.JsonUtility can read this with no
    // Newtonsoft dependency.

    [Serializable]
    public class GroupDef
    {
        public string path;      // underscore-joined, e.g. "engine_vertal_valtrans"
        public string label;
        public string info;
        public string toggle;
        public string[] showIf;  // "_Foo" or "_Foo=3"; all entries ANDed

        // Integration symbol this group needs (e.g. "ZET_LTCGI"). When set and
        // the matching package is absent, the group is hidden outright: a toggle
        // for a feature that physically cannot run is worse than no toggle.
        // Empty or missing means always shown, so existing JSON is unaffected.
        public string requires;
    }

    [Serializable]
    public class TooltipDef
    {
        public string name;
        public string text;
    }

    /// <summary>
    /// Dropdown options for a float property, by index: options[0] is value 0.
    ///
    /// These live here rather than in a [Enum(...)] ShaderLab attribute because
    /// that route has two hard limits and both fail near-silently. Unity's built-in
    /// Enum drawer is a fixed set of constructors, one per name/value pair count,
    /// and stops at seven pairs. And the ShaderLab attribute lexer accepts only
    /// identifiers, numbers, dots, commas, spaces and hyphens - commas separate
    /// arguments, so there is no safe delimiter left for packing a long list into
    /// one argument. JSON has neither problem, and the inspector is already
    /// reading this file for tooltips and groups.
    /// </summary>
    [Serializable]
    public class EnumDef
    {
        public string name;
        public string[] options;
    }

    [Serializable]
    public class ZetUIData
    {
        /// <summary>Banner text, lifted from the shader header by the codemod.</summary>
        public string title;
        public string version;

        public GroupDef[] groups;
        public TooltipDef[] tooltips;
        public EnumDef[] enums;

        /// <summary>
        /// Properties driving an //ifex block. Marking one animated means that
        /// block can never be stripped at lock time. Extracted by the codemod, so
        /// it stays correct if the ifex blocks change. Absent in older JSON, which
        /// simply means no warnings.
        /// </summary>
        public string[] lockCritical;

        private HashSet<string> _lockCriticalSet;

        public bool IsLockCritical(string propertyName)
        {
            if (_lockCriticalSet == null)
            {
                _lockCriticalSet = new HashSet<string>();
                if (lockCritical != null)
                    foreach (string n in lockCritical)
                        if (!string.IsNullOrEmpty(n)) _lockCriticalSet.Add(n);
            }

            return _lockCriticalSet.Contains(propertyName);
        }

        private Dictionary<string, string[]> _enumLookup;

        /// <summary>Dropdown options for a property, or null to draw it normally.</summary>
        public string[] EnumOptions(string propertyName)
        {
            if (_enumLookup == null)
            {
                _enumLookup = new Dictionary<string, string[]>();
                if (enums != null)
                    foreach (EnumDef e in enums)
                        if (!string.IsNullOrEmpty(e.name) && e.options != null && e.options.Length > 0)
                            _enumLookup[e.name] = e.options;
            }

            return _enumLookup.TryGetValue(propertyName, out string[] opts) ? opts : null;
        }

        private Dictionary<string, string> _tooltipLookup;

        public string Tooltip(string propertyName)
        {
            if (_tooltipLookup == null)
            {
                _tooltipLookup = new Dictionary<string, string>();
                if (tooltips != null)
                    foreach (TooltipDef t in tooltips)
                        if (!string.IsNullOrEmpty(t.name))
                            _tooltipLookup[t.name] = t.text;
            }

            return _tooltipLookup.TryGetValue(propertyName, out string text) ? text : null;
        }

        /// <summary>
        /// Loads "&lt;ShaderFile&gt;UI.json" from beside the .shader asset. Returns an
        /// empty instance rather than null when absent, so a missing companion file
        /// degrades to an unlabelled-but-functional inspector instead of throwing.
        /// </summary>
        public static ZetUIData Load(Shader shader)
        {
            string shaderPath = AssetDatabase.GetAssetPath(shader);

            if (!string.IsNullOrEmpty(shaderPath) &&
                shaderPath.EndsWith(".shader", StringComparison.OrdinalIgnoreCase))
            {
                string jsonPath = shaderPath.Substring(0, shaderPath.Length - ".shader".Length) + "UI.json";
                var asset = AssetDatabase.LoadAssetAtPath<TextAsset>(jsonPath);

                if (asset != null)
                {
                    try
                    {
                        return JsonUtility.FromJson<ZetUIData>(asset.text) ?? Empty();
                    }
                    catch (Exception e)
                    {
                        Debug.LogError("[ZetsFancyShader] Failed to parse " + jsonPath + ": " + e.Message);
                    }
                }
                else
                {
                    Debug.LogWarning("[ZetsFancyShader] No UI data at " + jsonPath +
                                     ". Group labels and tooltips will be missing.");
                }
            }

            return Empty();
        }

        private static ZetUIData Empty()
        {
            return new ZetUIData
            {
                title = string.Empty,
                version = string.Empty,
                groups = new GroupDef[0],
                tooltips = new TooltipDef[0],
                enums = new EnumDef[0],
                lockCritical = new string[0]
            };
        }
    }

    // ------------------------------------------------------------ conditions

    /// <summary>
    /// A single visibility test. ShaderLab's attribute lexer accepts only
    /// identifiers, numbers, dots, commas and spaces - no operators - so a
    /// comparison is expressed as two arguments and conjunction as repeated
    /// attributes:
    ///
    ///     [ShowIf(_Foo)]                 non-zero
    ///     [ShowIf(_Bar, 3)]              equal to 3
    ///     [ShowIf(_Foo)] [ShowIf(_Bar, 3)]   both, ANDed
    ///
    /// The companion JSON has no such constraint and uses "_Foo" / "_Bar=3".
    /// </summary>
    public struct ZetCondition
    {
        public string Property;
        public bool HasValue;
        public float Value;

        /// <summary>Parses an attribute argument list: "_Bar, 3" or "_Foo".</summary>
        public static bool TryParseArgs(string args, out ZetCondition condition)
        {
            condition = default(ZetCondition);
            if (string.IsNullOrEmpty(args)) return false;

            int comma = args.IndexOf(',');
            if (comma < 0)
            {
                condition.Property = args.Trim();
                condition.HasValue = false;
                return condition.Property.Length > 0;
            }

            condition.Property = args.Substring(0, comma).Trim();
            if (condition.Property.Length == 0) return false;

            float parsed;
            condition.HasValue = float.TryParse(
                args.Substring(comma + 1).Trim(),
                NumberStyles.Float, CultureInfo.InvariantCulture, out parsed);
            condition.Value = parsed;
            return true;
        }

        /// <summary>Parses the JSON form: "_Foo" or "_Bar=3".</summary>
        public static bool TryParseJson(string text, out ZetCondition condition)
        {
            condition = default(ZetCondition);
            if (string.IsNullOrEmpty(text)) return false;

            int equals = text.IndexOf('=');
            if (equals < 0)
            {
                condition.Property = text.Trim();
                condition.HasValue = false;
                return condition.Property.Length > 0;
            }

            condition.Property = text.Substring(0, equals).Trim();
            if (condition.Property.Length == 0) return false;

            float parsed;
            condition.HasValue = float.TryParse(
                text.Substring(equals + 1).Trim(),
                NumberStyles.Float, CultureInfo.InvariantCulture, out parsed);
            condition.Value = parsed;
            return true;
        }

        public bool Evaluate(Func<string, float?> getFloat)
        {
            float? actual = getFloat(Property);

            // Fail open on unknown properties: a typo should leave a control
            // visible and obviously wrong, not silently blank a whole section.
            if (!actual.HasValue) return true;

            const float Epsilon = 0.0001f;
            return HasValue
                ? Math.Abs(actual.Value - Value) < Epsilon
                : Math.Abs(actual.Value) >= Epsilon;
        }

        /// <summary>All conditions must pass. An empty or null list is always visible.</summary>
        public static bool EvaluateAll(List<ZetCondition> conditions, Func<string, float?> getFloat)
        {
            if (conditions == null) return true;
            for (int i = 0; i < conditions.Count; i++)
                if (!conditions[i].Evaluate(getFloat)) return false;
            return true;
        }
    }
}
