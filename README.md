# ZetsFancyShader

Yet another toon and PBR shader for VRChat avatars.
- LTCGI area lights, VRC Light Volumes, and AudioLink — with a built-in material inspector to help you diagnose issues.

PC only. Unity 2022.3. MIT.

**[Install page →](https://zetph.github.io/ZetsFancyShader)**

---

## Install

**IMPORTANT, THIS MUST BE DONE:**. 

The first two are dependencies; **add them before the shader or VCC has nowhere to resolve them from.**

| | Repository | Package |
|---|---|---|
| 1 | [vpm.pimaker.at](https://vpm.pimaker.at/) | `at.pimaker.ltcgi` |
| 2 | [redsim.github.io/vpmlisting](https://redsim.github.io/vpmlisting/) | `red.sim.lightvolumes` (2.1.3+) |
| 3 | [zetph.github.io/ZetsFancyShader](https://zetph.github.io/ZetsFancyShader) | `com.zetph.zetsfancyshader` |

Then open your avatar project in VCC and add ZetsFancyShader from the package list. Both dependencies install with it automatically.

Adding the shader on its own will fail to resolve; VCC only searches repositories you have already added, and neither dependency is in VRChat's curated repo.

## Features

**World lighting** — LTCGI area lights and VRC Light Volumes, both with specular. Falls back to Unity light probes in worlds that use neither.

**AudioLink** — emission, geometry break and glitch driven by the music. The sampling layer is embedded, so reactive features idle quietly rather than breaking when no AudioLink object is present.

**Toon and PBR** — ramp shading with metallic, smoothness and AO from a packed map, plus subsurface scattering for skin and thin cloth.

**Effects** — interior mapping, refraction, outlines, matcaps, iridescence, dissolve, and a screen shader for panels and displays.

**Debug views** — render one term on its own (albedo, normals, AO, ambient, reflection, LTCGI) instead of guessing which input turned a material black. Strips out entirely when the material is locked.

**Its own tooling** — material inspector, locking, animated-property tracking, dependency checking and a channel packer.

**Eye shader** — a companion shader for eyes, sharing the packed-map format and the same lighting paths; **experimental WIP.**

## Two things worth knowing

1. Disabled features are stripped at lock time, not at toggle time. An unlocked material compiles every feature it declares, including the refraction GrabPass, so uploading unlocked is both slower and heavier than it needs to be. `ZetLockOnUpload` handles this automatically.

2. **LTCGI and Light Volumes are required, not optional.** Their `#include`s are only stripped when a material locks, so an unlocked material in a project missing either package fails to compile — pink materials rather than a missing feature. This is why the install order above matters.

## Debug views

If a material looks wrong, switch the Debug View dropdown rather than guessing:

| Symptom | Look at |
|---|---|
| Surface renders black | AO, then Ambient |
| Surface is a mirror | Metallic |
| Reflections missing | Smoothness, then Reflection |
| Wrong lighting direction | World Normal |
| Packed map read wrong | Packed Map RGB |

Set it back to Off before locking. It drives an `//ifex`, so Off removes the feature from the locked shader, and anything else ships the debug view to everyone who sees you.

## Contributing

Issues and pull requests welcome. 

If you're reporting a rendering problem, the most useful thing you can include is a screenshot of the relevant debug view and the world it happens in — the same material often behaves differently in a Light Volumes world than in one with baked probes.

## Credits

- [LTCGI](https://github.com/PiMaker/ltcgi) by PiMaker
- [VRC Light Volumes](https://github.com/REDSIM/VRCLightVolumes) by RED_SIM
- [AudioLink](https://github.com/llealloo/audiolink) by llealloo

## Links

[Releases](https://github.com/Zetph/ZetsFancyShader/releases) · [Discord](https://discord.gg/T2he8aAkyr)
