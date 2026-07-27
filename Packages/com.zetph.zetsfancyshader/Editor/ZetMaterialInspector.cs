// ZetsFancyShader inspector - revision 30 (locked-view marker fix)
using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Zetph.FancyShader.EditorUI
{
    /// <summary>
    /// Material inspector for ZetsFancyShader.
    ///
    ///     CustomEditor "Zetph.FancyShader.EditorUI.ZetMaterialInspector"
    ///
    /// Structure comes from ShaderLab attributes, prose from the companion
    /// "&lt;ShaderName&gt;UI.json" beside the .shader asset:
    ///
    ///     [Group(engine_stencil)]      membership in a nested group
    ///     [GroupToggle(engine_prox)]   this property is that group's enable switch
    ///     [ShowIf(_Foo)]               visible while _Foo is non-zero
    ///     [ShowIf(_Bar, 3)]            visible while _Bar equals 3
    ///     [ZetLockButton]              the lock / optimize control
    ///
    /// Path segments are joined with underscores rather than dots, and conditions
    /// carry no operators, because ShaderLab rejects both in an arbitrary
    /// attribute argument. ([Enum(Some.Type.Name)] works only because Enum is a
    /// recognised attribute whose argument is lexed as a type name.) No group id
    /// contains an underscore, so the split is unambiguous. Repeated [ShowIf]
    /// attributes are ANDed.
    /// </summary>
    public class ZetMaterialInspector : ShaderGUI
    {
        private const string GroupAttr = "Group(";
        private const string GroupToggleAttr = "GroupToggle(";
        private const string ShowIfAttr = "ShowIf(";
        private const string LockAttr = "ZetLockButton";

        private const float HeaderHeight = 22f;
        private const float IndentWidth = 15f;   // matches EditorGUI.indentLevel
        private const float ToggleSize = 15f;
        private const float ArrowWidth = 13f;
        private const float GutterWidth = 18f;
        private const float BannerHeight = 42f;

        private const string AnimationModeKey = "Zetph.FancyShader.UI.AnimationMode";
        private const string ShowInactiveKey = "Zetph.FancyShader.UI.ShowInactiveWhenLocked";

        private class Node
        {
            public string Path;
            public GroupDef Def;
            public List<ZetCondition> Show;
            public string PrefKey;
            public int Order = int.MaxValue;

            /// <summary>Any property in this subtree marked animated.</summary>
            public bool HasAnimated;

            /// <summary>Anything in this subtree actually configured away from defaults.</summary>
            public bool HasContent;

            public readonly List<Node> Groups = new List<Node>();
            public readonly List<Entry> Properties = new List<Entry>();
        }

        private class Entry
        {
            public string Name;
            public string Tooltip;
            public List<ZetCondition> Show;
            public int Order;
            public int PropertyIndex;

            /// <summary>Refreshed each OnGUI from the cached animated set.</summary>
            public bool Animated;

            /// <summary>Differs from the shader default, or holds a texture.</summary>
            public bool Meaningful;
        }

        private Shader _shader;
        private ZetUIData _data;
        private Node _root;
        private string _lockProperty;
        private string _search = string.Empty;

        private readonly Dictionary<string, MaterialProperty> _lookup =
            new Dictionary<string, MaterialProperty>();

        // Property row rects from the last repaint, used to catch right-click
        // before Unity's own property context menu takes the event.
        private readonly Dictionary<string, Rect> _rowRects = new Dictionary<string, Rect>();

        // Texture property -> companion float the shader can branch on. HLSL has
        // no way to ask whether a texture is bound, so a branch that means "only
        // if the user assigned one" has to be told.
        private readonly List<KeyValuePair<string, string>> _assignmentFlags =
            new List<KeyValuePair<string, string>>();

        private bool _animationMode;
        private bool _animationModeLoaded;

        // Drawing a locked material: structure visible, baked values inert.
        private bool _lockedView;
        private bool _showInactiveWhenLocked;

        // Animated flags live in material tags, so reading them means a GetTag per
        // property. Cached and refreshed only when something changes rather than
        // 700-odd lookups every repaint.
        private readonly HashSet<string> _animated = new HashSet<string>();
        private bool _animatedDirty = true;
        private UnityEngine.Object[] _animatedFor;

        private static GUIStyle _infoStyle;
        private static GUIStyle _headerLabelStyle;
        private static GUIStyle _animBadgeStyle;
        private static GUIStyle _bannerTitleStyle;
        private static GUIStyle _bannerVersionStyle;

        // ---------------------------------------------------------------- GUI

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            var material = materialEditor.target as Material;
            if (material == null || material.shader == null)
            {
                base.OnGUI(materialEditor, properties);
                return;
            }

            if (_root == null || _shader != material.shader)
            {
                // A locked material points at a generated copy, so structure and
                // prose come from whichever shader the source actually is.
                _shader = ZetShaderLocker.ResolveSourceShader(material) ?? material.shader;
                _data = ZetUIData.Load(_shader);
                Rebuild();
            }

            // Unity rebuilds this array every frame; the tree stores names only.
            _lookup.Clear();
            for (int i = 0; i < properties.Length; i++)
                _lookup[properties[i].name] = properties[i];

            EnsureStyles();

            if (!_animationModeLoaded)
            {
                _animationMode = EditorPrefs.GetBool(AnimationModeKey, false);
                _showInactiveWhenLocked = EditorPrefs.GetBool(ShowInactiveKey, false);
                _animationModeLoaded = true;
            }

            RefreshAnimated(materialEditor);
            SyncAssignmentFlags(materialEditor);
            MarkState(_root);

            // Right-click is handled here, before a single property has drawn.
            // Checking it inside DrawEntry could never work: Unity's own material
            // fields consume the event, so nothing downstream of ShaderProperty
            // ever sees it. Rects come from the previous repaint, which is stable.
            HandleRightClick(materialEditor);

            DrawBanner(material);
            DrawLockButton(materialEditor);

            if (ZetShaderLocker.IsLocked(material))
            {
                DrawLockedBody(materialEditor);

                EditorGUILayout.Space(6f);
                materialEditor.RenderQueueField();
                materialEditor.EnableInstancingField();
                materialEditor.DoubleSidedGIField();
                return;
            }

            DrawSearchField();

            if (Event.current.type == EventType.Repaint)
                _rowRects.Clear();

            if (string.IsNullOrEmpty(_search))
                DrawNodeChildren(_root, materialEditor, 1);
            else
                DrawFiltered(_root, materialEditor, _search.ToLowerInvariant());

            EditorGUILayout.Space(6f);
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            _root = null;
            _shader = null;
            base.AssignNewShaderToMaterial(material, oldShader, newShader);
        }

        private static void EnsureStyles()
        {
            if (_infoStyle == null)
            {
                _infoStyle = new GUIStyle(EditorStyles.label)
                {
                    wordWrap = true,
                    fontSize = 11,
                    padding = new RectOffset(2, 4, 2, 4)
                };
                _infoStyle.normal.textColor = EditorGUIUtility.isProSkin
                    ? new Color(0.62f, 0.62f, 0.62f)
                    : new Color(0.35f, 0.35f, 0.35f);
            }

            if (_bannerTitleStyle == null)
            {
                _bannerTitleStyle = new GUIStyle(EditorStyles.boldLabel)
                {
                    fontSize = 15,
                    alignment = TextAnchor.MiddleLeft
                };
            }

            if (_bannerVersionStyle == null)
            {
                _bannerVersionStyle = new GUIStyle(EditorStyles.miniLabel)
                {
                    alignment = TextAnchor.UpperLeft
                };
                _bannerVersionStyle.normal.textColor = EditorGUIUtility.isProSkin
                    ? new Color(0.68f, 0.68f, 0.68f)
                    : new Color(0.32f, 0.32f, 0.32f);
            }

            if (_animBadgeStyle == null)
            {
                _animBadgeStyle = new GUIStyle(EditorStyles.miniBoldLabel)
                {
                    alignment = TextAnchor.MiddleRight
                };
            }

            if (_headerLabelStyle == null)
            {
                _headerLabelStyle = new GUIStyle(EditorStyles.boldLabel)
                {
                    alignment = TextAnchor.MiddleLeft
                };
            }
        }

        // ------------------------------------------------------------- build

        private void Rebuild()
        {
            _root = new Node { Path = string.Empty };
            _lockProperty = null;

            var byPath = new Dictionary<string, Node> { { string.Empty, _root } };

            // Groups shallowest-first, so a parent always exists before a child
            // needs it regardless of emission order.
            var defs = new List<GroupDef>(_data.groups ?? new GroupDef[0]);
            defs.Sort((a, b) => SegmentCount(a.path).CompareTo(SegmentCount(b.path)));

            foreach (GroupDef def in defs)
            {
                if (string.IsNullOrEmpty(def.path) || byPath.ContainsKey(def.path)) continue;

                var node = new Node
                {
                    Path = def.path,
                    Def = def,
                    Show = ParseJsonConditions(def.showIf),
                    PrefKey = "Zetph.FancyShader." + _shader.name + "." + def.path
                };

                Node parent;
                if (!byPath.TryGetValue(ParentPath(def.path), out parent))
                    parent = _root;

                parent.Groups.Add(node);
                byPath[def.path] = node;
            }

            _assignmentFlags.Clear();

            int count = _shader.GetPropertyCount();

            // Convention: a texture _Foo may declare a companion float _HasFoo.
            // The inspector keeps it in sync so the shader can branch on whether
            // anything was actually assigned, rather than on a strength slider
            // that says nothing about the slot being empty.
            for (int i = 0; i < count; i++)
            {
                if (_shader.GetPropertyType(i) != ShaderPropertyType.Texture) continue;

                string texture = _shader.GetPropertyName(i);
                string flag = "_Has" + texture.TrimStart('_');

                if (_shader.FindPropertyIndex(flag) >= 0)
                    _assignmentFlags.Add(new KeyValuePair<string, string>(texture, flag));
            }

            for (int i = 0; i < count; i++)
            {
                string name = _shader.GetPropertyName(i);
                string[] attributes = _shader.GetPropertyAttributes(i);

                if (HasAttribute(attributes, LockAttr))
                {
                    _lockProperty = name;
                    continue;
                }

                // A group's toggle is drawn in that group's header, not inline.
                if (AttributeArgument(attributes, GroupToggleAttr) != null) continue;

                if ((_shader.GetPropertyFlags(i) & ShaderPropertyFlags.HideInInspector) != 0)
                    continue;

                string path = AttributeArgument(attributes, GroupAttr) ?? string.Empty;
                Node owner = EnsureGroup(byPath, path);

                owner.Properties.Add(new Entry
                {
                    Name = name,
                    PropertyIndex = i,
                    Tooltip = _data.Tooltip(name),
                    Show = FilterConditions(ParseAttributeConditions(attributes), byPath, path),
                    Order = i
                });

                PropagateOrder(byPath, path, i);
            }

            PruneEmpty(_root);

            // DrawNodeChildren merges groups against properties by Order, which
            // requires both lists sorted. Properties already are - added in shader
            // index order - but groups were added in JSON order, which List.Sort
            // scrambled further because introsort is not stable.
            SortByOrder(_root);
        }

        /// <summary>
        /// Drops conditions that merely restate an ancestor group's enable toggle.
        /// Those are now expressed by greying the whole section out, so keeping
        /// them would hide the controls the greying is meant to reveal. Conditions
        /// on anything else - a sibling mode, a format choice - still hide.
        /// </summary>
        private static List<ZetCondition> FilterConditions(
            List<ZetCondition> conditions, Dictionary<string, Node> byPath, string path)
        {
            if (conditions == null || conditions.Count == 0) return null;

            var enables = new HashSet<string>();
            string walk = path;
            while (!string.IsNullOrEmpty(walk))
            {
                Node n;
                if (byPath.TryGetValue(walk, out n) && n.Def != null && !string.IsNullOrEmpty(n.Def.toggle))
                    enables.Add(n.Def.toggle);
                walk = ParentPath(walk);
            }

            List<ZetCondition> kept = null;
            for (int i = 0; i < conditions.Count; i++)
            {
                // Only a bare truthiness test on the enable property is redundant.
                // "_Foo equals 3" is a real distinction even if _Foo is the toggle.
                if (!conditions[i].HasValue && enables.Contains(conditions[i].Property))
                    continue;

                if (kept == null) kept = new List<ZetCondition>();
                kept.Add(conditions[i]);
            }

            return kept;
        }

        private Node EnsureGroup(Dictionary<string, Node> byPath, string path)
        {
            if (string.IsNullOrEmpty(path)) return _root;

            Node existing;
            if (byPath.TryGetValue(path, out existing)) return existing;

            Node parent = EnsureGroup(byPath, ParentPath(path));

            var node = new Node
            {
                Path = path,
                PrefKey = "Zetph.FancyShader." + _shader.name + "." + path
            };

            parent.Groups.Add(node);
            byPath[path] = node;

            Debug.LogWarning("[ZetsFancyShader] Group \"" + path +
                             "\" is referenced by a property but absent from the UI JSON. " +
                             "Rendering it unlabelled.");
            return node;
        }

        private static void PropagateOrder(Dictionary<string, Node> byPath, string path, int order)
        {
            while (!string.IsNullOrEmpty(path))
            {
                Node node;
                if (byPath.TryGetValue(path, out node) && order < node.Order)
                    node.Order = order;
                path = ParentPath(path);
            }
        }

        private static void PruneEmpty(Node node)
        {
            for (int i = node.Groups.Count - 1; i >= 0; i--)
            {
                Node child = node.Groups[i];
                PruneEmpty(child);

                if (child.Properties.Count == 0 && child.Groups.Count == 0)
                    node.Groups.RemoveAt(i);
            }
        }

        private static void SortByOrder(Node node)
        {
            node.Groups.Sort((a, b) => a.Order.CompareTo(b.Order));
            node.Properties.Sort((a, b) => a.Order.CompareTo(b.Order));

            for (int i = 0; i < node.Groups.Count; i++)
                SortByOrder(node.Groups[i]);
        }

        private static List<ZetCondition> ParseAttributeConditions(string[] attributes)
        {
            if (attributes == null) return null;

            List<ZetCondition> result = null;
            foreach (string a in attributes)
            {
                if (!a.StartsWith(ShowIfAttr, StringComparison.Ordinal)) continue;

                int close = a.LastIndexOf(')');
                if (close < ShowIfAttr.Length) continue;

                ZetCondition c;
                if (!ZetCondition.TryParseArgs(a.Substring(ShowIfAttr.Length, close - ShowIfAttr.Length), out c))
                    continue;

                if (result == null) result = new List<ZetCondition>();
                result.Add(c);
            }

            return result;
        }

        private static List<ZetCondition> ParseJsonConditions(string[] entries)
        {
            if (entries == null || entries.Length == 0) return null;

            List<ZetCondition> result = null;
            foreach (string e in entries)
            {
                ZetCondition c;
                if (!ZetCondition.TryParseJson(e, out c)) continue;

                if (result == null) result = new List<ZetCondition>();
                result.Add(c);
            }

            return result;
        }

        private static int SegmentCount(string path)
        {
            if (string.IsNullOrEmpty(path)) return 0;
            int n = 1;
            for (int i = 0; i < path.Length; i++)
                if (path[i] == '_') n++;
            return n;
        }

        private static string ParentPath(string path)
        {
            int sep = path.LastIndexOf('_');
            return sep < 0 ? string.Empty : path.Substring(0, sep);
        }

        private static bool HasAttribute(string[] attributes, string exact)
        {
            if (attributes == null) return false;
            foreach (string a in attributes)
                if (string.Equals(a, exact, StringComparison.Ordinal)) return true;
            return false;
        }

        private static string AttributeArgument(string[] attributes, string prefix)
        {
            if (attributes == null) return null;
            foreach (string a in attributes)
            {
                if (!a.StartsWith(prefix, StringComparison.Ordinal)) continue;
                int close = a.LastIndexOf(')');
                if (close < prefix.Length) continue;
                return a.Substring(prefix.Length, close - prefix.Length);
            }
            return null;
        }

        // ----------------------------------------------------------- drawing

        private float? GetFloat(string propertyName)
        {
            MaterialProperty p;
            return _lookup.TryGetValue(propertyName, out p) ? p.floatValue : (float?)null;
        }

        /// <summary>
        /// Writes each _HasFoo companion to match whether _Foo holds a real asset.
        /// Only writes on change, so this does not dirty the material every frame,
        /// and never touches a locked material - those values are already baked.
        /// </summary>
        private void SyncAssignmentFlags(MaterialEditor editor)
        {
            if (_assignmentFlags.Count == 0) return;

            foreach (UnityEngine.Object o in editor.targets)
            {
                var m = o as Material;
                if (m == null || ZetShaderLocker.IsLocked(m)) continue;

                for (int i = 0; i < _assignmentFlags.Count; i++)
                {
                    string texture = _assignmentFlags[i].Key;
                    string flag = _assignmentFlags[i].Value;

                    if (!m.HasProperty(texture) || !m.HasProperty(flag)) continue;

                    float want = IsRealTexture(m.GetTexture(texture)) ? 1f : 0f;
                    if (Mathf.Abs(m.GetFloat(flag) - want) < 0.0001f) continue;

                    m.SetFloat(flag, want);
                    EditorUtility.SetDirty(m);
                }
            }
        }

        /// <summary>
        /// A real project asset, not Unity's built-in stand-in. A slot declaring
        /// = "black" or = "white" resolves to a built-in texture rather than null,
        /// so a null check alone reports every empty slot as filled.
        /// </summary>
        private static bool IsRealTexture(Texture texture)
        {
            if (texture == null) return false;

            string path = AssetDatabase.GetAssetPath(texture);
            return !string.IsNullOrEmpty(path) &&
                   (path.StartsWith("Assets/", StringComparison.Ordinal) ||
                    path.StartsWith("Packages/", StringComparison.Ordinal));
        }

        private void RefreshAnimated(MaterialEditor editor)
        {
            if (!_animatedDirty && _animatedFor == editor.targets) return;

            _animated.Clear();
            _animatedFor = editor.targets;
            _animatedDirty = false;

            int count = _shader.GetPropertyCount();
            for (int i = 0; i < count; i++)
            {
                string name = _shader.GetPropertyName(i);
                if (ZetAnimatedProperties.IsAnimated(editor.targets, name))
                    _animated.Add(name);
            }
        }

        /// <summary>
        /// Propagates "contains something animated" and "contains real content"
        /// up the tree.
        ///
        /// Both flags are computed here rather than during drawing. They used to
        /// be set inside DrawEntry, which meant a collapsed or hidden section
        /// never updated them and its badge never appeared.
        /// </summary>
        private bool MarkState(Node node)
        {
            bool animated = false;
            bool content = false;

            // This loop only records per-property state. It must NOT decide
            // content: doing so counted hidden properties, so a section stayed
            // listed because some value behind a switched-off toggle had once
            // been nudged, and the visibility-aware test below never ran.
            for (int i = 0; i < node.Properties.Count; i++)
            {
                Entry e = node.Properties[i];

                e.Animated = _animated.Contains(e.Name);
                e.Meaningful = e.Animated || IsMeaningful(e);

                if (e.Animated) animated = true;
            }

            for (int i = 0; i < node.Groups.Count; i++)
            {
                if (MarkState(node.Groups[i])) animated = true;
                if (node.Groups[i].HasContent) content = true;
            }

            MaterialProperty toggle = FindToggle(node);

            if (toggle != null)
            {
                // A section with an enable switch is judged by that switch alone.
                // Leftover values inside a section that is off are baked out with
                // it, so counting them listed half the shader as "in use" - which
                // is exactly what the value test did on its own.
                content = toggle.floatValue > 0.5f;
            }
            else
            {
                // No enable switch, so fall back to whether anything was actually
                // configured - but only counting properties that are currently
                // visible. Height and Parallax hides this way: its strength and
                // offset values are gated behind toggles that are off, so they do
                // not count, and nothing ungated was ever set.
                for (int i = 0; i < node.Properties.Count && !content; i++)
                {
                    Entry e = node.Properties[i];
                    if (!e.Meaningful) continue;
                    if (!ZetCondition.EvaluateAll(e.Show, GetFloat)) continue;

                    content = true;
                }
            }

            // Animated always shows: it is live in the locked shader whatever
            // else is switched off around it.
            if (animated) content = true;

            node.HasAnimated = animated;
            node.HasContent = content;
            return animated;
        }

        /// <summary>
        /// Whether a property was actually configured: a texture is assigned, or
        /// the value differs from the shader's own default. This is what lets the
        /// locked view hide a section like Height and Parallax, which carries no
        /// enable toggle of its own and so cannot be judged by one.
        /// </summary>
        private bool IsMeaningful(Entry entry)
        {
            MaterialProperty p;
            if (!_lookup.TryGetValue(entry.Name, out p)) return false;

            int i = entry.PropertyIndex;
            if (i < 0 || i >= _shader.GetPropertyCount()) return false;

            switch (_shader.GetPropertyType(i))
            {
                case ShaderPropertyType.Texture:
                    return IsRealTexture(p.textureValue);

                case ShaderPropertyType.Float:
                case ShaderPropertyType.Range:
                case ShaderPropertyType.Int:
                    return Mathf.Abs(p.floatValue - _shader.GetPropertyDefaultFloatValue(i)) > 0.0001f;

                case ShaderPropertyType.Color:
                case ShaderPropertyType.Vector:
                    return (p.vectorValue - (Vector4)_shader.GetPropertyDefaultVectorValue(i)).sqrMagnitude > 1e-8f;

                default:
                    return false;
            }
        }

        private void HandleRightClick(MaterialEditor editor)
        {
            Event e = Event.current;
            if (e.type != EventType.ContextClick &&
                !(e.type == EventType.MouseDown && e.button == 1)) return;

            foreach (KeyValuePair<string, Rect> pair in _rowRects)
            {
                if (!pair.Value.Contains(e.mousePosition)) continue;

                ShowPropertyMenu(pair.Key, _animated.Contains(pair.Key), editor);
                e.Use();
                return;
            }
        }

        private void DrawNodeChildren(Node node, MaterialEditor editor, int depth)
        {
            // Merge subgroups and loose properties back into declaration order.
            int gi = 0, pi = 0;
            while (gi < node.Groups.Count || pi < node.Properties.Count)
            {
                bool takeGroup =
                    pi >= node.Properties.Count ||
                    (gi < node.Groups.Count && node.Groups[gi].Order <= node.Properties[pi].Order);

                if (takeGroup) DrawGroup(node.Groups[gi++], editor, depth);
                else DrawEntry(node.Properties[pi++], editor);
            }
        }

        private void DrawGroup(Node group, MaterialEditor editor, int depth)
        {
            if (!ZetCondition.EvaluateAll(group.Show, GetFloat)) return;

            MaterialProperty toggle = FindToggle(group);
            bool enabled = toggle == null || toggle.hasMixedValue || toggle.floatValue > 0.5f;

            // On a locked material, anything left at defaults with no toggle on
            // was baked out entirely. Judging by the enable toggle alone missed
            // sections that have no toggle - Height and Parallax being the case
            // that surfaced it.
            if (_lockedView && !group.HasContent && !_showInactiveWhenLocked)
                return;

            bool wasExpanded = EditorPrefs.GetBool(group.PrefKey, false);

            // BeginVertical hands back the union of everything drawn inside, which
            // is how the frame learns its own height. The rect is only meaningful
            // during Repaint - in the Layout pass it comes back empty.
            Rect frame = EditorGUILayout.BeginVertical();

            bool isExpanded = DrawHeader(group, depth, wasExpanded, toggle, editor, enabled);

            if (isExpanded != wasExpanded)
                EditorPrefs.SetBool(group.PrefKey, isExpanded);

            if (isExpanded)
            {
                // Disabled rather than hidden: the controls stay visible so the
                // section reads as switched off instead of unimplemented.
                // DisabledScope nests, so a disabled parent greys every descendant.
                using (new EditorGUI.DisabledScope(!enabled))
                {
                    EditorGUI.indentLevel++;

                    if (group.Def != null && !string.IsNullOrEmpty(group.Def.info))
                        DrawInfo(group.Def.info);

                    DrawNodeChildren(group, editor, depth + 1);

                    EditorGUI.indentLevel--;
                }

                EditorGUILayout.Space(4f);
            }

            EditorGUILayout.EndVertical();

            // Outline drawn last so it frames header and body together. An outline
            // has no fill, so drawing it over the contents costs nothing visually.
            if (Event.current.type == EventType.Repaint && frame.width > 1f && isExpanded)
            {
                Rect outline = frame;
                outline.xMin += (depth - 1) * IndentWidth;
                ZetUITheme.Border(outline, ZetUITheme.FrameBorder(depth, enabled),
                                  ZetUITheme.AllCorners(ZetUITheme.Radius), 1f);
            }

            EditorGUILayout.Space(2f);
        }

        /// <summary>
        /// One header row, drawn and hit-tested entirely by hand.
        ///
        /// Nothing here is an IMGUI control. Two earlier attempts mixed
        /// EditorGUI.Toggle and EditorGUI.Foldout with a manual click handler and
        /// the checkbox stopped responding: the toggle was not consuming the
        /// event, so the click fell through to header expansion. Whether that was
        /// GUI.enabled from an enclosing DisabledScope, a control-ID desync when a
        /// section's child count changes mid-event, or a rect smaller than the
        /// toggle style wants, the fix is the same - own the input. With no
        /// control IDs allocated in this row, there is nothing left to desync.
        /// </summary>
        private bool DrawHeader(Node group, int depth, bool expanded, MaterialProperty toggle,
                                MaterialEditor editor, bool enabled)
        {
            Rect row = GUILayoutUtility.GetRect(0f, HeaderHeight, GUILayout.ExpandWidth(true));
            row.xMin += (depth - 1) * IndentWidth;

            // Square off the bottom while open so the header meets the body frame
            // cleanly instead of leaving a pinched gap.
            Vector4 corners = expanded
                ? ZetUITheme.TopCorners(ZetUITheme.Radius)
                : ZetUITheme.AllCorners(ZetUITheme.Radius);

            ZetUITheme.Fill(row, ZetUITheme.HeaderFill(depth, enabled), corners);

            // Top-level tabs get an accent stripe so they read as a different rank
            // from their subsections rather than just a shade apart.
            if (depth <= 1)
            {
                var stripe = new Rect(row.x + 2f, row.y + 4f, 3f, row.height - 8f);
                ZetUITheme.Fill(stripe, ZetUITheme.HeaderStripe(enabled), ZetUITheme.AllCorners(1.5f));
            }

            float left = row.x + (depth <= 1 ? 10f : 5f);

            var arrowRect = new Rect(left, row.y + (HeaderHeight - ArrowWidth) * 0.5f,
                                     ArrowWidth, ArrowWidth);

            // Toggle space is reserved whether or not the group has one, so labels
            // stay in a column.
            var toggleRect = new Rect(arrowRect.xMax + 4f, row.y + (HeaderHeight - ToggleSize) * 0.5f,
                                      ToggleSize, ToggleSize);

            // The visible box is 15px; the target is the full header height and a
            // few pixels either side, which is far easier to hit.
            var toggleHit = new Rect(toggleRect.x - 5f, row.y, toggleRect.width + 10f, row.height);

            // Reserve the badge column unconditionally so a label never reflows
            // when something inside becomes animated.
            var badgeRect = new Rect(row.xMax - 26f, row.y, 22f, HeaderHeight);

            var labelRect = new Rect(toggleRect.xMax + 6f, row.y,
                                     Mathf.Max(badgeRect.x - toggleRect.xMax - 10f, 10f), HeaderHeight);

            Event e = Event.current;

            if (e.type == EventType.MouseDown && e.button == 0 && row.Contains(e.mousePosition))
            {
                if (toggle != null && !_lockedView && toggleHit.Contains(e.mousePosition))
                {
                    bool now = !(toggle.floatValue > 0.5f);

                    editor.RegisterPropertyChangeUndo(toggle.name);
                    toggle.floatValue = now ? 1f : 0f;

                    // Enabling refraction changes the queue the GrabPass needs.
                    // Previously this only re-asserted when the user touched
                    // Transparency Mode.
                    if (toggle.name == "_RefractEnable")
                        ReapplyRenderMode(editor);
                }
                else
                {
                    // Anywhere else on the bar expands or collapses, which is a far
                    // larger target than the arrow alone.
                    expanded = !expanded;
                }

                e.Use();
                GUI.changed = true;
            }

            if (e.type == EventType.Repaint)
            {
                // Drawn from styles rather than controls: same pixels, no input.
                EditorStyles.foldout.Draw(arrowRect, false, false, expanded, false);

                if (toggle != null)
                {
                    bool on = toggle.floatValue > 0.5f;
                    EditorStyles.toggle.Draw(toggleRect, false, false, on, false);
                }

                string label = group.Def != null && !string.IsNullOrEmpty(group.Def.label)
                    ? group.Def.label
                    : group.Path;

                if (toggle != null && toggle.hasMixedValue)
                    label += "  (mixed)";

                _headerLabelStyle.Draw(labelRect, label, false, false, false, false);

                // Green tick plus A, matching what ThryEditor showed, so a
                // collapsed section still tells you something inside is animated.
                if (group.HasAnimated)
                {
                    Color prev = _animBadgeStyle.normal.textColor;
                    _animBadgeStyle.normal.textColor = ZetUITheme.Animated(true);
                    _animBadgeStyle.Draw(badgeRect, "\u2713A", false, false, false, false);
                    _animBadgeStyle.normal.textColor = prev;
                }
            }

            return expanded;
        }

        private MaterialProperty FindToggle(Node group)
        {
            string name = group.Def != null ? group.Def.toggle : null;
            if (string.IsNullOrEmpty(name)) return null;

            MaterialProperty p;
            return _lookup.TryGetValue(name, out p) ? p : null;
        }

        // Column width per indent level, captured on the last repaint. The height
        // has to be reserved during Layout, before any rect exists, so on the first
        // frame there is nothing else to measure against.
        private static readonly Dictionary<int, float> _infoWidths = new Dictionary<int, float>();

        private static void DrawInfo(string text)
        {
            var content = new GUIContent(text);
            int indent = EditorGUI.indentLevel;

            // GetRect(content, style) is wrong for a wordWrap style: it measures
            // height against the style's PREFERRED (unwrapped, single-line) width,
            // then layout clamps the rect to the column and IndentedRect narrows it
            // again - so the text wraps to n lines inside a rect sized for one, and
            // the tail gets clipped. Measure by hand against the real width.
            // The first-frame fallback is deliberately narrow: over-reserving costs
            // a few pixels of whitespace, under-reserving eats the last line.
            float width;
            if (!_infoWidths.TryGetValue(indent, out width) || width < 1f)
                width = EditorGUIUtility.currentViewWidth - 40f - indent * 15f;

            float height = _infoStyle.CalcHeight(content, Mathf.Max(60f, width));

            Rect r = EditorGUI.IndentedRect(
                GUILayoutUtility.GetRect(0f, height, GUILayout.ExpandWidth(true)));

            if (Event.current.type == EventType.Repaint)
                _infoWidths[indent] = r.width;

            EditorGUI.LabelField(r, content, _infoStyle);
        }

        /// <summary>
        /// Texture slot drawn Standard-shader style: thumbnail against the left
        /// edge, label to its right. Unity's default ShaderProperty parks the slot
        /// at the far right of a three-line block, which turns "which slots in this
        /// section are filled?" into a scan down the right margin.
        /// Tiling/offset only appears when the property declares it.
        /// </summary>
        private static void DrawTextureRow(MaterialProperty property, GUIContent label, MaterialEditor editor)
        {
            editor.TexturePropertySingleLine(label, property);

            if ((property.flags & MaterialProperty.PropFlags.NoScaleOffset) == 0)
            {
                EditorGUI.indentLevel += 2;
                editor.TextureScaleOffsetProperty(property);
                EditorGUI.indentLevel -= 2;
            }
        }

        private void DrawEntry(Entry entry, MaterialEditor editor)
        {
            if (!ZetCondition.EvaluateAll(entry.Show, GetFloat)) return;

            MaterialProperty property;
            if (!_lookup.TryGetValue(entry.Name, out property)) return;

            bool animated = entry.Animated;

            string tip = entry.Tooltip;

            if (_lockedView)
            {
                // On a locked material the useful thing to say is whether this
                // value still does anything, not what it does.
                tip = animated
                    ? "Animated - still live in the locked shader."
                    : "Baked into the locked shader. Unlock to change.";
            }
            else if (animated)
            {
                tip = string.IsNullOrEmpty(tip)
                    ? "Animated: left live for animation instead of baked at lock."
                    : tip + "\n\nAnimated: left live for animation instead of baked at lock.";
            }

            Event e = Event.current;

            // Right-click, tested against the previous frame's rect because Unity's
            // own material fields consume the event before anything downstream of
            // ShaderProperty could see it.
            //
            // Deliberately no early return here. Skipping the layout calls below on
            // one event desyncs GUILayout for the remainder of the frame, which is
            // why the first attempt at this silently did nothing.
            Rect cached;
            if (e.type == EventType.MouseDown && e.button == 1 &&
                _rowRects.TryGetValue(entry.Name, out cached) && cached.Contains(e.mousePosition))
            {
                ShowPropertyMenu(entry.Name, animated, editor);
                e.Use();
            }

            // Marking properties animated is meaningless on a locked material -
            // the decision was made when it was baked.
            bool showGutter = _animationMode && !_lockedView;

            Rect gutter = default(Rect);

            if (showGutter)
            {
                EditorGUILayout.BeginHorizontal();

                gutter = GUILayoutUtility.GetRect(GutterWidth, GutterWidth,
                                                  GUILayout.Width(GutterWidth),
                                                  GUILayout.ExpandWidth(false));

                // Hit-tested by hand and drawn from a style, same as the group
                // headers, so it allocates no control ID.
                if (e.type == EventType.MouseDown && e.button == 0 && gutter.Contains(e.mousePosition))
                {
                    ToggleAnimated(entry.Name, animated, editor);
                    e.Use();
                    GUI.changed = true;
                }
            }

            // BeginVertical hands back the union of the property's rows, which a
            // texture field needs - it draws three lines, and GetLastRect would only
            // cover the final one.
            Rect row = EditorGUILayout.BeginVertical();

            // Baked values are shown but not editable. Animated ones stay live,
            // so this scope is the only difference between the two paths - which
            // is why they share everything below rather than returning early.
            using (new EditorGUI.DisabledScope(_lockedView && !animated))
            {
                var content = new GUIContent(property.displayName, tip);

                if (property.type == MaterialProperty.PropType.Texture)
                    DrawTextureRow(property, content, editor);
                else
                    editor.ShaderProperty(property, content);
            }

            EditorGUILayout.EndVertical();

            if (showGutter)
                EditorGUILayout.EndHorizontal();

            if (e.type == EventType.Repaint)
            {
                _rowRects[entry.Name] = row;

                if (showGutter)
                {
                    // Centred on the property's FIRST line, not on the whole row: a
                    // texture field is three lines tall and a box floating beside
                    // its midpoint reads as belonging to nothing.
                    float line = EditorGUIUtility.singleLineHeight;
                    var box = new Rect(gutter.x + 1f, gutter.y + (line - 14f) * 0.5f, 14f, 14f);
                    EditorStyles.toggle.Draw(box, false, false, animated, false);
                }

                if (animated && row.width > 1f)
                {
                    var marker = new Rect(row.x, row.y + 1f, 2f, row.height - 2f);
                    ZetUITheme.Fill(marker, ZetUITheme.Animated(true), ZetUITheme.AllCorners(1f));
                }
            }
        }

        /// <summary>
        /// Flips the animated flag, warning first when the property gates an //ifex
        /// block. Turning the flag off never warns - that direction is always safe.
        /// </summary>
        private void ToggleAnimated(string propertyName, bool animated, MaterialEditor editor)
        {
            bool critical = _data != null && _data.IsLockCritical(propertyName);

            if (!animated && critical)
            {
                bool ok = EditorUtility.DisplayDialog(
                    "Mark " + propertyName + " as animated?",
                    ZetAnimatedProperties.LockWarning(propertyName) + "\n\nMark it animated anyway?",
                    "Mark Animated", "Cancel");
                if (!ok) return;
            }

            ZetAnimatedProperties.SetAnimated(editor.targets, propertyName, !animated);
            _animatedDirty = true;
        }

        /// <summary>Right-click menu on a property row.</summary>
        private void ShowPropertyMenu(string propertyName, bool animated, MaterialEditor editor)
        {
            var menu = new GenericMenu();
            bool critical = _data != null && _data.IsLockCritical(propertyName);

            menu.AddItem(new GUIContent(critical ? "Animated (defeats a lock-time strip)" : "Animated"),
                animated,
                () => ToggleAnimated(propertyName, animated, editor));

            menu.AddSeparator(string.Empty);
            menu.AddItem(new GUIContent("Copy Property Name"), false,
                () => EditorGUIUtility.systemCopyBuffer = propertyName);

            menu.ShowAsContext();
        }

        private void DrawFiltered(Node node, MaterialEditor editor, string query)
        {
            foreach (Entry entry in node.Properties)
            {
                MaterialProperty property;
                bool matches =
                    entry.Name.ToLowerInvariant().Contains(query) ||
                    (_lookup.TryGetValue(entry.Name, out property) &&
                     property.displayName.ToLowerInvariant().Contains(query));

                if (matches) DrawEntry(entry, editor);
            }

            foreach (Node child in node.Groups)
                DrawFiltered(child, editor, query);
        }

        // ------------------------------------------------------------ chrome

        private void DrawBanner(Material material)
        {
            string title = _data != null && !string.IsNullOrEmpty(_data.title)
                ? _data.title
                : _shader.name;

            string version = _data != null ? _data.version : null;
            bool locked = ZetShaderLocker.IsLocked(material);

            Rect row = GUILayoutUtility.GetRect(0f, BannerHeight, GUILayout.ExpandWidth(true));

            ZetUITheme.Fill(row, ZetUITheme.HeaderFill(1, true),
                            ZetUITheme.AllCorners(ZetUITheme.Radius));

            var stripe = new Rect(row.x + 3f, row.y + 5f, 4f, row.height - 10f);
            ZetUITheme.Fill(stripe, ZetUITheme.HeaderStripe(true), ZetUITheme.AllCorners(2f));

            if (Event.current.type == EventType.Repaint)
            {
                var titleRect = new Rect(row.x + 14f, row.y + 4f, row.width - 130f, 20f);
                _bannerTitleStyle.Draw(titleRect, title, false, false, false, false);

                if (!string.IsNullOrEmpty(version))
                {
                    var verRect = new Rect(row.x + 14f, row.y + 22f, row.width - 130f, 14f);
                    _bannerVersionStyle.Draw(verRect, version, false, false, false, false);
                }

                // Lock state belongs here rather than only on the button: it is
                // the one fact you want visible without scrolling.
                var chip = new Rect(row.xMax - 78f, row.y + 12f, 68f, row.height - 24f);
                ZetUITheme.Fill(chip,
                    locked ? ZetUITheme.Animated(false) : ZetUITheme.FrameBorder(1, true),
                    ZetUITheme.AllCorners(3f));

                Color prev = _bannerVersionStyle.normal.textColor;
                _bannerVersionStyle.alignment = TextAnchor.MiddleCenter;
                _bannerVersionStyle.normal.textColor = locked
                    ? (EditorGUIUtility.isProSkin ? Color.black : Color.white)
                    : prev;

                _bannerVersionStyle.Draw(chip, locked ? "LOCKED" : "unlocked",
                                         false, false, false, false);

                _bannerVersionStyle.normal.textColor = prev;
                _bannerVersionStyle.alignment = TextAnchor.UpperLeft;
            }

            EditorGUILayout.Space(4f);
        }

        private void DrawLockButton(MaterialEditor editor)
        {
            if (_lockProperty == null) return;

            var material = editor.target as Material;
            if (material == null) return;

            bool locked = ZetShaderLocker.IsLocked(material);

            if (locked)
            {
                if (GUILayout.Button("Unlock"))
                    RunLock(editor, false);

                EditorGUILayout.LabelField(
                    "Locked. Values are baked into a generated shader; unlock to edit them.",
                    _infoStyle);
                EditorGUILayout.Space(2f);
                return;
            }

            if (GUILayout.Button("Lock / Optimize"))
                RunLock(editor, true);

            // Describe the outcome before committing to it, so the button is not a
            // leap of faith. Cheap: reads the file, strips nothing.
            ZetShaderLocker.Plan plan = ZetShaderLocker.Build(material);

            if (plan.Error != null)
            {
                EditorGUILayout.HelpBox("Cannot lock: " + plan.Error, MessageType.Error);
            }
            else if (plan.LinesRemoved == 0)
            {
                EditorGUILayout.HelpBox(
                    "Nothing to strip - every gated feature is either enabled or marked animated.",
                    MessageType.Info);
            }
            else
            {
                var sb = new System.Text.StringBuilder();
                sb.Append("Unlocked. Locking bakes ").Append(plan.Inlined)
                  .Append(" properties to constants and removes ")
                  .Append(plan.LinesRemoved).Append(" lines");

                var stripped = new List<string>();
                foreach (KeyValuePair<string, bool> kv in plan.Strip)
                    if (kv.Value) stripped.Add(kv.Key);

                if (stripped.Count > 0)
                    sb.Append(" (").Append(string.Join(", ", stripped.ToArray())).Append(")");
                sb.Append('.');

                if (plan.AnimatedKept.Count > 0)
                    sb.Append("\nLeft live because animated: ")
                      .Append(string.Join(", ", plan.AnimatedKept.ToArray()));
                else
                    sb.Append("\nNothing is marked animated - every value will be frozen.");

                EditorGUILayout.HelpBox(sb.ToString(), MessageType.Warning);
            }

            EditorGUILayout.Space(2f);
        }

        /// <summary>
        /// A locked material shows its whole structure, not just the live bits.
        /// The point is confirmation: you should be able to open Emission 0 and
        /// see the mask and colour you configured actually went in. Baked values
        /// are drawn disabled, because moving them would change nothing; animated
        /// properties stay live, because they still do.
        /// </summary>
        private void DrawLockedBody(MaterialEditor editor)
        {
            EditorGUILayout.BeginHorizontal();
            EditorGUILayout.LabelField("Baked configuration", EditorStyles.miniBoldLabel);

            bool show = GUILayout.Toggle(_showInactiveWhenLocked,
                new GUIContent("Show off", "Also list sections that were switched off when this material was locked."),
                EditorStyles.miniButton, GUILayout.Width(64f));

            if (show != _showInactiveWhenLocked)
            {
                _showInactiveWhenLocked = show;
                EditorPrefs.SetBool(ShowInactiveKey, show);
            }
            EditorGUILayout.EndHorizontal();
            EditorGUILayout.Space(2f);

            _lockedView = true;
            DrawNodeChildren(_root, editor, 1);
            _lockedView = false;
        }

        private static void RunLock(MaterialEditor editor, bool lockThem)
        {
            foreach (UnityEngine.Object o in editor.targets)
            {
                var m = o as Material;
                if (m == null) continue;

                string msg;
                bool ok = lockThem
                    ? ZetShaderLocker.Lock(m, out msg)
                    : ZetShaderLocker.Unlock(m, out msg);

                Debug.Log("[ZetsFancyShader] " + m.name + ": " + msg);

                if (!ok && lockThem)
                    EditorUtility.DisplayDialog("Lock failed", m.name + "\n\n" + msg, "OK");
            }

            AssetDatabase.SaveAssets();
            GUIUtility.ExitGUI();
        }

        private void DrawSearchField()
        {
            EditorGUILayout.BeginHorizontal();
            _search = EditorGUILayout.TextField("Search", _search);
            if (!string.IsNullOrEmpty(_search) && GUILayout.Button("x", GUILayout.Width(22f)))
            {
                _search = string.Empty;
                GUI.FocusControl(null);
            }

            bool mode = GUILayout.Toggle(_animationMode,
                new GUIContent("Anim", "Show a checkbox beside every property for marking it animated. " +
                                       "Animated properties are left live at lock time instead of baked."),
                EditorStyles.miniButton, GUILayout.Width(42f));

            if (mode != _animationMode)
            {
                _animationMode = mode;
                EditorPrefs.SetBool(AnimationModeKey, mode);
            }

            EditorGUILayout.EndHorizontal();

            if (_animationMode)
                EditorGUILayout.LabelField(
                    "Animation mode: tick a property to keep it live through locking.", _infoStyle);

            EditorGUILayout.Space(4f);
        }

        private static void ReapplyRenderMode(MaterialEditor editor)
        {
            foreach (UnityEngine.Object o in editor.targets)
            {
                var m = o as Material;
                if (m == null || !m.HasProperty("_AlphaMode")) continue;

                int mode = Mathf.Clamp(Mathf.RoundToInt(m.GetFloat("_AlphaMode")), 0, 2);
                ZetRenderModeDrawer.Apply(m, mode);
            }
        }
    }
}
