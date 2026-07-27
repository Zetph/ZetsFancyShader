# ZetsFancyShader — off ThryEditor

Migrated shaders, the companion JSON, the inspector that reads them, and the codemod that
produced it all.

```
Editor/ZetMaterialInspector.cs      the ShaderGUI
Editor/ZetUIData.cs                 JSON model, loader, ShowIf evaluator
migrated/ZetsFancyShader.shader     rewritten Properties block
migrated/ZetsFancyShaderUI.json     group labels, info text, 613 tooltips
migrated/ZetsFancyEyeShader.shader
migrated/ZetsFancyEyeShaderUI.json
tools/migrate_shader.py             re-runnable codemod
```

## Conventions

| Was | Is |
|---|---|
| `m_start_x` … `m_end_x`, bare `m_x` | `[Group(engine/stencil)]` on each property |
| `--{tooltip:...}` | `tooltips` array in the companion JSON |
| `--{condition_show:{type:AND,...}}` | `[ShowIf(_Foo && _Bar==3)]` |
| `--{reference_property:_X}` | `[GroupToggle(engine/prox)]` on `_X` itself |
| `[ZetInfoBox] info_x ("prose")` | `info` field on the group in JSON |
| `[ThryShaderOptimizerLockButton]` | `[ZetLockButton]` |
| `shader_is_using_thry_editor` | deleted |
| `GeometryShader_Enabled`, `Tessellation_Enabled` | deleted — ThryEditor optimizer hints, never referenced in your HLSL |

The JSON must sit beside its shader and be named `<ShaderFileName>UI.json`. A missing file
logs a warning and falls back to an unlabelled but functional inspector.

## Results

|  | Before | After |
|---|---|---|
| Properties-block lines | 960 | 705 |
| Median line length | 170 | 115 |
| p90 line length | 259 | 146 |
| Longest line | 584 | 195 |
| Dummy marker properties | 252 | 0 |

252 fewer serialised floats on every material. Both shaders migrated with zero warnings;
brace balance verified.

## Install

1. Copy `migrated/*` over your shader folder.
2. Copy `Editor/*.cs` in beside your existing drawers.
3. **Delete `ZetInfoBoxDrawer.cs`** — all 52 info boxes are JSON now, the drawer has no
   callers.
4. `ZetMapPackerDrawer` and `ZetRenderModeDrawer` are unchanged and still work; they are
   plain `MaterialPropertyDrawer`s, which `MaterialEditor.ShaderProperty` dispatches to.
5. Gut `ZetDependencyChecker` — the `ThryPresent()` probe and its modal are obsolete. Its
   original premise (bundling ThryEditor would collide with Poiyomi's copy) is exactly the
   problem a namespaced in-house inspector dissolves.

`ZetRenderModeDrawer` is in the global namespace while the inspector is namespaced. C#
resolves that outward without help; if you later namespace the drawers, update the
`ReapplyRenderMode` call site.

## Re-running the codemod

```
python3 tools/migrate_shader.py Foo.shader --dry-run
python3 tools/migrate_shader.py Foo.shader --out-shader Foo.new.shader --out-json FooUI.json
```

It reports unhandled metadata keys and unbalanced markers rather than silently dropping
them, so it stays useful if you revise the conventions later.

## Still outstanding

**Locking.** `[ZetLockButton]` renders disabled with a warning. The six `//ifex` blocks are
untouched and inert to Unity — they are comments until something acts on them:

| Line | Condition | Strips |
|---|---|---|
| 835 | `_LTCGI==0` | LTCGI include |
| 843 | `_LightVolumes==0` | Light Volumes include |
| 903, 1733, ~2600, ~3350 | `_RefractEnable==0` | GrabPass + refraction |
| ~2900 | `_OutlineStdEnable==0` | Outline pass |

All are `_Prop==0` guarding a region to delete — no value inlining, no macro expansion. A
minimum viable locker reads the source, evaluates those six conditions against the material,
deletes the regions, writes a generated `Hidden/Locked/...` shader and reassigns, storing the
original path in a material override tag so unlocking can restore it.

**`vpmDependencies` is still `{}`** while the shader hard-includes `at.pimaker.ltcgi` and
`red.sim.lightvolumes`. Unlocked materials in a project without those packages fail to
compile. Unchanged by this migration, and still the most likely thing to break for a new
user.

**Package identity** still disagrees across `package.json` (`com.zetph.…`), the asmdef
assembly name (`dev.zetph.…`), and the asmdef filename.

**Header comments** in both shaders still credit ThryEditor and describe its optimizer. Once
locking is yours, those lines and the MIT attribution can go.
