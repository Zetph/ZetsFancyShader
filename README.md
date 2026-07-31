# ZetsFancyShader

Yet another toon and PBR shader for VRChat avatars.

- LTCGI area lights, VRC Light Volumes, and AudioLink with a built-in material inspector to help you diagnose issues.

PC only. Unity 2022.3. MIT.

**[Install page →](https://zetph.github.io/ZetsFancyShader)**

---

## Install

Add this listing to VCC and install ZetsFancyShader. That's the whole thing:

```
https://zetph.github.io/ZetsFancyShader
```

### Optional extras

None of these are required. 

The shader compiles and works without them, add whichever you want, before or after installing the shader, and the matching features switch on by themselves!

| Repository | Package | Adds |
|---|---|---|
| [vpm.pimaker.at](https://vpm.pimaker.at/) | `at.pimaker.ltcgi` | LTCGI area lights |
| [redsim.github.io/vpmlisting](https://redsim.github.io/vpmlisting/) | `red.sim.lightvolumes` (2.1.3+) | VRC Light Volumes |
| VRChat curated (already in VCC) | `com.llealloo.audiolink` | Audio-reactive features |

Sections for packages you don't have appear grayed out in the inspector with a note and an Add to VCC button. 

Your settings in those sections are kept either way - install the package later and it picks up where you left off.

## Features

**World lighting** - LTCGI area lights and VRC Light Volumes, both with specular, when those packages are present. Falls back to Unity light probes otherwise.

**AudioLink** - emission, geometry break and glitch driven by the music. The sampling layer is embedded, so reactive features idle quietly rather than breaking when no AudioLink object is present.

**Toon and PBR** - ramp shading with metallic, smoothness and AO from a packed map, plus subsurface scattering for skin and thin cloth.

**Effects** - interior mapping, refraction, outlines, matcaps, iridescence, dissolve, and a screen shader for panels and displays.

**Debug views** - render one term on its own (albedo, normals, AO, ambient, reflection, LTCGI) instead of guessing which input turned a material black. Strips out entirely when the material is locked.

**Its own tooling** - material inspector, locking, animated-property tracking, dependency checking and a channel packer.

**Eye shader** - a companion shader for eyes, sharing the packed-map format and the same lighting paths; **experimental WIP.**

## Two things worth knowing

1. Disabled features are stripped at lock time, not at toggle time. An unlocked material compiles every feature it declares, including the refraction GrabPass, so uploading unlocked is both slower and heavier than it needs to be. `ZetLockOnUpload` handles this automatically.

2. Integration availability is resolved in C#, not in the shader. `ZetIntegrationGenerator` checks which packages are installed and writes `Runtime/Generated/ZetIntegrations.cginc`, which the shaders include unconditionally. That file is regenerated on domain reload, so adding or removing a package is picked up automatically — and because it resolves at edit time rather than compile time, locked and unlocked materials behave identically. If a section ever looks out of step with what you have installed, **Tools → ZetsFancyShader → Regenerate Integrations** forces a rebuild.

## Debug views

If a material looks wrong, utilise the Debug View dropdown:

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

If you're reporting a rendering problem, the most useful thing you can include is a screenshot of the relevant debug view and the world it happens in. 

!! The same material often behaves differently in a Light Volumes world than in one with baked probes.

## Credits

- [LTCGI](https://github.com/PiMaker/ltcgi) by PiMaker
- [VRC Light Volumes](https://github.com/REDSIM/VRCLightVolumes) by RED_SIM
- [AudioLink](https://github.com/llealloo/audiolink) by llealloo

## Links

[Releases](https://github.com/Zetph/ZetsFancyShader/releases) · [Discord](https://discord.gg/T2he8aAkyr)
