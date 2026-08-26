// ZetStencilCalculatorDrawer.cs
// Inline stencil test simulator embedded in the ZetsFancyShader material inspector.
//
// Triggered by this line in the shader's Properties block:
//     [ZetStencilCalculator] _StencilCalcUI ("Stencil Calculator", Float) = 0
//
// INSTALL: place inside any folder named "Editor".
//
// WHY THIS EXISTS
// Stencils are the least legible part of a material. The reference value, read
// mask and write mask are all bytes, the comparison runs against the masked
// buffer rather than the raw one, and which of the three operations fires
// depends on both the comparison and the depth test. In practice people copy
// numbers from a guide and hope. This shows the arithmetic: the buffer as bits,
// which of those bits the test actually reads, the outcome of the comparison,
// and which operation the GPU would take.
//
// It is a simulation for the editor only. Nothing here changes what the GPU
// does; it reads the same properties the pass already declares and works out
// what the hardware would conclude from them.

using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;

public class ZetStencilCalculatorDrawer : MaterialPropertyDrawer
{
    // The buffer value to test against is a what-if: the real one depends on
    // whatever else drew there first, so the user supplies it.
    static int _existing = 0;
    static bool _simulateZFail = false;
    static bool _expanded = true;

    const float RowH = 18f;

    public override float GetPropertyHeight(MaterialProperty prop, string label, MaterialEditor editor)
    {
        return 0f;   // drawn manually below; Unity's own row is suppressed
    }

    public override void OnGUI(Rect position, MaterialProperty prop, string label, MaterialEditor editor)
    {
        Material m = editor.target as Material;
        if (m == null) return;

        _expanded = EditorGUILayout.Foldout(_expanded, "Stencil Calculator", true, EditorStyles.foldoutHeader);
        if (!_expanded) return;

        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _rowIndex = 0;

        int refVal = GetByte(m, "_StencilRef");
        int readMask = GetByte(m, "_StencilReadMask", 255);
        int writeMask = GetByte(m, "_StencilWriteMask", 255);
        CompareFunction comp = (CompareFunction)GetByte(m, "_StencilComp", (int)CompareFunction.Always);
        StencilOp passOp = (StencilOp)GetByte(m, "_StencilPass");
        StencilOp failOp = (StencilOp)GetByte(m, "_StencilFail");
        StencilOp zfailOp = (StencilOp)GetByte(m, "_StencilZFail");

        _existing = EditorGUILayout.IntSlider("Existing buffer value", _existing, 0, 255);
        _simulateZFail = EditorGUILayout.Toggle(
            new GUIContent("Simulate depth fail",
                           "Previews the case where the stencil test passes but the pixel is behind something."),
            _simulateZFail);

        EditorGUILayout.Space(4);

        // The comparison runs on the masked values, not the raw ones. Both are
        // recomputed after the editable rows below, since editing a bit changes them.
        int readBuffer, readRef;

        EditorGUILayout.LabelField("Read: what the comparison sees", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        BitHeader();
        _existing = BitRowEditable("Existing buffer", null, null, _existing, 255);
        refVal    = BitRowEditable("Reference value", m, "_StencilRef", refVal, readMask);
        readMask  = BitRowEditable("Read mask", m, "_StencilReadMask", readMask, 255);
        readBuffer = _existing & readMask;
        readRef    = refVal & readMask;
        BitRowReadOnly("Compared: buffer", readBuffer, 255, true);
        BitRowReadOnly("Compared: reference", readRef, 255, true);
        EditorGUILayout.EndVertical();

        EditorGUILayout.Space(4);

        bool stencilPasses = Compare(comp, readRef, readBuffer);
        bool zPasses = !_simulateZFail;
        StencilOp taken = !stencilPasses ? failOp : (zPasses ? passOp : zfailOp);
        string takenName = !stencilPasses ? "Fail Op" : (zPasses ? "Pass Op" : "ZFail Op");

        // Only bits the write mask allows can change; recomputed after its row below.
        int written;

        Divider();
        FlowChart(comp, stencilPasses, zPasses, passOp, zfailOp, failOp);
        Divider();
        EditorGUILayout.LabelField("Write: what the buffer becomes", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        BitHeader();
        BitRowReadOnly("Before", _existing, 255);
        writeMask = BitRowEditable("Write mask", m, "_StencilWriteMask", writeMask, 255);
        written = (_existing & ~writeMask) | (ApplyOp(taken, _existing, refVal) & writeMask);
        BitRowReadOnly("After", written, 255, true);
        EditorGUILayout.EndVertical();

        EditorGUILayout.Space(6);

        string verdict = string.Format(
            "{0} {1}  ->  {2} takes {3}, buffer {4}",
            comp, DescribeCompare(comp, readRef, readBuffer),
            stencilPasses ? (zPasses ? "pixel drawn" : "depth fails") : "pixel discarded",
            takenName + " (" + taken + ")",
            written == _existing ? "unchanged at " + _existing : _existing + " becomes " + written);

        EditorGUILayout.HelpBox(verdict, stencilPasses && zPasses ? MessageType.Info : MessageType.Warning);

        if (comp == CompareFunction.Always && passOp == StencilOp.Keep)
        {
            EditorGUILayout.HelpBox(
                "Always + Keep is the neutral setting: every pixel draws and the buffer is never written, "
                + "so the stencil has no effect. That is the correct state when the feature is unused.",
                MessageType.None);
        }

        EditorGUILayout.EndVertical();
    }

    // ---------------------------------------------------------------- helpers

    static int GetByte(Material m, string name, int fallback = 0)
    {
        return m.HasProperty(name) ? Mathf.Clamp(Mathf.RoundToInt(m.GetFloat(name)), 0, 255) : fallback;
    }

    // GUILayout with explicit widths rather than manual Rect maths: the surrounding
    // inspector indents and clips its content area, so hand-computed rectangles kept
    // pushing the bit cells outside the visible region. Layout measures itself.
    const float LabelW = 150f;
    const float CellW  = 28f;
    const float ValueW = 52f;

    static readonly GUILayoutOption[] LabelOpt = { GUILayout.Width(LabelW) };
    static readonly GUILayoutOption[] CellOpt  = { GUILayout.Width(CellW) };
    static readonly GUILayoutOption[] ValueOpt = { GUILayout.Width(ValueW) };

    static int _rowIndex;

    // Faint zebra striping: eight identical cells in a row are hard to track across
    // without it, and it costs one rect per row.
    static void RowBackdrop()
    {
        if ((_rowIndex++ & 1) == 0) return;
        Rect r = GUILayoutUtility.GetLastRect();
        EditorGUI.DrawRect(new Rect(r.x, r.y, r.width, r.height), new Color(1f, 1f, 1f, 0.03f));
    }

    static GUIStyle _cell;
    static GUIStyle Cell
    {
        get
        {
            if (_cell == null)
            {
                _cell = new GUIStyle(EditorStyles.miniLabel);
                _cell.alignment = TextAnchor.MiddleCenter;
            }
            return _cell;
        }
    }

    static void BitHeader()
    {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField("bit", EditorStyles.miniLabel, LabelOpt);
        for (int i = 0; i < 8; i++)
        {
            int weight = 128 >> i;
            // The weight itself is too wide for a cell, so the exponent is shown and
            // the weight moved to the tooltip.
            EditorGUILayout.LabelField(new GUIContent((7 - i).ToString(), "bit value " + weight),
                                       Cell, CellOpt);
        }
        EditorGUILayout.LabelField("dec", EditorStyles.miniLabel, ValueOpt);
        GUILayout.FlexibleSpace();
        EditorGUILayout.EndHorizontal();
    }

    // Editable bit grid: clicking a bit writes the value straight back to the
    // material, so the calculator drives the real properties instead of being a
    // read-only mirror of them.
    static int BitRowEditable(string label, Material m, string prop, int value, int mask)
    {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField(label, EditorStyles.miniLabel, LabelOpt);
        int result = value;
        Color prev = GUI.color;
        for (int i = 0; i < 8; i++)
        {
            int bit = 128 >> i;
            bool set = (value & bit) != 0;
            // Bits the mask excludes are dimmed: the test cannot see them, and showing
            // them at full strength is what makes masks confusing in the first place.
            GUI.color = (mask & bit) != 0 ? prev : new Color(1f, 1f, 1f, 0.35f);
            bool now = GUILayout.Toggle(set, GUIContent.none, CellOpt);
            if (now != set) result = now ? (value | bit) : (value & ~bit);
        }
        GUI.color = prev;
        EditorGUILayout.LabelField(result.ToString(), EditorStyles.miniLabel, ValueOpt);
        GUILayout.FlexibleSpace();
        EditorGUILayout.EndHorizontal();
        RowBackdrop();

        if (result != value && m != null && prop != null && m.HasProperty(prop))
        {
            Undo.RecordObject(m, "Edit stencil " + prop);
            m.SetFloat(prop, result);
            EditorUtility.SetDirty(m);
        }
        return result;
    }

    static void BitRowReadOnly(string label, int value, int mask, bool dim = false)
    {
        EditorGUILayout.BeginHorizontal();
        EditorGUILayout.LabelField(label, EditorStyles.miniLabel, LabelOpt);
        Color prev = GUI.color;
        for (int i = 0; i < 8; i++)
        {
            int bit = 128 >> i;
            bool set = (value & bit) != 0;
            bool visible = (mask & bit) != 0;
            // Set bits are tinted so the pattern is readable without counting columns.
            GUI.color = !visible ? new Color(1f, 1f, 1f, 0.28f)
                      : set     ? new Color(0.55f, 0.95f, 0.65f, dim ? 0.9f : 1f)
                                : new Color(1f, 1f, 1f, 0.45f);
            EditorGUILayout.LabelField(set ? "1" : "0", Cell, CellOpt);
        }
        GUI.color = prev;
        EditorGUILayout.LabelField(value.ToString(), EditorStyles.miniLabel, ValueOpt);
        GUILayout.FlexibleSpace();
        EditorGUILayout.EndHorizontal();
        RowBackdrop();
    }

    static void Divider()
    {
        EditorGUILayout.Space(2);
        Rect r = EditorGUILayout.GetControlRect(false, 1f);
        EditorGUI.DrawRect(r, new Color(1f, 1f, 1f, 0.12f));
        EditorGUILayout.Space(2);
    }

    // Decision flow: which of the three operations the outcome actually selects.
    // Stencil docs describe this as a branch and it is far easier to read as one.
    static void FlowChart(CompareFunction comp, bool stencilPasses, bool zPasses,
                          StencilOp passOp, StencilOp zfailOp, StencilOp failOp)
    {
        EditorGUILayout.LabelField("Which operation fires", EditorStyles.boldLabel);
        // Equal flexible widths: three fixed-width boxes overflowed the inspector and
        // clipped the last branch off the end entirely.
        EditorGUILayout.BeginHorizontal();
        Branch("Pass Op", passOp, stencilPasses && zPasses, "passes, drawn");
        Branch("ZFail Op", zfailOp, stencilPasses && !zPasses, "passes, behind");
        Branch("Fail Op", failOp, !stencilPasses, "fails");
        EditorGUILayout.EndHorizontal();
    }

    static void Branch(string title, StencilOp op, bool active, string when)
    {
        Color prev = GUI.color;
        if (!active) GUI.color = new Color(1f, 1f, 1f, 0.35f);
        EditorGUILayout.BeginVertical(EditorStyles.helpBox, GUILayout.MinWidth(90f));
        EditorGUILayout.LabelField(active ? "\u25b6 " + title : title,
                                   active ? EditorStyles.boldLabel : EditorStyles.miniLabel);
        EditorGUILayout.LabelField(op.ToString(), EditorStyles.miniLabel);
        EditorGUILayout.LabelField(when, EditorStyles.miniLabel);
        EditorGUILayout.EndVertical();
        GUI.color = prev;
    }

    static bool Compare(CompareFunction f, int refv, int buf)
    {
        switch (f)
        {
            case CompareFunction.Never:        return false;
            case CompareFunction.Less:         return refv <  buf;
            case CompareFunction.Equal:        return refv == buf;
            case CompareFunction.LessEqual:    return refv <= buf;
            case CompareFunction.Greater:      return refv >  buf;
            case CompareFunction.NotEqual:     return refv != buf;
            case CompareFunction.GreaterEqual: return refv >= buf;
            default:                           return true;   // Always / Disabled
        }
    }

    static string DescribeCompare(CompareFunction f, int refv, int buf)
    {
        if (f == CompareFunction.Always) return "(reference vs buffer ignored)";
        if (f == CompareFunction.Never)  return "(never passes)";
        return "(" + refv + " vs " + buf + ")";
    }

    static int ApplyOp(StencilOp op, int buffer, int refv)
    {
        switch (op)
        {
            case StencilOp.Zero:           return 0;
            case StencilOp.Replace:        return refv;
            case StencilOp.IncrementSaturate: return Mathf.Min(buffer + 1, 255);
            case StencilOp.DecrementSaturate: return Mathf.Max(buffer - 1, 0);
            case StencilOp.Invert:         return (~buffer) & 255;
            case StencilOp.IncrementWrap:  return (buffer + 1) & 255;
            case StencilOp.DecrementWrap:  return (buffer - 1) & 255;
            default:                       return buffer;   // Keep
        }
    }
}
