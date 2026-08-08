// ==============================================================================
// ZetsFancyShader
// Version: v0.4.1
// Author: Zetph
//
// Welcome to the source code!
// This shader was built to give the VRChat, Booth, and Gumroad creator
// communities a highly performant, feature-rich toon and FX shader without
// the heavy runtime cost.
//
// If you are reading this, you are either curious about how things work under
// the hood, or you are looking to write custom modifications. Feel free to
// explore! Because this integrates with ThryEditor, remember that the optimizer
// handles stripping the heavy features at lock-time to keep your framerates
// high. Keep that in mind if you start poking around or adding custom passes.
//
// A massive thank you to the open-source tools that make this ecosystem great:
// - ThryEditor by Thryrallo (MIT License)
// - AudioLink by llealloo (MIT License)
// - LTCGI by pimaker (MIT License)
//
// This shader is free, but if you find it useful for your avatars, consider
// dropping a tip to support future development. Enjoy the alpha!
// ==============================================================================
Shader "Zetph/ZetsFancyShader"
{
        Properties
    {
        [HideInInspector] shader_master_label ("ZetsFancyShader", Float) = 0
        [ZetLockButton] _ShaderOptimizerEnabled ("Lock / Optimize", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] [Group(engine)] _CullMode ("Culling Mode (Back = Best Perf)", Float) = 2
        [IntRange] [Group(engine_stencil)] _StencilRef ("Stencil Reference Value (0-255)", Range(0, 255)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [Group(engine_stencil)] _StencilComp ("Stencil Comparison (Always = off)", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] [Group(engine_stencil)] _StencilPass ("On Stencil Pass (Keep = off)", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] [Group(engine_stencil)] _StencilFail ("On Stencil Fail", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] [Group(engine_stencil)] _StencilZFail ("On Depth Fail", Float) = 0
        [IntRange] [Group(engine_stencil)] _StencilReadMask ("Read Mask", Range(0, 255)) = 255
        [IntRange] [Group(engine_stencil)] _StencilWriteMask ("Write Mask", Range(0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] [Group(engine_renderstate)] _ZTest ("Depth Test", Float) = 4
        [Enum(Off, 0, On, 1)] [Group(engine_renderstate)] _ZWriteOverride ("Depth Write Override", Float) = 1
        [Enum(None, 0, Red, 8, Green, 4, Blue, 2, Alpha, 1, RGB, 14, RGBA, 15)] [Group(engine_renderstate)] _ColorMask ("Color Mask", Float) = 15
        [Group(engine_renderstate)] _OffsetFactor ("Depth Offset Factor", Range(-5, 5)) = 0
        [Group(engine_renderstate)] _OffsetUnits ("Depth Offset Units", Range(-100, 100)) = 0
        [Toggle] [GroupToggle(engine_prox)] _ProximityFade ("Enable Camera Proximity Fade", Float) = 0
        [Group(engine_prox)] [ShowIf(_ProximityFade)] _ProxMin ("Fade Start Distance (m)", Float) = 0.2
        [Group(engine_prox)] [ShowIf(_ProximityFade)] _ProxMax ("Fade End Distance (m)", Float) = 0.6
        [Toggle] [GroupToggle(engine_alenv)] _ALEnvEnable ("Enable AudioLink Smoothing", Float) = 1
        [Group(engine_alenv)] [ShowIf(_ALEnvEnable)] _ALEnvRelease ("Release / Tail", Range(0, 1)) = 0.45
        [Toggle] [GroupToggle(engine_cc)] _UseColorChord ("Enable AudioLink ColorChord", Float) = 0
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Em0 ("Theme: Emission 0", Float) = 0
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Em1 ("Theme: Emission 1", Float) = 1
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Em2 ("Theme: Emission 2", Float) = 2
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Em3 ("Theme: Emission 3", Float) = 3
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Outline ("Theme: Glitch Outline", Float) = 2
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Stars ("Theme: Constellation", Float) = 3
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Rim ("Theme: Fresnel Rim", Float) = 0
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Break ("Theme: Geometry Break", Float) = 1
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Speaker ("Theme: Speaker Ripple", Float) = 1
        [Enum(Theme 0, 0, Theme 1, 1, Theme 2, 2, Theme 3, 3)] [Group(engine_cc)] [ShowIf(_UseColorChord)] _CC_Dissolve ("Theme: Dissolve", Float) = 1
        [Toggle] [GroupToggle(engine_vertal)] _VertALEnable ("Enable AudioLink Vertex FX", Float) = 0
        [NoScaleOffset] [Group(engine_vertal)] [ShowIf(_VertALEnable)] _VertALMask ("Effect Mask (R, white = moves)", 2D) = "white" {}
        [Toggle] [GroupToggle(engine_vertal_valtrans)] _VertALTransEnable ("Enable Local Translation", Float) = 0
        [Group(engine_vertal_valtrans)] [ShowIf(_VertALTransEnable)] _VertALTransMin ("Translation Min (m)", Vector) = (0, 0, 0, 0)
        [Group(engine_vertal_valtrans)] [ShowIf(_VertALTransEnable)] _VertALTransMax ("Translation Max (m)", Vector) = (0, 0, 0, 0)
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valtrans)] [ShowIf(_VertALTransEnable)] _VertALTransBandX ("Band X", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valtrans)] [ShowIf(_VertALTransEnable)] _VertALTransBandY ("Band Y", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valtrans)] [ShowIf(_VertALTransEnable)] _VertALTransBandZ ("Band Z", Float) = 0
        [Toggle] [GroupToggle(engine_vertal_valwtrans)] _VertALWTransEnable ("Enable World Translation", Float) = 0
        [Group(engine_vertal_valwtrans)] [ShowIf(_VertALWTransEnable)] _VertALWTransMin ("World Translation Min (m)", Vector) = (0, 0, 0, 0)
        [Group(engine_vertal_valwtrans)] [ShowIf(_VertALWTransEnable)] _VertALWTransMax ("World Translation Max (m)", Vector) = (0, 0, 0, 0)
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valwtrans)] [ShowIf(_VertALWTransEnable)] _VertALWTransBandX ("Band X", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valwtrans)] [ShowIf(_VertALWTransEnable)] _VertALWTransBandY ("Band Y", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valwtrans)] [ShowIf(_VertALWTransEnable)] _VertALWTransBandZ ("Band Z", Float) = 0
        [Toggle] [GroupToggle(engine_vertal_valrot)] _VertALRotEnable ("Enable Rotation", Float) = 0
        [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRot ("Rotation (deg)", Vector) = (0, 0, 0, 0)
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRotBandX ("Band X", Float) = 0
        [Enum(Intensity, 0, Accumulate, 1, Accumulate When Quiet, 2, Ping Pong, 3)] [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRotModeX ("Motion Type X", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRotBandY ("Band Y", Float) = 0
        [Enum(Intensity, 0, Accumulate, 1, Accumulate When Quiet, 2, Ping Pong, 3)] [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRotModeY ("Motion Type Y", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRotBandZ ("Band Z", Float) = 0
        [Enum(Intensity, 0, Accumulate, 1, Accumulate When Quiet, 2, Ping Pong, 3)] [Group(engine_vertal_valrot)] [ShowIf(_VertALRotEnable)] _VertALRotModeZ ("Motion Type Z", Float) = 0
        [Toggle] [GroupToggle(engine_vertal_valspin)] _VertALRotSpdEnable ("Enable Band-Driven Spin", Float) = 0
        [Group(engine_vertal_valspin)] [ShowIf(_VertALRotSpdEnable)] _VertALRotSpd ("Spin (deg per audio-second)", Vector) = (0, 0, 0, 0)
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valspin)] [ShowIf(_VertALRotSpdEnable)] _VertALRotSpdBand ("Spin Band", Float) = 0
        [Toggle] [GroupToggle(engine_vertal_valscale)] _VertALScaleEnable ("Enable Scale", Float) = 0
        [Group(engine_vertal_valscale)] [ShowIf(_VertALScaleEnable)] _VertALScaleMin ("Scale Min", Vector) = (1, 1, 1, 1)
        [Group(engine_vertal_valscale)] [ShowIf(_VertALScaleEnable)] _VertALScaleMax ("Scale Max", Vector) = (1, 1, 1, 1)
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valscale)] [ShowIf(_VertALScaleEnable)] _VertALScaleBand ("Scale Band", Float) = 0
        [Toggle] [GroupToggle(engine_vertal_valuv)] _VertALUVEnable ("Enable UV Scroll", Float) = 0
        [Enum(Offset by Intensity, 0, Scroll by Intensity, 1)] [Group(engine_vertal_valuv)] [ShowIf(_VertALUVEnable)] _VertALUVMode ("UV Mode", Float) = 1
        [Group(engine_vertal_valuv)] [ShowIf(_VertALUVEnable)] _VertALUVSpeed ("UV Direction / Speed (X,Y)", Vector) = (0.25, 0, 0, 0)
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(engine_vertal_valuv)] [ShowIf(_VertALUVEnable)] _VertALUVBand ("UV Band", Float) = 0
        [Group(base)] _MainTex ("Base Texture (Albedo)", 2D) = "white" {}
        [Normal] [Group(base)] _BumpMap ("Normal Map (Surface Detail)", 2D) = "bump" {}
        [Group(base)] _BumpScale ("Normal Strength", Range(0, 2)) = 1
        [ZetRenderMode] [Group(base)] _AlphaMode ("Transparency Mode", Float) = 0
        [Group(base)] [ShowIf(_AlphaMode, 1)] _Cutoff ("Cutout Threshold", Range(0, 1)) = 0.5
        [Toggle] [Group(base)] [ShowIf(_AlphaMode)] _AlphaSourceEnable ("Use Separate Alpha Map", Float) = 0
        [NoScaleOffset] [Group(base)] [ShowIf(_AlphaMode)] [ShowIf(_AlphaSourceEnable)] _AlphaTex ("Alpha / Opacity Map", 2D) = "white" {}
        [Enum(Red, 0, Green, 1, Blue, 2, Alpha, 3)] [Group(base)] [ShowIf(_AlphaMode)] [ShowIf(_AlphaSourceEnable)] _AlphaChannel ("Opacity Channel", Float) = 0
        [HideInInspector] [Group(base)] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] [Group(base)] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] [Group(base)] _ZWrite ("__zw", Float) = 1.0
        [HideInInspector] [Group(base)] _AlphaToMask ("__a2c", Float) = 0.0
        [Toggle] [Group(base)] _ColorAdjustEnable ("Colour Adjust", Float) = 0
        [Group(base)] [ShowIf(_ColorAdjustEnable)] _Saturation ("Saturation", Range(0, 2)) = 1.0
        [Group(base)] [ShowIf(_ColorAdjustEnable)] _Brightness ("Brightness", Range(0, 5)) = 1.0
        [Group(base)] [ShowIf(_ColorAdjustEnable)] _Gamma ("Gamma", Range(0.1, 3)) = 1.0
        [Group(base)] [ShowIf(_ColorAdjustEnable)] _BaseHueShift ("Static Hue Shift", Range(0, 1)) = 0.0
        [Toggle] [Group(base)] [ShowIf(_ColorAdjustEnable)] _BaseHueShiftAL ("AudioLink Hue Shift", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(base)] [ShowIf(_ColorAdjustEnable)] _BaseHueBand ("AL Hue Band", Float) = 0
        [Toggle] [GroupToggle(base_decals)] _DecalsEnable ("Enable Decals", Float) = 0
        [Toggle] [GroupToggle(base_decals_decal0)] _Decal0Enable ("Enable Decal 0", Float) = 0
        [NoScaleOffset] [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Tex ("Decal Image", 2D) = "white" {}
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Color ("Tint", Color) = (1, 1, 1, 1)
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Opacity ("Opacity", Range(0, 1)) = 1
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0PosX ("Position X", Range(0, 1)) = 0.5
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0PosY ("Position Y", Range(0, 1)) = 0.5
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Scale ("Size", Range(0.01, 2)) = 0.3
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Rotation ("Rotation", Range(0, 360)) = 0
        [Enum(Normal, 0, Add, 1, Multiply, 2, Screen, 3)] [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Blend ("Blend Mode", Float) = 0
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Emit ("Emission Glow", Range(0, 4)) = 0
        [Toggle] [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Overlay ("Draw On Top (over room/screen)", Float) = 0
        [Toggle] [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] _Decal0Flipbook ("Animated (Flipbook)", Float) = 0
        [IntRange] [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] [ShowIf(_Decal0Flipbook)] _Decal0FlipCols ("Flipbook Columns", Range(1, 16)) = 4
        [IntRange] [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] [ShowIf(_Decal0Flipbook)] _Decal0FlipRows ("Flipbook Rows", Range(1, 16)) = 4
        [Group(base_decals_decal0)] [ShowIf(_Decal0Enable)] [ShowIf(_Decal0Flipbook)] _Decal0FlipFPS ("Flipbook Speed (FPS)", Range(1, 60)) = 12
        [Toggle(ZET_DEC1)] [GroupToggle(base_decals_decal1)] _Decal1Enable ("Enable Decal 1", Float) = 0
        [NoScaleOffset] [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Tex ("Decal Image", 2D) = "white" {}
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Color ("Tint", Color) = (1, 1, 1, 1)
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Opacity ("Opacity", Range(0, 1)) = 1
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1PosX ("Position X", Range(0, 1)) = 0.5
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1PosY ("Position Y", Range(0, 1)) = 0.5
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Scale ("Size", Range(0.01, 2)) = 0.3
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Rotation ("Rotation", Range(0, 360)) = 0
        [Enum(Normal, 0, Add, 1, Multiply, 2, Screen, 3)] [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Blend ("Blend Mode", Float) = 0
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Emit ("Emission Glow", Range(0, 4)) = 0
        [Toggle] [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Overlay ("Draw On Top (over room/screen)", Float) = 0
        [Toggle] [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] _Decal1Flipbook ("Animated (Flipbook)", Float) = 0
        [IntRange] [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] [ShowIf(_Decal1Flipbook)] _Decal1FlipCols ("Flipbook Columns", Range(1, 16)) = 4
        [IntRange] [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] [ShowIf(_Decal1Flipbook)] _Decal1FlipRows ("Flipbook Rows", Range(1, 16)) = 4
        [Group(base_decals_decal1)] [ShowIf(_Decal1Enable)] [ShowIf(_Decal1Flipbook)] _Decal1FlipFPS ("Flipbook Speed (FPS)", Range(1, 60)) = 12
        [Toggle(ZET_DEC2)] [GroupToggle(base_decals_decal2)] _Decal2Enable ("Enable Decal 2", Float) = 0
        [NoScaleOffset] [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Tex ("Decal Image", 2D) = "white" {}
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Color ("Tint", Color) = (1, 1, 1, 1)
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Opacity ("Opacity", Range(0, 1)) = 1
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2PosX ("Position X", Range(0, 1)) = 0.5
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2PosY ("Position Y", Range(0, 1)) = 0.5
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Scale ("Size", Range(0.01, 2)) = 0.3
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Rotation ("Rotation", Range(0, 360)) = 0
        [Enum(Normal, 0, Add, 1, Multiply, 2, Screen, 3)] [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Blend ("Blend Mode", Float) = 0
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Emit ("Emission Glow", Range(0, 4)) = 0
        [Toggle] [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Overlay ("Draw On Top (over room/screen)", Float) = 0
        [Toggle] [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] _Decal2Flipbook ("Animated (Flipbook)", Float) = 0
        [IntRange] [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] [ShowIf(_Decal2Flipbook)] _Decal2FlipCols ("Flipbook Columns", Range(1, 16)) = 4
        [IntRange] [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] [ShowIf(_Decal2Flipbook)] _Decal2FlipRows ("Flipbook Rows", Range(1, 16)) = 4
        [Group(base_decals_decal2)] [ShowIf(_Decal2Enable)] [ShowIf(_Decal2Flipbook)] _Decal2FlipFPS ("Flipbook Speed (FPS)", Range(1, 60)) = 12
        [Toggle(ZET_DEC3)] [GroupToggle(base_decals_decal3)] _Decal3Enable ("Enable Decal 3", Float) = 0
        [NoScaleOffset] [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Tex ("Decal Image", 2D) = "white" {}
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Color ("Tint", Color) = (1, 1, 1, 1)
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Opacity ("Opacity", Range(0, 1)) = 1
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3PosX ("Position X", Range(0, 1)) = 0.5
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3PosY ("Position Y", Range(0, 1)) = 0.5
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Scale ("Size", Range(0.01, 2)) = 0.3
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Rotation ("Rotation", Range(0, 360)) = 0
        [Enum(Normal, 0, Add, 1, Multiply, 2, Screen, 3)] [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Blend ("Blend Mode", Float) = 0
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Emit ("Emission Glow", Range(0, 4)) = 0
        [Toggle] [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Overlay ("Draw On Top (over room/screen)", Float) = 0
        [Toggle] [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] _Decal3Flipbook ("Animated (Flipbook)", Float) = 0
        [IntRange] [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] [ShowIf(_Decal3Flipbook)] _Decal3FlipCols ("Flipbook Columns", Range(1, 16)) = 4
        [IntRange] [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] [ShowIf(_Decal3Flipbook)] _Decal3FlipRows ("Flipbook Rows", Range(1, 16)) = 4
        [Group(base_decals_decal3)] [ShowIf(_Decal3Enable)] [ShowIf(_Decal3Flipbook)] _Decal3FlipFPS ("Flipbook Speed (FPS)", Range(1, 60)) = 12
        [Toggle] [GroupToggle(base_uvtd)] _UVTileDiscardEnable ("Enable UV Tile Discard", Float) = 0
        [Enum(UV0, 0, UV1, 1)] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileDiscardChannel ("UV Channel", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow0_0 ("Discard Tile (0,0)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow0_1 ("Discard Tile (1,0)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow0_2 ("Discard Tile (2,0)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow0_3 ("Discard Tile (3,0)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow1_0 ("Discard Tile (0,1)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow1_1 ("Discard Tile (1,1)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow1_2 ("Discard Tile (2,1)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow1_3 ("Discard Tile (3,1)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow2_0 ("Discard Tile (0,2)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow2_1 ("Discard Tile (1,2)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow2_2 ("Discard Tile (2,2)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow2_3 ("Discard Tile (3,2)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow3_0 ("Discard Tile (0,3)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow3_1 ("Discard Tile (1,3)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow3_2 ("Discard Tile (2,3)", Float) = 0
        [Toggle] [Group(base_uvtd)] [ShowIf(_UVTileDiscardEnable)] _UVTileRow3_3 ("Discard Tile (3,3)", Float) = 0
        [Toggle] [GroupToggle(base_detail)] _DetailEnable ("Enable Detail Maps", Float) = 0
        [Group(base_detail)] [ShowIf(_DetailEnable)] _DetailMask ("Detail Mask", 2D) = "white" {}
        [Group(base_detail)] [ShowIf(_DetailEnable)] _DetailTiling ("Detail Tiling (X,Y) + Offset (Z,W)", Vector) = (8, 8, 0, 0)
        [Group(base_detail)] [ShowIf(_DetailEnable)] _DetailAlbedo ("Detail Albedo (grey = neutral)", 2D) = "grey" {}
        [Group(base_detail)] [ShowIf(_DetailEnable)] _DetailAlbedoStrength ("Albedo Detail Strength", Range(0, 1)) = 1
        [Normal] [Group(base_detail)] [ShowIf(_DetailEnable)] _DetailNormal ("Detail Normal", 2D) = "bump" {}
        [Group(base_detail)] [ShowIf(_DetailEnable)] _DetailNormalStrength ("Normal Detail Strength", Range(0, 4)) = 1
        [Enum(Toon Ramp, 0, Realistic PBR, 1, Cloth, 2)] [Group(lighting)] _LightingModel ("Lighting Model", Float) = 0
        [Group(lighting)] [ShowIf(_LightingModel, 0)] _ShadowEdge ("Shadow Edge (Toon)", Range(0, 1)) = 0.5
        [Group(lighting)] [ShowIf(_LightingModel, 0)] _ShadowSoft ("Shadow Softness (Toon)", Range(0.001, 0.5)) = 0.01
        [Group(lighting)] [ShowIf(_LightingModel, 0)] _ShadowDither ("Shadow Dithering (Toon)", Range(0, 0.1)) = 0
        [Group(lighting)] [ShowIf(_LightingModel, 0)] _SpecEdge ("Specular Edge (Toon)", Range(0.001, 0.5)) = 0.08
        [Group(lighting)] [ShowIf(_LightingModel, 2)] _ClothWrap ("Cloth Diffuse Wrap", Range(0, 1)) = 0.5
        [HDR] [Group(lighting)] [ShowIf(_LightingModel, 2)] _SheenColor ("Sheen Color", Color) = (1, 1, 1, 1)
        [Group(lighting)] _ShadowTint ("Shadow Tint", Color) = (0.5, 0.5, 0.5, 1)
        [Group(lighting)] _MaxBrightness ("Max Light Brightness", Range(0, 5)) = 1.0
        [Group(lighting)] _MinBrightness ("Min Light Brightness", Range(0, 1)) = 0.0
        [Group(lighting)] _GrayscaleLighting ("Grayscale Lighting", Range(0, 1)) = 0.0
        [Group(lighting)] _ReceiveShadows ("Receive Casted Shadows", Range(0, 1)) = 1.0
        [Toggle] [GroupToggle(lighting_sss)] _SSSEnable ("Enable Subsurface Scattering", Float) = 0
        [Group(lighting_sss)] [ShowIf(_SSSEnable)] _SSSMask ("SSS Mask", 2D) = "white" {}
        [Enum(Custom Color, 0, From Base Color, 1, Skin, 2, Foliage, 3, Marble, 4)] [Group(lighting_sss)] [ShowIf(_SSSEnable)] _SSSTintMode ("Tint Source", Float) = 0
        [HDR] [Group(lighting_sss)] [ShowIf(_SSSEnable)] [ShowIf(_SSSTintMode, 0)] _SSSColor ("Scatter Color", Color) = (1.0, 0.25, 0.1, 1)
        [Group(lighting_sss_sssterm)] [ShowIf(_SSSEnable)] _SSSTermWidth ("Terminator Scatter Width", Range(0, 1)) = 0.35
        [Group(lighting_sss_sssterm)] [ShowIf(_SSSEnable)] _SSSTermStrength ("Terminator Scatter Strength", Range(0, 2)) = 0.6
        [Group(lighting_sss_ssstrans)] [ShowIf(_SSSEnable)] _SSSThicknessMap ("Thickness Map (black = thin)", 2D) = "black" {}
        [Group(lighting_sss_ssstrans)] [ShowIf(_SSSEnable)] _SSSTransStrength ("Transmission Strength", Range(0, 4)) = 1
        [Group(lighting_sss_ssstrans)] [ShowIf(_SSSEnable)] _SSSTransPower ("Transmission Focus", Range(1, 16)) = 4
        [Group(lighting_sss_ssstrans)] [ShowIf(_SSSEnable)] _SSSTransDistortion ("Normal Distortion", Range(0, 1)) = 0.4
        [Group(lighting_sss_sssworld)] [ShowIf(_SSSEnable)] _SSSAmbient ("Ambient Transmission", Range(0, 1)) = 0.2
        [Group(lighting_sss_sssworld)] [ShowIf(_SSSEnable)] _SSSProbeLight ("Probe Light Transmission", Range(0, 2)) = 1
        [Toggle] [Group(lighting_sss_sssworld)] [ShowIf(_SSSEnable)] _SSSLTCGI ("LTCGI Transmission", Float) = 0
        [Group(lighting_sss_sssworld)] [ShowIf(_SSSEnable)] [ShowIf(_LightVolumes)] _SSSLVDepth ("Volume Sample Depth", Range(0, 0.3)) = 0.05
        [Toggle] [Group(lighting_reflspec)] _ReflectionsEnable ("Enable Reflection Probes", Float) = 1
        [NoScaleOffset] [Group(lighting_reflspec)] [ShowIf(_ReflectionsEnable)] _BakedCubemap ("Reflection Fallback Cubemap", Cube) = "black" {}
        [HideInInspector] [Group(lighting_reflspec)] _HasBakedCubemap ("", Float) = 0
        [Group(lighting_reflspec)] [ShowIf(_ReflectionsEnable)] _FallbackCubemapStrength ("Fallback Strength (fills dark worlds)", Range(0, 2)) = 1
        [Toggle] [Group(lighting_reflspec)] [ShowIf(_ReflectionsEnable)] _ForceFallback ("Force Fallback (preview - ignore world probe)", Float) = 0
        [Group(lighting_reflspec)] [ShowIf(_ReflectionsEnable)] _ReflStrength ("Reflection Strength", Range(0, 2)) = 1
        [Enum(ZFS Packed, 0, Unity MetalSmooth, 1)] [Group(lighting_reflspec)] _PackMode ("Packed Map Format", Float) = 0
        [NoScaleOffset] [Group(lighting_reflspec)] _PackedMap ("Packed PBR Map (R=Metallic  G=AO  B=Smoothness)", 2D) = "white" {}
        [Toggle] [Group(lighting_reflspec)] _InvSmooth ("Map uses Roughness (invert smoothness)", Float) = 0
        [Group(lighting_reflspec)] _PackedTiling ("Packed Tiling (X,Y)", Vector) = (1, 1, 0, 0)
        [Group(lighting_reflspec)] _PackedOffset ("Packed Offset (X,Y)", Vector) = (0, 0, 0, 0)
        [Group(lighting_reflspec)] _PackedPan ("Packed Panning (X,Y)", Vector) = (0, 0, 0, 0)
        [Toggle] [Group(lighting_reflspec)] _PackedStochastic ("Stochastic Sampling", Float) = 0
        [Group(lighting_reflspec)] _Metallic ("Metallic", Range(0, 1)) = 0
        [Group(lighting_reflspec)] _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        [Toggle] [Group(lighting_reflspec)] _AdvancedRemap ("Advanced Map Remapping", Float) = 0
        [Group(lighting_reflspec)] [ShowIf(_AdvancedRemap)] _MetallicMin ("Metallic Floor (map black)", Range(0, 1)) = 0
        [Group(lighting_reflspec)] [ShowIf(_AdvancedRemap)] _SmoothnessMin ("Smoothness Floor (map black)", Range(0, 1)) = 0
        [Group(lighting_reflspec)] _OcclusionStrength ("AO Strength", Range(0, 1)) = 1
        [Toggle] [Group(lighting_reflspec)] _ReflTintOn ("Tint Reflections", Float) = 0
        [Group(lighting_reflspec)] [ShowIf(_ReflTintOn)] _ReflTint ("Reflection Tint", Color) = (1, 1, 1, 1)
        [Toggle] [Group(lighting_reflspec)] _SpecTintOn ("Tint Specular", Float) = 0
        [Group(lighting_reflspec)] [ShowIf(_SpecTintOn)] _SpecTint ("Specular Tint", Color) = (1, 1, 1, 1)
        [ZetMapPacker] [Group(lighting_reflspec)] _MapPackerUI ("Map Packer", Float) = 0
        [Toggle] [GroupToggle(lighting_reflspec_aniso)] _AnisoEnable ("Enable Anisotropic Highlights", Float) = 0
        [HDR] [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoColor ("Anisotropic Color", Color) = (1, 1, 1, 1)
        [Enum(Tangent, 0, Bitangent, 1)] [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoDir ("Highlight Direction", Float) = 0
        [Enum(Mesh Tangent, 0, Tangent Flow Map, 1, Object Space Map, 2)] [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoDirMode ("Direction Source", Float) = 0
        [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] [ShowIf(_AnisoDirMode)] _AnisoFlowMap ("Tangent Flow Map (RG)", 2D) = "bump" {}
        [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] [ShowIf(_AnisoDirMode)] _AnisoObjectMap ("Object Direction Map (RGB)", 2D) = "grey" {}
        [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoShift ("Highlight Offset", Range(-1, 1)) = 0
        [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoPower ("Highlight Sharpness", Range(0, 10)) = 5.0
        [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoStrength ("Highlight Strength", Range(0, 5)) = 1.0
        [Group(lighting_reflspec_aniso)] [ShowIf(_AnisoEnable)] _AnisoMask ("Anisotropic Mask (optional)", 2D) = "white" {}
        [Toggle] [GroupToggle(lighting_reflspec_stylespec)] _StyleSpecEnable ("Enable Stylized Specular", Float) = 0
        [HDR] [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _StyleSpecTint ("Highlight Tint", Color) = (1, 1, 1, 1)
        [Toggle] [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _StyleSpecUseLight ("Use Light Color", Float) = 1
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _StyleSpecMask ("Highlight Mask (optional)", 2D) = "white" {}
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS1Size ("Layer 1 Size", Range(0, 1)) = 0.3
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS1Feather ("Layer 1 Feather", Range(0, 1)) = 0.1
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS1Strength ("Layer 1 Strength", Range(0, 4)) = 1
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS2Size ("Layer 2 Size", Range(0, 1)) = 0.15
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS2Feather ("Layer 2 Feather", Range(0, 1)) = 0.05
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS2Strength ("Layer 2 Strength", Range(0, 4)) = 0
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS3Size ("Layer 3 Size", Range(0, 1)) = 0.07
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS3Feather ("Layer 3 Feather", Range(0, 1)) = 0.02
        [Group(lighting_reflspec_stylespec)] [ShowIf(_StyleSpecEnable)] _SS3Strength ("Layer 3 Strength", Range(0, 4)) = 0
        [Toggle] [GroupToggle(lighting_reflspec_spec2)] _Spec2Enable ("Enable 2nd Specular (Clear Coat)", Float) = 0
        [HDR] [Group(lighting_reflspec_spec2)] [ShowIf(_Spec2Enable)] _Spec2Color ("2nd Specular Tint", Color) = (1, 1, 1, 1)
        [Group(lighting_reflspec_spec2)] [ShowIf(_Spec2Enable)] _Spec2Smoothness ("2nd Smoothness", Range(0, 1)) = 0.8
        [Group(lighting_reflspec_spec2)] [ShowIf(_Spec2Enable)] _Spec2Mask ("2nd Specular Mask", 2D) = "white" {}
        [Toggle] [GroupToggle(lighting_matcaps_mc0)] _MatcapEnable ("Enable MatCap 0", Float) = 0
        [Group(lighting_matcaps_mc0)] [ShowIf(_MatcapEnable)] _MatcapTex ("MatCap 0 Texture", 2D) = "black" {}
        [Enum(Additive, 0, Multiply, 1, Screen, 2)] [Group(lighting_matcaps_mc0)] [ShowIf(_MatcapEnable)] _MatcapMode ("Blend Mode", Float) = 0
        [Group(lighting_matcaps_mc0)] [ShowIf(_MatcapEnable)] _MatcapStrength ("Strength (0-100)", Range(0, 100)) = 50
        [Group(lighting_matcaps_mc0)] [ShowIf(_MatcapEnable)] _MatcapMask ("MatCap 0 Mask", 2D) = "white" {}
        [Toggle(ZET_MC1)] [GroupToggle(lighting_matcaps_mc1)] _Matcap1Enable ("Enable MatCap 1", Float) = 0
        [Group(lighting_matcaps_mc1)] [ShowIf(_Matcap1Enable)] _Matcap1Tex ("MatCap 1 Texture", 2D) = "black" {}
        [Enum(Additive, 0, Multiply, 1, Screen, 2)] [Group(lighting_matcaps_mc1)] [ShowIf(_Matcap1Enable)] _Matcap1Mode ("Blend Mode", Float) = 0
        [Group(lighting_matcaps_mc1)] [ShowIf(_Matcap1Enable)] _Matcap1Strength ("Strength (0-100)", Range(0, 100)) = 50
        [Group(lighting_matcaps_mc1)] [ShowIf(_Matcap1Enable)] _Matcap1Mask ("MatCap 1 Mask", 2D) = "white" {}
        [Toggle(ZET_MC2)] [GroupToggle(lighting_matcaps_mc2)] _Matcap2Enable ("Enable MatCap 2", Float) = 0
        [Group(lighting_matcaps_mc2)] [ShowIf(_Matcap2Enable)] _Matcap2Tex ("MatCap 2 Texture", 2D) = "black" {}
        [Enum(Additive, 0, Multiply, 1, Screen, 2)] [Group(lighting_matcaps_mc2)] [ShowIf(_Matcap2Enable)] _Matcap2Mode ("Blend Mode", Float) = 0
        [Group(lighting_matcaps_mc2)] [ShowIf(_Matcap2Enable)] _Matcap2Strength ("Strength (0-100)", Range(0, 100)) = 50
        [Group(lighting_matcaps_mc2)] [ShowIf(_Matcap2Enable)] _Matcap2Mask ("MatCap 2 Mask", 2D) = "white" {}
        [Toggle(ZET_MC3)] [GroupToggle(lighting_matcaps_mc3)] _Matcap3Enable ("Enable MatCap 3", Float) = 0
        [Group(lighting_matcaps_mc3)] [ShowIf(_Matcap3Enable)] _Matcap3Tex ("MatCap 3 Texture", 2D) = "black" {}
        [Enum(Additive, 0, Multiply, 1, Screen, 2)] [Group(lighting_matcaps_mc3)] [ShowIf(_Matcap3Enable)] _Matcap3Mode ("Blend Mode", Float) = 0
        [Group(lighting_matcaps_mc3)] [ShowIf(_Matcap3Enable)] _Matcap3Strength ("Strength (0-100)", Range(0, 100)) = 50
        [Group(lighting_matcaps_mc3)] [ShowIf(_Matcap3Enable)] _Matcap3Mask ("MatCap 3 Mask", 2D) = "white" {}
        [Toggle(ZET_MC4)] [GroupToggle(lighting_matcaps_mc4)] _Matcap4Enable ("Enable MatCap 4", Float) = 0
        [Group(lighting_matcaps_mc4)] [ShowIf(_Matcap4Enable)] _Matcap4Tex ("MatCap 4 Texture", 2D) = "black" {}
        [Enum(Additive, 0, Multiply, 1, Screen, 2)] [Group(lighting_matcaps_mc4)] [ShowIf(_Matcap4Enable)] _Matcap4Mode ("Blend Mode", Float) = 0
        [Group(lighting_matcaps_mc4)] [ShowIf(_Matcap4Enable)] _Matcap4Strength ("Strength (0-100)", Range(0, 100)) = 50
        [Group(lighting_matcaps_mc4)] [ShowIf(_Matcap4Enable)] _Matcap4Mask ("MatCap 4 Mask", 2D) = "white" {}
        [NoScaleOffset] [Group(emission)] _Em0BgTex ("Infinity Mirror Pattern (shared)", 2D) = "white" {}
        [Toggle] [GroupToggle(emission_em0)] _Em0Enable ("Enable Emission 0", Float) = 0
        [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0Mask ("Emission 0 Mask", 2D) = "white" {}
        [HDR] [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0Color ("Emission 0 Color", Color) = (0, 1, 1, 1)
        [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0Intensity ("Emission Intensity", Range(0, 10)) = 1
        [Toggle] [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0Hue ("AL Hue Shift", Float) = 0
        [Enum(Pulse, 0, Sweep Up Body, 1, Center Out Pulse, 2, Gradient Path, 3)] [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0Mode ("Audio Mode", Float) = 0
        [NoScaleOffset] [Group(emission_em0)] [ShowIf(_Em0Enable)] [ShowIf(_Em0Mode, 3)] _Em0PathTex ("Path Gradient (black = start)", 2D) = "black" {}
        [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0Base ("Brightness Base", Range(0, 2)) = 0.15
        [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0EdgeGlow ("Edge Glow", Range(0, 4)) = 0
        [Group(emission_em0)] [ShowIf(_Em0Enable)] _Em0EdgePower ("Edge Sharpness", Range(0.5, 8)) = 3
        [Toggle] [GroupToggle(emission_em0_em0al)] _Em0ALEnable ("Enable AudioLink Reactivity", Float) = 1
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em0_em0al)] [ShowIf(_Em0ALEnable)] _Em0Band ("Primary AL Band", Float) = 0
        [Group(emission_em0_em0al)] [ShowIf(_Em0ALEnable)] _Em0AL ("AL Boost (reactive brightness)", Range(0, 4)) = 1.5
        [Group(emission_em0_em0al)] [ShowIf(_Em0ALEnable)] _Em0PulseScale ("Center-Out Ring Spacing", Range(0.1, 10)) = 2.0
        [Group(emission_em0_em0al)] [ShowIf(_Em0ALEnable)] _Em0Center ("Projection Center (UV)", Vector) = (0.5, 0.5, 0, 0)
        [Toggle] [Group(emission_em0_em0al)] [ShowIf(_Em0ALEnable)] _Em0VolBoost ("Boost by Overall Volume", Float) = 0
        [Group(emission_em0_em0al)] [ShowIf(_Em0VolBoost)] _Em0VolAmt ("Volume Boost Amount", Range(0, 4)) = 1.0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em0_em0al_em0aladj)] [ShowIf(_Em0ALEnable)] _Em0MultBand ("Multiplier Band", Float) = 0
        [Group(emission_em0_em0al_em0aladj)] [ShowIf(_Em0ALEnable)] _Em0MultAmt ("Multiplier Amount", Range(0, 4)) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em0_em0al_em0aladj)] [ShowIf(_Em0ALEnable)] _Em0AddBand ("Additive Band", Float) = 3
        [Group(emission_em0_em0al_em0aladj)] [ShowIf(_Em0ALEnable)] _Em0AddAmt ("Additive Amount", Range(0, 4)) = 0
        [Toggle] [GroupToggle(emission_em0_em0lb)] _Em0LightBased ("Enable Light-Based Emission", Float) = 0
        [Group(emission_em0_em0lb)] [ShowIf(_Em0LightBased)] _Em0MinEmiss ("Min Emission Multiplier (dark)", Range(0, 4)) = 1
        [Group(emission_em0_em0lb)] [ShowIf(_Em0LightBased)] _Em0MaxEmiss ("Max Emission Multiplier (lit)", Range(0, 4)) = 0
        [Group(emission_em0_em0lb)] [ShowIf(_Em0LightBased)] _Em0MinLight ("Min Lighting", Range(0, 1)) = 0
        [Group(emission_em0_em0lb)] [ShowIf(_Em0LightBased)] _Em0MaxLight ("Max Lighting", Range(0, 1)) = 1
        [Toggle] [GroupToggle(emission_em0_em0blink)] _Em0Blink ("Enable Blinking", Float) = 0
        [Group(emission_em0_em0blink)] [ShowIf(_Em0Blink)] _Em0BlinkSpeed ("Blink Speed", Range(0, 20)) = 3
        [Group(emission_em0_em0blink)] [ShowIf(_Em0Blink)] _Em0BlinkMin ("Blink Minimum", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em0_em0scan)] _Em0Scan ("Enable Scan / Sweep", Float) = 0
        [Enum(Vertical, 0, Horizontal, 1)] [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanDir ("Direction", Float) = 0
        [Enum(Loop, 0, Ping Pong, 1)] [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanMode ("Motion", Float) = 0
        [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanSpeed ("Speed", Range(0, 10)) = 1
        [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanWidth ("Band Width", Range(0.02, 1)) = 0.15
        [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanSoft ("Edge Softness", Range(0, 0.5)) = 0.05
        [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanFloor ("Outside-Band Glow", Range(0, 1)) = 0
        [IntRange] [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanPixels ("Pixelation", Range(0, 128)) = 0
        [Group(emission_em0_em0scan)] [ShowIf(_Em0Scan)] _Em0ScanGlitch ("Glitch Flicker", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em0_em0mir)] _Em0Mirror ("Enable Infinity Mirror", Float) = 0
        [Toggle] [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0Triplanar ("Use 3D Triplanar Mapping", Float) = 0
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0Rotation ("Pattern Rotation", Range(0, 360)) = 0
        [HDR] [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0BgColor ("Background Tint", Color) = (0.2, 0.2, 0.2, 1)
        [Toggle] [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0ScaleLock ("Uniform Scale (Use X)", Float) = 1
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0BgScale ("Background Scale (X,Y)", Vector) = (1.0, 1.0, 0, 0)
        [Toggle] [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0TileX ("Tile Horizontally (X)", Float) = 1
        [Toggle] [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0TileY ("Tile Vertically (Y)", Float) = 1
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0Pan ("Background Pan Speed (X,Y)", Vector) = (0, 0, 0, 0)
        [IntRange] [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0Layers ("Infinity Mirror Layers", Range(1, 10)) = 3
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0Parallax ("Initial Depth (0-100)", Range(0, 100)) = 25
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0LayerDist ("Distance Between Layers (0-100)", Range(0, 100)) = 25
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0NearBright ("Min-Depth Brightness", Range(0, 2)) = 1.0
        [Group(emission_em0_em0mir)] [ShowIf(_Em0Mirror)] _Em0FarBright ("Max-Depth Brightness", Range(0, 2)) = 0.3
        [Toggle(ZET_EM1)] [GroupToggle(emission_em1)] _Em1Enable ("Enable Emission 1", Float) = 0
        [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1Mask ("Emission 1 Mask", 2D) = "white" {}
        [HDR] [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1Color ("Emission 1 Color", Color) = (0, 1, 1, 1)
        [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1Intensity ("Emission Intensity", Range(0, 10)) = 1
        [Toggle] [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1Hue ("AL Hue Shift", Float) = 0
        [Enum(Pulse, 0, Sweep Up Body, 1, Center Out Pulse, 2, Gradient Path, 3)] [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1Mode ("Audio Mode", Float) = 0
        [NoScaleOffset] [Group(emission_em1)] [ShowIf(_Em1Enable)] [ShowIf(_Em1Mode, 3)] _Em1PathTex ("Path Gradient (black = start)", 2D) = "black" {}
        [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1Base ("Brightness Base", Range(0, 2)) = 0.1
        [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1EdgeGlow ("Edge Glow", Range(0, 4)) = 0
        [Group(emission_em1)] [ShowIf(_Em1Enable)] _Em1EdgePower ("Edge Sharpness", Range(0.5, 8)) = 3
        [Toggle] [GroupToggle(emission_em1_em1al)] _Em1ALEnable ("Enable AudioLink Reactivity", Float) = 1
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em1_em1al)] [ShowIf(_Em1ALEnable)] _Em1Band ("Primary AL Band", Float) = 0
        [Group(emission_em1_em1al)] [ShowIf(_Em1ALEnable)] _Em1AL ("AL Boost (reactive brightness)", Range(0, 4)) = 1.5
        [Group(emission_em1_em1al)] [ShowIf(_Em1ALEnable)] _Em1PulseScale ("Center-Out Ring Spacing", Range(0.1, 10)) = 2.0
        [Group(emission_em1_em1al)] [ShowIf(_Em1ALEnable)] _Em1Center ("Projection Center (UV)", Vector) = (0.5, 0.5, 0, 0)
        [Toggle] [Group(emission_em1_em1al)] [ShowIf(_Em1ALEnable)] _Em1VolBoost ("Boost by Overall Volume", Float) = 0
        [Group(emission_em1_em1al)] [ShowIf(_Em1VolBoost)] _Em1VolAmt ("Volume Boost Amount", Range(0, 4)) = 1.0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em1_em1al_em1aladj)] [ShowIf(_Em1ALEnable)] _Em1MultBand ("Multiplier Band", Float) = 0
        [Group(emission_em1_em1al_em1aladj)] [ShowIf(_Em1ALEnable)] _Em1MultAmt ("Multiplier Amount", Range(0, 4)) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em1_em1al_em1aladj)] [ShowIf(_Em1ALEnable)] _Em1AddBand ("Additive Band", Float) = 3
        [Group(emission_em1_em1al_em1aladj)] [ShowIf(_Em1ALEnable)] _Em1AddAmt ("Additive Amount", Range(0, 4)) = 0
        [Toggle] [GroupToggle(emission_em1_em1lb)] _Em1LightBased ("Enable Light-Based Emission", Float) = 0
        [Group(emission_em1_em1lb)] [ShowIf(_Em1LightBased)] _Em1MinEmiss ("Min Emission Multiplier (dark)", Range(0, 4)) = 1
        [Group(emission_em1_em1lb)] [ShowIf(_Em1LightBased)] _Em1MaxEmiss ("Max Emission Multiplier (lit)", Range(0, 4)) = 0
        [Group(emission_em1_em1lb)] [ShowIf(_Em1LightBased)] _Em1MinLight ("Min Lighting", Range(0, 1)) = 0
        [Group(emission_em1_em1lb)] [ShowIf(_Em1LightBased)] _Em1MaxLight ("Max Lighting", Range(0, 1)) = 1
        [Toggle] [GroupToggle(emission_em1_em1blink)] _Em1Blink ("Enable Blinking", Float) = 0
        [Group(emission_em1_em1blink)] [ShowIf(_Em1Blink)] _Em1BlinkSpeed ("Blink Speed", Range(0, 20)) = 3
        [Group(emission_em1_em1blink)] [ShowIf(_Em1Blink)] _Em1BlinkMin ("Blink Minimum", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em1_em1scan)] _Em1Scan ("Enable Scan / Sweep", Float) = 0
        [Enum(Vertical, 0, Horizontal, 1)] [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanDir ("Direction", Float) = 0
        [Enum(Loop, 0, Ping Pong, 1)] [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanMode ("Motion", Float) = 0
        [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanSpeed ("Speed", Range(0, 10)) = 1
        [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanWidth ("Band Width", Range(0.02, 1)) = 0.15
        [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanSoft ("Edge Softness", Range(0, 0.5)) = 0.05
        [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanFloor ("Outside-Band Glow", Range(0, 1)) = 0
        [IntRange] [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanPixels ("Pixelation", Range(0, 128)) = 0
        [Group(emission_em1_em1scan)] [ShowIf(_Em1Scan)] _Em1ScanGlitch ("Glitch Flicker", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em1_em1mir)] _Em1Mirror ("Enable Infinity Mirror", Float) = 0
        [Toggle] [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1Triplanar ("Use 3D Triplanar Mapping", Float) = 0
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1Rotation ("Pattern Rotation", Range(0, 360)) = 0
        [HDR] [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1BgColor ("Background Tint", Color) = (0.2, 0.2, 0.2, 1)
        [Toggle] [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1ScaleLock ("Uniform Scale (Use X)", Float) = 1
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1BgScale ("Background Scale (X,Y)", Vector) = (1.0, 1.0, 0, 0)
        [Toggle] [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1TileX ("Tile Horizontally (X)", Float) = 1
        [Toggle] [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1TileY ("Tile Vertically (Y)", Float) = 1
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1Pan ("Background Pan Speed (X,Y)", Vector) = (0, 0, 0, 0)
        [IntRange] [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1Layers ("Infinity Mirror Layers", Range(1, 10)) = 3
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1Parallax ("Initial Depth (0-100)", Range(0, 100)) = 25
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1LayerDist ("Distance Between Layers (0-100)", Range(0, 100)) = 25
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1NearBright ("Min-Depth Brightness", Range(0, 2)) = 1.0
        [Group(emission_em1_em1mir)] [ShowIf(_Em1Mirror)] _Em1FarBright ("Max-Depth Brightness", Range(0, 2)) = 0.3
        [Toggle(ZET_EM2)] [GroupToggle(emission_em2)] _Em2Enable ("Enable Emission 2", Float) = 0
        [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2Mask ("Emission 2 Mask", 2D) = "white" {}
        [HDR] [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2Color ("Emission 2 Color", Color) = (1, 0, 1, 1)
        [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2Intensity ("Emission Intensity", Range(0, 10)) = 1
        [Toggle] [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2Hue ("AL Hue Shift", Float) = 0
        [Enum(Pulse, 0, Sweep Up Body, 1, Center Out Pulse, 2, Gradient Path, 3)] [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2Mode ("Audio Mode", Float) = 0
        [NoScaleOffset] [Group(emission_em2)] [ShowIf(_Em2Enable)] [ShowIf(_Em2Mode, 3)] _Em2PathTex ("Path Gradient (black = start)", 2D) = "black" {}
        [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2Base ("Brightness Base", Range(0, 2)) = 0.15
        [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2EdgeGlow ("Edge Glow", Range(0, 4)) = 0
        [Group(emission_em2)] [ShowIf(_Em2Enable)] _Em2EdgePower ("Edge Sharpness", Range(0.5, 8)) = 3
        [Toggle] [GroupToggle(emission_em2_em2al)] _Em2ALEnable ("Enable AudioLink Reactivity", Float) = 1
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em2_em2al)] [ShowIf(_Em2ALEnable)] _Em2Band ("Primary AL Band", Float) = 0
        [Group(emission_em2_em2al)] [ShowIf(_Em2ALEnable)] _Em2AL ("AL Boost (reactive brightness)", Range(0, 4)) = 1.5
        [Group(emission_em2_em2al)] [ShowIf(_Em2ALEnable)] _Em2PulseScale ("Center-Out Ring Spacing", Range(0.1, 10)) = 2.0
        [Group(emission_em2_em2al)] [ShowIf(_Em2ALEnable)] _Em2Center ("Projection Center (UV)", Vector) = (0.5, 0.5, 0, 0)
        [Toggle] [Group(emission_em2_em2al)] [ShowIf(_Em2ALEnable)] _Em2VolBoost ("Boost by Overall Volume", Float) = 0
        [Group(emission_em2_em2al)] [ShowIf(_Em2VolBoost)] _Em2VolAmt ("Volume Boost Amount", Range(0, 4)) = 1.0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em2_em2al_em2aladj)] [ShowIf(_Em2ALEnable)] _Em2MultBand ("Multiplier Band", Float) = 0
        [Group(emission_em2_em2al_em2aladj)] [ShowIf(_Em2ALEnable)] _Em2MultAmt ("Multiplier Amount", Range(0, 4)) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em2_em2al_em2aladj)] [ShowIf(_Em2ALEnable)] _Em2AddBand ("Additive Band", Float) = 3
        [Group(emission_em2_em2al_em2aladj)] [ShowIf(_Em2ALEnable)] _Em2AddAmt ("Additive Amount", Range(0, 4)) = 0
        [Toggle] [GroupToggle(emission_em2_em2lb)] _Em2LightBased ("Enable Light-Based Emission", Float) = 0
        [Group(emission_em2_em2lb)] [ShowIf(_Em2LightBased)] _Em2MinEmiss ("Min Emission Multiplier (dark)", Range(0, 4)) = 1
        [Group(emission_em2_em2lb)] [ShowIf(_Em2LightBased)] _Em2MaxEmiss ("Max Emission Multiplier (lit)", Range(0, 4)) = 0
        [Group(emission_em2_em2lb)] [ShowIf(_Em2LightBased)] _Em2MinLight ("Min Lighting", Range(0, 1)) = 0
        [Group(emission_em2_em2lb)] [ShowIf(_Em2LightBased)] _Em2MaxLight ("Max Lighting", Range(0, 1)) = 1
        [Toggle] [GroupToggle(emission_em2_em2blink)] _Em2Blink ("Enable Blinking", Float) = 0
        [Group(emission_em2_em2blink)] [ShowIf(_Em2Blink)] _Em2BlinkSpeed ("Blink Speed", Range(0, 20)) = 3
        [Group(emission_em2_em2blink)] [ShowIf(_Em2Blink)] _Em2BlinkMin ("Blink Minimum", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em2_em2scan)] _Em2Scan ("Enable Scan / Sweep", Float) = 0
        [Enum(Vertical, 0, Horizontal, 1)] [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanDir ("Direction", Float) = 0
        [Enum(Loop, 0, Ping Pong, 1)] [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanMode ("Motion", Float) = 0
        [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanSpeed ("Speed", Range(0, 10)) = 1
        [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanWidth ("Band Width", Range(0.02, 1)) = 0.15
        [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanSoft ("Edge Softness", Range(0, 0.5)) = 0.05
        [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanFloor ("Outside-Band Glow", Range(0, 1)) = 0
        [IntRange] [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanPixels ("Pixelation", Range(0, 128)) = 0
        [Group(emission_em2_em2scan)] [ShowIf(_Em2Scan)] _Em2ScanGlitch ("Glitch Flicker", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em2_em2mir)] _Em2Mirror ("Enable Infinity Mirror", Float) = 0
        [Toggle] [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2Triplanar ("Use 3D Triplanar Mapping", Float) = 0
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2Rotation ("Pattern Rotation", Range(0, 360)) = 0
        [HDR] [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2BgColor ("Background Tint", Color) = (0.2, 0.2, 0.2, 1)
        [Toggle] [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2ScaleLock ("Uniform Scale (Use X)", Float) = 1
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2BgScale ("Background Scale (X,Y)", Vector) = (1.0, 1.0, 0, 0)
        [Toggle] [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2TileX ("Tile Horizontally (X)", Float) = 1
        [Toggle] [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2TileY ("Tile Vertically (Y)", Float) = 1
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2Pan ("Background Pan Speed (X,Y)", Vector) = (0, 0, 0, 0)
        [IntRange] [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2Layers ("Infinity Mirror Layers", Range(1, 10)) = 3
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2Parallax ("Initial Depth (0-100)", Range(0, 100)) = 25
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2LayerDist ("Distance Between Layers (0-100)", Range(0, 100)) = 25
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2NearBright ("Min-Depth Brightness", Range(0, 2)) = 1.0
        [Group(emission_em2_em2mir)] [ShowIf(_Em2Mirror)] _Em2FarBright ("Max-Depth Brightness", Range(0, 2)) = 0.3
        [Toggle(ZET_EM3)] [GroupToggle(emission_em3)] _Em3Enable ("Enable Emission 3", Float) = 0
        [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3Mask ("Emission 3 Mask", 2D) = "white" {}
        [HDR] [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3Color ("Emission 3 Color", Color) = (1, 1, 0, 1)
        [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3Intensity ("Emission Intensity", Range(0, 10)) = 1
        [Toggle] [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3Hue ("AL Hue Shift", Float) = 0
        [Enum(Pulse, 0, Sweep Up Body, 1, Center Out Pulse, 2, Gradient Path, 3)] [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3Mode ("Audio Mode", Float) = 0
        [NoScaleOffset] [Group(emission_em3)] [ShowIf(_Em3Enable)] [ShowIf(_Em3Mode, 3)] _Em3PathTex ("Path Gradient (black = start)", 2D) = "black" {}
        [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3Base ("Brightness Base", Range(0, 2)) = 0.15
        [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3EdgeGlow ("Edge Glow", Range(0, 4)) = 0
        [Group(emission_em3)] [ShowIf(_Em3Enable)] _Em3EdgePower ("Edge Sharpness", Range(0.5, 8)) = 3
        [Toggle] [GroupToggle(emission_em3_em3al)] _Em3ALEnable ("Enable AudioLink Reactivity", Float) = 1
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em3_em3al)] [ShowIf(_Em3ALEnable)] _Em3Band ("Primary AL Band", Float) = 0
        [Group(emission_em3_em3al)] [ShowIf(_Em3ALEnable)] _Em3AL ("AL Boost (reactive brightness)", Range(0, 4)) = 1.5
        [Group(emission_em3_em3al)] [ShowIf(_Em3ALEnable)] _Em3PulseScale ("Center-Out Ring Spacing", Range(0.1, 10)) = 2.0
        [Group(emission_em3_em3al)] [ShowIf(_Em3ALEnable)] _Em3Center ("Projection Center (UV)", Vector) = (0.5, 0.5, 0, 0)
        [Toggle] [Group(emission_em3_em3al)] [ShowIf(_Em3ALEnable)] _Em3VolBoost ("Boost by Overall Volume", Float) = 0
        [Group(emission_em3_em3al)] [ShowIf(_Em3VolBoost)] _Em3VolAmt ("Volume Boost Amount", Range(0, 4)) = 1.0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em3_em3al_em3aladj)] [ShowIf(_Em3ALEnable)] _Em3MultBand ("Multiplier Band", Float) = 0
        [Group(emission_em3_em3al_em3aladj)] [ShowIf(_Em3ALEnable)] _Em3MultAmt ("Multiplier Amount", Range(0, 4)) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(emission_em3_em3al_em3aladj)] [ShowIf(_Em3ALEnable)] _Em3AddBand ("Additive Band", Float) = 3
        [Group(emission_em3_em3al_em3aladj)] [ShowIf(_Em3ALEnable)] _Em3AddAmt ("Additive Amount", Range(0, 4)) = 0
        [Toggle] [GroupToggle(emission_em3_em3lb)] _Em3LightBased ("Enable Light-Based Emission", Float) = 0
        [Group(emission_em3_em3lb)] [ShowIf(_Em3LightBased)] _Em3MinEmiss ("Min Emission Multiplier (dark)", Range(0, 4)) = 1
        [Group(emission_em3_em3lb)] [ShowIf(_Em3LightBased)] _Em3MaxEmiss ("Max Emission Multiplier (lit)", Range(0, 4)) = 0
        [Group(emission_em3_em3lb)] [ShowIf(_Em3LightBased)] _Em3MinLight ("Min Lighting", Range(0, 1)) = 0
        [Group(emission_em3_em3lb)] [ShowIf(_Em3LightBased)] _Em3MaxLight ("Max Lighting", Range(0, 1)) = 1
        [Toggle] [GroupToggle(emission_em3_em3blink)] _Em3Blink ("Enable Blinking", Float) = 0
        [Group(emission_em3_em3blink)] [ShowIf(_Em3Blink)] _Em3BlinkSpeed ("Blink Speed", Range(0, 20)) = 3
        [Group(emission_em3_em3blink)] [ShowIf(_Em3Blink)] _Em3BlinkMin ("Blink Minimum", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em3_em3scan)] _Em3Scan ("Enable Scan / Sweep", Float) = 0
        [Enum(Vertical, 0, Horizontal, 1)] [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanDir ("Direction", Float) = 0
        [Enum(Loop, 0, Ping Pong, 1)] [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanMode ("Motion", Float) = 0
        [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanSpeed ("Speed", Range(0, 10)) = 1
        [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanWidth ("Band Width", Range(0.02, 1)) = 0.15
        [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanSoft ("Edge Softness", Range(0, 0.5)) = 0.05
        [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanFloor ("Outside-Band Glow", Range(0, 1)) = 0
        [IntRange] [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanPixels ("Pixelation", Range(0, 128)) = 0
        [Group(emission_em3_em3scan)] [ShowIf(_Em3Scan)] _Em3ScanGlitch ("Glitch Flicker", Range(0, 1)) = 0
        [Toggle] [GroupToggle(emission_em3_em3mir)] _Em3Mirror ("Enable Infinity Mirror", Float) = 0
        [Toggle] [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3Triplanar ("Use 3D Triplanar Mapping", Float) = 0
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3Rotation ("Pattern Rotation", Range(0, 360)) = 0
        [HDR] [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3BgColor ("Background Tint", Color) = (0.2, 0.2, 0.2, 1)
        [Toggle] [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3ScaleLock ("Uniform Scale (Use X)", Float) = 1
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3BgScale ("Background Scale (X,Y)", Vector) = (1.0, 1.0, 0, 0)
        [Toggle] [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3TileX ("Tile Horizontally (X)", Float) = 1
        [Toggle] [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3TileY ("Tile Vertically (Y)", Float) = 1
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3Pan ("Background Pan Speed (X,Y)", Vector) = (0, 0, 0, 0)
        [IntRange] [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3Layers ("Infinity Mirror Layers", Range(1, 10)) = 3
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3Parallax ("Initial Depth (0-100)", Range(0, 100)) = 25
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3LayerDist ("Distance Between Layers (0-100)", Range(0, 100)) = 25
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3NearBright ("Min-Depth Brightness", Range(0, 2)) = 1.0
        [Group(emission_em3_em3mir)] [ShowIf(_Em3Mirror)] _Em3FarBright ("Max-Depth Brightness", Range(0, 2)) = 0.3
        [Toggle] [GroupToggle(specialfx_room)] _RoomEnable ("Enable Interior Mapping", Float) = 0
        [NoScaleOffset] [Group(specialfx_room)] [ShowIf(_RoomEnable)] _RoomCube ("Room Cubemap", Cube) = "black" {}
        [NoScaleOffset] [Group(specialfx_room)] [ShowIf(_RoomEnable)] _RoomMask ("Window Mask", 2D) = "white" {}
        [HDR] [Group(specialfx_room)] [ShowIf(_RoomEnable)] _RoomColor ("Room Tint", Color) = (1, 1, 1, 1)
        [Group(specialfx_room)] [ShowIf(_RoomEnable)] _RoomDepth ("Room Depth", Range(0.1, 4)) = 1
        [Group(specialfx_room)] [ShowIf(_RoomEnable)] _RoomTile ("Room Tiling", Range(1, 8)) = 1
        [Group(specialfx_room_roommotion)] [ShowIf(_RoomEnable)] _RoomScrollX ("Spin Horizontal", Range(-2, 2)) = 0
        [Group(specialfx_room_roommotion)] [ShowIf(_RoomEnable)] _RoomScrollY ("Spin Vertical", Range(-2, 2)) = 0
        [Group(specialfx_room_roommotion)] [ShowIf(_RoomEnable)] _RoomSlideX ("Slide Horizontal", Range(-2, 2)) = 0
        [Group(specialfx_room_roommotion)] [ShowIf(_RoomEnable)] _RoomSlideY ("Slide Vertical", Range(-2, 2)) = 0
        [Group(specialfx_room_roomglass)] [ShowIf(_RoomEnable)] _RoomEdge ("Window Edge", Range(0.002, 0.5)) = 0.05
        [Group(specialfx_room_roomglass)] [ShowIf(_RoomEnable)] _RoomGlassWarp ("Glass Ripple", Range(0, 1)) = 0
        [Group(specialfx_room_roomglass)] [ShowIf(_RoomEnable)] _RoomGlassChroma ("Glass Chromatic", Range(0, 1)) = 0
        [Enum(None, 0, Fog, 1, Dream Haze, 2)] [Group(specialfx_room_roomatmo)] [ShowIf(_RoomEnable)] _RoomDepthMode ("Depth Atmosphere", Float) = 1
        [Group(specialfx_room_roomatmo)] [ShowIf(_RoomEnable)] _RoomFade ("Atmosphere Amount", Range(0, 1)) = 0.3
        [HDR] [Group(specialfx_room_roomatmo)] [ShowIf(_RoomEnable)] _RoomHazeColor ("Haze Color", Color) = (0.5, 0.7, 1.0, 1)
        [Group(specialfx_room_roomatmo)] [ShowIf(_RoomEnable)] _RoomSoften ("Softness", Range(0, 1)) = 0
        [Toggle] [Group(specialfx_room_roomal)] [ShowIf(_RoomEnable)] _RoomALEnable ("AudioLink Reactive", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_room_roomal)] [ShowIf(_RoomEnable)] [ShowIf(_RoomALEnable)] _RoomBand ("AL Band", Float) = 3
        [Group(specialfx_room_roomal)] [ShowIf(_RoomEnable)] [ShowIf(_RoomALEnable)] _RoomAL ("AL Boost", Range(0, 8)) = 2
        [Toggle] [GroupToggle(specialfx_refract)] _RefractEnable ("Enable Refraction", Float) = 0
        [NoScaleOffset] [Group(specialfx_refract)] [ShowIf(_RefractEnable)] _RefractMask ("Refraction Mask", 2D) = "white" {}
        [Group(specialfx_refract)] [ShowIf(_RefractEnable)] _RefractStrength ("Distortion Strength", Range(0, 1)) = 0.15
        [Group(specialfx_refract)] [ShowIf(_RefractEnable)] _RefractCA ("Chromatic Aberration", Range(0, 1)) = 0.2
        [HDR] [Group(specialfx_refract)] [ShowIf(_RefractEnable)] _RefractTint ("Glass Tint", Color) = (1, 1, 1, 1)
        [Group(specialfx_refract)] [ShowIf(_RefractEnable)] _RefractBlend ("Refraction Amount", Range(0, 1)) = 1
        [NoScaleOffset] [Group(specialfx_refract_refractshimmer)] [ShowIf(_RefractEnable)] _RefractMap ("Shimmer Map (optional)", 2D) = "bump" {}
        [Group(specialfx_refract_refractshimmer)] [ShowIf(_RefractEnable)] _RefractTile ("Shimmer Tiling", Range(1, 16)) = 4
        [Group(specialfx_refract_refractshimmer)] [ShowIf(_RefractEnable)] _RefractScroll ("Shimmer Speed", Range(0, 2)) = 0.3
        [Toggle] [Group(specialfx_refract_refractal)] [ShowIf(_RefractEnable)] _RefractALEnable ("AudioLink Reactive", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_refract_refractal)] [ShowIf(_RefractEnable)] [ShowIf(_RefractALEnable)] _RefractBand ("AL Band", Float) = 0
        [Group(specialfx_refract_refractal)] [ShowIf(_RefractEnable)] [ShowIf(_RefractALEnable)] _RefractAL ("AL Boost", Range(0, 8)) = 3
        [Toggle] [GroupToggle(specialfx_screen)] _ScreenEnable ("Enable Screen Display", Float) = 0
        [NoScaleOffset] [Group(specialfx_screen)] [ShowIf(_ScreenEnable)] _ScreenMask ("Screen Mask", 2D) = "white" {}
        [Enum(Oscilloscope, 0, EQ Bars, 1)] [Group(specialfx_screen)] [ShowIf(_ScreenEnable)] _ScreenMode ("Screen Mode", Float) = 0
        [HDR] [Group(specialfx_screen)] [ShowIf(_ScreenEnable)] _ScreenLineColor ("Wave Color", Color) = (0, 1, 1, 1)
        [Group(specialfx_screen)] [ShowIf(_ScreenEnable)] _ScreenWaveAmp ("Wave Amplitude", Range(0, 0.5)) = 0.22
        [Group(specialfx_screen)] [ShowIf(_ScreenEnable)] _ScreenWaveSamples ("Waveform Samples", Float) = 512
        [Group(specialfx_screen)] [ShowIf(_ScreenEnable)] _ScreenLineWidth ("Line Width", Range(0.001, 0.1)) = 0.02
        [Group(specialfx_screen_scrbackdrop)] [ShowIf(_ScreenEnable)] _ScreenArt ("Screen Art", 2D) = "black" {}
        [Group(specialfx_screen_scrbackdrop)] [ShowIf(_ScreenEnable)] _ScreenArtStrength ("Screen Art Strength", Range(0, 2)) = 0.4
        [Group(specialfx_screen_scrbackdrop)] [ShowIf(_ScreenEnable)] _ScreenBackdrop ("Backdrop", 2D) = "white" {}
        [HDR] [Group(specialfx_screen_scrbackdrop)] [ShowIf(_ScreenEnable)] _ScreenBGColor ("Background Tint", Color) = (0.02, 0.06, 0.08, 1)
        [Toggle] [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridProc ("Procedural Grid", Float) = 1
        [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridCells ("Grid Cells Across", Float) = 12
        [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridLineW ("Grid Line Width", Range(0.005, 0.2)) = 0.04
        [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridMinor ("Grid Minor Lines", Range(0, 1)) = 0.35
        [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridTex ("Grid Texture", 2D) = "black" {}
        [HDR] [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridColor ("Grid Color", Color) = (0.2, 0.5, 0.5, 1)
        [Group(specialfx_screen_scrgrid)] [ShowIf(_ScreenEnable)] _ScreenGridStrength ("Grid Strength", Range(0, 1)) = 0.5
        [Group(specialfx_screen_scrlcd)] [ShowIf(_ScreenEnable)] _ScreenLCDTex ("LCD Subpixel Tile", 2D) = "white" {}
        [Group(specialfx_screen_scrlcd)] [ShowIf(_ScreenEnable)] _ScreenLCDStrength ("LCD Strength", Range(0, 1)) = 0
        [Group(specialfx_screen_scrlcd)] [ShowIf(_ScreenEnable)] _ScreenScanline ("Scanline Strength", Range(0, 1)) = 0.25
        [Group(specialfx_screen_scrlcd)] [ShowIf(_ScreenEnable)] _ScreenScanCount ("Scanline Count", Float) = 64
        [Toggle] [Group(specialfx_screen_scrbsod)] [ShowIf(_ScreenEnable)] _ScreenBSOD ("BSOD Mode", Float) = 0
        [Toggle] [Group(specialfx_screen_scrbsod)] [ShowIf(_ScreenEnable)] _ScreenBSODNoAL ("Crash When No AudioLink", Float) = 0
        [Group(specialfx_screen_scrbsod)] [ShowIf(_ScreenEnable)] _ScreenBSODTex ("Crash Image", 2D) = "black" {}
        [Toggle] [GroupToggle(specialfx_rim)] _RimEnable ("Enable Fresnel Rim", Float) = 0
        [Enum(Off, 0, Always On, 1, Audio Reactive, 2)] [Group(specialfx_rim)] [ShowIf(_RimEnable)] _RimState ("Rim Mode", Float) = 1
        [HDR] [Group(specialfx_rim)] [ShowIf(_RimEnable)] _RimColor ("Rim Color", Color) = (0, 1, 1, 1)
        [Toggle] [Group(specialfx_rim)] [ShowIf(_RimEnable)] _RimHueShift ("AL Hue Shift", Float) = 0
        [Group(specialfx_rim_rimadv)] [ShowIf(_RimEnable)] _RimWidth ("Rim Width", Range(0, 1)) = 0.35
        [Group(specialfx_rim_rimadv)] [ShowIf(_RimEnable)] _RimSoft ("Rim Softness", Range(0.001, 0.5)) = 0.06
        [Group(specialfx_rim_rimadv)] [ShowIf(_RimEnable)] _RimBase ("Rim Intensity (always on)", Range(0, 2)) = 0.15
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_rim_rimadv)] [ShowIf(_RimEnable)] _RimBand ("Rim AL Band", Float) = 0
        [Group(specialfx_rim_rimadv)] [ShowIf(_RimEnable)] _RimAL ("Rim AL Boost", Range(0, 4)) = 1.5
        [Toggle] [GroupToggle(specialfx_speaker)] _SpeakerEnable ("Enable Speaker Ripple", Float) = 0
        [Group(specialfx_speaker)] [ShowIf(_SpeakerEnable)] _SpeakerMask ("Speaker Gradient Mask", 2D) = "black" {}
        [Group(specialfx_speaker)] [ShowIf(_SpeakerEnable)] _SpeakerMaskBlur ("Mask Smoothing", Range(0, 1)) = 0.3
        [HDR] [Group(specialfx_speaker)] [ShowIf(_SpeakerEnable)] _SpeakerColor ("Speaker Wave Color", Color) = (0, 1, 1, 1)
        [Enum(Off, 0, Always On, 1, Audio Reactive, 2)] [Group(specialfx_speaker)] [ShowIf(_SpeakerEnable)] _SpeakerState ("Ripple Mode", Float) = 1
        [Toggle] [Group(specialfx_speaker)] [ShowIf(_SpeakerEnable)] _SpeakerHueShift ("AL Hue Shift", Float) = 0
        [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerIntensity ("Forward Projection (m)", Range(0, 1)) = 0.15
        [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerExpansion ("Dome Lift", Range(0, 1)) = 0.1
        [IntRange] [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerRings ("Number of Rings (Max 6)", Range(1, 6)) = 4
        [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerSpeed ("Ripple Speed", Range(0, 5)) = 2.0
        [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerRingThickness ("Ring Thickness", Range(0.002, 0.06)) = 0.02
        [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerRingSoftness ("Ring Softness", Range(0.0005, 0.025)) = 0.01
        [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerThreshold ("Beat Threshold", Range(0, 1)) = 0.3
        [Enum(Outward, 0, Inward, 1)] [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerDirection ("Ripple Direction", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_speaker_spkadv)] [ShowIf(_SpeakerEnable)] _SpeakerBand ("Speaker AL Band", Float) = 0
        [Toggle] [GroupToggle(specialfx_eq)] _EQEnable ("Enable Live EQ Visualizer", Float) = 0
        [Group(specialfx_eq)] [ShowIf(_EQEnable)] _EQMask ("EQ Screen Mask", 2D) = "black" {}
        [HDR] [Group(specialfx_eq)] [ShowIf(_EQEnable)] _EQColor ("EQ Bar Color", Color) = (0, 1, 1, 1)
        [IntRange] [Group(specialfx_eq)] [ShowIf(_EQEnable)] _EQColumns ("Number of EQ Bars", Range(2, 32)) = 8
        [Group(specialfx_eq)] [ShowIf(_EQEnable)] _EQGain ("Bar Gain", Range(0.5, 16)) = 4
        [Group(specialfx_eq)] [ShowIf(_EQEnable)] _EQCurve ("Bar Curve", Range(0.25, 2)) = 0.7
        [Toggle] [GroupToggle(specialfx_irid)] _IridEnable ("Enable Iridescence", Float) = 0
        [Group(specialfx_irid)] [ShowIf(_IridEnable)] _IridMask ("Iridescence Mask", 2D) = "white" {}
        [HDR] [Group(specialfx_irid)] [ShowIf(_IridEnable)] _IridColor1 ("Iridescence Phase 1", Color) = (1, 0, 0, 1)
        [HDR] [Group(specialfx_irid)] [ShowIf(_IridEnable)] _IridColor2 ("Iridescence Phase 2", Color) = (0, 1, 0, 1)
        [HDR] [Group(specialfx_irid)] [ShowIf(_IridEnable)] _IridColor3 ("Iridescence Phase 3", Color) = (0, 0, 1, 1)
        [Group(specialfx_irid_iridadv)] [ShowIf(_IridEnable)] _IridThickness ("Film Thickness (0-100)", Range(0, 100)) = 50
        [Group(specialfx_irid_iridadv)] [ShowIf(_IridEnable)] _IridSpeed ("Passive Shift Speed (-50 to 50)", Range(-50, 50)) = 10
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_irid_iridadv)] [ShowIf(_IridEnable)] _IridBand ("Iridescence AL Band", Float) = 1
        [Group(specialfx_irid_iridadv)] [ShowIf(_IridEnable)] _IridAL ("AL Phase Reactivity (0-100)", Range(0, 100)) = 20
        [Toggle] [GroupToggle(specialfx_dissolve)] _DissolveEnable ("Enable Data-Burn Dissolve", Float) = 0
        [HDR] [Group(specialfx_dissolve)] [ShowIf(_DissolveEnable)] _DissolveColor ("Burn Edge Color", Color) = (1, 0.2, 0, 1)
        [Toggle] [Group(specialfx_dissolve)] [ShowIf(_DissolveEnable)] _DissolveHueShift ("AL Hue Shift", Float) = 0
        [Group(specialfx_dissolve)] [ShowIf(_DissolveEnable)] _DissolveTex ("Dissolve Noise Pattern", 2D) = "white" {}
        [Group(specialfx_dissolve_dissadv)] [ShowIf(_DissolveEnable)] _DissolveAmount ("Base Dissolve Amount (0-100)", Range(0, 100)) = 0
        [Group(specialfx_dissolve_dissadv)] [ShowIf(_DissolveEnable)] _DissolveAL ("Audio Reactivity (0-100)", Range(0, 100)) = 30
        [Group(specialfx_dissolve_dissadv)] [ShowIf(_DissolveEnable)] _DissolveWidth ("Edge Glow Width (0-100)", Range(0, 100)) = 15
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_dissolve_dissadv)] [ShowIf(_DissolveEnable)] _DissolveBand ("Burn AL Band", Float) = 0
        [Toggle] [GroupToggle(specialfx_outline)] _OutlineEnable ("Enable Glitch Outline", Float) = 0
        [Group(specialfx_outline)] [ShowIf(_OutlineEnable)] _OutlineMask ("Outline Target Mask", 2D) = "black" {}
        [Enum(Off, 0, Always On, 1, Audio Reactive, 2)] [Group(specialfx_outline)] [ShowIf(_OutlineEnable)] _OutlineState ("Outline Mode", Float) = 1
        [HDR] [Group(specialfx_outline)] [ShowIf(_OutlineEnable)] _OutlineColor ("Outline Effect Color", Color) = (0, 1, 1, 1)
        [Toggle] [Group(specialfx_outline)] [ShowIf(_OutlineEnable)] _OutlineHueShift ("AL Hue Shift", Float) = 0
        [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineFloat ("Hologram Hover Height (0-100)", Range(0, 100)) = 20
        [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineRGBSplit ("RGB Split Amount (0-100)", Range(0, 100)) = 30
        [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineSpread ("Outline Spread Width (0-100)", Range(0, 100)) = 25
        [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineSlices ("Outline Block Density", Float) = 50.0
        [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineSpeed ("Outline Jitter Speed", Range(0, 50)) = 15.0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineBand ("Outline AL Band", Float) = 2
        [Group(specialfx_outline_outadv)] [ShowIf(_OutlineEnable)] _OutlineAL ("Outline AL Boost", Range(0, 4)) = 1.5
        [Toggle] [GroupToggle(specialfx_outlinestd)] _OutlineStdEnable ("Enable Standard Outline", Float) = 0
        [HDR] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdColor ("Outline Color", Color) = (0, 0, 0, 1)
        [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdWidth ("Outline Width", Range(0, 1)) = 0.15
        [Enum(World metres, 0, Screen constant, 1)] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdWidthMode ("Width Mode", Float) = 0
        [NoScaleOffset] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdMask ("Outline Mask (white = outline)", 2D) = "white" {}
        [Toggle] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdVColorMask ("Also Mask by Vertex Color", Float) = 0
        [Enum(Red, 0, Green, 1, Blue, 2, Alpha, 3)] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] [ShowIf(_OutlineStdVColorMask)] _OutlineStdVColorChannel ("Vertex Color Channel", Float) = 0
        [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdTexTint ("Texture Tint", Range(0, 1)) = 0
        [Toggle] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdLit ("Lit by Scene Light", Float) = 0
        [Toggle] [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] _OutlineStdDistFade ("Distance Falloff [EXPERIMENTAL]", Float) = 0
        [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] [ShowIf(_OutlineStdDistFade)] _OutlineStdFadeNear ("Full Width Within (m)", Range(0, 10)) = 1
        [Group(specialfx_outlinestd)] [ShowIf(_OutlineStdEnable)] [ShowIf(_OutlineStdDistFade)] _OutlineStdFadeFar ("Gone Beyond (m)", Range(0, 20)) = 5
        [Toggle] [GroupToggle(specialfx_stars)] _StarEnable ("Enable Constellation FX", Float) = 0
        [Group(specialfx_stars)] [ShowIf(_StarEnable)] _StarMask ("Constellation Mask (optional)", 2D) = "white" {}
        [Group(specialfx_stars)] [ShowIf(_StarEnable)] _ConstellationBlend ("Blend Mode", Float) = 0
        [Group(specialfx_stars)] [ShowIf(_StarEnable)] _StarUVSource ("UV Source", Float) = 0
        [Group(specialfx_stars)] [ShowIf(_StarEnable)] _ConstellationEmission ("Emission Strength", Range(0, 8)) = 1
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_stars)] [ShowIf(_StarEnable)] _StarBand ("Stars AL Band", Float) = 2
        [Enum(Base Color, 0, ColorChord, 1, Random Per Star, 2)] [Group(specialfx_stars)] [ShowIf(_StarEnable)] _StarColorMode ("Star Color Mode", Float) = 0
        [HDR] [Group(specialfx_stars)] [ShowIf(_StarEnable)] _StarColor ("Star Base Color", Color) = (1, 1, 1, 1)
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarSaturation ("Star Color Saturation", Range(0, 3)) = 1.5
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarAL ("Star AL Pop Boost (0-10)", Range(0, 10)) = 3.0
        [IntRange] [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarLayers ("Constellation Layers", Range(1, 5)) = 3
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarDensity ("Star Density", Range(0, 100)) = 50
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarSize ("Star Size", Range(0, 100)) = 25
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarScatter ("Star Scatter", Range(0, 1)) = 0.7
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarSoftness ("Star Softness", Range(0, 100)) = 35
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarTwinkle ("Twinkle Amount", Range(0, 100)) = 50
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarTwinkleSpeed ("Twinkle Speed", Range(0, 100)) = 30
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarSpeed ("Global Drift Speed", Range(0, 100)) = 15
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarDrift ("Chaotic Jitter", Range(0, 100)) = 25
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarParallax ("Parallax Depth", Range(0, 100)) = 30
        [Group(specialfx_stars_staradv)] [ShowIf(_StarEnable)] _StarGlassWarp ("Glass Warp", Range(0, 1)) = 0
        [Toggle] [GroupToggle(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineEnable ("Enable Constellation Lines", Float) = 0
        [Enum(Line Color, 0, Star Color, 1)] [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineColorMode ("Line Color Mode", Float) = 0
        [HDR] [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineColor ("Line Color", Color) = (0.6, 0.8, 1.0, 1)
        [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineStrength ("Line Brightness", Range(0, 4)) = 1
        [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineThickness ("Line Thickness", Range(0, 100)) = 25
        [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineMaxLen ("Max Connection Length", Range(0, 100)) = 55
        [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineFade ("Length Falloff", Range(0, 100)) = 50
        [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineDepthFade ("Depth Fade", Range(0, 100)) = 40
        [Group(specialfx_stars_lines)] [ShowIf(_StarEnable)] _StarLineSpeed ("Line Motion", Range(0, 100)) = 30
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] _NebulaColorMode ("Nebula Color Mode", Float) = 0
        [HDR] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] _StarBgColor ("Nebula Base Color", Color) = (0.05, 0.0, 0.1, 1)
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] _NebulaBright ("Nebula Brightness", Range(0, 3)) = 1.0
        [HDR] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] _NebulaPopColor ("Nebula AL Pop Color", Color) = (0.5, 0.0, 1.0, 1)
        [HDR] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 3)] _NebGradColor0 ("Gradient Color 1", Color) = (0.05, 0.05, 0.4, 1)
        [HDR] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 3)] _NebGradColor1 ("Gradient Color 2", Color) = (0.35, 0.1, 0.6, 1)
        [HDR] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 3)] _NebGradColor2 ("Gradient Color 3", Color) = (0.8, 0.2, 0.7, 1)
        [HDR] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 3)] _NebGradColor3 ("Gradient Color 4", Color) = (1.0, 0.5, 0.8, 1)
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 3)] _NebGradPos1 ("Color 2 Position", Range(0, 1)) = 0.33
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 3)] _NebGradPos2 ("Color 3 Position", Range(0, 1)) = 0.66
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_NebulaColorMode, 4)] _NebGradTex ("Gradient Ramp", 2D) = "white" {}
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] _NebulaAL ("Nebula Pop Transition Sensitivity", Range(0, 10)) = 2.0
        [Toggle] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] _RaymarchEnable ("Enable Raymarched Nebula", Float) = 0
        [IntRange] [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_RaymarchEnable)] _RaymarchSteps ("Raymarch Quality", Range(8, 128)) = 32
        [Group(specialfx_stars_nebula)] [ShowIf(_StarEnable)] [ShowIf(_RaymarchEnable)] _RaymarchDensity ("Fog Density", Range(0, 10)) = 2.0
        [Toggle] [GroupToggle(specialfx_holo)] _HoloEnable ("Enable Hologram", Float) = 0
        [HDR] [Group(specialfx_holo)] [ShowIf(_HoloEnable)] _HoloColor ("Holo Color", Color) = (0.0, 0.9, 1.0, 1)
        [Group(specialfx_holo)] [ShowIf(_HoloEnable)] _HoloTintAmount ("Tint Amount", Range(0, 1)) = 0.7
        [Group(specialfx_holo)] [ShowIf(_HoloEnable)] _HoloTransStyle ("Transparency Style", Float) = 0
        [Group(specialfx_holo)] [ShowIf(_HoloEnable)] _HoloOpacity ("Base Opacity", Range(0, 1)) = 0.5
        [Group(specialfx_holo_scan)] [ShowIf(_HoloEnable)] _HoloScanDensity ("Scanline Density", Range(0, 200)) = 60
        [Group(specialfx_holo_scan)] [ShowIf(_HoloEnable)] _HoloScanSpeed ("Scanline Speed", Range(0, 20)) = 3
        [Group(specialfx_holo_scan)] [ShowIf(_HoloEnable)] _HoloScanSharpness ("Scanline Sharpness", Range(1, 16)) = 4
        [Group(specialfx_holo_scan)] [ShowIf(_HoloEnable)] _HoloScanStrength ("Scanline Strength", Range(0, 4)) = 1
        [Group(specialfx_holo_rim)] [ShowIf(_HoloEnable)] _HoloRimStrength ("Rim Strength", Range(0, 4)) = 1.5
        [Group(specialfx_holo_rim)] [ShowIf(_HoloEnable)] _HoloRimPower ("Rim Power", Range(0.5, 8)) = 3
        [Group(specialfx_holo_sweep)] [ShowIf(_HoloEnable)] _HoloSweepStrength ("Sweep Strength", Range(0, 4)) = 1
        [Group(specialfx_holo_sweep)] [ShowIf(_HoloEnable)] _HoloSweepSpeed ("Sweep Speed", Range(0, 10)) = 1.5
        [Group(specialfx_holo_sweep)] [ShowIf(_HoloEnable)] _HoloSweepWidth ("Sweep Width", Range(0.001, 0.5)) = 0.05
        [Group(specialfx_holo_glitch)] [ShowIf(_HoloEnable)] _HoloFlicker ("Flicker", Range(0, 1)) = 0.15
        [Group(specialfx_holo_glitch)] [ShowIf(_HoloEnable)] _HoloGlitchAmount ("Glitch Amount", Range(0, 1)) = 0.2
        [Group(specialfx_holo_glitch)] [ShowIf(_HoloEnable)] _HoloGlitchSpeed ("Glitch Speed", Range(0, 10)) = 2
        [Toggle] [GroupToggle(specialfx_plasma)] _PlasmaEnable ("Enable Plasma Hits", Float) = 0
        [IntRange] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaSites ("Hit Sites", Range(1, 8)) = 8
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaSpread ("Hit Spread", Range(0.1, 3)) = 0.9
        [Enum(Random Per Site, 0, Fixed Color, 1, Per Hit, 2)] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaColorMode ("Color Mode", Float) = 0
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 1)] _PlasmaColor ("Fixed Color", Color) = (0.0, 0.8, 1.0, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] _PlasmaColor1 ("Hit 1 Color", Color) = (1.0, 0.2, 0.2, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 2, ge)] _PlasmaColor2 ("Hit 2 Color", Color) = (1.0, 0.6, 0.1, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 3, ge)] _PlasmaColor3 ("Hit 3 Color", Color) = (0.9, 1.0, 0.2, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 4, ge)] _PlasmaColor4 ("Hit 4 Color", Color) = (0.2, 1.0, 0.4, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 5, ge)] _PlasmaColor5 ("Hit 5 Color", Color) = (0.2, 0.9, 1.0, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 6, ge)] _PlasmaColor6 ("Hit 6 Color", Color) = (0.3, 0.4, 1.0, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 7, ge)] _PlasmaColor7 ("Hit 7 Color", Color) = (0.7, 0.3, 1.0, 1)
        [HDR] [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] [ShowIf(_PlasmaColorMode, 2)] [ShowIf(_PlasmaSites, 8, ge)] _PlasmaColor8 ("Hit 8 Color", Color) = (1.0, 0.3, 0.8, 1)
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaGlow ("Glow Strength", Range(0, 8)) = 2
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaRate ("Hit Rate", Range(0.2, 8)) = 2
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaThreshold ("Audio Threshold", Range(0, 1)) = 0.3
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaRippleDist ("Hit Reach", Range(0.03, 1.5)) = 0.4
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaRingWidth ("Ring Width", Range(0.01, 0.5)) = 0.08
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaHitSize ("Hit Flash Size", Range(0.01, 0.5)) = 0.12
        [Group(specialfx_plasma)] [ShowIf(_PlasmaEnable)] _PlasmaDisplace ("Displacement", Range(0, 0.3)) = 0.05
        [Toggle] [GroupToggle(specialfx_break)] _BreakEnable ("Enable Geometry Break", Float) = 0
        [Group(specialfx_break)] [ShowIf(_BreakEnable)] _MaskTex ("Effect Mask (white = breaks)", 2D) = "white" {}
        [HDR] [Group(specialfx_break)] [ShowIf(_BreakEnable)] _EmissionColor ("Break Glow", Color) = (0, 1, 1, 1)
        [Enum(Full Energy, 0, Glowing Fragments, 1)] [Group(specialfx_break)] [ShowIf(_BreakEnable)] _BreakStyle ("Break Style (preset)", Float) = 0
        [Toggle] [Group(specialfx_break)] [ShowIf(_BreakEnable)] _BreakManual ("Manual Glow Override", Float) = 1
        [Group(specialfx_break)] [ShowIf(_BreakEnable)] _BreakGlow ("Surface Glow Strength", Range(0, 1)) = 1
        [Group(specialfx_break)] [ShowIf(_BreakEnable)] [ShowIf(_BreakManual)] _BreakCoreGlow ("Gap Fill Glow (inner core)", Range(0, 1)) = 1
        [Group(specialfx_break)] [ShowIf(_BreakEnable)] [ShowIf(_BreakManual)] _BreakFade ("Break Fade (transparent gap)", Range(0, 1)) = 0
        [Toggle] [Group(specialfx_break)] [ShowIf(_BreakEnable)] _BreakHueShift ("AL Hue Shift", Float) = 0
        [Enum(Pixel Grid, 0, Splinter Wave, 1)] [Group(specialfx_break)] [ShowIf(_BreakEnable)] _BreakMode ("Effect Mode", Float) = 1
        [Enum(Audio Beat, 0, Slow Float, 1)] [Group(specialfx_break)] [ShowIf(_BreakEnable)] _BreakDrive ("Break Trigger", Float) = 0
        [Group(specialfx_break)] [ShowIf(_BreakDrive)] _FloatSpeed ("Float Cycle Speed", Range(0, 3)) = 0.4
        [Group(specialfx_break)] [ShowIf(_BreakDrive)] _FloatReach ("Float Reach (peak break)", Range(0, 1)) = 0.7
        [Group(specialfx_break)] [ShowIf(_BreakDrive)] _FloatStagger ("Float Stagger (low = in sync)", Range(0, 1)) = 0.3
        [Group(specialfx_break)] [ShowIf(_BreakDrive)] _FloatAudio ("Float Audio Nudge", Range(0, 1)) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Band ("Break AL Band", Float) = 0
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Threshold ("Trigger Threshold", Range(0, 1)) = 0.1
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _GridSize ("Pixel Grid Density (Pixel Grid mode)", Range(8, 128)) = 48
        [IntRange] [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Tessellation ("Tessellation", Range(1, 12)) = 4
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _TessNear ("Tess Full Detail Within (m)", Range(0, 20)) = 2
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _TessFar ("Tess Off Beyond (m)", Range(0, 30)) = 5
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _WaveBottom ("Wave Start (Splinter, m)", Range(-3, 4)) = 0.0
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _WaveTop ("Wave End (Splinter, m)", Range(-3, 4)) = 1.6
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _RiseHeight ("Rise Height (m)", Range(0, 1)) = 0.25
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Spread ("Pop Outward", Range(0, 0.5)) = 0.05
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Jitter ("Float Drift", Range(0, 0.3)) = 0.03
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Shrink ("Shrink Amount", Range(0, 1)) = 0.9
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _Tumble ("Shard Tumble", Range(0, 10)) = 3
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _EdgeWidth ("Edge Glow Width", Range(0, 100)) = 15
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _EdgeGap ("Separation Gap", Range(0, 0.5)) = 0.12
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _HeatGlow ("Pre-Break Heat", Range(0, 3)) = 0.8
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _CoreTiling ("Core Pattern Tiling", Range(0.1, 8)) = 1
        [Group(specialfx_break_breakadv)] [ShowIf(_BreakEnable)] _CoreDepth ("Core Parallax Depth", Range(0, 100)) = 25
        [Group(specialfx_break)] [ShowIf(_BreakEnable)] _CoreTex ("Inner Core Pattern", 2D) = "white" {}
        [Toggle] [GroupToggle(specialfx_glitter)] _GlitterEnable ("Enable Glitter", Float) = 0
        [HDR] [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterColor ("Sparkle Color", Color) = (1, 1, 1, 1)
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterMask ("Glitter Mask", 2D) = "white" {}
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterDensity ("Density", Range(0, 1)) = 0.5
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterSize ("Flake Size", Range(0, 1)) = 0.3
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterBrightness ("Brightness", Range(0, 10)) = 2
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterAmount ("Sparkle Amount", Range(0, 1)) = 0.5
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterViewRange ("Viewable Angle", Range(0, 1)) = 0.3
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterSpeed ("Twinkle Speed", Range(0, 20)) = 6
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterFlow ("Drift Direction (XY)", Vector) = (0, 0, 0, 0)
        [Enum(UV, 0, World Triplanar, 1)] [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterProjection ("Projection", Float) = 0
        [Toggle] [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterLit ("Lit by World Lighting", Float) = 0
        [Toggle] [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] _GlitterALEnable ("AudioLink Reactive", Float) = 0
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] [ShowIf(_GlitterALEnable)] _GlitterBand ("AL Band", Float) = 3
        [Group(specialfx_glitter)] [ShowIf(_GlitterEnable)] [ShowIf(_GlitterALEnable)] _GlitterAL ("AL Sparkle Boost", Range(0, 10)) = 3
        [Toggle] [GroupToggle(specialfx_glitch)] _GlitchEnable ("Enable Mesh Glitch", Float) = 0
        [Group(specialfx_glitch)] [ShowIf(_GlitchEnable)] _GlitchMask ("Glitch Area Mask", 2D) = "white" {}
        [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(specialfx_glitch_glitchadv)] [ShowIf(_GlitchEnable)] _GlitchBand ("Glitch AL Band", Float) = 0
        [Group(specialfx_glitch_glitchadv)] [ShowIf(_GlitchEnable)] _GlitchThreshold ("Glitch Threshold", Range(0, 1)) = 0.35
        [Group(specialfx_glitch_glitchadv)] [ShowIf(_GlitchEnable)] _GlitchIntensity ("Displacement (m)", Range(0, 0.2)) = 0.04
        [Group(specialfx_glitch_glitchadv)] [ShowIf(_GlitchEnable)] _GlitchSlices ("Block Density", Float) = 30
        [Group(specialfx_glitch_glitchadv)] [ShowIf(_GlitchEnable)] _GlitchRGBSplit ("RGB Split (UV)", Range(0, 0.05)) = 0.008
        [Group(specialfx_glitch_glitchadv)] [ShowIf(_GlitchEnable)] _GlitchHue ("Neon Intensity", Range(0, 3.2)) = 0
        [Group(specialfx_height)] _HeightMap ("Height Map (B&W)", 2D) = "black" {}
        [Toggle] [Group(specialfx_height)] _HeightToNormalEnable ("Convert Height to Bump Normals", Float) = 0
        [Group(specialfx_height)] [ShowIf(_HeightToNormalEnable)] _HeightStrength ("Recess / Bump Depth", Range(0, 5)) = 1.0
        [Toggle] [Group(specialfx_height)] _ParallaxEnable ("Enable Parallax Heightmapping", Float) = 0
        [Group(specialfx_height)] [ShowIf(_ParallaxEnable)] _ParallaxMask ("Parallax Mask", 2D) = "white" {}
        [Group(specialfx_height)] [ShowIf(_ParallaxEnable)] _ParallaxStrength ("Strength", Range(0, 0.2)) = 0.02
        [Group(specialfx_height)] [ShowIf(_ParallaxEnable)] _ParallaxOffset ("Offset (Height Bias)", Range(-1, 1)) = 0
        [Group(specialfx_height)] [ShowIf(_ParallaxEnable)] _ParallaxMipBias ("Mip Bias", Range(-2, 2)) = 0
        [Toggle(LTCGI)] [GroupToggle(ltcgi)] _LTCGI ("LTCGI System", Float) = 0
        [Group(ltcgi)] [ShowIf(_LTCGI)] _LTCGIStrength ("LTCGI Strength", Range(0, 2)) = 1
        [Toggle] [Group(ltcgi)] [ShowIf(_LTCGI)] _LTCGITintOn ("Tint LTCGI", Float) = 0
        [Group(ltcgi)] [ShowIf(_LTCGI)] [ShowIf(_LTCGITintOn)] _LTCGIDiffuseTint ("LTCGI Diffuse Tint", Color) = (1, 1, 1, 1)
        [Group(ltcgi)] [ShowIf(_LTCGI)] [ShowIf(_LTCGITintOn)] _LTCGISpecularTint ("LTCGI Specular Tint", Color) = (1, 1, 1, 1)
        [Group(ltcgi)] [ShowIf(_LTCGI)] _LTCGIOcclusion ("LTCGI Occlusion", Range(0, 1)) = 1
        [Toggle(ZET_LIGHT_VOLUMES)] [GroupToggle(lightvolumes)] _LightVolumes ("Light Volumes System", Float) = 1
        [Group(lightvolumes)] [ShowIf(_LightVolumes)] _LightVolumesStrength ("Light Volumes Strength", Range(0, 2)) = 1
        [Toggle] [Group(lightvolumes)] [ShowIf(_LightVolumes)] _LightVolumesSpec ("Light Volume Speculars", Float) = 1
        [Group(lightvolumes)] [ShowIf(_LightVolumes)] _LVPointShading ("Point Light Shaping", Range(0, 4)) = 1
        // --- VRSL GI -------------------------------------------------------
        // No package required. The world publishes _Udon_VRSL_GI_LightTexture as
        // a global, exactly like AudioLink's _AudioTexture, so the avatar only
        // has to read it. In a world without VRSL GI the texture is unbound, the
        // light count reads 0, and the loop never runs.
        [Toggle(ZET_VRSLGI)] [GroupToggle(vrslgi)] _VRSLGI ("VRSL GI System", Float) = 0
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGIStrength ("VRSL GI Strength", Range(0, 4)) = 1
        [Toggle] [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGISpecular ("VRSL GI Speculars", Float) = 1
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGISpecularMult ("Specular Multiplier", Range(0, 4)) = 1
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGISpecularClamp ("Specular Clamp", Range(0, 8)) = 2
        [Toggle] [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGIToon ("Toon Falloff", Float) = 0
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGIOcclusion ("Apply AO", Range(0, 1)) = 1

        // Debug views. Drives an //ifex, so Off strips every line of this from a
        // locked shader - production builds carry none of it.
        // Options come from ZetsFancyShaderUI.json - see EnumDef for why not [Enum].
        [Group(debug)] _DebugView ("Debug View", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "VRCFallback" = "Toon" }
        Cull [_CullMode] 
        Stencil
        {
            Ref [_StencilRef]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
            Comp [_StencilComp]
            Pass [_StencilPass]
            Fail [_StencilFail]
            ZFail [_StencilZFail]
        }
        // ==============================================================================
        // CGINCLUDE BLOCK
        // ==============================================================================
        CGINCLUDE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityStandardUtils.cginc"
            // --- AudioLink sampling layer (embedded) ---
            // v64j: ZFS no longer includes AudioLink.cginc from ANY path.
            // Two independent reasons, both learned the hard way:
            //  1. Thry's ShaderOptimizer inlines every include line by
            //     literally opening the file, ignoring preprocessor guards -
            //     so an include path that doesn't exist on a user's machine
            //     crashes material locking with DirectoryNotFoundException.
            //  2. __has_include guards proved unreliable in Unity's shader
            //     preprocessor, silently compiling the no-audio path even with
            //     the package installed.
            // Instead, the minimal sampling layer is embedded below, copied
            // verbatim from AudioLink - MIT License, c. llealloo & contributors,
            // github.com/llealloo/audiolink. It reads the _AudioTexture global
            // bound by the AudioLink runtime, so reactivity is independent of
            // package install state - the same architecture Poiyomi uses.
            // AudioLinkIsAvailable still returns false when no AudioLink is
            // running in the world. AUDIOLINK_CGINC_INCLUDED is defined so the
            // real AudioLink include no-ops if anything ever pulls it in later.
            #define AUDIOLINK_CGINC_INCLUDED
            #define ZET_AUDIOLINK 1
            #define ZET_AUDIOLINK_EMBEDDED 1
                #define ALPASS_DFT                uint2(0,4)
                #define ALPASS_WAVEFORM           uint2(0,6)
                #define ALPASS_AUDIOLINK          uint2(0,0)
                #define ALPASS_AUDIOLINKHISTORY   uint2(1,0)
                #define ALPASS_THEME_COLOR0       uint2(0,23)
                #define ALPASS_THEME_COLOR1       uint2(1,23)
                #define ALPASS_THEME_COLOR2       uint2(2,23)
                #define ALPASS_THEME_COLOR3       uint2(3,23)
                #define ALPASS_FILTEREDAUDIOLINK  uint2(0,28)
                #define ALPASS_CHRONOTENSITY      uint2(16,28)
                #define AUDIOLINK_WIDTH           128
                #if defined(SHADER_API_GLCORE) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3) || (SHADER_TARGET < 45)
                    #define ZET_AL_STDIDX 1
                #endif
                uniform float4 _AudioTexture_TexelSize;
                #ifdef ZET_AL_STDIDX
                    sampler2D _AudioTexture;
                    #define AudioLinkData(xycoord) tex2Dlod(_AudioTexture, float4(uint2(xycoord) * _AudioTexture_TexelSize.xy, 0, 0))
                #else
                    uniform Texture2D<float4> _AudioTexture;
                    #define AudioLinkData(xycoord) _AudioTexture[uint2(xycoord)]
                #endif
                float4 AudioLinkDataMultiline(uint2 xycoord) { return AudioLinkData(uint2(xycoord.x % AUDIOLINK_WIDTH, xycoord.y + xycoord.x / AUDIOLINK_WIDTH)); }
                float4 AudioLinkLerp(float2 xy) { return lerp(AudioLinkData(xy), AudioLinkData(xy + int2(1, 0)), frac(xy.x)); }
                float4 AudioLinkLerpMultiline(float2 xy) { return lerp(AudioLinkDataMultiline(xy), AudioLinkDataMultiline(xy + float2(1, 0)), frac(xy.x)); }
                bool AudioLinkIsAvailable()
                {
                    #ifndef ZET_AL_STDIDX
                        int width, height;
                        _AudioTexture.GetDimensions(width, height);
                        return width > 16;
                    #else
                        return _AudioTexture_TexelSize.z > 16;
                    #endif
                }
                uint AudioLinkDecodeDataAsUInt(uint2 indexloc)
                {
                    uint4 rpx = AudioLinkData(indexloc);
                    return rpx.x + rpx.y * 1024 + rpx.z * 1048576 + rpx.w * 1073741824;
                }
                float AudioLinkGetChronoTime(uint index, uint band)
                {
                    return (AudioLinkDecodeDataAsUInt(ALPASS_CHRONOTENSITY + uint2(index, band))) / 100000.0;
                }
            // --- VRSL GI light data (world-published global) -------------------
            // Declared in the same form and the same place as _AudioTexture,
            // deliberately: that is the one global texture in this shader proven
            // to work alongside the sampler_MainTex pairing. A bare "Texture2D"
            // declared down beside the pass-level slots broke that pairing -
            // Unity reported sampler_MainTex as matching no texture - so this
            // copies the known-good pattern rather than inventing a second one.
            uniform Texture2D<float4> _Udon_VRSL_GI_LightTexture;
            // --- Optional world lighting integrations ---
            // Availability is resolved in C# by ZetIntegrationGenerator and written
            // into this file, which ALWAYS exists and is always valid to include.
            // It defines ZET_LTCGI and/or ZET_LV_OK only for packages actually
            // present, so a project missing either one still compiles.
            //
            // This replaced bare includes inside //ifex. That worked, but ifex only
            // strips at LOCK time, so an unlocked material compiled both includes
            // unconditionally - which made both packages hard dependencies of the
            // SOURCE and forced every user to add two third-party VPM repos before
            // installing anything. The in-shader alternatives both failed:
            // __has_include was silently eaten in locked copies, and keyword-guarding
            // the include died at lock because the optimizer does not carry enabled
            // keywords into the locked shader as preprocessor defines.
            //
            // Resolving it in C# sidesteps all of that: by lock time this is an
            // ordinary include that either does or does not define a symbol.
            // Relative on purpose: an absolute Packages/<id>/ path only resolves
            // when the package is installed via VPM. A .unitypackage install drops
            // everything under Assets/ instead, and the absolute path breaks.
            #include "Generated/ZetIntegrations.cginc"

            // --- VRSL GI ------------------------------------------------------
            // Declared here rather than pulled from VRSLGI-Functions.cginc on
            // purpose. That file declares _LTCGIStrength, _AreaLitStrength and
            // ~30 other uniforms of its own - _LTCGIStrength collides with ours
            // outright - and it carries a "#pragma exclude_renderers d3d11 gles"
            // inside its specular block, which would silently drop this shader on
            // the exact platform VRChat PC runs. The texture LAYOUT is the
            // contract; that cginc is just one consumer of it.
            //
            // Row layout of _Udon_VRSL_GI_LightTexture, addressed by Load(int3(x, row, 0)):
            //   row 0 : light colour rgb, .a = range multiplier
            //   row 1 : light position xyz, .w > 180 marks a spotlight
            //   row 2 : Load(int3(0,2,0)).r is the light COUNT
            //   row 3 : spot direction xyz, .w packs cone angle and edge blend
            // The texture itself is declared INSIDE each pass under
            // ZET_VRSLGI, with the other keyword-gated slots - see the texture
            // budget note below. Declaring it here cost a texture slot in every
            // variant whether or not the feature was on, and this shader is
            // already over Unity's 64-texture cap without help.

            // Hard ceiling on the loop. The count comes from a texture this
            // shader does not own; if it is ever garbage, an uncapped [loop]
            // hangs the GPU rather than rendering wrong.
            #define ZET_VRSL_MAX_LIGHTS 64
            // --- Textures & Samplers (kept outside the per-material cbuffer) ---
            Texture2D _MainTex; SamplerState sampler_MainTex;
            SamplerState sampler_LinearClamp;
            SamplerState sampler_LinearRepeat;
            Texture2D _HeightMap;
            Texture2D _ParallaxMask;
            Texture2D _BumpMap;
            Texture2D _AlphaTex;
            Texture2D _PackedMap;
            Texture2D _CoreTex;
            Texture2D _DissolveTex;
            Texture2D _MatcapTex; Texture2D _MatcapMask;
            Texture2D _MaskTex;
            Texture2D _NebGradTex;
            Texture2D _Em0Mask;
            Texture2D _Em0BgTex;
            Texture2D _OutlineMask;
            Texture2D _OutlineStdMask;
            Texture2D _StarMask;
            Texture2D _IridMask;
            Texture2D _EQMask;
            Texture2D _GlitchMask;
            Texture2D _SpeakerMask;
            Texture2D _Spec2Mask;
            Texture2D _AnisoMask;
            Texture2D _SSSMask;
            Texture2D _SSSThicknessMap;
            Texture2D _DetailMask;
            Texture2D _DetailAlbedo;
            Texture2D _DetailNormal;
            Texture2D _Em0PathTex;
            Texture2D _AnisoFlowMap;
            Texture2D _AnisoObjectMap;
            Texture2D _StyleSpecMask;
            Texture2D _Decal0Tex;
            Texture2D _GlitterMask;
            Texture2D _VertALMask;
            // ---- Secondary-slot textures: umbrella-keyword gated -------------
            // Unity caps a shader at 64 texture parameters, and ZFS's full set
            // with LTCGI + Light Volumes reaches ~73. The texture-hungry slot
            // families compile in only when their umbrella toggle sets a
            // keyword, Poiyomi-style but at coarse granularity: flipping an
            // umbrella recompiles once; everything inside stays instant
            // uniform-branch toggles. With an umbrella off, its slots'
            // textures are not part of the compiled program and cost nothing.
            // All three umbrellas + LTCGI + LV on ONE unlocked material can
            // still exceed the cap - Unity will say so; turn something off.
            TextureCube _RoomCube;
            Texture2D _RoomMask;
            Texture2D _RefractMask;
            Texture2D _RefractMap;
            Texture2D _ScreenMask;
            Texture2D _ScreenArt;
            Texture2D _ScreenBackdrop;
            Texture2D _ScreenGridTex;
            Texture2D _ScreenLCDTex;
            Texture2D _ScreenBSODTex;
//ifex _RefractEnable==0
            // v64: screenspace-texture macros -> Texture2DArray under SPS-I so
            // refraction samples the correct eye slice in VR.
            UNITY_DECLARE_SCREENSPACE_TEXTURE(_ZetGrabTex);
//endex
            TextureCube _BakedCubemap;
            // --- Material properties: one-per-line in UnityPerMaterial so the
            //     Thry optimizer can regenerate this block cleanly when locking. ---
            CBUFFER_START(UnityPerMaterial)
            float _LightingModel;
            float _ProximityFade;
            float _SpeakerMaskBlur;
            float _ProxMin;
            float _ProxMax;
            float _UseColorChord;
            float _ALEnvEnable;
            float _ALEnvRelease;
            float _VertALEnable;
            float _VertALTransEnable; float4 _VertALTransMin; float4 _VertALTransMax;
            float _VertALTransBandX; float _VertALTransBandY; float _VertALTransBandZ;
            float _VertALWTransEnable; float4 _VertALWTransMin; float4 _VertALWTransMax;
            float _VertALWTransBandX; float _VertALWTransBandY; float _VertALWTransBandZ;
            float _VertALRotEnable; float4 _VertALRot;
            float _VertALRotBandX; float _VertALRotBandY; float _VertALRotBandZ;
            float _VertALRotModeX; float _VertALRotModeY; float _VertALRotModeZ;
            float _VertALRotSpdEnable; float4 _VertALRotSpd; float _VertALRotSpdBand;
            float _VertALScaleEnable; float4 _VertALScaleMin; float4 _VertALScaleMax; float _VertALScaleBand;
            float _VertALUVEnable; float _VertALUVMode; float4 _VertALUVSpeed; float _VertALUVBand;
            float _RoomEnable; float4 _RoomColor; float _RoomDepth; float _RoomTile; float _RoomFade; float _RoomDepthMode; float4 _RoomHazeColor; float _RoomSoften; float _RoomGlassWarp; float _RoomGlassChroma; float _RoomScrollX; float _RoomScrollY; float _RoomSlideX; float _RoomSlideY; float _RoomEdge; float _RoomALEnable; float _RoomBand; float _RoomAL; float _RefractEnable; float _RefractStrength; float _RefractCA; float4 _RefractTint; float _RefractBlend; float _RefractTile; float _RefractScroll; float _RefractALEnable; float _RefractBand; float _RefractAL; float _ScreenEnable; float _ScreenMode; float4 _ScreenLineColor; float _ScreenWaveAmp; float _ScreenWaveSamples; float _ScreenLineWidth; float _ScreenArtStrength; float4 _ScreenArt_ST; float4 _ScreenBackdrop_ST; float4 _ScreenBGColor; float _ScreenGridProc; float _ScreenGridCells; float _ScreenGridLineW; float _ScreenGridMinor; float4 _ScreenGridTex_ST; float4 _ScreenGridColor; float _ScreenGridStrength; float4 _ScreenLCDTex_ST; float _ScreenLCDStrength; float _ScreenScanline; float _ScreenScanCount; float _ScreenBSOD; float _ScreenBSODNoAL; float4 _ScreenBSODTex_ST;
            float _CC_Em0;
            float _CC_Em1;
            float _CC_Em2;
            float _CC_Em3;
            float _CC_Outline;
            float _CC_Stars;
            float _CC_Rim;
            float _CC_Break;
            float _CC_Speaker;
            float _CC_Dissolve;
            float _ColorAdjustEnable;
            float _Saturation;
            float _Brightness;
            float _Gamma;
            float _BaseHueShift;
            float _BaseHueShiftAL;
            float _BaseHueBand;
            float _MinBrightness;
            float _MaxBrightness;
            float _GrayscaleLighting;
            float _ReceiveShadows;
            float _SSSEnable;
            float4 _SSSColor;
            float _SSSTermWidth;
            float _SSSTermStrength;
            float _SSSTransStrength;
            float _SSSTransPower;
            float _SSSTransDistortion;
            float _SSSAmbient;
            float _SSSProbeLight;
            float _SSSLTCGI;
            float _SSSTintMode;
            float _SSSLVDepth;
            float _ClothWrap;
            float4 _SheenColor;
            float _UVTileDiscardEnable;
            float _UVTileDiscardChannel;
            float _UVTileRow0_0;
            float _UVTileRow0_1;
            float _UVTileRow0_2;
            float _UVTileRow0_3;
            float _UVTileRow1_0;
            float _UVTileRow1_1;
            float _UVTileRow1_2;
            float _UVTileRow1_3;
            float _UVTileRow2_0;
            float _UVTileRow2_1;
            float _UVTileRow2_2;
            float _UVTileRow2_3;
            float _UVTileRow3_0;
            float _UVTileRow3_1;
            float _UVTileRow3_2;
            float _UVTileRow3_3;
            float _DetailEnable;
            float4 _DetailTiling;
            float _DetailAlbedoStrength;
            float _DetailNormalStrength;
            float _ParallaxEnable;
            float _ParallaxStrength;
            float _ParallaxOffset;
            float _ParallaxMipBias;
            float _HeightToNormalEnable;
            float _HeightStrength;
            float _IridEnable;
            float _IridThickness;
            float _IridSpeed;
            float _IridBand;
            float _IridAL;
            float4 _IridColor1;
            float4 _IridColor2;
            float4 _IridColor3;
            float _MatcapEnable;
            float _MatcapMode;
            float _MatcapStrength;
            float _Matcap1Enable;
            float _Matcap1Mode;
            float _Matcap1Strength;
            float _Matcap2Enable;
            float _Matcap2Mode;
            float _Matcap2Strength;
            float _Matcap3Enable;
            float _Matcap3Mode;
            float _Matcap3Strength;
            float _Matcap4Enable;
            float _Matcap4Mode;
            float _Matcap4Strength;
            float _DissolveEnable;
            float _DissolveAmount;
            float _DissolveAL;
            float _DissolveWidth;
            float _DissolveBand;
            float4 _DissolveColor;
            float _EQEnable;
            float _EQColumns;
            float _EQGain;
            float _EQCurve;
            float4 _EQColor;
            float4 _EQMask_ST;
            float _SpeakerState;
            float _SpeakerDirection;
            float _SpeakerEnable;
            float _SpeakerIntensity;
            float _SpeakerRings;
            float _SpeakerSpeed;
            float _SpeakerBand;
            float _SpeakerExpansion;
            float _SpeakerRingThickness;
            float _SpeakerRingSoftness;
            float _SpeakerThreshold;
            float _SpeakerHueShift;
            float4 _SpeakerColor;
            float _AnisoEnable;
            float _AnisoDir;
            float _AnisoDirMode;
            float _AnisoShift;
            float _AnisoPower;
            float _AnisoStrength;
            float4 _AnisoColor;
            float _StyleSpecEnable; float4 _StyleSpecTint; float _StyleSpecUseLight;
            float _SS1Size; float _SS1Feather; float _SS1Strength;
            float _SS2Size; float _SS2Feather; float _SS2Strength;
            float _SS3Size; float _SS3Feather; float _SS3Strength;
            float _Spec2Enable;
            float _Spec2Smoothness;
            float4 _Spec2Color;
            float4 _MainTex_ST;
            float _BumpScale;
            float _AlphaMode;
            float _Cutoff;
            float _AlphaSourceEnable;
            float _AlphaChannel;
            float _OcclusionStrength;
            float _Metallic;
            float _Smoothness;
            float _ReflTintOn;
            float _SpecTintOn;
            float _PackedStochastic;
            float _InvSmooth;
            float _MetallicMin;
            float _SmoothnessMin;
            float _PackMode;
            float4 _ReflTint;
            float4 _SpecTint;
            float4 _PackedTiling;
            float4 _PackedOffset;
            float4 _PackedPan;
            float _SpecEdge;
            float _FallbackCubemapStrength;
            float _ForceFallback;
            float _HasBakedCubemap;
            float _ReflStrength;
            float _GlitterEnable; float4 _GlitterColor; float _GlitterDensity; float _GlitterSize; float _GlitterBrightness;
            float _GlitterAmount; float _GlitterViewRange; float _GlitterSpeed; float4 _GlitterFlow; float _GlitterProjection;
            float _GlitterLit; float _GlitterALEnable; float _GlitterBand; float _GlitterAL;
            float _DecalsEnable;
            float _Decal0Enable; float4 _Decal0Color; float _Decal0Opacity; float _Decal0Rotation; float _Decal0Blend; float _Decal0Emit; float _Decal0PosX; float _Decal0PosY; float _Decal0Scale; float _Decal0Overlay; float _Decal0Flipbook; float _Decal0FlipCols; float _Decal0FlipRows; float _Decal0FlipFPS;
            float _Decal1Enable; float4 _Decal1Color; float _Decal1Opacity; float _Decal1Rotation; float _Decal1Blend; float _Decal1Emit; float _Decal1PosX; float _Decal1PosY; float _Decal1Scale; float _Decal1Overlay; float _Decal1Flipbook; float _Decal1FlipCols; float _Decal1FlipRows; float _Decal1FlipFPS;
            float _Decal2Enable; float4 _Decal2Color; float _Decal2Opacity; float _Decal2Rotation; float _Decal2Blend; float _Decal2Emit; float _Decal2PosX; float _Decal2PosY; float _Decal2Scale; float _Decal2Overlay; float _Decal2Flipbook; float _Decal2FlipCols; float _Decal2FlipRows; float _Decal2FlipFPS;
            float _Decal3Enable; float4 _Decal3Color; float _Decal3Opacity; float _Decal3Rotation; float _Decal3Blend; float _Decal3Emit; float _Decal3PosX; float _Decal3PosY; float _Decal3Scale; float _Decal3Overlay; float _Decal3Flipbook; float _Decal3FlipCols; float _Decal3FlipRows; float _Decal3FlipFPS;
            float _ReflectionsEnable;
            float4 _EmissionColor;
            float _BreakGlow;
            float _BreakFade;
            float _BreakStyle;
            float _BreakManual;
            float _BreakCoreGlow;
            float4 _Em0Color;
            float4 _Em0BgColor;
            float4 _Em0Center;
            float4 _Em0BgScale;
            float4 _Em0Pan;
            float _Em0Enable;
            float _Em0Hue;
            float _Em0Base;
            float _Em0Band;
            float _Em0AL;
            float _Em0Mode;
            float _Em0PulseScale;
            float _Em0Rotation;
            float _Em0Mirror;
            float _Em0Triplanar;
            float _Em0ScaleLock;
            float _Em0TileX;
            float _Em0TileY;
            float _Em0Layers;
            float _Em0Parallax;
            float _Em0LayerDist;
            float _Em0NearBright;
            float _Em0FarBright;
            float _Em0ALEnable;
            float _Em0MultBand;
            float _Em0MultAmt;
            float _Em0AddBand;
            float _Em0AddAmt;
            float _Em0VolBoost;
            float _Em0VolAmt;
            float _Em0Intensity;
            float _Em0EdgeGlow;
            float _Em0EdgePower;
            float _Em0LightBased;
            float _Em0MinEmiss;
            float _Em0MaxEmiss;
            float _Em0MinLight;
            float _Em0MaxLight;
            float _Em0Blink;
            float _Em0BlinkSpeed;
            float _Em0BlinkMin;
            float _Em0Scan; float _Em0ScanDir; float _Em0ScanMode; float _Em0ScanSpeed; float _Em0ScanWidth; float _Em0ScanSoft; float _Em0ScanFloor; float _Em0ScanPixels; float _Em0ScanGlitch;
            float4 _Em1Color;
            float4 _Em1BgColor;
            float4 _Em1Center;
            float4 _Em1BgScale;
            float4 _Em1Pan;
            float _Em1Enable;
            float _Em1Hue;
            float _Em1Base;
            float _Em1Band;
            float _Em1AL;
            float _Em1Mode;
            float _Em1PulseScale;
            float _Em1Rotation;
            float _Em1Mirror;
            float _Em1Triplanar;
            float _Em1ScaleLock;
            float _Em1TileX;
            float _Em1TileY;
            float _Em1Layers;
            float _Em1Parallax;
            float _Em1LayerDist;
            float _Em1NearBright;
            float _Em1FarBright;
            float _Em1ALEnable;
            float _Em1MultBand;
            float _Em1MultAmt;
            float _Em1AddBand;
            float _Em1AddAmt;
            float _Em1VolBoost;
            float _Em1VolAmt;
            float _Em1Intensity;
            float _Em1EdgeGlow;
            float _Em1EdgePower;
            float _Em1LightBased;
            float _Em1MinEmiss;
            float _Em1MaxEmiss;
            float _Em1MinLight;
            float _Em1MaxLight;
            float _Em1Blink;
            float _Em1BlinkSpeed;
            float _Em1BlinkMin;
            float _Em1Scan; float _Em1ScanDir; float _Em1ScanMode; float _Em1ScanSpeed; float _Em1ScanWidth; float _Em1ScanSoft; float _Em1ScanFloor; float _Em1ScanPixels; float _Em1ScanGlitch;
            float4 _Em2Color;
            float4 _Em2BgColor;
            float4 _Em2Center;
            float4 _Em2BgScale;
            float4 _Em2Pan;
            float _Em2Enable;
            float _Em2Hue;
            float _Em2Base;
            float _Em2Band;
            float _Em2AL;
            float _Em2Mode;
            float _Em2PulseScale;
            float _Em2Rotation;
            float _Em2Mirror;
            float _Em2Triplanar;
            float _Em2ScaleLock;
            float _Em2TileX;
            float _Em2TileY;
            float _Em2Layers;
            float _Em2Parallax;
            float _Em2LayerDist;
            float _Em2NearBright;
            float _Em2FarBright;
            float _Em2ALEnable;
            float _Em2MultBand;
            float _Em2MultAmt;
            float _Em2AddBand;
            float _Em2AddAmt;
            float _Em2VolBoost;
            float _Em2VolAmt;
            float _Em2Intensity;
            float _Em2EdgeGlow;
            float _Em2EdgePower;
            float _Em2LightBased;
            float _Em2MinEmiss;
            float _Em2MaxEmiss;
            float _Em2MinLight;
            float _Em2MaxLight;
            float _Em2Blink;
            float _Em2BlinkSpeed;
            float _Em2BlinkMin;
            float _Em2Scan; float _Em2ScanDir; float _Em2ScanMode; float _Em2ScanSpeed; float _Em2ScanWidth; float _Em2ScanSoft; float _Em2ScanFloor; float _Em2ScanPixels; float _Em2ScanGlitch;
            float4 _Em3Color;
            float4 _Em3BgColor;
            float4 _Em3Center;
            float4 _Em3BgScale;
            float4 _Em3Pan;
            float _Em3Enable;
            float _Em3Hue;
            float _Em3Base;
            float _Em3Band;
            float _Em3AL;
            float _Em3Mode;
            float _Em3PulseScale;
            float _Em3Rotation;
            float _Em3Mirror;
            float _Em3Triplanar;
            float _Em3ScaleLock;
            float _Em3TileX;
            float _Em3TileY;
            float _Em3Layers;
            float _Em3Parallax;
            float _Em3LayerDist;
            float _Em3NearBright;
            float _Em3FarBright;
            float _Em3ALEnable;
            float _Em3MultBand;
            float _Em3MultAmt;
            float _Em3AddBand;
            float _Em3AddAmt;
            float _Em3VolBoost;
            float _Em3VolAmt;
            float _Em3Intensity;
            float _Em3EdgeGlow;
            float _Em3EdgePower;
            float _Em3LightBased;
            float _Em3MinEmiss;
            float _Em3MaxEmiss;
            float _Em3MinLight;
            float _Em3MaxLight;
            float _Em3Blink;
            float _Em3BlinkSpeed;
            float _Em3BlinkMin;
            float _Em3Scan; float _Em3ScanDir; float _Em3ScanMode; float _Em3ScanSpeed; float _Em3ScanWidth; float _Em3ScanSoft; float _Em3ScanFloor; float _Em3ScanPixels; float _Em3ScanGlitch;
            float4 _ShadowTint;
            float4 _RimColor;
            float _ShadowEdge;
            float _ShadowSoft;
            float _ShadowDither;
            float _LTCGIStrength;
            // Toggle floats. [Toggle(KEYWORD)] declares a keyword but the float
            // itself still needs declaring to be readable at runtime, which is how
            // the unlocked build learns the user switched the feature off.
            float _LightVolumes;
            float _LTCGI;
            float _DebugView;
            float _VRSLGI; float _VRSLGIStrength; float _VRSLGISpecular;
            float _VRSLGISpecularMult; float _VRSLGISpecularClamp;
            float _VRSLGIToon; float _VRSLGIOcclusion;
            float _LTCGITintOn; float4 _LTCGIDiffuseTint; float4 _LTCGISpecularTint; float _LTCGIOcclusion;
            float _ZTest; float _ZWriteOverride; float _ColorMask; float _OffsetFactor; float _OffsetUnits;
            float _LightVolumesStrength;
            float _LightVolumesSpec;
            float _LVPointShading;
            float _RimState;
            float _RimEnable;
            float _RimWidth;
            float _RimSoft;
            float _RimBase;
            float _RimBand;
            float _RimAL;
            float _RimHueShift;
            float _OutlineHueShift;
            float _BreakHueShift;
            float _DissolveHueShift;
            float _BreakMode;
            float _Band;
            float _Threshold;
            float _GridSize;
            float _Tessellation;
            float _BreakEnable;
            float _BreakDrive;
            float _FloatSpeed;
            float _FloatReach;
            float _FloatStagger;
            float _FloatAudio;
            float _TessNear;
            float _TessFar;
            float _WaveBottom;
            float _WaveTop;
            float _RiseHeight;
            float _Spread;
            float _Jitter;
            float _Shrink;
            float _Tumble;
            float _EdgeWidth;
            float _EdgeGap;
            float _HeatGlow;
            float _GlitchEnable;
            float _GlitchBand;
            float _GlitchThreshold;
            float _GlitchIntensity;
            float _GlitchSlices;
            float _GlitchRGBSplit;
            float _GlitchHue;
            float _CoreDepth;
            float _CoreTiling;
            float _OutlineState;
            float _OutlineEnable;
            float _OutlineSpread;
            float _OutlineSlices;
            float _OutlineSpeed;
            float _OutlineBand;
            float _OutlineAL;
            float _OutlineFloat;
            float _OutlineStdEnable; float4 _OutlineStdColor; float _OutlineStdWidth; float _OutlineStdWidthMode; float _OutlineStdTexTint; float _OutlineStdLit; float _OutlineStdDistFade; float _OutlineStdFadeNear; float _OutlineStdFadeFar; float _OutlineStdVColorMask; float _OutlineStdVColorChannel;
            float _OutlineRGBSplit;
            float4 _OutlineColor;
            float _StarEnable; float _ConstellationBlend; float _ConstellationEmission; float _StarUVSource;
            float _StarDensity;
            float _StarSize; float _StarScatter;
            float _StarSpeed;
            float _StarParallax;
            float _StarGlassWarp;
            float _StarBand;
            float _StarColorMode;
            float _StarSaturation;
            float _NebulaColorMode;
            float4 _NebGradColor0; float4 _NebGradColor1; float4 _NebGradColor2; float4 _NebGradColor3;
            float _NebGradPos1; float _NebGradPos2;
            float _StarAL;
            float _NebulaAL;
            float _StarSoftness;
            float _StarDrift;
            float _StarLayers;
            float _StarTwinkle;
            float _StarTwinkleSpeed;
            float4 _StarColor;
            float4 _StarBgColor;
            float4 _NebulaPopColor;
            float _RaymarchEnable;
            float _NebulaBright;
            float _RaymarchSteps;
            float _RaymarchDensity;
            float _HoloEnable; float4 _HoloColor; float _HoloTintAmount; float _HoloTransStyle; float _HoloOpacity;
            float _HoloScanDensity; float _HoloScanSpeed; float _HoloScanSharpness; float _HoloScanStrength;
            float _HoloRimStrength; float _HoloRimPower;
            float _HoloSweepStrength; float _HoloSweepSpeed; float _HoloSweepWidth;
            float _HoloFlicker; float _HoloGlitchAmount; float _HoloGlitchSpeed;
            float _PlasmaEnable; float _PlasmaSites; float _PlasmaSpread; float _PlasmaColorMode; float4 _PlasmaColor;
            float4 _PlasmaColor1; float4 _PlasmaColor2; float4 _PlasmaColor3; float4 _PlasmaColor4;
            float4 _PlasmaColor5; float4 _PlasmaColor6; float4 _PlasmaColor7; float4 _PlasmaColor8;
            float _PlasmaGlow; float _PlasmaRate; float _PlasmaThreshold; float _PlasmaRippleDist; float _PlasmaRingWidth; float _PlasmaHitSize; float _PlasmaDisplace;
            float _StarLineEnable; float _StarLineColorMode; float4 _StarLineColor;
            float _StarLineStrength; float _StarLineThickness; float _StarLineMaxLen;
            float _StarLineFade; float _StarLineDepthFade; float _StarLineSpeed;
            CBUFFER_END
            // ---- UV Tile Discard --------------------------------------------
            // Vertex-level: a discarded tile collapses its vertices to NaN, so the
            // GPU culls the triangles (and their whole tessellation patches) before
            // any further work. Applied in every pass including outline and shadow.
            float ZetUVTileDiscarded(float2 uv0, float2 uv1) {
                if (_UVTileDiscardEnable < 0.5) return 0.0;
                float2 tuv = (_UVTileDiscardChannel > 0.5) ? uv1 : uv0;
                int tx = clamp((int)floor(tuv.x), 0, 3);
                int ty = clamp((int)floor(tuv.y), 0, 3);
                float t;
                if      (ty == 0) t = (tx == 0) ? _UVTileRow0_0 : (tx == 1) ? _UVTileRow0_1 : (tx == 2) ? _UVTileRow0_2 : _UVTileRow0_3;
                else if (ty == 1) t = (tx == 0) ? _UVTileRow1_0 : (tx == 1) ? _UVTileRow1_1 : (tx == 2) ? _UVTileRow1_2 : _UVTileRow1_3;
                else if (ty == 2) t = (tx == 0) ? _UVTileRow2_0 : (tx == 1) ? _UVTileRow2_1 : (tx == 2) ? _UVTileRow2_2 : _UVTileRow2_3;
                else              t = (tx == 0) ? _UVTileRow3_0 : (tx == 1) ? _UVTileRow3_1 : (tx == 2) ? _UVTileRow3_2 : _UVTileRow3_3;
                return t;
            }
            // ---- SSS diffusion-profile tint ---------------------------------
            // The scatter tint is the material's absorption filter (what the
            // pigment lets through), never invented light. From Base Color
            // saturates the albedo toward its dominant channel and normalizes
            // it to 1, so the transmission hue tracks the painted skin tone.
            half3 ZetSSSTint(half3 baseCol) {
                if (_SSSTintMode < 0.5) return _SSSColor.rgb;
                if (_SSSTintMode < 1.5) {
                    half3 t = pow(max(baseCol, 0.02), 1.5);
                    return t / max(max(t.r, max(t.g, t.b)), 1e-3);
                }
                if (_SSSTintMode < 2.5) return half3(1.0, 0.3, 0.15);    // skin
                if (_SSSTintMode < 3.5) return half3(0.45, 1.0, 0.25);   // foliage
                return half3(0.95, 0.85, 0.7);                           // marble
            }
            struct DummyAppdata { float4 vertex; };
            // Under SHADOWS_SHADOWMASK without screen shadows or a lightmap,
            // AutoLight's SHADOW_COORDS expands to nothing while TRANSFER_SHADOW
            // still writes _ShadowCoord (from lightmap UVs an avatar does not
            // have) - invalid subscript. Guard the transfer with the exact same
            // condition the attenuation reads use, so both ends stay consistent.
            #if defined(SHADOWS_SHADOWMASK) && !defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON)
                #define ZET_TRANSFER_SHADOW(o)
            #else
                #define ZET_TRANSFER_SHADOW(o) TRANSFER_SHADOW(o)
            #endif
            float hash2(float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
            void ApplyBreakStyle(float style, inout float gap, inout float fade) {
                if (style > 0.5) { gap = 0.0; fade = 0.0; } // Glowing Fragments
                else             { gap = 1.0; fade = 0.0; } // Full Energy
            }
            float2 hash2D(float2 p) { return frac(sin(float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)))) * 43758.5453); }
            // The jitter and drift the star points use, for any cell in layer s. Each
            // star gets its own drift frequency and phase per axis, so the field wanders
            // as scattered points instead of oscillating on one shared clock (the "wave").
            float2 ZetStarJitter(float2 cell, float s) {
                float2 rr = (hash2D(cell + s * 11.23) - 0.5) * _StarScatter;
                float2 freq  = 0.35 + hash2D(cell + s * 13.7) * 1.65;   // 0.35..2.0, per star and axis
                float2 phase = hash2D(cell + s * 4.9) * 6.2832;
                float jt = _Time.y;
                rr += float2(sin(jt * freq.x + phase.x), sin(jt * freq.y + phase.y)) * (_StarDrift * 0.003);
                return rr;
            }
            // Photoshop-style blend of the constellation (src) over the surface (dst).
            half3 ZetPhotoBlend(half3 d, half3 s, float mode) {
                if (mode < 0.5) return d + s;                                                 // Add
                else if (mode < 1.5) return 1.0 - (1.0 - saturate(d)) * (1.0 - saturate(s));  // Screen
                else if (mode < 2.5) return d * s;                                            // Multiply
                else if (mode < 3.5) return lerp(2.0 * d * s, 1.0 - 2.0 * (1.0 - d) * (1.0 - s), step(0.5, d)); // Overlay
                else if (mode < 4.5) return max(d, s);                                        // Lighten
                else if (mode < 5.5) return min(d, s);                                        // Darken
                else return s;                                                                // Replace
            }
            // Four-stop gradient (stops 0 and 3 anchored at 0 and 1; 1 and 2 movable).
            half3 ZetNebGrad(float t) {
                t = saturate(t);
                half3 c = _NebGradColor0.rgb;
                c = lerp(c, _NebGradColor1.rgb, saturate(t / max(_NebGradPos1, 1e-4)));
                c = lerp(c, _NebGradColor2.rgb, saturate((t - _NebGradPos1) / max(_NebGradPos2 - _NebGradPos1, 1e-4)));
                c = lerp(c, _NebGradColor3.rgb, saturate((t - _NebGradPos2) / max(1.0 - _NebGradPos2, 1e-4)));
                return c;
            }
            // 4x4 ordered dither, 0..1, array-free. For screen-door transparency.
            float ZetBayer2(float2 a) { a = floor(a); return frac(a.x * 0.5 + a.y * a.y * 0.75); }
            float ZetBayer4(float2 p) { return ZetBayer2(0.5 * p) * 0.25 + ZetBayer2(p); }
            // Holographic overlay: object-space scanlines, rim glow, a travelling sweep
            // bar, flicker, glitch tearing, mono tint, and see-through (true alpha or
            // ordered dither). Applied to the finished colour just before fog.
            void ZetApplyHologram(inout half3 col, inout half alpha, float3 wPos, float3 wNrm, float2 sp) {
                if (_HoloEnable < 0.5) return;
                float3 objPos = mul(unity_WorldToObject, float4(wPos, 1.0)).xyz;   // avatar's own space
                float3 vdir = normalize(_WorldSpaceCameraPos - wPos);
                half3 nrm = normalize(wNrm);
                float t = _Time.y;

                // Glitch: occasional horizontal tear of the scan coordinate.
                float bnd = floor(objPos.y * 40.0);
                float roll = frac(sin(bnd * 12.9898 + floor(t * (_HoloGlitchSpeed + 1.0))) * 43758.5453);
                float tear = step(1.0 - _HoloGlitchAmount * 0.35, roll) * (frac(sin(bnd * 78.233) * 1234.5) - 0.5) * _HoloGlitchAmount * 0.2;
                float scanY = objPos.y + tear;

                // Scanlines banded along the avatar's up axis, scrolling.
                float sc = 0.5 + 0.5 * sin(scanY * _HoloScanDensity * 6.2832 - t * _HoloScanSpeed);
                float scan = pow(sc, _HoloScanSharpness) * _HoloScanStrength;

                // Sweep bar cycling up the body.
                float sweepPos = frac(t * (_HoloSweepSpeed * 0.1));
                float sweep = smoothstep(_HoloSweepWidth, 0.0, abs(frac(objPos.y * 0.5) - sweepPos)) * _HoloSweepStrength;

                // Fresnel rim glow.
                float rim = pow(1.0 - saturate(dot(nrm, vdir)), _HoloRimPower) * _HoloRimStrength;

                // Flicker: two-rate brightness flutter.
                float flick = 1.0 - _HoloFlicker * 0.5 * (0.5 + 0.5 * sin(t * 30.0 + sin(t * 7.0) * 3.0));

                // Collapse toward the holo colour, then add holographic light.
                half lum = dot(col, half3(0.299, 0.587, 0.114));
                col = lerp(col, lum * _HoloColor.rgb, _HoloTintAmount);
                col = col * flick + _HoloColor.rgb * (scan + sweep + rim);

                // See-through: bright bands read as more solid.
                float holoA = saturate(_HoloOpacity + scan + sweep + rim);
                if (_HoloTransStyle < 0.5) alpha *= holoA;              // true alpha (needs a Transparent mode)
                else if (holoA < ZetBayer4(sp)) clip(-1);              // dither (works in Opaque or Cutout)
            }
            // v64e: stateless fast-attack / smooth-release envelope. 2 taps:
            // raw band + AudioLink's pre-filtered row (column = Release knob).
            // (A per-invocation static cache lived here in v64b-v64d; mutable
            // static initialization proved unreliable per-stage, returning 0
            // for all fragment-stage AudioLink reactivity. Never again.)
            // v64f: the v63 envelope, restored verbatim. Peak-hold over recent
            // band history with exponential decay: fast attack, tunable release,
            // and - critically - the floor returns to the true instantaneous
            // level between beats. (The v64 filtered-row version floored the
            // envelope at the track's running average; see changelog.)
            float ALEnv(uint band) {
                float env = AudioLinkData(ALPASS_AUDIOLINK + uint2(0, band)).r;
                if (_ALEnvEnable < 0.5) return env;
                uint stride = (uint)max(1.0, lerp(1.0, 8.0, saturate(_ALEnvRelease)));
                [unroll]
                for (uint k = 1u; k < 12u; k++)
                    env = max(env, AudioLinkData(ALPASS_AUDIOLINK + uint2(k * stride, band)).r * exp2(-(float)k * 0.28));
                return env;
            }
            // ---- AudioLink Vertex FX (v63) --------------------------------------
            // Band level for vertex motion: fast attack, smoothed release via
            // AudioLink's pre-filtered rows (reuses the _ALEnvRelease knob).
            float ZetVertBand(uint band)
            {
                // v64f: route through the restored envelope (the filtered-row
                // read here had the same running-average-floor flaw).
                return saturate(ALEnv(band));
            }
            // Motion value with Poiyomi-style modes. Accumulate modes read
            // Chronotensity (band energy pre-integrated by AudioLink) so motion
            // glides instead of snapping back when the band level changes.
            float ZetVertMotion(uint band, float mode)
            {
                float result = 0.0;
                if (mode < 0.5) result = ZetVertBand(band);                                 // Intensity 0..1
                else if (mode < 1.5) result = AudioLinkGetChronoTime(0, band);              // Accumulate
                else if (mode < 2.5) result = AudioLinkGetChronoTime(1, band);              // Accumulate when quiet
                else result = abs(frac(AudioLinkGetChronoTime(0, band) * 0.25) * 2.0 - 1.0);// Ping-pong 0..1..0
                return result;
            }
            // Euler XYZ rotation (radians), rotation order X then Y then Z.
            float3 ZetRotEuler(float3 p, float3 ang)
            {
                float3 s = sin(ang), c = cos(ang);
                p.yz = float2(p.y * c.x - p.z * s.x, p.y * s.x + p.z * c.x);
                p.xz = float2(p.x * c.y + p.z * s.y, -p.x * s.y + p.z * c.y);
                p.xy = float2(p.x * c.z - p.y * s.z, p.x * s.z + p.y * c.z);
                return p;
            }
            // Master vertex-FX: modifies object-space position, normal, tangent,
            // and the post-ST UV. uv0 = raw mesh UV (pre _MainTex_ST) for the mask.
            // Order: scale -> rotation -> spin -> local translation -> world translation.
            void ZetApplyVertexAL(inout float3 pos, inout float3 nrm, inout float3 tanXYZ,
                                  float2 uv0, inout float2 uvOut)
            {
                if (_VertALEnable < 0.5) return;
                if (!AudioLinkIsAvailable()) return;
                float m = _VertALMask.SampleLevel(sampler_LinearClamp, uv0, 0).r;
                if (m <= 0.001) return;
                if (_VertALScaleEnable > 0.5)
                {
                    float sv = ZetVertBand((uint)_VertALScaleBand);
                    float3 sc = lerp(_VertALScaleMin.xyz, _VertALScaleMax.xyz, sv);
                    pos *= lerp(float3(1, 1, 1), sc, m);
                }
                if (_VertALRotEnable > 0.5)
                {
                    float3 ang = radians(_VertALRot.xyz) * m * float3(
                        ZetVertMotion((uint)_VertALRotBandX, _VertALRotModeX),
                        ZetVertMotion((uint)_VertALRotBandY, _VertALRotModeY),
                        ZetVertMotion((uint)_VertALRotBandZ, _VertALRotModeZ));
                    pos    = ZetRotEuler(pos,    ang);
                    nrm    = ZetRotEuler(nrm,    ang);
                    tanXYZ = ZetRotEuler(tanXYZ, ang);
                }
                if (_VertALRotSpdEnable > 0.5)
                {
                    float ct = AudioLinkGetChronoTime(0, (uint)_VertALRotSpdBand);
                    float3 ang = radians(_VertALRotSpd.xyz) * ct * m;
                    pos    = ZetRotEuler(pos,    ang);
                    nrm    = ZetRotEuler(nrm,    ang);
                    tanXYZ = ZetRotEuler(tanXYZ, ang);
                }
                if (_VertALTransEnable > 0.5)
                {
                    float3 tl = float3(
                        ZetVertBand((uint)_VertALTransBandX),
                        ZetVertBand((uint)_VertALTransBandY),
                        ZetVertBand((uint)_VertALTransBandZ));
                    pos += lerp(_VertALTransMin.xyz, _VertALTransMax.xyz, tl) * m;
                }
                if (_VertALWTransEnable > 0.5)
                {
                    float3 tw = float3(
                        ZetVertBand((uint)_VertALWTransBandX),
                        ZetVertBand((uint)_VertALWTransBandY),
                        ZetVertBand((uint)_VertALWTransBandZ));
                    float3 wOff = lerp(_VertALWTransMin.xyz, _VertALWTransMax.xyz, tw);
                    pos += mul((float3x3)unity_WorldToObject, wOff) * m;
                }
                if (_VertALUVEnable > 0.5)
                {
                    float u = (_VertALUVMode < 0.5)
                        ? ZetVertBand((uint)_VertALUVBand)
                        : AudioLinkGetChronoTime(0, (uint)_VertALUVBand);
                    uvOut += _VertALUVSpeed.xy * u;
                }
            }
            half3 ApplyDecal(Texture2D tex, SamplerState samp, float2 pos, float scale, float rot, half4 tint, float opacity, float blend, float emit, float4 fb, float2 uv, half3 base, inout half3 emiss) {
                float2 d = (uv - pos) / max(scale, 1e-4);
                float a = radians(rot); float sn = sin(a), cs = cos(a);
                d = float2(d.x * cs - d.y * sn, d.x * sn + d.y * cs) + 0.5;
                float box = step(0.0, d.x) * step(d.x, 1.0) * step(0.0, d.y) * step(d.y, 1.0);
                float2 sampUV = d;
                if (fb.w > 0.5) {
                    float cols = max(fb.x, 1.0), rows = max(fb.y, 1.0);
                    float fi = fmod(floor(_Time.y * fb.z), cols * rows);
                    float fx = fmod(fi, cols), fy = floor(fi / cols);
                    sampUV = float2((fx + saturate(d.x)) / cols, (rows - 1.0 - fy + saturate(d.y)) / rows);
                }
                half4 tx = tex.Sample(samp, sampUV);
                half al = tx.a * tint.a * opacity * box;   // opacity is a plain uniform: animate 0..1 from a menu (e.g. blush)
                half3 dc = tx.rgb * tint.rgb;
                half3 outc;
                if (blend > 2.5)      outc = lerp(base, 1.0 - (1.0 - base) * (1.0 - dc), al); // Screen
                else if (blend > 1.5) outc = lerp(base, base * dc, al);                       // Multiply
                else if (blend > 0.5) outc = base + dc * al;                                  // Add
                else                  outc = lerp(base, dc, al);                              // Normal
                emiss += dc * al * emit;
                return outc;
            }
            float3 rotAround(float3 p, float3 axis, float ang) { float s = sin(ang), c = cos(ang); return p * c + cross(axis, p) * s + axis * dot(axis, p) * (1.0 - c); }
            
            half3 hueShift(half3 c, float a) {
                const half3 k = half3(0.57735, 0.57735, 0.57735);
                half co = cos(a);
                return c * co + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - co);
            }
            // --- Plasma Hits: audio-gated hits that pop at random spots in the -------
            // avatar's own 3D space and ripple outward. Each of the up to 8 slots relocates
            // on its own clock; brightness is the band envelope past a threshold, so it's
            // dark without audio (and without AudioLink). Slots cycle the four bands.
            float  ZetHash1(float n) { return frac(sin(n * 43.32 + 7.13) * 43758.5453); }
            float3 ZetHash3(float n) { return frac(sin(float3(n * 12.98 + 1.3, n * 78.23 + 4.7, n * 37.71 + 9.1)) * 43758.5453); }
            half3  ZetPlasmaColor(float s) { return hueShift(half3(1.0, 0.15, 0.15), ZetHash1(s + 3.1) * 6.28318); }
            float  ZetPlasmaGate(float e) { return saturate((e - _PlasmaThreshold) / max(1.0 - _PlasmaThreshold, 0.01)); }
            // Per-hit colour slot, for the Per Hit colour mode.
            half3  ZetPlasmaSlot(int k) {
                return k == 0 ? _PlasmaColor1.rgb : k == 1 ? _PlasmaColor2.rgb : k == 2 ? _PlasmaColor3.rgb :
                       k == 3 ? _PlasmaColor4.rgb : k == 4 ? _PlasmaColor5.rgb : k == 5 ? _PlasmaColor6.rgb :
                       k == 6 ? _PlasmaColor7.rgb : _PlasmaColor8.rgb;
            }
            // Random point in the avatar's own 3D space for a spawn seed.
            float3 ZetPlasmaSite(float seed) {
                float3 h = ZetHash3(seed);
                return float3((h.x - 0.5) * 2.0, h.y * 2.0, (h.z - 0.5) * 2.0) * _PlasmaSpread;
            }
            // The expanding ring front for a hit: a thin band that travels out and fades.
            float ZetPlasmaField(float d, float ph) {
                return smoothstep(_PlasmaRingWidth, 0.0, abs(d - ph * _PlasmaRippleDist)) * (1.0 - ph);
            }
            // One relocating hit for slot k. Seed changes each cycle, so it jumps to a new
            // random spot; shared by both stages so glow and displacement line up.
            float ZetPlasmaHit(float3 objP, int k, float e, out float d, out float ph, out float seed) {
                float clock = _Time.y * _PlasmaRate + ZetHash1((float)k * 1.37) * 17.0;
                ph = frac(clock);
                seed = floor(clock) * 8.0 + (float)k + 0.5;
                d = length(objP - ZetPlasmaSite(seed));
                return ZetPlasmaField(d, ph) * e;
            }
            void ZetApplyPlasmaDisplace(inout float3 zp, float3 zn) {
                if (_PlasmaEnable < 0.5 || _PlasmaDisplace < 0.0001 || !AudioLinkIsAvailable()) return;
                float e0 = ZetPlasmaGate(ZetVertBand(0)), e1 = ZetPlasmaGate(ZetVertBand(1));
                float e2 = ZetPlasmaGate(ZetVertBand(2)), e3 = ZetPlasmaGate(ZetVertBand(3));
                float disp = 0, d, ph, seed;
                int cnt = (int)_PlasmaSites;
                [loop] for (int i = 0; i < 8; i++) {
                    if (i >= cnt) break;
                    float e = (i & 3) == 0 ? e0 : (i & 3) == 1 ? e1 : (i & 3) == 2 ? e2 : e3;
                    disp += ZetPlasmaHit(zp, i, e, d, ph, seed);
                }
                zp += zn * disp * _PlasmaDisplace;
            }
            void ZetApplyPlasma(inout half3 col, float3 wPos) {
                if (_PlasmaEnable < 0.5 || !AudioLinkIsAvailable()) return;
                float3 objP = mul(unity_WorldToObject, float4(wPos, 1.0)).xyz;
                float e0 = ZetPlasmaGate(ALEnv(0)), e1 = ZetPlasmaGate(ALEnv(1));
                float e2 = ZetPlasmaGate(ALEnv(2)), e3 = ZetPlasmaGate(ALEnv(3));
                half3 add = 0; float d, ph, seed;
                int cnt = (int)_PlasmaSites;
                [loop] for (int i = 0; i < 8; i++) {
                    if (i >= cnt) break;
                    float e = (i & 3) == 0 ? e0 : (i & 3) == 1 ? e1 : (i & 3) == 2 ? e2 : e3;
                    float f = ZetPlasmaHit(objP, i, e, d, ph, seed);
                    float flash = e * (1.0 - ph) * (1.0 - ph) * smoothstep(_PlasmaHitSize, 0.0, d);
                    half3 c = (_PlasmaColorMode < 0.5) ? ZetPlasmaColor(seed)
                            : (_PlasmaColorMode < 1.5) ? _PlasmaColor.rgb : ZetPlasmaSlot(i);
                    add += c * (f + flash);
                }
                col += add * _PlasmaGlow;
            }
            float hash31(float3 p3) {
                p3  = frac(p3 * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }
            float noise3D(float3 x) {
                float3 i = floor(x); float3 f = frac(x); f = f * f * (3.0 - 2.0 * f);
                return lerp(lerp(lerp(hash31(i + float3(0,0,0)), hash31(i + float3(1,0,0)), f.x),
                                 lerp(hash31(i + float3(0,1,0)), hash31(i + float3(1,1,0)), f.x), f.y),
                            lerp(lerp(hash31(i + float3(0,0,1)), hash31(i + float3(1,0,1)), f.x),
                                 lerp(hash31(i + float3(0,1,1)), hash31(i + float3(1,1,1)), f.x), f.y), f.z);
            }
            // ---- Parallax Occlusion Mapping (raymarched height -> UV displacement) ----
            float2 ParallaxOcclusion(Texture2D hmap, SamplerState samp, float2 uv, float2 dir, float strength, float offset, float mipBias)
            {
                float2 P = dir * strength;
                const int STEPS = 16;
                float layerStep = 1.0 / STEPS;
                float2 dUV = P / STEPS;
                float mscale = exp2(mipBias);
                float2 dx = ddx(uv) * mscale, dy = ddy(uv) * mscale;
                float2 curUV = uv;
                float curLayer = 0.0;
                float curH = 1.0 - saturate(hmap.SampleGrad(samp, curUV, dx, dy).r + offset);
                [unroll]
                for (int i = 0; i < STEPS; i++) {
                    if (curLayer >= curH) break;
                    curUV -= dUV;
                    curH = 1.0 - saturate(hmap.SampleGrad(samp, curUV, dx, dy).r + offset);
                    curLayer += layerStep;
                }
                float2 prevUV = curUV + dUV;
                float afterD = curH - curLayer;
                float beforeD = (1.0 - saturate(hmap.SampleGrad(samp, prevUV, dx, dy).r + offset)) - (curLayer - layerStep);
                float w = saturate(afterD / max(afterD - beforeD, 1e-5));
                return lerp(curUV, prevUV, w);
            }
            // ---- Packed PBR map: Metallic / Smoothness / Reflection Mask / Specular Mask ----
            half4 StochasticSample(Texture2D tex, SamplerState s, float2 uv)
            {
                float2 dx = ddx(uv), dy = ddy(uv);
                float2 sk = mul(float2x2(1.0, 0.0, -0.57735027, 1.15470054), uv * 3.4641016);
                float2 base = floor(sk);
                float2 f = frac(sk);
                float3 w; float2 v1, v2 = base + float2(1.0, 0.0), v3 = base + float2(0.0, 1.0);
                if (f.x + f.y < 1.0) { v1 = base;       w = float3(1.0 - f.x - f.y, f.x, f.y); }
                else                 { v1 = base + 1.0; w = float3(f.x + f.y - 1.0, 1.0 - f.y, 1.0 - f.x); }
                float2 h1 = frac(sin(mul(float2x2(127.1, 311.7, 269.5, 183.3), v1)) * 43758.5453);
                float2 h2 = frac(sin(mul(float2x2(127.1, 311.7, 269.5, 183.3), v2)) * 43758.5453);
                float2 h3 = frac(sin(mul(float2x2(127.1, 311.7, 269.5, 183.3), v3)) * 43758.5453);
                w = w * w * w; w /= (w.x + w.y + w.z);
                return tex.SampleGrad(s, uv + h1, dx, dy) * w.x + tex.SampleGrad(s, uv + h2, dx, dy) * w.y + tex.SampleGrad(s, uv + h3, dx, dy) * w.z;
            }
            half4 SamplePackedMap(float2 uv)
            {
                float2 puv = uv * _PackedTiling.xy + _PackedOffset.xy + _Time.y * _PackedPan.xy;
                return (_PackedStochastic > 0.5) ? StochasticSample(_PackedMap, sampler_MainTex, puv) : _PackedMap.Sample(sampler_MainTex, puv);
            }
            // Opacity for cutout/transparent: the albedo alpha, or a chosen channel of a dedicated map.
            half GetOpacity(half albedoA, float2 uv)
            {
                if (_AlphaSourceEnable < 0.5) return albedoA;
                half4 a = _AlphaTex.Sample(sampler_MainTex, uv);
                return (_AlphaChannel < 0.5) ? a.r : (_AlphaChannel < 1.5) ? a.g : (_AlphaChannel < 2.5) ? a.b : a.a;
            }
            // ---- Unified emission slot: multi-band AL blend (mult/add) + volume boost + infinity mirror ----
            struct EmSlot {
                float enable; half3 baseColor; float hueOn; float baseAmt; float band; float alBoost; float mode; float pulseScale;
                float2 projCenter; float rotationDeg; float mirrorOn; float triplanar; half3 bgColor; float scaleLock; float2 bgScale;
                float tileX; float tileY; float2 pan; float layers; float parallax; float layerDist; float nearBright; float farBright;
                float alEnable; float multBand; float multAmt; float addBand; float addAmt; float volBoost; float volAmt;
                float intensity; float edgeStrength; float edgePower; float lightBased; float minEmiss; float maxEmiss; float minLight; float maxLight;
                float blinkOn; float blinkSpeed; float blinkMin;
                float scanOn; float scanDir; float scanMode; float scanSpeed; float scanWidth; float scanSoft; float scanFloor; float scanPixels; float scanGlitch;
            };
            half3 EvalEmissionSlot(EmSlot s, Texture2D maskTex, Texture2D bgTex, Texture2D pathTex,
                float2 uv, float3 wPos, float3 N, float3 viewDir, float2 vT, float proxAlpha, bool alAvail, float litFactor)
            {
                if (s.enable < 0.5) return half3(0, 0, 0);
                float maskVal = maskTex.Sample(sampler_LinearClamp, uv).r;
                if (maskVal <= 0.001) return half3(0, 0, 0);
                float sig = 0.0;
                if (s.alEnable > 0.5 && alAvail) {
                    float prim;
                    if (s.mode < 0.5) {
                        prim = ALEnv((uint)s.band);
                    } else if (s.mode < 1.5) {
                        prim = AudioLinkLerp(ALPASS_AUDIOLINK + float2(saturate((wPos.y - unity_ObjectToWorld._m13 - _WaveBottom) / max(_WaveTop - _WaveBottom, 0.001)) * 127.0, (uint)s.band)).r;
                    } else if (s.mode < 2.5) {
                        float pulseDist = saturate(length(uv - s.projCenter) * s.pulseScale);
                        prim = AudioLinkLerp(ALPASS_AUDIOLINKHISTORY + float2(pulseDist * 126.0, (uint)s.band)).r;
                    } else {
                        // Gradient Path: the painted gradient value indexes the
                        // band's history, so the newest audio enters at black and
                        // travels along the ramp toward white.
                        float g = saturate(pathTex.Sample(sampler_LinearClamp, uv).r);
                        prim = AudioLinkLerp(ALPASS_AUDIOLINKHISTORY + float2(g * 126.0, (uint)s.band)).r;
                    }
                    sig = prim;
                    sig *= (1.0 + ALEnv((uint)s.multBand) * s.multAmt);
                    sig += ALEnv((uint)s.addBand) * s.addAmt;
                    if (s.volBoost > 0.5) {
                        float vol = (AudioLinkData(ALPASS_AUDIOLINK + uint2(0, 0)).r
                                   + AudioLinkData(ALPASS_AUDIOLINK + uint2(0, 1)).r
                                   + AudioLinkData(ALPASS_AUDIOLINK + uint2(0, 2)).r
                                   + AudioLinkData(ALPASS_AUDIOLINK + uint2(0, 3)).r) * 0.25;
                        sig *= (1.0 + vol * s.volAmt);
                    }
                    // No saturate here: a beat already drives prim to ~1, so a
                    // clamp made the Multiplier / Additive / Volume stages
                    // invisible at exactly the peaks they exist to boost. The
                    // signal may exceed 1; downstream brightness is
                    // base + sig * boost, which is meant to push into HDR bloom.
                    sig = max(sig, 0.0);
                }
                half3 finalCol = s.baseColor;
                // hue phase uses the clamped signal so overdriven audio does not
                // spin the hue wheel past a full rotation
                if (s.hueOn > 0.5) finalCol = hueShift(finalCol, (alAvail ? saturate(sig) : _Time.y * 0.5) * 6.28318);
                if (s.mirrorOn > 0.5) {
                    half3 bgAccum = 0;
                    float denom = max(s.layers - 1.0, 1.0);
                    float rad = radians(s.rotationDeg);
                    float rotS = sin(rad), rotC = cos(rad);
                    float2 finalScale = s.scaleLock > 0.5 ? float2(s.bgScale.x, s.bgScale.x) : s.bgScale.xy;
                    float2 safeScale = max(finalScale, 0.001);
                    if (s.triplanar > 0.5) {
                        float3 blend = abs(N); blend /= dot(blend, 1.0);
                        float3 safeView = sign(viewDir) * max(abs(viewDir), 0.001);
                        float2 uvX = wPos.zy / safeScale; float2 uvY = wPos.xz / safeScale; float2 uvZ = wPos.xy / safeScale;
                        [loop]
                        for (int lx = 0; lx < 10; lx++) {
                            if (lx >= s.layers) break;
                            float cd = (s.parallax * 0.002) + (lx * (s.layerDist * 0.002));
                            float2 pX = uvX + (safeView.zy / safeView.x) * cd + _Time.y * s.pan;
                            float2 pY = uvY + (safeView.xz / safeView.y) * cd + _Time.y * s.pan;
                            float2 pZ = uvZ + (safeView.xy / safeView.z) * cd + _Time.y * s.pan;
                            half3 cX = bgTex.SampleLevel(sampler_MainTex, pX, 0).rgb;
                            half3 cY = bgTex.SampleLevel(sampler_MainTex, pY, 0).rgb;
                            half3 cZ = bgTex.SampleLevel(sampler_MainTex, pZ, 0).rgb;
                            bgAccum += (cX * blend.x + cY * blend.y + cZ * blend.z) * s.bgColor * lerp(s.nearBright, s.farBright, lx / denom);
                        }
                    } else {
                        float2 bgUV = uv - s.projCenter;
                        bgUV = float2(bgUV.x * rotC - bgUV.y * rotS, bgUV.x * rotS + bgUV.y * rotC);
                        [loop]
                        for (int ly = 0; ly < 10; ly++) {
                            if (ly >= s.layers) break;
                            float cd = (s.parallax * 0.002) + (ly * (s.layerDist * 0.002));
                            float2 rawUV = (bgUV / safeScale) + float2(0.5, 0.5);
                            rawUV -= (vT / (dot(viewDir, N) + 0.42)) * cd;
                            rawUV += _Time.y * s.pan;
                            float bounds = 1.0;
                            if (s.tileX < 0.5) bounds *= step(0.0, rawUV.x) * step(rawUV.x, 1.0);
                            if (s.tileY < 0.5) bounds *= step(0.0, rawUV.y) * step(rawUV.y, 1.0);
                            float fX = s.tileX > 0.5 ? frac(rawUV.x) : rawUV.x;
                            float fY = s.tileY > 0.5 ? frac(rawUV.y) : rawUV.y;
                            bgAccum += bgTex.SampleLevel(sampler_MainTex, float2(fX, fY), 0).rgb * s.bgColor * lerp(s.nearBright, s.farBright, ly / denom) * bounds;
                        }
                    }
                    finalCol = bgAccum;
                }
                float fres = pow(saturate(1.0 - saturate(dot(N, viewDir))), s.edgePower);
                float bright = (s.baseAmt + sig * s.alBoost) + fres * s.edgeStrength;
                if (s.lightBased > 0.5) {
                    float ll = saturate((saturate(litFactor) - s.minLight) / max(s.maxLight - s.minLight, 0.001));
                    bright *= lerp(s.minEmiss, s.maxEmiss, ll);
                }
                if (s.blinkOn > 0.5) {
                    bright *= lerp(s.blinkMin, 1.0, sin(_Time.y * s.blinkSpeed) * 0.5 + 0.5);
                }
                if (s.scanOn > 0.5) {
                    // axis the band travels along: vertical -> uv.y, horizontal -> uv.x
                    float axis = (s.scanDir < 0.5) ? uv.y : uv.x;
                    // retro pixelation: snap the axis to a block grid so the band reads chunky
                    if (s.scanPixels >= 1.0) axis = (floor(axis * s.scanPixels) + 0.5) / s.scanPixels;
                    float tt = _Time.y * s.scanSpeed;
                    // Loop = saw 0..1 wrap; Ping-Pong = triangle 0..1..0 (scanner bounce)
                    float pos = (s.scanMode > 0.5) ? abs(frac(tt * 0.5) * 2.0 - 1.0) : frac(tt);
                    float d = abs(axis - pos);
                    float band = 1.0 - smoothstep(s.scanWidth * 0.5, s.scanWidth * 0.5 + s.scanSoft + 1e-4, d);
                    // glitch: punch random pixels out of the band, refreshed ~8x/sec
                    if (s.scanGlitch > 0.001) {
                        float gpx = (s.scanPixels >= 1.0) ? s.scanPixels : 64.0;
                        float other = (s.scanDir < 0.5) ? uv.x : uv.y;
                        float2 cell = floor(float2(other, axis) * gpx);
                        band *= step(s.scanGlitch, hash2(cell + floor(tt * 8.0)));
                    }
                    bright *= lerp(s.scanFloor, 1.0, band);
                }
                return finalCol * bright * s.intensity * maskVal * proxAlpha;
            }
        ENDCG
//ifex _RefractEnable==0
        GrabPass { "_ZetGrabTex" }
//endex
        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            ColorMask [_ColorMask]
            Offset [_OffsetFactor], [_OffsetUnits]
            AlphaToMask [_AlphaToMask]
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hull
            #pragma domain dom
            #pragma geometry geom
            #pragma fragment fragBase
            #pragma target 5.0
            #pragma shader_feature_local _ ZET_VRSLGI
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma shader_feature_local _ LTCGI
            #pragma shader_feature_local _ ZET_LIGHT_VOLUMES
            #pragma shader_feature_local _ ZET_MC1
            #pragma shader_feature_local _ ZET_MC2
            #pragma shader_feature_local _ ZET_MC3
            #pragma shader_feature_local _ ZET_MC4
            #pragma shader_feature_local _ ZET_EM1
            #pragma shader_feature_local _ ZET_EM2
            #pragma shader_feature_local _ ZET_EM3
            #pragma shader_feature_local _ ZET_DEC1
            #pragma shader_feature_local _ ZET_DEC2
            #pragma shader_feature_local _ ZET_DEC3
                // Per-slot textures live INSIDE the pass, not in CGINCLUDE: Thry's
                // optimizer injects its baked keyword defines inside each Pass
                // block, so anything keyword-guarded in CGINCLUDE is evaluated
                // with the keyword UNDEFINED at lock - that is what silently ate
                // these declarations (and the LTCGI / LV includes before them).
                #if defined(ZET_MC1)
                    Texture2D _Matcap1Tex; Texture2D _Matcap1Mask;
                #endif
                #if defined(ZET_MC2)
                    Texture2D _Matcap2Tex; Texture2D _Matcap2Mask;
                #endif
                #if defined(ZET_MC3)
                    Texture2D _Matcap3Tex; Texture2D _Matcap3Mask;
                #endif
                #if defined(ZET_MC4)
                    Texture2D _Matcap4Tex; Texture2D _Matcap4Mask;
                #endif
                #if defined(ZET_EM1)
                    Texture2D _Em1Mask; Texture2D _Em1PathTex;
                #endif
                #if defined(ZET_EM2)
                    Texture2D _Em2Mask; Texture2D _Em2PathTex;
                #endif
                #if defined(ZET_EM3)
                    Texture2D _Em3Mask; Texture2D _Em3PathTex;
                #endif
                #if defined(ZET_DEC1)
                    Texture2D _Decal1Tex;
                #endif
                #if defined(ZET_DEC2)
                    Texture2D _Decal2Tex;
                #endif
                #if defined(ZET_DEC3)
                    Texture2D _Decal3Tex;
                #endif
            struct appdata {
                float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 uv : TEXCOORD0; float2 uv1 : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2g {
                float4 objPos : TEXCOORD1; float3 normal : NORMAL; float4 tangent : TANGENT; float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct g2f {
                float4 pos : SV_POSITION; 
                float2 uv : TEXCOORD0; 
                float4 fx : TEXCOORD1;   
                float3 wNrm : TEXCOORD2; 
                UNITY_FOG_COORDS(3) 
                float3 wPos : TEXCOORD4; 
                float3 bary : TEXCOORD5; 
                float4 wTan : TEXCOORD6; 
                SHADOW_COORDS(7)
                #ifdef VERTEXLIGHT_ON
                float3 vLights : TEXCOORD8;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };
            v2g vert(appdata v) {
                v2g o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                if (ZetUVTileDiscarded(v.uv, v.uv1) > 0.5) v.vertex = asfloat(0x7FC00000).xxxx;   // NaN culls the triangle
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                float3 zp = v.vertex.xyz;
                float3 zn = v.normal;
                float3 zt = v.tangent.xyz;
                ZetApplyVertexAL(zp, zn, zt, v.uv, o.uv);
                ZetApplyPlasmaDisplace(zp, zn);
                o.objPos = float4(zp, v.vertex.w);
                o.normal = zn;
                o.tangent = float4(zt, v.tangent.w);
                return o;
            }
            struct TessFactors { float edge[3] : SV_TessFactor; float inside : SV_InsideTessFactor; };
            TessFactors patchConstant(InputPatch<v2g, 3> patch) {
                if (_BreakEnable < 0.5) {   // v64: skip the 3 mask samples when break is off
                    TessFactors o1; o1.edge[0] = 1.0; o1.edge[1] = 1.0; o1.edge[2] = 1.0; o1.inside = 1.0; return o1;
                }
                float f = 1.0;
                float mask = max(max(_MaskTex.SampleLevel(sampler_LinearClamp, patch[0].uv, 0).r, _MaskTex.SampleLevel(sampler_LinearClamp, patch[1].uv, 0).r), _MaskTex.SampleLevel(sampler_LinearClamp, patch[2].uv, 0).r);
                float3 centerPos = (patch[0].objPos.xyz + patch[1].objPos.xyz + patch[2].objPos.xyz) / 3.0;
                float3 worldPos = mul(unity_ObjectToWorld, float4(centerPos, 1.0)).xyz;
                float distFactor = saturate((_TessFar - distance(worldPos, _WorldSpaceCameraPos)) / max(_TessFar - _TessNear, 0.001));
                f = (_BreakEnable > 0.5 && mask > 0.2) ? max(lerp(1.0, _Tessellation, distFactor), 1.0) : 1.0;
                TessFactors o; o.edge[0] = f; o.edge[1] = f; o.edge[2] = f; o.inside = f; return o;
            }
            [domain("tri")] [outputcontrolpoints(3)] [outputtopology("triangle_cw")] [partitioning("integer")] [patchconstantfunc("patchConstant")]
            v2g hull(InputPatch<v2g, 3> patch, uint id : SV_OutputControlPointID) { return patch[id]; }
            [domain("tri")]
            v2g dom(TessFactors f, OutputPatch<v2g, 3> patch, float3 b : SV_DomainLocation) {
                v2g o;
                UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
                o.objPos  = patch[0].objPos * b.x + patch[1].objPos * b.y + patch[2].objPos * b.z;
                o.normal  = normalize(patch[0].normal * b.x + patch[1].normal * b.y + patch[2].normal * b.z);
                o.tangent = float4(normalize(patch[0].tangent.xyz * b.x + patch[1].tangent.xyz * b.y + patch[2].tangent.xyz * b.z), patch[0].tangent.w);
                o.uv      = patch[0].uv * b.x + patch[1].uv * b.y + patch[2].uv * b.z; return o;
            }
            [maxvertexcount(24)]
            void geom(triangle v2g i[3], inout TriangleStream<g2f> stream) {
                UNITY_SETUP_INSTANCE_ID(i[0]);
                float3 center   = (i[0].objPos.xyz + i[1].objPos.xyz + i[2].objPos.xyz) / 3.0;
                float3 faceNrm  = normalize(i[0].normal + i[1].normal + i[2].normal);
                float2 uvCenter = (i[0].uv + i[1].uv + i[2].uv) / 3.0;
                bool alAvail = AudioLinkIsAvailable();
                float rnd = 0, t = 0, heat = 0;
                if (_BreakEnable > 0.5) {
                    float mask = 0;
                    if (_BreakMode < 0.5) {
                        float2 cell = floor(uvCenter * _GridSize) / _GridSize;
                        mask  = _MaskTex.SampleLevel(sampler_LinearClamp, cell, 0).r;
                        rnd = hash2(cell);
                        float audio = alAvail ? ALEnv((uint)_Band) : 0.0;
                        float drive = saturate(audio * mask - _Threshold) / max(1.0 - _Threshold, 0.0001);
                        t = smoothstep(0.0, 1.0, saturate((drive - rnd) * 2.0));
                        heat = smoothstep(rnd * 0.15, max(rnd, 0.02), drive);
                    } else {
                        mask = _MaskTex.SampleLevel(sampler_LinearClamp, uvCenter, 0).r;
                        rnd = hash2(uvCenter * 57.31);
                        float heightW = mul(unity_ObjectToWorld, float4(center, 1)).y - unity_ObjectToWorld._m13;
                        float coord = saturate((heightW - _WaveBottom) / max(_WaveTop - _WaveBottom, 0.001));
                        float audio = alAvail ? AudioLinkLerp(ALPASS_AUDIOLINK + float2(coord * 127.0, (uint)_Band)).r : 0.0;
                        float level = saturate((audio * mask - _Threshold) / max(1.0 - _Threshold, 0.0001));
                        float startE = 0.15 + rnd * 0.35;
                        t = smoothstep(startE, 0.85 + rnd * 0.15, level);
                        heat = smoothstep(startE * 0.15, startE, level);
                    }
                    if (_BreakDrive > 0.5) {
                        float ph = _Time.y * _FloatSpeed + rnd * 6.2831 * _FloatStagger;
                        float floatT = smoothstep(0.0, 1.0, sin(ph) * 0.5 + 0.5) * _FloatReach;
                        float nudge = (alAvail && _FloatAudio > 0.001) ? ALEnv((uint)_Band) * _FloatAudio : 0.0;
                        t = saturate((floatT + nudge) * mask);
                        heat = smoothstep(0.0, 0.6, t);
                    }
                }
                float glitchAmt = 0, tick = 0;
                if (_GlitchEnable > 0.5) {
                    float gMask = _GlitchMask.SampleLevel(sampler_LinearClamp, uvCenter, 0).r;
                    float ga = alAvail ? ALEnv((uint)_GlitchBand) : 0.0;
                    glitchAmt = ga * step(_GlitchThreshold, ga) * gMask;
                    tick = floor(_Time.y * 15.0);
                }
                // Core Backfaces
                float bGap = _BreakCoreGlow; if (_BreakManual < 0.5) { float _bf = _BreakFade; ApplyBreakStyle(_BreakStyle, bGap, _bf); }
                if (t > 0.001 && bGap > 0.001) {
                    [unroll] for (int k = 0; k < 3; k++) {
                        g2f o; UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                        float3 p = i[k].objPos.xyz - i[k].normal * 0.005;
                        o.pos = UnityObjectToClipPos(float4(p, 1));
                        o.uv = i[k].uv; o.fx = float4(-1.0, heat, 0, 0.0);
                        o.wNrm = UnityObjectToWorldNormal(i[k].normal);
                        o.wTan = float4(UnityObjectToWorldDir(i[k].tangent.xyz), i[k].tangent.w);
                        o.wPos = mul(unity_ObjectToWorld, float4(p, 1)).xyz;
                    #ifdef VERTEXLIGHT_ON
                        // Demoted (non-important / over-budget) point lights land in
                        // the unity_4LightPos arrays instead of ForwardAdd. Without
                        // this, an avatar goes flat the moment the camera's pixel
                        // light ranking drops a light - while mirrors, ranking their
                        // own smaller set, keep it. Per-vertex by design: cheap.
                        o.vLights = Shade4PointLights(
                            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                            unity_4LightAtten0, o.wPos, o.wNrm);
                    #endif
                        o.bary = (k == 0) ? float3(1,0,0) : (k == 1) ? float3(0,1,0) : float3(0,0,1);
                        DummyAppdata v; v.vertex = float4(p, 1);
                        ZET_TRANSFER_SHADOW(o); UNITY_TRANSFER_FOG(o, o.pos); stream.Append(o);
                    }
                    stream.RestartStrip();
                }
                float phase = _Time.y * 3.0 + rnd * 6.2831;
                float3 upO = normalize(mul((float3x3)unity_WorldToObject, float3(0, 1, 0)));
                float3 driftO = normalize(mul((float3x3)unity_WorldToObject, float3(sin(phase), 0, cos(phase))));
                float3 offset = upO * (t * _RiseHeight * (0.5 + rnd)) + faceNrm * (t * _Spread) + driftO * (_Jitter * t);
                float3 axis = normalize(float3(hash2(uvCenter + 1.7), hash2(uvCenter + 3.9), hash2(uvCenter + 7.3)) - 0.5 + 1e-4);
                float ang = (rnd * 2.0 - 1.0) * _Tumble * t;
                float gap = _EdgeGap * smoothstep(0.0, 0.15, t);
                // Main Mesh
                [unroll] for (int j = 0; j < 3; j++) {
                    g2f o; UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    float3 rel = lerp(i[j].objPos.xyz, center, saturate(t * _Shrink + gap)) - center;
                    rel = rotAround(rel, axis, ang);
                    float3 p = center + rel + offset;
                    if (glitchAmt > 0.001) {
                        float3 wP = mul(unity_ObjectToWorld, float4(p, 1)).xyz;
                        float3 voxel = floor(wP * _GlitchSlices);
                        float2 seed = float2(voxel.x * 3.1 + voxel.z * 7.3, voxel.y * 5.1 + tick);
                        float active = step(0.7, hash2(seed));
                        float3 glitchDir = normalize(float3(hash2(seed + 1.2)*2-1, hash2(seed + 3.4)*2-1, hash2(seed + 5.6)*2-1));
                        p += glitchDir * _GlitchIntensity * glitchAmt * active;
                    }
                    o.pos = UnityObjectToClipPos(float4(p, 1));
                    o.uv = i[j].uv; o.fx = float4(t, heat, glitchAmt, 0.0);
                    o.wNrm = UnityObjectToWorldNormal(rotAround(i[j].normal, axis, ang));
                    o.wTan = float4(UnityObjectToWorldDir(rotAround(i[j].tangent.xyz, axis, ang)), i[j].tangent.w);
                    o.wPos = mul(unity_ObjectToWorld, float4(p, 1)).xyz;
                    #ifdef VERTEXLIGHT_ON
                        // Demoted (non-important / over-budget) point lights land in
                        // the unity_4LightPos arrays instead of ForwardAdd. Without
                        // this, an avatar goes flat the moment the camera's pixel
                        // light ranking drops a light - while mirrors, ranking their
                        // own smaller set, keep it. Per-vertex by design: cheap.
                        o.vLights = Shade4PointLights(
                            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                            unity_4LightAtten0, o.wPos, o.wNrm);
                    #endif
                    o.bary = (j == 0) ? float3(1,0,0) : (j == 1) ? float3(0,1,0) : float3(0,0,1);
                    DummyAppdata v; v.vertex = float4(p, 1);
                    ZET_TRANSFER_SHADOW(o); UNITY_TRANSFER_FOG(o, o.pos); stream.Append(o);
                }
                stream.RestartStrip();
                // Hologram Speaker Rings
                if (_SpeakerEnable > 0.5 && _SpeakerState > 0.5) {
                    float spkCenterMask = _SpeakerMask.SampleLevel(sampler_LinearClamp, uvCenter, 0).r;
                    if (spkCenterMask > 0.01) {
                        float ringsF = clamp(round(_SpeakerRings), 1.0, 6.0);
                        // Ring list, filled by one of the two emitters below and
                        // drawn by the shared emit loop at the bottom.
                        float ringPhase[6] = {0,0,0,0,0,0};
                        float ringAud[6]   = {0,0,0,0,0,0};
                        float ringFlash[6] = {0,0,0,0,0,0};
                        int emitN = 0;
                        if (_SpeakerState > 1.5) {
                            // BEAT-EMITTED RINGS. A stateless shader cannot latch
                            // "a beat happened" - but AudioLink's band history IS
                            // that state: 128 columns, one per rendered frame,
                            // column 0 = now. Every frame we re-derive the same
                            // beat list from it with a Schmitt trigger walking
                            // oldest -> newest: fire when the band rises past
                            // Threshold, re-arm once it dips under 60% of it. One
                            // hit = one ring, even through sustained bass. Each
                            // ring is pinned to its own beat: its age is the
                            // onset's column, which scrolls one column per frame,
                            // so ignition is same-frame at radius zero and travel
                            // is smooth. Nothing is quantized to a ring clock and
                            // no beat can be missed while it's in the window.
                            // Tuning points: 0.6 = re-arm ratio; 90.0 = assumed
                            // history columns/second, so ring speed tracks the
                            // world framerate; the ~1.4s history window caps ring
                            // lifetime - below Speed ~0.75 a ring can scroll out
                            // of the window before finishing its travel.
                            if (alAvail) {
                                float rearm = _SpeakerThreshold * 0.6;
                                int cStart = (int)min(126.0, 90.0 / max(_SpeakerSpeed, 0.05));
                                float onsetCol[6] = {0,0,0,0,0,0};
                                float onsetLvl[6] = {0,0,0,0,0,0};
                                uint found = 0;
                                bool armed = AudioLinkData(ALPASS_AUDIOLINK + uint2(cStart, (uint)_SpeakerBand)).r < rearm;
                                [loop]
                                for (int c = cStart - 1; c >= 0; c--) {
                                    float lvl = AudioLinkData(ALPASS_AUDIOLINK + uint2(c, (uint)_SpeakerBand)).r;
                                    if (armed) {
                                        if (lvl >= _SpeakerThreshold) {
                                            onsetCol[found % 6u] = (float)c;
                                            onsetLvl[found % 6u] = lvl;
                                            found++; armed = false;
                                        }
                                    } else {
                                        // ring brightness = the hit's peak, not the crossing value
                                        onsetLvl[(found + 5u) % 6u] = max(onsetLvl[(found + 5u) % 6u], lvl);
                                        if (lvl < rearm) armed = true;
                                    }
                                }
                                uint keepN = min(found, (uint)ringsF);
                                [loop]
                                for (uint k = 0; k < 6u; k++) {
                                    if (k >= keepN) break;
                                    uint slot = (found + 5u - k) % 6u;   // newest beats get the ring budget
                                    ringPhase[emitN] = saturate((onsetCol[slot] / 90.0) * _SpeakerSpeed);
                                    ringAud[emitN]   = onsetLvl[slot];
                                    ringFlash[emitN] = 1.0 + smoothstep(0.25, 0.0, ringPhase[emitN]);   // ~2x bloom at birth, settled by a quarter of travel
                                    emitN++;
                                }
                            }
                        } else {
                            // ALWAYS ON: continuous clock rings, as before.
                            [unroll]
                            for (int r = 0; r < 6; r++) {
                                if (r >= (int)ringsF) break;
                                ringPhase[emitN] = frac(_Time.y * _SpeakerSpeed + (float)r / ringsF);
                                ringAud[emitN]   = 1.0;
                                ringFlash[emitN] = 1.0;
                                emitN++;
                            }
                        }
                        [loop]
                        for (int rr = 0; rr < 6; rr++) {
                            if (rr >= emitN) break;
                            float rPhase = ringPhase[rr];
                            [unroll]
                            for (int idx = 0; idx < 3; idx++) {
                                g2f o; UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                                float3 p = i[idx].objPos.xyz; float3 n = i[idx].normal;
                                
                                // Shells always travel on rPhase; audio drives brightness
                                // only. Scaling displacement by audio makes the shells
                                // snap each frame (the strobing bug, fixed twice now) -
                                // do not re-couple these.
                                p += n * rPhase * _SpeakerIntensity; 
                                p += n * (rPhase * rPhase * _SpeakerExpansion); 
                                o.pos = UnityObjectToClipPos(float4(p, 1)); 
                                o.uv = i[idx].uv; 
                                // fx: y = birth flash, z = beat strength, w = phase + 1
                                o.fx = float4(0, ringFlash[rr], ringAud[rr], rPhase + 1.0); 
                                
                                o.wNrm = UnityObjectToWorldNormal(n); 
                                o.wTan = float4(UnityObjectToWorldDir(i[idx].tangent.xyz), i[idx].tangent.w);
                                o.wPos = mul(unity_ObjectToWorld, float4(p, 1)).xyz;
                    #ifdef VERTEXLIGHT_ON
                        // Demoted (non-important / over-budget) point lights land in
                        // the unity_4LightPos arrays instead of ForwardAdd. Without
                        // this, an avatar goes flat the moment the camera's pixel
                        // light ranking drops a light - while mirrors, ranking their
                        // own smaller set, keep it. Per-vertex by design: cheap.
                        o.vLights = Shade4PointLights(
                            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                            unity_4LightAtten0, o.wPos, o.wNrm);
                    #endif
                                o.bary = (idx == 0) ? float3(1,0,0) : (idx == 1) ? float3(0,1,0) : float3(0,0,1);
                                DummyAppdata v; v.vertex = float4(p, 1);
                                ZET_TRANSFER_SHADOW(o); UNITY_TRANSFER_FOG(o, o.pos); stream.Append(o);
                            }
                            stream.RestartStrip();
                        }
                    }
                }
            }
            #if defined(ZET_VRSLGI)
            // Accumulates VRSL GI point and spot lights. Diffuse and specular
            // are returned separately: diffuse is multiplied by albedo downstream
            // with every other diffuse term, specular is added after, because
            // specCol already carries the F0 tint.
            void ZetVRSLGI(float3 wPos, half3 n, half3 viewDir, half smoothness,
                           out half3 vrslDiffuse, out half3 vrslSpec)
            {
                vrslDiffuse = 0;
                vrslSpec = 0;

                int lightCount = (int) _Udon_VRSL_GI_LightTexture.Load(int3(0, 2, 0)).r;
                lightCount = clamp(lightCount, 0, ZET_VRSL_MAX_LIGHTS);

                half specPower = exp2(smoothness * 9.0 + 1.0);

                [loop]
                for (int x = 0; x < lightCount; x++)
                {
                    float4 rawColor = _Udon_VRSL_GI_LightTexture.Load(int3(x, 0, 0));
                    float4 lightPos = _Udon_VRSL_GI_LightTexture.Load(int3(x, 1, 0));

                    // The 0.5 and the range scaling by .a are VRSL's own
                    // normalisation - matching them is what keeps brightness in
                    // step with the world's fixtures.
                    half3 lightColor = rawColor.rgb * (0.5 * rawColor.a);

                    float3 toLight = lightPos.xyz - wPos;
                    float range = length(toLight) * rawColor.a;
                    half3 lightDir = normalize(toLight);

                    half atten = saturate(dot(lightDir, n));
                    if (_VRSLGIToon > 0.5)
                    {
                        // Hard terminator, to match a toon base rather than
                        // dropping a smooth lambert gradient onto flat shading.
                        atten = smoothstep(0.0, 0.01, lerp(0.0025, 1.0, atten));
                    }

                    float falloff = 1.0 / max(range * range, 0.0001);

                    half spec = 0;
                    if (_VRSLGISpecular > 0.5)
                    {
                        half3 H = normalize(lightDir + viewDir);
                        spec = pow(saturate(dot(n, H)), specPower) * _VRSLGISpecularMult;
                        spec = min(spec, _VRSLGISpecularClamp);
                    }

                    // Spot cone. lightPos.w above 180 flags a spotlight; row 3
                    // holds the direction, with the cone angle and the edge blend
                    // packed into .w as integer and fractional parts.
                    if (lightPos.w > 180.0)
                    {
                        float4 rawDir = _Udon_VRSL_GI_LightTexture.Load(int3(x, 3, 0));
                        float angle = (floor(rawDir.w - 1.0) / 255.0) * 180.0;
                        float blend = frac(rawDir.w);

                        float theta = dot(lightDir, normalize(-rawDir.xyz));
                        float cone = saturate(theta - cos(radians(angle)));

                        atten = lerp(atten, atten * cone, blend);
                        spec  = lerp(spec,  spec  * cone, blend);
                    }

                    vrslDiffuse += falloff * lightColor * atten;
                    vrslSpec    += falloff * lightColor * spec;
                }

                vrslDiffuse *= _VRSLGIStrength;
                vrslSpec    *= _VRSLGIStrength;
            }
            #endif

            fixed4 fragBase(g2f i, fixed facing : VFACE) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                bool alAvail = AudioLinkIsAvailable();
                if (i.fx.w > 0.5) { 
                    float rPhase = i.fx.w - 1.0;
            
                    // v64: single mip-biased tap replaces the 9-tap box blur.
                    // Needs mipmaps enabled on the speaker mask texture.
                    float spkMask = _SpeakerMask.SampleLevel(sampler_LinearClamp, i.uv, _SpeakerMaskBlur * 4.0).r;
                    clip(spkMask - 0.003);
                    float radial = (_SpeakerDirection < 0.5) ? (1.0 - spkMask) : spkMask;
                    float distToRing = abs(radial - rPhase);
                    float ringWeight = 1.0 - smoothstep(_SpeakerRingThickness, _SpeakerRingThickness + max(_SpeakerRingSoftness, 0.0005), distToRing); 
            
                    // Beat strength from geom (fx.z); fx.y carries the birth flash.
                    float spkAudio = i.fx.z;
    
                    float life = smoothstep(0.0, 0.25, rPhase) * (1.0 - smoothstep(0.65, 1.0, rPhase));
                    float alpha = ringWeight * life * spkAudio;
                    clip(alpha - 0.05);
                    half3 cc0 = half3(1,1,1), cc1 = half3(1,1,1), cc2 = half3(1,1,1), cc3 = half3(1,1,1);
                    if (alAvail) { cc0 = AudioLinkData(ALPASS_THEME_COLOR0).rgb; cc1 = AudioLinkData(ALPASS_THEME_COLOR1).rgb; cc2 = AudioLinkData(ALPASS_THEME_COLOR2).rgb; cc3 = AudioLinkData(ALPASS_THEME_COLOR3).rgb; }
                    half3 c_spk = _UseColorChord > 0.5 ? (_CC_Speaker < 0.5 ? cc0 : _CC_Speaker < 1.5 ? cc1 : _CC_Speaker < 2.5 ? cc2 : cc3) : _SpeakerColor.rgb;
                    if (_SpeakerHueShift > 0.5) c_spk = hueShift(c_spk, (alAvail ? spkAudio : _Time.y * 0.5) * 6.28318);
                    c_spk *= max(i.fx.y, 1.0);   // birth flash: newborn rings bloom ~2x, settling over the first quarter of travel
                    UNITY_APPLY_FOG(i.fogCoord, c_spk);
                    return fixed4(c_spk, saturate(alpha * 1.5)); 
                }
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
                float3 N = normalize(i.wNrm); float3 T = normalize(i.wTan.xyz); float3 B = cross(N, T) * (i.wTan.w * unity_WorldTransformParams.w);
                float2 vT = float2(dot(viewDir, T), dot(viewDir, B));
                if (_ParallaxEnable > 0.5) {
                    float pMask = _ParallaxMask.Sample(sampler_MainTex, i.uv).r;
                    if (pMask > 0.001) {
                        float2 pdir = vT / max(dot(viewDir, N), 0.1);
                        float2 pUV = ParallaxOcclusion(_HeightMap, sampler_MainTex, i.uv, pdir, _ParallaxStrength, _ParallaxOffset, _ParallaxMipBias);
                        i.uv = lerp(i.uv, pUV, pMask);
                    }
                }
                half proxAlpha = 1.0; if (_ProximityFade > 0.5) proxAlpha = smoothstep(_ProxMin, _ProxMax, distance(_WorldSpaceCameraPos, i.wPos));
                half3 cc0 = half3(1,1,1), cc1 = half3(1,1,1), cc2 = half3(1,1,1), cc3 = half3(1,1,1);
                if (alAvail) { cc0 = AudioLinkData(ALPASS_THEME_COLOR0).rgb; cc1 = AudioLinkData(ALPASS_THEME_COLOR1).rgb; cc2 = AudioLinkData(ALPASS_THEME_COLOR2).rgb; cc3 = AudioLinkData(ALPASS_THEME_COLOR3).rgb; }
                half3 c_em0 = _UseColorChord > 0.5 ? (_CC_Em0 < 0.5 ? cc0 : _CC_Em0 < 1.5 ? cc1 : _CC_Em0 < 2.5 ? cc2 : cc3) : _Em0Color.rgb;
                half3 c_em1 = _UseColorChord > 0.5 ? (_CC_Em1 < 0.5 ? cc0 : _CC_Em1 < 1.5 ? cc1 : _CC_Em1 < 2.5 ? cc2 : cc3) : _Em1Color.rgb;
                half3 c_em2 = _UseColorChord > 0.5 ? (_CC_Em2 < 0.5 ? cc0 : _CC_Em2 < 1.5 ? cc1 : _CC_Em2 < 2.5 ? cc2 : cc3) : _Em2Color.rgb;
                half3 c_em3 = _UseColorChord > 0.5 ? (_CC_Em3 < 0.5 ? cc0 : _CC_Em3 < 1.5 ? cc1 : _CC_Em3 < 2.5 ? cc2 : cc3) : _Em3Color.rgb;
                half3 c_out = _UseColorChord > 0.5 ? (_CC_Outline < 0.5 ? cc0 : _CC_Outline < 1.5 ? cc1 : _CC_Outline < 2.5 ? cc2 : cc3) : _OutlineColor.rgb;
                half3 c_star = _UseColorChord > 0.5 ? (_CC_Stars < 0.5 ? cc0 : _CC_Stars < 1.5 ? cc1 : _CC_Stars < 2.5 ? cc2 : cc3) : _StarColor.rgb;
                half3 c_rim = _UseColorChord > 0.5 ? (_CC_Rim < 0.5 ? cc0 : _CC_Rim < 1.5 ? cc1 : _CC_Rim < 2.5 ? cc2 : cc3) : _RimColor.rgb;
                half3 c_break = _UseColorChord > 0.5 ? (_CC_Break < 0.5 ? cc0 : _CC_Break < 1.5 ? cc1 : _CC_Break < 2.5 ? cc2 : cc3) : _EmissionColor.rgb;
                half3 c_dissolve = _UseColorChord > 0.5 ? (_CC_Dissolve < 0.5 ? cc0 : _CC_Dissolve < 1.5 ? cc1 : _CC_Dissolve < 2.5 ? cc2 : cc3) : _DissolveColor.rgb;
                half3 burnGlow = 0;
                if (_DissolveEnable > 0.5) {
                    float dNoise = _DissolveTex.Sample(sampler_LinearRepeat, i.uv).r; 
                    float alD = alAvail ? ALEnv((uint)_DissolveBand) : 0.0;
                    float dLevel = saturate((_DissolveAmount * 0.01) + (alD * (_DissolveAL * 0.01)));
                    clip(dNoise - dLevel); 
                    float edgeW = (_DissolveWidth * 0.001) * (1.0 + alD * 2.0);
                    float isEdge = 1.0 - smoothstep(dLevel, dLevel + edgeW, dNoise);
                    half3 final_c_dissolve = c_dissolve;
                    if (_DissolveHueShift > 0.5) final_c_dissolve = hueShift(final_c_dissolve, (alAvail ? alD : _Time.y * 0.5) * 6.28318);
                    burnGlow = final_c_dissolve * isEdge; 
                }
                float bSurf = _BreakGlow, bGap = _BreakCoreGlow, bFade = _BreakFade;
                if (_BreakManual < 0.5) ApplyBreakStyle(_BreakStyle, bGap, bFade);
                if (bFade > 0.001 && i.fx.x > 0.001) {
                    float fadeN = hash2(i.uv * 97.0);
                    clip(fadeN - saturate(i.fx.x) * bFade);
                }
                if (i.fx.x < -0.5) {
                    float al_break = alAvail ? ALEnv((uint)_Band) : 0.0;
                    half3 final_c_break = c_break;
                    if (_BreakHueShift > 0.5) final_c_break = hueShift(final_c_break, (alAvail ? al_break : _Time.y * 0.5) * 6.28318);
                    float2 parallaxUV = i.uv * _CoreTiling - vT * (_CoreDepth * 0.002);
                    fixed4 core = fixed4(0,0,0,1); core.rgb += final_c_break * (_CoreTex.Sample(sampler_MainTex, parallaxUV).r + i.fx.y * _HeatGlow) * proxAlpha * bGap;
                    UNITY_APPLY_FOG(i.fogCoord, core); return core;
                }
                if (facing < 0) {
                    if (i.fx.x > 0.001) {
                        float al_break = alAvail ? ALEnv((uint)_Band) : 0.0;
                        half3 final_c_break = c_break;
                        if (_BreakHueShift > 0.5) final_c_break = hueShift(final_c_break, (alAvail ? al_break : _Time.y * 0.5) * 6.28318);
                        fixed4 inner = fixed4(0,0,0,1); inner.rgb += final_c_break * (i.fx.x * 0.5 + i.fx.y * 0.3) * proxAlpha * bGap;
                        UNITY_APPLY_FOG(i.fogCoord, inner); return inner;
                    }
                    N = -N; B = -B; vT.y = -vT.y;   // v64: flip the whole frame
                }
                fixed4 albedo = _MainTex.Sample(sampler_MainTex, i.uv);
                if (_DetailEnable > 0.5) {
                    half dMask = _DetailMask.Sample(sampler_LinearRepeat, i.uv).r;
                    if (dMask > 0.001) {
                        half3 dAlb = _DetailAlbedo.Sample(sampler_LinearRepeat, i.uv * _DetailTiling.xy + _DetailTiling.zw).rgb;
                        albedo.rgb *= lerp(half3(1, 1, 1), dAlb * 2.0, _DetailAlbedoStrength * dMask);   // 2x: mid grey is neutral
                    }
                }
                half outAlpha = 1.0;
                if (_AlphaMode > 0.5) {
                    half op = GetOpacity(albedo.a, i.uv);
                    if (_AlphaMode > 1.5) {
                        // Transparent: straight alpha blend
                        outAlpha = saturate(op);
                        clip(outAlpha - 0.001);
                    } else {
                        // Cutout: sharpen the alpha edge so MSAA alpha-to-coverage gives a crisp anti-aliased cutout
                        half aCut = saturate((op - _Cutoff) / max(fwidth(op), 1e-5) + 0.5);
                        clip(aCut - 0.001);
                        outAlpha = aCut;
                    }
                }
                if (i.fx.z > 0.001) {
                    float2 split = float2(_GlitchRGBSplit * i.fx.z, 0);
                    albedo.r = _MainTex.Sample(sampler_MainTex, i.uv + split).r; albedo.b = _MainTex.Sample(sampler_MainTex, i.uv - split).b;
                    if (_GlitchHue > 0.001) {
                        float3 voxel = floor(i.wPos * _GlitchSlices); float2 seed = float2(voxel.x * 3.1 + voxel.z * 7.3, voxel.y * 5.1 + floor(_Time.y * 15.0));
                        if (step(0.7, hash2(seed)) > 0.5) {
                            float rc = hash2(seed + 8.9); half3 neon = rc > 0.66 ? half3(0,1,1) : rc > 0.33 ? half3(0,1,0) : half3(1,0,1);
                            albedo.rgb = lerp(albedo.rgb, neon, saturate(_GlitchHue * i.fx.z));
                        }
                    }
                }
                if (_ColorAdjustEnable > 0.5) {
                    if (_BaseHueShift > 0.0 || _BaseHueShiftAL > 0.5) {
                        float hueAmt = _BaseHueShift + (alAvail ? ALEnv((uint)_BaseHueBand) * _BaseHueShiftAL : 0.0);
                        albedo.rgb = hueShift(albedo.rgb, hueAmt * 6.28318);
                    }
                    half3 gray = dot(albedo.rgb, half3(0.299, 0.587, 0.114)).xxx;
                    albedo.rgb = lerp(gray, albedo.rgb, _Saturation);
                    albedo.rgb *= _Brightness;
                    albedo.rgb = pow(max(albedo.rgb, 0), _Gamma);
                }
                half3 decalEmiss = 0;
                if (_DecalsEnable > 0.5) {
                    if (_Decal0Enable > 0.5 && _Decal0Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal0Tex, sampler_LinearClamp, float2(_Decal0PosX, _Decal0PosY), _Decal0Scale, _Decal0Rotation, _Decal0Color, _Decal0Opacity, _Decal0Blend, _Decal0Emit, float4(_Decal0FlipCols, _Decal0FlipRows, _Decal0FlipFPS, _Decal0Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #if defined(ZET_DEC1)
                    if (_Decal1Enable > 0.5 && _Decal1Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal1Tex, sampler_LinearClamp, float2(_Decal1PosX, _Decal1PosY), _Decal1Scale, _Decal1Rotation, _Decal1Color, _Decal1Opacity, _Decal1Blend, _Decal1Emit, float4(_Decal1FlipCols, _Decal1FlipRows, _Decal1FlipFPS, _Decal1Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #endif
                    #if defined(ZET_DEC2)
                    if (_Decal2Enable > 0.5 && _Decal2Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal2Tex, sampler_LinearClamp, float2(_Decal2PosX, _Decal2PosY), _Decal2Scale, _Decal2Rotation, _Decal2Color, _Decal2Opacity, _Decal2Blend, _Decal2Emit, float4(_Decal2FlipCols, _Decal2FlipRows, _Decal2FlipFPS, _Decal2Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #endif
                    #if defined(ZET_DEC3)
                    if (_Decal3Enable > 0.5 && _Decal3Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal3Tex, sampler_LinearClamp, float2(_Decal3PosX, _Decal3PosY), _Decal3Scale, _Decal3Rotation, _Decal3Color, _Decal3Opacity, _Decal3Blend, _Decal3Emit, float4(_Decal3FlipCols, _Decal3FlipRows, _Decal3FlipFPS, _Decal3Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #endif
                }
                half4 packed = SamplePackedMap(i.uv);
                half metRaw = packed.r;
                // Unity MetallicSmoothness maps store smoothness in Alpha (no AO channel);
                // ZFS packed maps store it in Blue. See _PackMode.
                half smoSrc = (_PackMode > 0.5) ? packed.a : packed.b;
                half smoRaw = (_InvSmooth > 0.5) ? (1.0 - smoSrc) : smoSrc;
                half metallic   = lerp(_MetallicMin, _Metallic, metRaw);   // floor 0 makes this metRaw * _Metallic
                half smoothness = lerp(_SmoothnessMin, _Smoothness, smoRaw);
                
                float3 nTS = UnpackScaleNormal(_BumpMap.Sample(sampler_MainTex, i.uv), _BumpScale);
                if (_DetailEnable > 0.5) {
                    half dMaskN = _DetailMask.Sample(sampler_LinearRepeat, i.uv).r;
                    float3 dTS = UnpackScaleNormal(_DetailNormal.Sample(sampler_LinearRepeat, i.uv * _DetailTiling.xy + _DetailTiling.zw), _DetailNormalStrength * dMaskN);
                    nTS = normalize(float3(nTS.xy + dTS.xy, nTS.z * dTS.z));   // whiteout blend
                }
                if (_HeightToNormalEnable > 0.5) {
                    float2 ts = float2(0.002, 0.002);
                    float hC = _HeightMap.Sample(sampler_MainTex, i.uv).r;
                    float hR = _HeightMap.Sample(sampler_MainTex, i.uv + float2(ts.x, 0)).r;
                    float hU = _HeightMap.Sample(sampler_MainTex, i.uv + float2(0, ts.y)).r;
                    float3 heightNorm = normalize(float3((hC - hR) * _HeightStrength, (hC - hU) * _HeightStrength, 1.0));
                    nTS = normalize(float3(nTS.xy + heightNorm.xy, nTS.z));
                }
                float3 n = normalize(T * nTS.x + B * nTS.y + N * nTS.z);
                if (_MatcapEnable > 0.5 || _Matcap1Enable > 0.5 || _Matcap2Enable > 0.5 || _Matcap3Enable > 0.5 || _Matcap4Enable > 0.5) {
                    float3 viewNorm = normalize(mul((float3x3)UNITY_MATRIX_V, n)); 
                    float2 mcUV = saturate(viewNorm.xy * 0.5 + 0.5) * 0.998 + 0.001;
                    
                    if (_MatcapEnable > 0.5) {
                        float mcMask = _MatcapMask.Sample(sampler_LinearClamp, i.uv).r;
                        if (mcMask > 0.01) {
                            half3 mcCol = _MatcapTex.Sample(sampler_MainTex, mcUV).rgb; float str = (_MatcapStrength * 0.01) * mcMask;
                            if (_MatcapMode < 0.5) albedo.rgb += mcCol * str; else if (_MatcapMode < 1.5) albedo.rgb *= lerp(half3(1,1,1), mcCol, str); else albedo.rgb = 1.0 - (1.0 - albedo.rgb) * (1.0 - mcCol * str); 
                        }
                    }
                    #if defined(ZET_MC1)
                    if (_Matcap1Enable > 0.5) {
                        float mcMask = _Matcap1Mask.Sample(sampler_LinearClamp, i.uv).r;
                        if (mcMask > 0.01) {
                            half3 mcCol = _Matcap1Tex.Sample(sampler_MainTex, mcUV).rgb; float str = (_Matcap1Strength * 0.01) * mcMask;
                            if (_Matcap1Mode < 0.5) albedo.rgb += mcCol * str; else if (_Matcap1Mode < 1.5) albedo.rgb *= lerp(half3(1,1,1), mcCol, str); else albedo.rgb = 1.0 - (1.0 - albedo.rgb) * (1.0 - mcCol * str); 
                        }
                    }
                    #endif
                    #if defined(ZET_MC2)
                    if (_Matcap2Enable > 0.5) {
                        float mcMask = _Matcap2Mask.Sample(sampler_LinearClamp, i.uv).r;
                        if (mcMask > 0.01) {
                            half3 mcCol = _Matcap2Tex.Sample(sampler_MainTex, mcUV).rgb; float str = (_Matcap2Strength * 0.01) * mcMask;
                            if (_Matcap2Mode < 0.5) albedo.rgb += mcCol * str; else if (_Matcap2Mode < 1.5) albedo.rgb *= lerp(half3(1,1,1), mcCol, str); else albedo.rgb = 1.0 - (1.0 - albedo.rgb) * (1.0 - mcCol * str); 
                        }
                    }
                    #endif
                    #if defined(ZET_MC3)
                    if (_Matcap3Enable > 0.5) {
                        float mcMask = _Matcap3Mask.Sample(sampler_LinearClamp, i.uv).r;
                        if (mcMask > 0.01) {
                            half3 mcCol = _Matcap3Tex.Sample(sampler_MainTex, mcUV).rgb; float str = (_Matcap3Strength * 0.01) * mcMask;
                            if (_Matcap3Mode < 0.5) albedo.rgb += mcCol * str; else if (_Matcap3Mode < 1.5) albedo.rgb *= lerp(half3(1,1,1), mcCol, str); else albedo.rgb = 1.0 - (1.0 - albedo.rgb) * (1.0 - mcCol * str); 
                        }
                    }
                    #endif
                    #if defined(ZET_MC4)
                    if (_Matcap4Enable > 0.5) {
                        float mcMask = _Matcap4Mask.Sample(sampler_LinearClamp, i.uv).r;
                        if (mcMask > 0.01) {
                            half3 mcCol = _Matcap4Tex.Sample(sampler_MainTex, mcUV).rgb; float str = (_Matcap4Strength * 0.01) * mcMask;
                            if (_Matcap4Mode < 0.5) albedo.rgb += mcCol * str; else if (_Matcap4Mode < 1.5) albedo.rgb *= lerp(half3(1,1,1), mcCol, str); else albedo.rgb = 1.0 - (1.0 - albedo.rgb) * (1.0 - mcCol * str); 
                        }
                    }
                    #endif
                }
                half3 specCol = lerp(half3(0.04, 0.04, 0.04), albedo.rgb, metallic);
                if (_IridEnable > 0.5) {
                    float iridMask = _IridMask.Sample(sampler_LinearClamp, i.uv).r;
                    if (iridMask > 0.001) {
                        float alIrid = alAvail ? ALEnv((uint)_IridBand) : 0.0;
                        float ndv = saturate(dot(n, viewDir));
                        float phase = frac((1.0 - ndv) * (_IridThickness * 0.1) + _Time.y * (_IridSpeed * 0.1) + (alIrid * (_IridAL * 0.05)));
                        
                        float p = phase * 3.0;
                        half3 iridColor = lerp(_IridColor1.rgb, _IridColor2.rgb, saturate(p));
                        iridColor = lerp(iridColor, _IridColor3.rgb, saturate(p - 1.0));
                        iridColor = lerp(iridColor, _IridColor1.rgb, saturate(p - 2.0));
                        albedo.rgb = lerp(albedo.rgb, albedo.rgb * iridColor * 2.0, 0.7 * iridMask); 
                        specCol = lerp(specCol, iridColor, 0.8 * iridMask); 
                    }
                }
                half aoRaw = (_PackMode > 0.5) ? 1.0 : packed.g;   // Unity MetallicSmoothness has no AO channel
                half ao = lerp(1.0, aoRaw, _OcclusionStrength);
                
                float dither = (frac(52.9829189 * frac(dot(i.pos.xy, float2(0.06711056, 0.00583715)))) - 0.5) * _ShadowDither;
                float3 H = normalize(_WorldSpaceLightPos0.xyz + viewDir);
                float ndl = dot(n, _WorldSpaceLightPos0.xyz);
                #if defined(SHADOWS_SHADOWMASK) && !defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON)
                    float atten = 1.0;
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.wPos);
                #endif
                atten = lerp(1.0, atten, _ReceiveShadows);
                
                half ramp;
                if (_LightingModel < 0.5) {
                    ramp = smoothstep(_ShadowEdge - _ShadowSoft, _ShadowEdge + _ShadowSoft, (ndl * 0.5 + 0.5) + dither) * atten;
                } else if (_LightingModel < 1.5) {
                    ramp = saturate(ndl) * atten;
                } else {
                    // Cloth: wrapped diffuse - fibers scatter light past the terminator
                    ramp = saturate((ndl + _ClothWrap) / (1.0 + _ClothWrap)) * atten;
                }
                float3 lightCol = _LightColor0.rgb;
                float lum = dot(lightCol, float3(0.299, 0.587, 0.114));
                lightCol = lerp(lightCol, float3(lum, lum, lum), _GrayscaleLighting);
                lightCol = clamp(lightCol, _MinBrightness, _MaxBrightness);
                half3 diffuseCol = albedo.rgb * (1.0 - metallic);
                half3 direct  = lightCol * lerp(_ShadowTint.rgb, half3(1, 1, 1), ramp);
                // Runtime toggle state. //ifex covers the LOCKED case by stripping
                // the include; while UNLOCKED ifex is inert and the optimizer does
                // not carry keywords as defines, so without this check the editor
                // renders LV and LTCGI on materials that have them switched off -
                // and the shader silently changes behaviour the moment it locks.
                bool lvOn    = (_LightVolumes > 0.5);
                bool ltcgiOn = (_LTCGI > 0.5);
                // Debug taps for terms that are otherwise scoped inside their own
                // blocks. Unused when the debug block is stripped, so the compiler
                // eliminates the writes.
                half3 dbgLTCGI = 0;
                half3 dbgRefl  = 0;
                half3 ambient = ShadeSH9(half4(n, 1)) * ao;
                half3 lvSpecAdd = half3(0, 0, 0);
                #if defined(ZET_LV_OK)
                    // VRC Light Volumes: per-pixel voxel probes replace the blended
                    // Unity probe ambient. LightVolumeSH falls back to unity SH
                    // internally in worlds without volumes, so it is safe to use
                    // unconditionally under the keyword. Requires the Light
                    // Volumes 2.1.3+ package (specular smoothness signature).
                    float3 lvL0, lvL1r, lvL1g, lvL1b;
                    // LV 3.x resolves the short LightVolumeSH overload with
                    // pointLightShading defaulting to 3 - sharper than the standard
                    // profile, which is what makes lighting snap between areas.
                    // Passing the slider explicitly restores LV's documented smooth
                    // gradient. The 2.x overload takes neither argument and disables
                    // shading entirely, so 2.1.3 still compiles unchanged.
                    if (lvOn) {
                        #if defined(VRCLV_VERSION) && VRCLV_VERSION >= 3
                            LightVolumeSH(i.wPos, lvL0, lvL1r, lvL1g, lvL1b, 0, n, _LVPointShading);
                        #else
                            LightVolumeSH(i.wPos, lvL0, lvL1r, lvL1g, lvL1b);
                        #endif
                        // ambient already holds the ShadeSH9 value, so the off-path
                        // needs no else branch.
                        ambient = LightVolumeEvaluate(n, lvL0, lvL1r, lvL1g, lvL1b) * ao * _LightVolumesStrength;
                        // Speculars are added to col later, NOT multiplied by albedo
                        // (the specColor variant already carries the F0 tint).
                        if (_LightVolumesSpec > 0.5)
                            lvSpecAdd = LightVolumeSpecular(specCol, smoothness, n, viewDir, lvL0, lvL1r, lvL1g, lvL1b) * _LightVolumesStrength;
                    }
                #endif
                #ifdef VERTEXLIGHT_ON
                    // Added after the Light Volumes override on purpose: demoted
                    // vertex lights are realtime Unity lights the volumes know
                    // nothing about, so they stack rather than being replaced.
                    ambient += i.vLights * ao;
                #endif
                if (_GrayscaleLighting > 0.0) { half ambLum = dot(ambient, half3(0.299, 0.587, 0.114)); ambient = lerp(ambient, ambLum.xxx, _GrayscaleLighting); }
                // Subsurface Scattering: warm terminator roll-off + backlight transmission
                half3 sssAdd = 0;
                if (_SSSEnable > 0.5) {
                    half sssMask = _SSSMask.Sample(sampler_LinearRepeat, i.uv).r;
                    if (sssMask > 0.001) {
                        half3 sssTint = ZetSSSTint(albedo.rgb);
                        // 1) Terminator scatter: tinted band where light grazes into
                        // shadow. Centered on the toon Shadow Edge so it hugs the ramp
                        // line, or on the lambert terminator in PBR mode.
                        float hLam = ndl * 0.5 + 0.5;
                        float edgeMid = (_LightingModel < 0.5) ? _ShadowEdge : 0.5;
                        float sssW = _SSSTermWidth * 0.5 + 1e-3;
                        float band = smoothstep(edgeMid - sssW, edgeMid, hLam) * (1.0 - smoothstep(edgeMid, edgeMid + sssW, hLam));
                        sssAdd += lightCol * atten * band * (_SSSTermStrength * sssMask) * sssTint;
                        // 2) Transmission: light bleeding through thin parts from
                        // behind (Barre-Brisebois/Bouchard approximation), plus a
                        // probe-lit floor so ears stay alive with no directional light.
                        half thin = (1.0 - _SSSThicknessMap.Sample(sampler_LinearRepeat, i.uv).r) * sssMask;
                        if (thin > 0.001) {
                            float3 vLTraw = _WorldSpaceLightPos0.xyz + n * _SSSTransDistortion;
                            float3 vLT = vLTraw * rsqrt(max(dot(vLTraw, vLTraw), 1e-6));
                            float lt = pow(saturate(dot(viewDir, -vLT)), _SSSTransPower);
                            half3 backAmb = ShadeSH9(half4(-n, 1)) * _SSSAmbient;
                            #if defined(ZET_LV_OK)
                                // Volumetric transmission: a second volume sample a
                                // few centimetres BEHIND the surface. The transmitted
                                // colour is literally the light present inside or
                                // behind the thin part - per-voxel, positional, and
                                // impossible with Unity's one-blended-probe model.
                                // Costs one extra LV fetch, paid only on transmitting
                                // (thin, masked) pixels in LV-enabled builds.
                                // Declared outside the branch: sites further down read
                                // these, and zeroed values there fall back to the
                                // unity_SHA* path rather than collapsing to nothing.
                                float3 lvbL0 = 0, lvbL1r = 0, lvbL1g = 0, lvbL1b = 0;
                                // The depth offset goes in worldPosOffset on 3.x, which
                                // moves only the voxel sample. Point Light Volumes keep the
                                // real fragment position so their attenuation stays correct.
                                if (lvOn) {
                                    #if defined(VRCLV_VERSION) && VRCLV_VERSION >= 3
                                        LightVolumeSH(i.wPos, lvbL0, lvbL1r, lvbL1g, lvbL1b, -n * _SSSLVDepth, -n, _LVPointShading);
                                    #else
                                        LightVolumeSH(i.wPos - n * _SSSLVDepth, lvbL0, lvbL1r, lvbL1g, lvbL1b);
                                    #endif
                                    backAmb = LightVolumeEvaluate(-n, lvbL0, lvbL1r, lvbL1g, lvbL1b) * _SSSAmbient;
                                }
                            #endif
                            sssAdd += (lightCol * atten * lt + backAmb) * (thin * _SSSTransStrength) * sssTint;
                            // Probe-light transmission: the probes' L1 SH band
                            // encodes the direction most light arrives from, so a
                            // baked sun or club rig gets the same focused, distorted
                            // transmission as a realtime directional. This is what
                            // makes Focus / Distortion work in probe-only worlds.
                            if (_SSSProbeLight > 0.001) {
                                float3 domRaw = unity_SHAr.xyz * 0.3 + unity_SHAg.xyz * 0.59 + unity_SHAb.xyz * 0.11;
                                #if defined(ZET_LV_OK)
                                    // dominant direction of the light BEHIND the
                                    // surface, from the offset sample above
                                    if (lvOn)
                                        domRaw = lvbL1r * 0.3 + lvbL1g * 0.59 + lvbL1b * 0.11;
                                #endif
                                float domLen = length(domRaw);
                                if (domLen > 1e-4) {
                                    float3 domDir = domRaw / domLen;
                                    half3 domCol = max(ShadeSH9(half4(domDir, 1)), 0.0);
                                    #if defined(ZET_LV_OK)
                                        if (lvOn)
                                            domCol = max(LightVolumeEvaluate(domDir, lvbL0, lvbL1r, lvbL1g, lvbL1b), 0.0);
                                    #endif
                                    float3 pLTraw = domDir + n * _SSSTransDistortion;
                                    float3 pLT = pLTraw * rsqrt(max(dot(pLTraw, pLTraw), 1e-6));
                                    float plt = pow(saturate(dot(viewDir, -pLT)), _SSSTransPower);
                                    sssAdd += domCol * plt * (thin * _SSSTransStrength * _SSSProbeLight) * sssTint;
                                }
                            }
                        }
                    }
                }
                // VRSL GI. Point and spot lights, so this belongs with direct
                // light rather than ambient - it is a rig pointed at you, not
                // indirect bounce. Runtime-gated for the same reason LV and LTCGI
                // are: //ifex only strips at lock, so an unlocked material would
                // otherwise run this with the toggle off.
                half3 vrslDiffuse = 0, vrslSpec = 0;
//ifex _VRSLGI==0
                #if defined(ZET_VRSLGI)
                if (_VRSLGI > 0.5)
                {
                    ZetVRSLGI(i.wPos, n, viewDir, smoothness, vrslDiffuse, vrslSpec);

                    half vrslAO = lerp(1.0, ao, _VRSLGIOcclusion);
                    vrslDiffuse *= vrslAO;
                    vrslSpec    *= vrslAO;
                }
                #endif
//endex
                direct += vrslDiffuse;

                fixed4 col = fixed4(diffuseCol * (direct + ambient + sssAdd), 1.0);
                col.rgb += lvSpecAdd;
                col.rgb += vrslSpec * specCol;
                half spec = pow(saturate(dot(n, H)), exp2(smoothness * 9.0 + 1.0));
                half3 anisoAdd = 0;
                if (_AnisoEnable > 0.5) {
                    float3 anisoDir;
                    if (_AnisoDirMode > 1.5) {
                        float3 odir = _AnisoObjectMap.Sample(sampler_LinearRepeat, i.uv).rgb * 2.0 - 1.0;
                        float3 owdir = mul((float3x3)unity_ObjectToWorld, odir);
                        anisoDir = (dot(odir, odir) > 1e-5) ? normalize(owdir) : T;
                    } else if (_AnisoDirMode > 0.5) {
                        float2 aflow = _AnisoFlowMap.Sample(sampler_LinearRepeat, i.uv).rg * 2.0 - 1.0;
                        float3 fdir = aflow.x * T + aflow.y * B;
                        anisoDir = (dot(fdir, fdir) > 1e-5) ? normalize(fdir) : T;
                    } else {
                        anisoDir = _AnisoDir > 0.5 ? B : T;
                    }
                    anisoDir = normalize(anisoDir + n * _AnisoShift);
                    float dotDH = dot(anisoDir, H);
                    float sinDH = sqrt(max(0.0, 1.0 - dotDH * dotDH)); 
                    float anisoSpec = pow(sinDH, exp2(smoothness * 9.0 + 1.0 + (_AnisoPower - 5.0) * 0.5)) * _AnisoStrength;
                    anisoSpec *= _AnisoMask.Sample(sampler_LinearRepeat, i.uv).r;
                    // additive tinted anisotropic lobe, weighted toward reflective (smooth/metallic) areas
                    anisoAdd = _AnisoColor.rgb * anisoSpec * lerp(0.5, 1.0, saturate(smoothness + metallic));
                }
                
                half3 specColT = (_SpecTintOn > 0.5) ? specCol * _SpecTint.rgb : specCol;
                if (_LightingModel < 0.5) {
                    col.rgb += specColT * lightCol * smoothstep(0.5 - _SpecEdge, 0.5 + _SpecEdge, spec) * ramp;
                } else if (_LightingModel < 1.5) {
                    col.rgb += specColT * lightCol * spec * ramp;
                } else {
                    // Charlie sheen (Estevez-Kulla NDF, Neubelt-Pettineo visibility):
                    // an inverted-Gaussian lobe that peaks at grazing angles - the
                    // velvet halo - instead of a mirror-direction hotspot.
                    float clothA = max(1.0 - smoothness, 0.07);
                    float sNoH = saturate(dot(n, H)); sNoH *= sNoH;
                    float dSheen = (2.0 + 1.0 / clothA) * pow(1.0 - sNoH, 0.5 / clothA) / (2.0 * UNITY_PI);
                    float sNoV = saturate(dot(n, viewDir));
                    float sNoL = saturate(ndl);
                    float visSheen = 1.0 / (4.0 * (sNoL + sNoV - sNoL * sNoV) + 1e-4);
                    col.rgb += _SheenColor.rgb * lightCol * (dSheen * visSheen * sNoL * atten);
                }
                col.rgb += anisoAdd * lightCol * ramp;
                if (_StyleSpecEnable > 0.5) {
                    float ssNdh = saturate(dot(n, H));
                    float ssMask = _StyleSpecMask.Sample(sampler_LinearRepeat, i.uv).r;
                    float ssLayers =
                        smoothstep(1.0 - _SS1Size - _SS1Feather, 1.0 - _SS1Size + _SS1Feather, ssNdh) * _SS1Strength +
                        smoothstep(1.0 - _SS2Size - _SS2Feather, 1.0 - _SS2Size + _SS2Feather, ssNdh) * _SS2Strength +
                        smoothstep(1.0 - _SS3Size - _SS3Feather, 1.0 - _SS3Size + _SS3Feather, ssNdh) * _SS3Strength;
                    half3 ssCol = _StyleSpecTint.rgb * ((_StyleSpecUseLight > 0.5) ? lightCol : half3(1, 1, 1));
                    col.rgb += ssCol * ssLayers * ssMask * ramp;
                }
                
                if (_Spec2Enable > 0.5) {
                    float spec2Mask = _Spec2Mask.Sample(sampler_LinearRepeat, i.uv).r;
                    half spec2 = pow(saturate(dot(n, H)), exp2(_Spec2Smoothness * 9.0 + 1.0));
                    
                    if (_LightingModel < 0.5) {
                        col.rgb += _Spec2Color.rgb * smoothstep(0.5 - _SpecEdge, 0.5 + _SpecEdge, spec2) * spec2Mask * lightCol * ramp;
                    } else {
                        col.rgb += _Spec2Color.rgb * spec2 * spec2Mask * lightCol * ramp;
                    }
                }
                if (_ReflectionsEnable > 0.5) {
                float3 reflDir = reflect(-viewDir, n);
                float reflMip = (1.0 - smoothness) * UNITY_SPECCUBE_LOD_STEPS;
                half3 probeRefl = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, reflMip), unity_SpecCube0_HDR);
                // Unity puts the second-nearest probe in unity_SpecCube1 and the
                // crossfade weight in unity_SpecCube0_BoxMin.w. Sampling only
                // SpecCube0 makes the reflection hard-switch the moment you cross
                // a probe boundary; blending is what the Standard shader does and
                // what makes walking between rooms look continuous.
                UNITY_BRANCH
                if (unity_SpecCube0_BoxMin.w < 0.99999) {
                    half3 probeRefl1 = DecodeHDR(UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflDir, reflMip), unity_SpecCube1_HDR);
                    probeRefl = lerp(probeRefl1, probeRefl, unity_SpecCube0_BoxMin.w);
                }
                // Fill in the baked cubemap only where the world probe is dark, so bright worlds
                // keep their native reflections while dark/probe-less worlds still show metallics.
                half probeLum = dot(probeRefl, half3(0.299, 0.587, 0.114));
                half fill = saturate(1.0 - probeLum * 3.0);
                half3 reflection = probeRefl;
                // Skip the fallback cube sample entirely in bright worlds (fill ~= 0) or when unused.
                if (_HasBakedCubemap > 0.5 && (_ForceFallback > 0.5 || (fill > 0.001 && _FallbackCubemapStrength > 0.0))) {
                    half3 fallbackRefl = _BakedCubemap.SampleLevel(sampler_LinearClamp, reflDir, reflMip).rgb * _FallbackCubemapStrength;
                    reflection = (_ForceFallback > 0.5) ? fallbackRefl : (probeRefl + fallbackRefl * fill);
                }
                // Reflection Strength: user multiplier x smoothness weighting so rough dielectrics
                // do not get a full blurry env reflection washed over them (that reads as rubbery).
                // Metals keep full reflection; non-metals fade with roughness.
                half reflStrength = _ReflStrength * lerp(smoothness, 1.0, metallic);
                if (_ReflTintOn > 0.5) reflection *= _ReflTint.rgb;
                dbgRefl = reflection * specCol * ao * reflStrength;
                col.rgb += reflection * specCol * ao * reflStrength;
                }
                #if defined(ZET_LTCGI)
                // Purely additive, so the off-path needs nothing but the branch.
                if (ltcgiOn) {
                    half3 lDiff = 0, lSpec = 0; LTCGI_Contribution(i.wPos, n, viewDir, 1.0 - smoothness, float2(0, 0), lDiff, lSpec);
                    half3 ltAO = lerp(half3(1,1,1), ao.xxx, _LTCGIOcclusion);
                    if (_LTCGITintOn > 0.5) { lDiff *= _LTCGIDiffuseTint.rgb; lSpec *= _LTCGISpecularTint.rgb; }
                    dbgLTCGI = (diffuseCol * lDiff * ltAO + specCol * lSpec) * _LTCGIStrength;
                    col.rgb += (diffuseCol * lDiff * ltAO + specCol * lSpec) * _LTCGIStrength;
                    // SSS: area screens behind the surface bleeding through thin
                    // parts. A second full LTCGI evaluation with the inverted
                    // normal - opt-in because of the cost. Diffuse only; no focus
                    // term needed since area lights are already spatially shaped.
                    if (_SSSEnable > 0.5 && _SSSLTCGI > 0.5) {
                        half sssMaskL = _SSSMask.Sample(sampler_LinearRepeat, i.uv).r;
                        half thinL = (1.0 - _SSSThicknessMap.Sample(sampler_LinearRepeat, i.uv).r) * sssMaskL;
                        if (thinL > 0.001) {
                            half3 sssTintL = ZetSSSTint(albedo.rgb);
                            half3 bDiff = 0, bSpec = 0; LTCGI_Contribution(i.wPos, -n, viewDir, 1.0, float2(0, 0), bDiff, bSpec);
                            col.rgb += diffuseCol * bDiff * (thinL * _SSSTransStrength) * sssTintL * _LTCGIStrength;
                        }
                    }
                }
                #endif
                EmSlot s0;
                s0.enable = _Em0Enable; s0.baseColor = c_em0; s0.hueOn = _Em0Hue; s0.baseAmt = _Em0Base; s0.band = _Em0Band; s0.alBoost = _Em0AL;
                s0.mode = _Em0Mode; s0.pulseScale = _Em0PulseScale; s0.projCenter = _Em0Center.xy; s0.rotationDeg = _Em0Rotation; s0.mirrorOn = _Em0Mirror; s0.triplanar = _Em0Triplanar;
                s0.bgColor = _Em0BgColor.rgb; s0.scaleLock = _Em0ScaleLock; s0.bgScale = _Em0BgScale.xy; s0.tileX = _Em0TileX; s0.tileY = _Em0TileY; s0.pan = _Em0Pan.xy;
                s0.layers = _Em0Layers; s0.parallax = _Em0Parallax; s0.layerDist = _Em0LayerDist; s0.nearBright = _Em0NearBright; s0.farBright = _Em0FarBright; s0.alEnable = _Em0ALEnable;
                s0.multBand = _Em0MultBand; s0.multAmt = _Em0MultAmt; s0.addBand = _Em0AddBand; s0.addAmt = _Em0AddAmt; s0.volBoost = _Em0VolBoost; s0.volAmt = _Em0VolAmt;
                s0.intensity = _Em0Intensity; s0.edgeStrength = _Em0EdgeGlow; s0.edgePower = _Em0EdgePower; s0.lightBased = _Em0LightBased; s0.minEmiss = _Em0MinEmiss; s0.maxEmiss = _Em0MaxEmiss;
                s0.minLight = _Em0MinLight; s0.maxLight = _Em0MaxLight; s0.blinkOn = _Em0Blink; s0.blinkSpeed = _Em0BlinkSpeed; s0.blinkMin = _Em0BlinkMin;
                s0.scanOn = _Em0Scan; s0.scanDir = _Em0ScanDir; s0.scanMode = _Em0ScanMode; s0.scanSpeed = _Em0ScanSpeed; s0.scanWidth = _Em0ScanWidth; s0.scanSoft = _Em0ScanSoft; s0.scanFloor = _Em0ScanFloor; s0.scanPixels = _Em0ScanPixels; s0.scanGlitch = _Em0ScanGlitch;
                col.rgb += EvalEmissionSlot(s0, _Em0Mask, _Em0BgTex, _Em0PathTex, i.uv, i.wPos, N, viewDir, vT, proxAlpha, alAvail, ramp);
                #if defined(ZET_EM1)
                EmSlot s1;
                s1.enable = _Em1Enable; s1.baseColor = c_em1; s1.hueOn = _Em1Hue; s1.baseAmt = _Em1Base; s1.band = _Em1Band; s1.alBoost = _Em1AL;
                s1.mode = _Em1Mode; s1.pulseScale = _Em1PulseScale; s1.projCenter = _Em1Center.xy; s1.rotationDeg = _Em1Rotation; s1.mirrorOn = _Em1Mirror; s1.triplanar = _Em1Triplanar;
                s1.bgColor = _Em1BgColor.rgb; s1.scaleLock = _Em1ScaleLock; s1.bgScale = _Em1BgScale.xy; s1.tileX = _Em1TileX; s1.tileY = _Em1TileY; s1.pan = _Em1Pan.xy;
                s1.layers = _Em1Layers; s1.parallax = _Em1Parallax; s1.layerDist = _Em1LayerDist; s1.nearBright = _Em1NearBright; s1.farBright = _Em1FarBright; s1.alEnable = _Em1ALEnable;
                s1.multBand = _Em1MultBand; s1.multAmt = _Em1MultAmt; s1.addBand = _Em1AddBand; s1.addAmt = _Em1AddAmt; s1.volBoost = _Em1VolBoost; s1.volAmt = _Em1VolAmt;
                s1.intensity = _Em1Intensity; s1.edgeStrength = _Em1EdgeGlow; s1.edgePower = _Em1EdgePower; s1.lightBased = _Em1LightBased; s1.minEmiss = _Em1MinEmiss; s1.maxEmiss = _Em1MaxEmiss;
                s1.minLight = _Em1MinLight; s1.maxLight = _Em1MaxLight; s1.blinkOn = _Em1Blink; s1.blinkSpeed = _Em1BlinkSpeed; s1.blinkMin = _Em1BlinkMin;
                s1.scanOn = _Em1Scan; s1.scanDir = _Em1ScanDir; s1.scanMode = _Em1ScanMode; s1.scanSpeed = _Em1ScanSpeed; s1.scanWidth = _Em1ScanWidth; s1.scanSoft = _Em1ScanSoft; s1.scanFloor = _Em1ScanFloor; s1.scanPixels = _Em1ScanPixels; s1.scanGlitch = _Em1ScanGlitch;
                col.rgb += EvalEmissionSlot(s1, _Em1Mask, _Em0BgTex, _Em1PathTex, i.uv, i.wPos, N, viewDir, vT, proxAlpha, alAvail, ramp);
                #endif
                #if defined(ZET_EM2)
                EmSlot s2;
                s2.enable = _Em2Enable; s2.baseColor = c_em2; s2.hueOn = _Em2Hue; s2.baseAmt = _Em2Base; s2.band = _Em2Band; s2.alBoost = _Em2AL;
                s2.mode = _Em2Mode; s2.pulseScale = _Em2PulseScale; s2.projCenter = _Em2Center.xy; s2.rotationDeg = _Em2Rotation; s2.mirrorOn = _Em2Mirror; s2.triplanar = _Em2Triplanar;
                s2.bgColor = _Em2BgColor.rgb; s2.scaleLock = _Em2ScaleLock; s2.bgScale = _Em2BgScale.xy; s2.tileX = _Em2TileX; s2.tileY = _Em2TileY; s2.pan = _Em2Pan.xy;
                s2.layers = _Em2Layers; s2.parallax = _Em2Parallax; s2.layerDist = _Em2LayerDist; s2.nearBright = _Em2NearBright; s2.farBright = _Em2FarBright; s2.alEnable = _Em2ALEnable;
                s2.multBand = _Em2MultBand; s2.multAmt = _Em2MultAmt; s2.addBand = _Em2AddBand; s2.addAmt = _Em2AddAmt; s2.volBoost = _Em2VolBoost; s2.volAmt = _Em2VolAmt;
                s2.intensity = _Em2Intensity; s2.edgeStrength = _Em2EdgeGlow; s2.edgePower = _Em2EdgePower; s2.lightBased = _Em2LightBased; s2.minEmiss = _Em2MinEmiss; s2.maxEmiss = _Em2MaxEmiss;
                s2.minLight = _Em2MinLight; s2.maxLight = _Em2MaxLight; s2.blinkOn = _Em2Blink; s2.blinkSpeed = _Em2BlinkSpeed; s2.blinkMin = _Em2BlinkMin;
                s2.scanOn = _Em2Scan; s2.scanDir = _Em2ScanDir; s2.scanMode = _Em2ScanMode; s2.scanSpeed = _Em2ScanSpeed; s2.scanWidth = _Em2ScanWidth; s2.scanSoft = _Em2ScanSoft; s2.scanFloor = _Em2ScanFloor; s2.scanPixels = _Em2ScanPixels; s2.scanGlitch = _Em2ScanGlitch;
                col.rgb += EvalEmissionSlot(s2, _Em2Mask, _Em0BgTex, _Em2PathTex, i.uv, i.wPos, N, viewDir, vT, proxAlpha, alAvail, ramp);
                #endif
                #if defined(ZET_EM3)
                EmSlot s3;
                s3.enable = _Em3Enable; s3.baseColor = c_em3; s3.hueOn = _Em3Hue; s3.baseAmt = _Em3Base; s3.band = _Em3Band; s3.alBoost = _Em3AL;
                s3.mode = _Em3Mode; s3.pulseScale = _Em3PulseScale; s3.projCenter = _Em3Center.xy; s3.rotationDeg = _Em3Rotation; s3.mirrorOn = _Em3Mirror; s3.triplanar = _Em3Triplanar;
                s3.bgColor = _Em3BgColor.rgb; s3.scaleLock = _Em3ScaleLock; s3.bgScale = _Em3BgScale.xy; s3.tileX = _Em3TileX; s3.tileY = _Em3TileY; s3.pan = _Em3Pan.xy;
                s3.layers = _Em3Layers; s3.parallax = _Em3Parallax; s3.layerDist = _Em3LayerDist; s3.nearBright = _Em3NearBright; s3.farBright = _Em3FarBright; s3.alEnable = _Em3ALEnable;
                s3.multBand = _Em3MultBand; s3.multAmt = _Em3MultAmt; s3.addBand = _Em3AddBand; s3.addAmt = _Em3AddAmt; s3.volBoost = _Em3VolBoost; s3.volAmt = _Em3VolAmt;
                s3.intensity = _Em3Intensity; s3.edgeStrength = _Em3EdgeGlow; s3.edgePower = _Em3EdgePower; s3.lightBased = _Em3LightBased; s3.minEmiss = _Em3MinEmiss; s3.maxEmiss = _Em3MaxEmiss;
                s3.minLight = _Em3MinLight; s3.maxLight = _Em3MaxLight; s3.blinkOn = _Em3Blink; s3.blinkSpeed = _Em3BlinkSpeed; s3.blinkMin = _Em3BlinkMin;
                s3.scanOn = _Em3Scan; s3.scanDir = _Em3ScanDir; s3.scanMode = _Em3ScanMode; s3.scanSpeed = _Em3ScanSpeed; s3.scanWidth = _Em3ScanWidth; s3.scanSoft = _Em3ScanSoft; s3.scanFloor = _Em3ScanFloor; s3.scanPixels = _Em3ScanPixels; s3.scanGlitch = _Em3ScanGlitch;
                col.rgb += EvalEmissionSlot(s3, _Em3Mask, _Em0BgTex, _Em3PathTex, i.uv, i.wPos, N, viewDir, vT, proxAlpha, alAvail, ramp);
                #endif
                col.rgb += decalEmiss;
//ifex _RefractEnable==0
                if (_RefractEnable > 0.5) {
                    float rfMask = _RefractMask.Sample(sampler_MainTex, i.uv).r;
                    if (rfMask > 0.001) {
                        float3 vn = mul((float3x3)UNITY_MATRIX_V, N);
                        float2 off = vn.xy * (_RefractStrength * 0.1);
                        half2 dn = _RefractMap.Sample(sampler_LinearRepeat, i.uv * _RefractTile + _Time.y * _RefractScroll * float2(0.1, 0.07)).rg * 2.0 - 1.0;
                        off += dn * (_RefractStrength * 0.05);
                        if (_RefractALEnable > 0.5 && alAvail) off *= 1.0 + ALEnv((uint)_RefractBand) * _RefractAL;
                        float2 suv = i.pos.xy / _ScreenParams.xy;
                        float ca = _RefractCA * 0.5;
                        half3 refr;
                        refr.r = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_ZetGrabTex, suv + off * (1.0 + ca)).r;
                        refr.g = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_ZetGrabTex, suv + off).g;
                        refr.b = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_ZetGrabTex, suv + off * (1.0 - ca)).b;
                        col.rgb = lerp(col.rgb, refr * _RefractTint.rgb, rfMask * _RefractBlend);
                    }
                }
//endex
                if (_RoomEnable > 0.5) {
                    float rMask = smoothstep(0.5 - _RoomEdge, 0.5 + _RoomEdge, _RoomMask.Sample(sampler_MainTex, i.uv).r);
                    if (rMask > 0.001) {
                        float2 cell = frac(i.uv * _RoomTile + float2(_RoomSlideX, _RoomSlideY) * (_Time.y * 0.1));
                        float3 ro = float3(cell, 0.0);
                        float3 rd;
                        rd.x = dot(-viewDir, T);
                        rd.y = dot(-viewDir, B);
                        rd.z = max(dot(viewDir, N), 0.02) / max(_RoomDepth, 0.05);
                        float3 boxMax = float3(rd.x > 0.0 ? 1.0 : 0.0, rd.y > 0.0 ? 1.0 : 0.0, 1.0);
                        float3 tt = (boxMax - ro) / rd;
                        float tmin = min(min(tt.x, tt.y), tt.z);
                        float3 hit = ro + rd * tmin;
                        float3 dir = hit - 0.5;
                        float ax = _Time.y * _RoomScrollX, ay = _Time.y * _RoomScrollY;
                        float cx = cos(ax), sx = sin(ax); dir.xz = float2(dir.x * cx - dir.z * sx, dir.x * sx + dir.z * cx);
                        float cy = cos(ay), sy = sin(ay); dir.yz = float2(dir.y * cy - dir.z * sy, dir.y * sy + dir.z * cy);
                        float depthT = saturate(hit.z);
                        float mip = _RoomSoften * lerp(2.0, 6.0, depthT);
                        dir.xy += float2(sin(cell.y * 25.0 + _Time.y * 2.0), cos(cell.x * 25.0 + _Time.y * 1.7)) * (_RoomGlassWarp * 0.03);
                        float rgca = _RoomGlassChroma * 0.03;
                        half3 room;
                        room.r = _RoomCube.SampleLevel(sampler_LinearClamp, dir + float3(rgca, 0, 0), mip).r;
                        room.g = _RoomCube.SampleLevel(sampler_LinearClamp, dir, mip).g;
                        room.b = _RoomCube.SampleLevel(sampler_LinearClamp, dir - float3(rgca, 0, 0), mip).b;
                        room *= _RoomColor.rgb;
                        if (_RoomDepthMode > 1.5) room = lerp(room, _RoomHazeColor.rgb, depthT * _RoomFade);
                        else if (_RoomDepthMode > 0.5) room *= lerp(1.0, 1.0 - _RoomFade, depthT);
                        if (_RoomALEnable > 0.5 && alAvail) room *= 1.0 + ALEnv((uint)_RoomBand) * _RoomAL;
                        col.rgb = lerp(col.rgb, room, rMask);
                    }
                }
                if (_ScreenEnable > 0.5) {
                    float scrMask = _ScreenMask.Sample(sampler_MainTex, i.uv).r;
                    if (scrMask > 0.001) {
                        float2 suv = i.uv;
                        bool bsod = _ScreenBSOD > 0.5 || (_ScreenBSODNoAL > 0.5 && !alAvail);
                        half3 scr;
                        if (bsod) {
                            scr = _ScreenBSODTex.Sample(sampler_LinearRepeat, suv * _ScreenBSODTex_ST.xy + _ScreenBSODTex_ST.zw).rgb;
                        } else {
                            half3 backdrop = _ScreenBackdrop.Sample(sampler_LinearRepeat, suv * _ScreenBackdrop_ST.xy + _ScreenBackdrop_ST.zw).rgb;
                            scr = _ScreenBGColor.rgb * backdrop;
                            scr += _ScreenArt.Sample(sampler_LinearRepeat, suv * _ScreenArt_ST.xy + _ScreenArt_ST.zw).rgb * _ScreenArtStrength;
                            float gridV;
                            if (_ScreenGridProc > 0.5) {
                                float2 g = suv * _ScreenGridCells;
                                float2 fw = max(fwidth(g), 1e-5);
                                float2 dl = abs(frac(g + 0.5) - 0.5);
                                float2 lineAA = 1.0 - smoothstep(_ScreenGridLineW - fw, _ScreenGridLineW + fw, dl);
                                gridV = max(lineAA.x, lineAA.y);
                                float2 gm = g * 4.0;
                                float2 fwm = max(fwidth(gm), 1e-5);
                                float2 dlm = abs(frac(gm + 0.5) - 0.5);
                                float2 lineM = 1.0 - smoothstep(_ScreenGridLineW * 2.0 - fwm, _ScreenGridLineW * 2.0 + fwm, dlm);
                                float minorFade = saturate((0.4 - max(fwm.x, fwm.y)) * 5.0);
                                gridV = max(gridV, max(lineM.x, lineM.y) * _ScreenGridMinor * minorFade);
                            } else {
                                gridV = _ScreenGridTex.Sample(sampler_LinearRepeat, suv * _ScreenGridTex_ST.xy + _ScreenGridTex_ST.zw).r;
                            }
                            scr += gridV * _ScreenGridColor.rgb * _ScreenGridStrength;
                            if (alAvail) {
                                if (_ScreenMode < 0.5) {
                                    float wav = AudioLinkLerpMultiline(ALPASS_WAVEFORM + float2(suv.x * _ScreenWaveSamples, 0)).r;
                                    float d = abs(suv.y - 0.5 - wav * _ScreenWaveAmp);
                                    float trace = smoothstep(_ScreenLineWidth, 0.0, d);
                                    float glow = smoothstep(_ScreenLineWidth * 5.0, 0.0, d) * 0.35;
                                    scr += _ScreenLineColor.rgb * (trace + glow);
                                } else {
                                    float bx = frac(suv.x * 4.0);
                                    float inBar = step(0.12, bx) * step(bx, 0.88);
                                    uint band = (uint)floor(suv.x * 4.0);
                                    float level = ALEnv(band);
                                    float lit = step(suv.y, level);
                                    float seg = step(frac(suv.y * 12.0), 0.78);
                                    scr += _ScreenLineColor.rgb * inBar * lit * seg;
                                }
                            }
                        }
                        float3 lcd = _ScreenLCDTex.Sample(sampler_LinearRepeat, suv * _ScreenLCDTex_ST.xy + _ScreenLCDTex_ST.zw).rgb;
                        float tilesPerPixel = fwidth(suv.x * _ScreenLCDTex_ST.x);
                        float lcdFade = saturate((0.7 - tilesPerPixel) * 3.0);
                        scr *= lerp(float3(1, 1, 1), lcd * 3.0, _ScreenLCDStrength * lcdFade);
                        float scanFW = fwidth(suv.y * _ScreenScanCount);
                        float scanFade = saturate((0.6 - scanFW) * 4.0);
                        scr *= 1.0 - _ScreenScanline * scanFade * (0.5 + 0.5 * sin(suv.y * _ScreenScanCount * 6.28318));
                        col.rgb = lerp(col.rgb, scr, scrMask);
                    }
                }
                // Overlay decals: drawn on top of room/screen/lighting
                if (_DecalsEnable > 0.5) {
                    half3 ovEmiss = 0;
                    if (_Decal0Enable > 0.5 && _Decal0Overlay > 0.5) col.rgb = ApplyDecal(_Decal0Tex, sampler_LinearClamp, float2(_Decal0PosX, _Decal0PosY), _Decal0Scale, _Decal0Rotation, _Decal0Color, _Decal0Opacity, _Decal0Blend, _Decal0Emit, float4(_Decal0FlipCols, _Decal0FlipRows, _Decal0FlipFPS, _Decal0Flipbook), i.uv, col.rgb, ovEmiss);
                    #if defined(ZET_DEC1)
                    if (_Decal1Enable > 0.5 && _Decal1Overlay > 0.5) col.rgb = ApplyDecal(_Decal1Tex, sampler_LinearClamp, float2(_Decal1PosX, _Decal1PosY), _Decal1Scale, _Decal1Rotation, _Decal1Color, _Decal1Opacity, _Decal1Blend, _Decal1Emit, float4(_Decal1FlipCols, _Decal1FlipRows, _Decal1FlipFPS, _Decal1Flipbook), i.uv, col.rgb, ovEmiss);
                    #endif
                    #if defined(ZET_DEC2)
                    if (_Decal2Enable > 0.5 && _Decal2Overlay > 0.5) col.rgb = ApplyDecal(_Decal2Tex, sampler_LinearClamp, float2(_Decal2PosX, _Decal2PosY), _Decal2Scale, _Decal2Rotation, _Decal2Color, _Decal2Opacity, _Decal2Blend, _Decal2Emit, float4(_Decal2FlipCols, _Decal2FlipRows, _Decal2FlipFPS, _Decal2Flipbook), i.uv, col.rgb, ovEmiss);
                    #endif
                    #if defined(ZET_DEC3)
                    if (_Decal3Enable > 0.5 && _Decal3Overlay > 0.5) col.rgb = ApplyDecal(_Decal3Tex, sampler_LinearClamp, float2(_Decal3PosX, _Decal3PosY), _Decal3Scale, _Decal3Rotation, _Decal3Color, _Decal3Opacity, _Decal3Blend, _Decal3Emit, float4(_Decal3FlipCols, _Decal3FlipRows, _Decal3FlipFPS, _Decal3Flipbook), i.uv, col.rgb, ovEmiss);
                    #endif
                    col.rgb += ovEmiss;
                }
                if (_GlitterEnable > 0.5) {
                    half gMask = _GlitterMask.Sample(sampler_MainTex, i.uv).r;
                    if (gMask > 0.001) {
                        float2 gc = (_GlitterProjection > 0.5) ? (i.wPos.xz + i.wPos.y) : i.uv;
                        gc += _GlitterFlow.xy * _Time.y * 0.1;
                        float2 grid = gc * (1.0 + _GlitterDensity * 250.0);
                        float2 cell = floor(grid);
                        float2 r2 = hash2D(cell);
                        float r1 = hash2D(cell + 31.7).x;
                        float2 fp = frac(grid) - r2;
                        float flake = 1.0 - smoothstep(0.0, _GlitterSize * 0.5 + 0.03, length(fp));
                        float3 fn = normalize(n + (float3(r2, r1) * 2.0 - 1.0));
                        float lobe = pow(saturate(dot(fn, viewDir)), lerp(150.0, 3.0, saturate(_GlitterViewRange)));
                        float twRaw = sin(_Time.y * _GlitterSpeed + r1 * 6.28318) * 0.5 + 0.5;
                        float tw = smoothstep(1.0 - _GlitterAmount, 1.0, twRaw);
                        float spark = flake * lobe * tw;
                        float gAL = (_GlitterALEnable > 0.5 && alAvail) ? (1.0 + ALEnv((uint)_GlitterBand) * _GlitterAL) : 1.0;
                        half3 g = _GlitterColor.rgb * (spark * _GlitterBrightness * gAL * gMask);
                        if (_GlitterLit > 0.5) g *= ramp;
                        col.rgb += g;
                    }
                }
                if (_OutlineEnable > 0.5 && _OutlineState > 0.5) 
                {
                    float alO = alAvail ? ALEnv((uint)_OutlineBand) : 0.0;
                    // Reactive: boosted band, saturated so beats reach the full always-on
                    // glitch. Raw alO alone triple-dips (brightness x spread x split all scale
                    // by it), which read as a dim, barely-moving outline on non-bass bands.
                    float visibility = (_OutlineState > 1.5) ? saturate(alO * _OutlineAL) : 1.0;
                    float2 floatUV = i.uv + (vT / (dot(viewDir, N) + 0.42)) * (_OutlineFloat * 0.001);
                    float t = _Time.y * _OutlineSpeed;
                    if (_OutlineState > 1.5) t *= (1.0 + alO * 2.0); 
                    
                    float noise = frac(sin((floor(floatUV.y * _OutlineSlices) + floor(t)) * 12.9898) * 43758.5453);
                    float currentSpread = (_OutlineSpread * 0.002) * visibility;
                    float offset = (noise * 2.0 - 1.0) * currentSpread * step(0.5, frac(sin(floor(t * 1.5) * 78.233) * 43758.5453));
                    
                    float splitAmt = (_OutlineRGBSplit * 0.001) * visibility;
                    half outR = saturate(_OutlineMask.Sample(sampler_LinearClamp, floatUV + float2(offset + splitAmt, 0.0)).r);
                    half outG = saturate(_OutlineMask.Sample(sampler_LinearClamp, floatUV + float2(offset, 0.0)).r);
                    half outB = saturate(_OutlineMask.Sample(sampler_LinearClamp, floatUV + float2(offset - splitAmt, 0.0)).r);
                    half3 final_c_out = c_out;
                    if (_OutlineHueShift > 0.5) final_c_out = hueShift(final_c_out, (alAvail ? alO : _Time.y * 0.5) * 6.28318);
                    col.rgb += final_c_out * half3(outR, outG, outB) * visibility * proxAlpha;
                }
                if (_StarEnable > 0.5) 
                {
                    float starMask = _StarMask.Sample(sampler_LinearClamp, i.uv).r;
                    if (starMask > 0.001) 
                    {
                        float alS = alAvail ? ALEnv((uint)_StarBand) : 0.0;
                        // UV source: UV0 (mesh), Panosphere (view ray, reads as real sky), or
                        // Polar. The mask stays on UV0, so it still confines the effect to a region.
                        float2 uvSrc = i.uv;
                        if (_StarUVSource == 1) {
                            float3 vd = normalize(i.wPos - _WorldSpaceCameraPos);
                            uvSrc = float2(atan2(vd.z, vd.x) * 0.15915 + 0.5, acos(clamp(vd.y, -1.0, 1.0)) * 0.31831);
                        } else if (_StarUVSource == 2) {
                            float2 pc = i.uv - 0.5;
                            uvSrc = float2(atan2(pc.y, pc.x) * 0.15915 + 0.5, length(pc) * 2.0);
                        }
                        float2 starUVw = uvSrc + float2(sin(uvSrc.y * 25.0 + _Time.y * 2.0), cos(uvSrc.x * 25.0 + _Time.y * 1.7)) * (_StarGlassWarp * 0.03);
                        float nebPop = saturate(alS * _NebulaAL);
                        half3 finalNebulaColor;
                        float nebT = saturate((noise3D(float3(starUVw * 4.0, _Time.y * 0.03)) - 0.5) * 2.5 + 0.5);
                        if (_NebulaColorMode == 1) finalNebulaColor = c_star * _NebulaBright * (1.0 + nebPop);
                        else if (_NebulaColorMode == 2) finalNebulaColor = hueShift(half3(0.5, 0.1, 1.0), _Time.y * 0.5) * _NebulaBright * (1.0 + nebPop); 
                        else if (_NebulaColorMode == 3) finalNebulaColor = ZetNebGrad(nebT) * _NebulaBright + _NebulaPopColor.rgb * nebPop;
                        else if (_NebulaColorMode == 4) finalNebulaColor = _NebGradTex.SampleLevel(sampler_LinearClamp, float2(nebT, 0.5), 0).rgb * _NebulaBright + _NebulaPopColor.rgb * nebPop;
                        else finalNebulaColor = _StarBgColor.rgb * _NebulaBright + _NebulaPopColor.rgb * nebPop;
                        
                        half3 starAccum = finalNebulaColor; 
                        
                        if (_RaymarchEnable > 0.5) {
                            float3 viewDirTan = normalize(float3(dot(viewDir, T), dot(viewDir, B), dot(viewDir, N)));
                            float3 rayPos = float3(starUVw * (_StarDensity * 0.1), 0.0);
                            float3 rayDir = -viewDirTan; 
                            
                            half3 rmAccum = 0;
                            half transmit = 1.0;
                            float stepSize = (_StarParallax * 0.005);
                            
                            [loop]
                            for(int r = 0; r < 128; r++) {
                                if (r >= _RaymarchSteps) break;
                                float3 p = rayPos + rayDir * (r * stepSize);
                                p.z -= _Time.y * (_StarSpeed * 0.02); 
                                
                                half n1 = noise3D(p * 3.0);
                                half n2 = noise3D(p * 8.0);
                                half dens = (n1 * 0.7 + n2 * 0.3);
                                dens = smoothstep(0.4, 0.9, dens) * (_RaymarchDensity * 0.5);
                                
                                if (dens > 0.01) {
                                    half3 emit = _StarBgColor.rgb * _NebulaBright * lerp(0.5, 1.0, n2) + _NebulaPopColor.rgb * nebPop;
                                    if (_NebulaColorMode == 2) emit = hueShift(emit, p.z * 0.5);
                                    else if (_NebulaColorMode == 3) emit = ZetNebGrad(n2) * _NebulaBright * lerp(0.5, 1.0, n2) + _NebulaPopColor.rgb * nebPop;
                                    else if (_NebulaColorMode == 4) emit = _NebGradTex.SampleLevel(sampler_LinearClamp, float2(saturate(n2), 0.5), 0).rgb * _NebulaBright * lerp(0.5, 1.0, n2) + _NebulaPopColor.rgb * nebPop;
                                    rmAccum += emit * dens * transmit * stepSize * 4.0;
                                    transmit *= exp(-dens * stepSize * 4.0); 
                                }
                                if (transmit < 0.01) break;
                            }
                            starAccum = rmAccum + finalNebulaColor * transmit;
                        }
                        float2 baseUV = starUVw * (_StarDensity * 0.4);
                        float timeOffset = _Time.y * (_StarSpeed * 0.01);
                        float2 viewOffset = (vT / (dot(viewDir, N) + 0.42));
                        [unroll(5)]
                        for (int s = 0; s < 5; s++) {
                            if (s >= _StarLayers) break;
                            float depth = 1.0 + (s * (_StarParallax * 0.02));
                            float2 starUV = baseUV * depth - viewOffset * depth;
                            starUV += timeOffset * (1.0 - s * 0.2); 
                            
                            float2 gv = frac(starUV) - 0.5;
                            float2 id = floor(starUV);
                            float2 r = ZetStarJitter(id, s);
                            float starHash = hash2(id + s * 7.31); 
                            
                            float twAmt = saturate(_StarTwinkle * 0.01);
                            float twPhase = _Time.y * (_StarTwinkleSpeed * 0.1) + starHash * 100.0 + s * 2.3;
                            half twWave = 0.5 + 0.5 * sin(twPhase);
                            float sizePulse = 1.0 + (twWave - 0.5) * 0.6 * twAmt;
                            float size = (_StarSize * 0.0015) * (1.0 - s * 0.2) * sizePulse; 
                            float soft = _StarSoftness * 0.0015;
                            float2 distVec = gv - r;
                            float maxDist = max(abs(distVec.x), abs(distVec.y));
                            half star = smoothstep(size + soft, size * 0.1, length(distVec)) * step(0.5, starHash);
                            star *= smoothstep(0.5, 0.3, maxDist); 
                            
                            // Full-range brightness twinkle: visible on bright/large stars, scales 0..1 with amount
                            half twinkle = 1.0 - twAmt * (1.0 - twWave);
                            float3 starPos3D = float3(starUV * 2.0, depth * 2.0 - _Time.y * (_StarSpeed * 0.02));
                            half gasDensity = noise3D(starPos3D * 3.0) * 0.7 + noise3D(starPos3D * 8.0) * 0.3;
                            half occlusion = lerp(1.0, smoothstep(0.6, 0.3, gasDensity), _RaymarchEnable);
                            half3 finalStarColor = _StarColor.rgb;
                            if (_StarColorMode == 1) finalStarColor = c_star;
                            else if (_StarColorMode == 2) finalStarColor = hueShift(half3(1.0, 0.2, 0.2), starHash * 6.28); 
                            finalStarColor = max(0.0, lerp(dot(finalStarColor, half3(0.299, 0.587, 0.114)).xxx, finalStarColor, _StarSaturation));
                            // Constellation lines: link this cell's star to neighbours in
                            // this layer's own 3x3, so both ends stay in the window and the
                            // link is never clipped. Depth comes from the layers themselves,
                            // which sit at different parallax depths and drift at their own speed.
                            if (_StarLineEnable > 0.5 && starHash >= 0.5) {
                                float lth    = _StarLineThickness * 0.0003 + 0.0004;
                                float lmaxL  = _StarLineMaxLen * 0.02 + 0.2;
                                float lfadeS = lerp(lmaxL, lmaxL * 0.3, saturate(_StarLineFade * 0.01));
                                float lineAmt = 0;
                                [unroll] for (int oy = -1; oy <= 1; oy++) {
                                    [unroll] for (int ox = -1; ox <= 1; ox++) {
                                        float2 o = float2(ox, oy);
                                        float2 ncell = id + o;
                                        if ((ox != 0 || oy != 0) && hash2(ncell + s * 7.31) >= 0.5) {
                                            float2 pn = o + ZetStarJitter(ncell, s);    // neighbour star, this-cell frame
                                            float2 ab = pn - r;
                                            float llen = length(ab);
                                            float lenFade = smoothstep(lmaxL, lfadeS, llen);
                                            float tt = saturate(dot(gv - r, ab) / max(dot(ab, ab), 1e-6));
                                            float dPerp = length(gv - (r + ab * tt));
                                            float taper = pow(abs(tt - 0.5) * 2.0, 1.6);
                                            float w = lerp(lth * 0.6, lth * 1.4, taper);
                                            float lcore = 1.0 - smoothstep(w * 0.2, w, dPerp);
                                            float lang = atan2(ab.y, ab.x);
                                            float lh = hash2(ncell + id + s * 3.7);
                                            float life = 0.55 + 0.45 * sin(_Time.y * (_StarLineSpeed * 0.03) + llen * 9.0 + lang * 2.0 + lh * 6.2832);
                                            lineAmt += lcore * lenFade * life;
                                        }
                                    }
                                }
                                half3 lc = (_StarLineColorMode > 0.5) ? finalStarColor : _StarLineColor.rgb;
                                float ldFade = lerp(1.0, 1.0 / depth, saturate(_StarLineDepthFade * 0.01));
                                starAccum += lc * lineAmt * ldFade * (1.0 + alS * _StarAL) * _StarLineStrength;
                            }
                            finalStarColor *= (1.0 + alS * _StarAL);
                            
                            starAccum += finalStarColor * star * (starHash * 2.0) * twinkle * occlusion;
                        }
                        col.rgb = lerp(col.rgb, ZetPhotoBlend(col.rgb, starAccum * _ConstellationEmission, _ConstellationBlend), starMask * proxAlpha);
                    }
                }
                
                if (_EQEnable > 0.5 && alAvail) {
                    float eqMask = _EQMask.Sample(sampler_LinearClamp, i.uv).r;
                    if (eqMask > 0.001) {
                        float2 uvEQ = i.uv * _EQMask_ST.xy + _EQMask_ST.zw;
                        float cols = max(2.0, round(_EQColumns));
                        float bandIndex = floor(uvEQ.x * cols) / cols; 
                        // v64c: DFT magnitudes are much quieter than the autogained band
                        // rows (no limiter stage) and only bins 0-239 are valid. Gain plus
                        // a sub-1 curve lift the spectrum into a readable log-style EQ.
                        float mag = AudioLinkLerpMultiline(ALPASS_DFT + float2(bandIndex * 238.0, 0.0)).g;
                        float alVal = saturate(pow(saturate(mag * _EQGain), _EQCurve));
                        half barMask = step(uvEQ.y, alVal);
                        half gap = step(frac(uvEQ.x * cols), 0.8);
                        
                        half3 finalEQColor = _EQColor.rgb * barMask * gap;
                        col.rgb += finalEQColor * eqMask * proxAlpha;
                    }
                }
                if (_RimEnable > 0.5 && _RimState > 0.5) {
                    float alRim = alAvail ? ALEnv((uint)_RimBand) : 0.0;
                    float visibility = (_RimState > 1.5) ? alRim : 1.0;
                    half3 final_c_rim = c_rim;
                    if (_RimHueShift > 0.5) final_c_rim = hueShift(final_c_rim, (alAvail ? alRim : _Time.y * 0.5) * 6.28318);
                    col.rgb += final_c_rim * smoothstep(1.0 - _RimWidth - _RimSoft, 1.0 - _RimWidth + _RimSoft, 1.0 - saturate(dot(n, viewDir))) * (_RimBase + alRim * _RimAL) * visibility * proxAlpha;
                }
                float al_break = alAvail ? ALEnv((uint)_Band) : 0.0;
                half3 final_c_break = c_break;
                if (_BreakHueShift > 0.5) final_c_break = hueShift(final_c_break, (alAvail ? al_break : _Time.y * 0.5) * 6.28318);
                float edgeDist = min(i.bary.x, min(i.bary.y, i.bary.z));
                half edge = (1.0 - smoothstep((_EdgeWidth * 0.005) * 0.5, (_EdgeWidth * 0.005), edgeDist)) * smoothstep(0.0, 0.05, i.fx.x);
                col.rgb += final_c_break * edge * proxAlpha * bSurf;
                col.rgb += final_c_break * i.fx.y * _HeatGlow * proxAlpha * bSurf;
                col.rgb += final_c_break * i.fx.x * proxAlpha * bSurf;
                
//ifex _DebugView==0
                // Returns before fog on purpose: a debug view should show the raw
                // term, not the term after the world's fog has been mixed into it.
                if (_DebugView > 0.5) {
                    half3 dbg;
                    if      (_DebugView < 1.5)  dbg = albedo.rgb;
                    else if (_DebugView < 2.5)  dbg = n * 0.5 + 0.5;
                    else if (_DebugView < 3.5)  dbg = metallic.xxx;
                    else if (_DebugView < 4.5)  dbg = smoothness.xxx;
                    else if (_DebugView < 5.5)  dbg = ao.xxx;
                    else if (_DebugView < 6.5)  dbg = ambient;
                    else if (_DebugView < 7.5)  dbg = direct;
                    else if (_DebugView < 8.5)  dbg = dbgLTCGI;
                    else if (_DebugView < 9.5)  dbg = lvSpecAdd;
                    else if (_DebugView < 10.5) dbg = dbgRefl;
                    else if (_DebugView < 11.5) dbg = packed.rgb;
                    else if (_DebugView < 12.5) dbg = half3(frac(i.uv), 0);
                    else if (_DebugView < 13.5) dbg = vrslDiffuse;
                    // Light count as greyscale. VRSL GI cannot be previewed in
                    // the editor at all, so this is the one number worth seeing
                    // in-world: black means the global is unbound, anything else
                    // means data is arriving and the problem is downstream.
                    #if defined(ZET_VRSLGI)
                    else                        dbg = ((half) _Udon_VRSL_GI_LightTexture.Load(int3(0, 2, 0)).r / 16.0).xxx;
                    #else
                    // VRSL GI switched off: no texture to count. Magenta rather
                    // than black, so "feature is off" cannot be mistaken for
                    // "the world is not publishing anything".
                    else                        dbg = half3(1, 0, 1);
                    #endif
                    return fixed4(dbg, 1.0);
                }
//endex
                half3 hcol = col.rgb;
                ZetApplyPlasma(hcol, i.wPos);
                ZetApplyHologram(hcol, outAlpha, i.wPos, i.wNrm, i.pos.xy);
                col.rgb = hcol;
                UNITY_APPLY_FOG(i.fogCoord, col);
                return fixed4(col.rgb, outAlpha);
            }
            ENDCG
        }
        // ==============================================================================
        // PASS: STANDARD OUTLINE (inverted hull) -- stripped when locked off
        // ==============================================================================
//ifex _OutlineStdEnable==0
        Pass
        {
            Name "OUTLINE"
            Tags { "LightMode" = "ForwardBase" }
            Cull Front
            CGPROGRAM
            #pragma vertex vertOL
            #pragma fragment fragOL
            #pragma target 5.0
            #pragma multi_compile_fog
            struct appdataOL { float4 vertex : POSITION; float3 normal : NORMAL; float2 uv : TEXCOORD0; float2 uv1 : TEXCOORD1; float4 color : COLOR; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct v2fOL { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; float3 wNrm : TEXCOORD1; UNITY_FOG_COORDS(2) UNITY_VERTEX_OUTPUT_STEREO };
            v2fOL vertOL(appdataOL v) {
                v2fOL o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                if (ZetUVTileDiscarded(v.uv, v.uv1) > 0.5) v.vertex = asfloat(0x7FC00000).xxxx;   // NaN culls the outline shell too
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                {
                    float3 zp = v.vertex.xyz; float3 zn = v.normal; float3 zt = float3(1, 0, 0);
                    ZetApplyVertexAL(zp, zn, zt, v.uv, o.uv);
                    ZetApplyPlasmaDisplace(zp, zn);
                    v.vertex.xyz = zp; v.normal = zn;
                }
                o.wNrm = UnityObjectToWorldNormal(v.normal);
                float m = _OutlineStdMask.SampleLevel(sampler_LinearClamp, o.uv, 0).r;
                if (_OutlineStdVColorMask > 0.5) {
                    float vc = (_OutlineStdVColorChannel < 0.5) ? v.color.r : (_OutlineStdVColorChannel < 1.5) ? v.color.g : (_OutlineStdVColorChannel < 2.5) ? v.color.b : v.color.a;
                    m *= vc;
                }
                float w = (_OutlineStdWidth * 0.01) * m * step(0.5, _OutlineStdEnable);
                float3 wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                if (_OutlineStdDistFade > 0.5) {   // EXPERIMENTAL: thin the shell with camera distance
                    float camDist = distance(_WorldSpaceCameraPos, wpos);
                    w *= saturate((_OutlineStdFadeFar - camDist) / max(_OutlineStdFadeFar - _OutlineStdFadeNear, 0.001));
                }
                if (_OutlineStdWidthMode > 0.5) {
                    // Screen: constant on-screen thickness (offset in clip space, aspect-corrected)
                    float4 clip = UnityObjectToClipPos(v.vertex);
                    float3 vN = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normal));
                    clip.xy += vN.xy * w * clip.w * float2(_ScreenParams.y / _ScreenParams.x, 1.0) * 2.0;
                    o.pos = clip;
                } else {
                    // World: fixed thickness in metres
                    o.pos = mul(UNITY_MATRIX_VP, float4(wpos + o.wNrm * w, 1.0));
                }
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }
            fixed4 fragOL(v2fOL i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                clip(_OutlineStdEnable - 0.5);
                fixed4 albedo = _MainTex.Sample(sampler_MainTex, i.uv);
                if (_AlphaMode > 0.5) clip(GetOpacity(albedo.a, i.uv) - _Cutoff);   // respect cutout/transparent shape
                half3 oc = _OutlineStdColor.rgb;
                oc = lerp(oc, oc * albedo.rgb, saturate(_OutlineStdTexTint));
                if (_OutlineStdLit > 0.5) {
                    half3 n = normalize(i.wNrm);
                    half ndl = saturate(dot(n, _WorldSpaceLightPos0.xyz)) * 0.5 + 0.5;
                    oc *= saturate(_LightColor0.rgb * ndl + ShadeSH9(half4(n, 1)));
                }
                fixed4 col = fixed4(oc, 1.0);
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
//endex
        // ==============================================================================
        // PASS 2: FORWARDADD (Direct Lighting ONLY)
        // ==============================================================================
        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One   
            ZWrite Off 
            CGPROGRAM
            #pragma vertex vert
            #pragma hull hull
            #pragma domain dom
            #pragma geometry geom
            #pragma fragment fragAdd
            #pragma target 5.0
            #pragma multi_compile_fwdadd_fullshadows
            #pragma shader_feature_local _ ZET_DEC1
            #pragma shader_feature_local _ ZET_DEC2
            #pragma shader_feature_local _ ZET_DEC3
            #pragma multi_compile_fog
                #if defined(ZET_DEC1)
                    Texture2D _Decal1Tex;
                #endif
                #if defined(ZET_DEC2)
                    Texture2D _Decal2Tex;
                #endif
                #if defined(ZET_DEC3)
                    Texture2D _Decal3Tex;
                #endif
            struct appdata {
                float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 uv : TEXCOORD0; float2 uv1 : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2g {
                float4 objPos : TEXCOORD1; float3 normal : NORMAL; float4 tangent : TANGENT; float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct g2f {
                float4 pos : SV_POSITION; 
                float2 uv : TEXCOORD0; 
                float4 fx : TEXCOORD1;   
                float3 wNrm : TEXCOORD2; 
                UNITY_FOG_COORDS(3) 
                float3 wPos : TEXCOORD4; 
                float3 bary : TEXCOORD5; 
                float4 wTan : TEXCOORD6; 
                SHADOW_COORDS(7)
                #ifdef VERTEXLIGHT_ON
                float3 vLights : TEXCOORD8;
                #endif
                UNITY_VERTEX_OUTPUT_STEREO
            };
            v2g vert(appdata v) {
                v2g o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                if (ZetUVTileDiscarded(v.uv, v.uv1) > 0.5) v.vertex = asfloat(0x7FC00000).xxxx;   // NaN culls the triangle
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                float3 zp = v.vertex.xyz;
                float3 zn = v.normal;
                float3 zt = v.tangent.xyz;
                ZetApplyVertexAL(zp, zn, zt, v.uv, o.uv);
                ZetApplyPlasmaDisplace(zp, zn);
                o.objPos = float4(zp, v.vertex.w);
                o.normal = zn;
                o.tangent = float4(zt, v.tangent.w);
                return o;
            }
            struct TessFactors { float edge[3] : SV_TessFactor; float inside : SV_InsideTessFactor; };
            TessFactors patchConstant(InputPatch<v2g, 3> patch) {
                if (_BreakEnable < 0.5) {   // v64: skip the 3 mask samples when break is off
                    TessFactors o1; o1.edge[0] = 1.0; o1.edge[1] = 1.0; o1.edge[2] = 1.0; o1.inside = 1.0; return o1;
                }
                float f = 1.0;
                float mask = max(max(_MaskTex.SampleLevel(sampler_LinearClamp, patch[0].uv, 0).r, _MaskTex.SampleLevel(sampler_LinearClamp, patch[1].uv, 0).r), _MaskTex.SampleLevel(sampler_LinearClamp, patch[2].uv, 0).r);
                float3 centerPos = (patch[0].objPos.xyz + patch[1].objPos.xyz + patch[2].objPos.xyz) / 3.0;
                float3 worldPos = mul(unity_ObjectToWorld, float4(centerPos, 1.0)).xyz;
                float distFactor = saturate((_TessFar - distance(worldPos, _WorldSpaceCameraPos)) / max(_TessFar - _TessNear, 0.001));
                f = (_BreakEnable > 0.5 && mask > 0.2) ? max(lerp(1.0, _Tessellation, distFactor), 1.0) : 1.0;
                TessFactors o; o.edge[0] = f; o.edge[1] = f; o.edge[2] = f; o.inside = f; return o;
            }
            [domain("tri")] [outputcontrolpoints(3)] [outputtopology("triangle_cw")] [partitioning("integer")] [patchconstantfunc("patchConstant")]
            v2g hull(InputPatch<v2g, 3> patch, uint id : SV_OutputControlPointID) { return patch[id]; }
            [domain("tri")]
            v2g dom(TessFactors f, OutputPatch<v2g, 3> patch, float3 b : SV_DomainLocation) {
                v2g o;
                UNITY_TRANSFER_INSTANCE_ID(patch[0], o);
                o.objPos  = patch[0].objPos * b.x + patch[1].objPos * b.y + patch[2].objPos * b.z;
                o.normal  = normalize(patch[0].normal * b.x + patch[1].normal * b.y + patch[2].normal * b.z);
                o.tangent = float4(normalize(patch[0].tangent.xyz * b.x + patch[1].tangent.xyz * b.y + patch[2].tangent.xyz * b.z), patch[0].tangent.w);
                o.uv      = patch[0].uv * b.x + patch[1].uv * b.y + patch[2].uv * b.z; return o;
            }
            [maxvertexcount(3)]   // main triangle only: core backfaces and speaker rings are not emitted in ForwardAdd
            void geom(triangle v2g i[3], inout TriangleStream<g2f> stream) {
                UNITY_SETUP_INSTANCE_ID(i[0]);
                float3 center   = (i[0].objPos.xyz + i[1].objPos.xyz + i[2].objPos.xyz) / 3.0;
                float3 faceNrm  = normalize(i[0].normal + i[1].normal + i[2].normal);
                float2 uvCenter = (i[0].uv + i[1].uv + i[2].uv) / 3.0;
                bool alAvail = AudioLinkIsAvailable();
                float rnd = 0, t = 0, heat = 0;
                if (_BreakEnable > 0.5) {
                    float mask = 0;
                    if (_BreakMode < 0.5) {
                        float2 cell = floor(uvCenter * _GridSize) / _GridSize;
                        mask  = _MaskTex.SampleLevel(sampler_LinearClamp, cell, 0).r;
                        rnd = hash2(cell);
                        float audio = alAvail ? ALEnv((uint)_Band) : 0.0;
                        float drive = saturate(audio * mask - _Threshold) / max(1.0 - _Threshold, 0.0001);
                        t = smoothstep(0.0, 1.0, saturate((drive - rnd) * 2.0));
                        heat = smoothstep(rnd * 0.15, max(rnd, 0.02), drive);
                    } else {
                        mask = _MaskTex.SampleLevel(sampler_LinearClamp, uvCenter, 0).r;
                        rnd = hash2(uvCenter * 57.31);
                        float heightW = mul(unity_ObjectToWorld, float4(center, 1)).y - unity_ObjectToWorld._m13;
                        float coord = saturate((heightW - _WaveBottom) / max(_WaveTop - _WaveBottom, 0.001));
                        float audio = alAvail ? AudioLinkLerp(ALPASS_AUDIOLINK + float2(coord * 127.0, (uint)_Band)).r : 0.0;
                        float level = saturate((audio * mask - _Threshold) / max(1.0 - _Threshold, 0.0001));
                        float startE = 0.15 + rnd * 0.35;
                        t = smoothstep(startE, 0.85 + rnd * 0.15, level);
                        heat = smoothstep(startE * 0.15, startE, level);
                    }
                    if (_BreakDrive > 0.5) {
                        float ph = _Time.y * _FloatSpeed + rnd * 6.2831 * _FloatStagger;
                        float floatT = smoothstep(0.0, 1.0, sin(ph) * 0.5 + 0.5) * _FloatReach;
                        float nudge = (alAvail && _FloatAudio > 0.001) ? ALEnv((uint)_Band) * _FloatAudio : 0.0;
                        t = saturate((floatT + nudge) * mask);
                        heat = smoothstep(0.0, 0.6, t);
                    }
                }
                float glitchAmt = 0, tick = 0;
                if (_GlitchEnable > 0.5) {
                    float gMask = _GlitchMask.SampleLevel(sampler_LinearClamp, uvCenter, 0).r;
                    float ga = alAvail ? ALEnv((uint)_GlitchBand) : 0.0;
                    glitchAmt = ga * step(_GlitchThreshold, ga) * gMask;
                    tick = floor(_Time.y * 15.0);
                }
                // Core Backfaces
                // (Removed from ForwardAdd pass entirely to save geometry fill rate!
                // fragAdd unconditionally returns black for core backfaces (i.fx.x < -0.5),
                // and with Blend One One black adds nothing - emitting them here is wasted math.)
                float phase = _Time.y * 3.0 + rnd * 6.2831;
                float3 upO = normalize(mul((float3x3)unity_WorldToObject, float3(0, 1, 0)));
                float3 driftO = normalize(mul((float3x3)unity_WorldToObject, float3(sin(phase), 0, cos(phase))));
                float3 offset = upO * (t * _RiseHeight * (0.5 + rnd)) + faceNrm * (t * _Spread) + driftO * (_Jitter * t);
                float3 axis = normalize(float3(hash2(uvCenter + 1.7), hash2(uvCenter + 3.9), hash2(uvCenter + 7.3)) - 0.5 + 1e-4);
                float ang = (rnd * 2.0 - 1.0) * _Tumble * t;
                float gap = _EdgeGap * smoothstep(0.0, 0.15, t);
                [unroll] for (int j = 0; j < 3; j++) {
                    g2f o; UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                    float3 rel = lerp(i[j].objPos.xyz, center, saturate(t * _Shrink + gap)) - center;
                    rel = rotAround(rel, axis, ang);
                    float3 p = center + rel + offset;
                    if (glitchAmt > 0.001) {
                        float3 wP = mul(unity_ObjectToWorld, float4(p, 1)).xyz;
                        float3 voxel = floor(wP * _GlitchSlices);
                        float2 seed = float2(voxel.x * 3.1 + voxel.z * 7.3, voxel.y * 5.1 + tick);
                        float active = step(0.7, hash2(seed));
                        float3 glitchDir = normalize(float3(hash2(seed + 1.2)*2-1, hash2(seed + 3.4)*2-1, hash2(seed + 5.6)*2-1));
                        p += glitchDir * _GlitchIntensity * glitchAmt * active;
                    }
                    o.pos = UnityObjectToClipPos(float4(p, 1));
                    o.uv = i[j].uv; o.fx = float4(t, heat, glitchAmt, 0.0);
                    o.wNrm = UnityObjectToWorldNormal(rotAround(i[j].normal, axis, ang));
                    o.wTan = float4(UnityObjectToWorldDir(rotAround(i[j].tangent.xyz, axis, ang)), i[j].tangent.w);
                    o.wPos = mul(unity_ObjectToWorld, float4(p, 1)).xyz;
                    #ifdef VERTEXLIGHT_ON
                        // Demoted (non-important / over-budget) point lights land in
                        // the unity_4LightPos arrays instead of ForwardAdd. Without
                        // this, an avatar goes flat the moment the camera's pixel
                        // light ranking drops a light - while mirrors, ranking their
                        // own smaller set, keep it. Per-vertex by design: cheap.
                        o.vLights = Shade4PointLights(
                            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                            unity_4LightAtten0, o.wPos, o.wNrm);
                    #endif
                    o.bary = (j == 0) ? float3(1,0,0) : (j == 1) ? float3(0,1,0) : float3(0,0,1);
                    DummyAppdata v; v.vertex = float4(p, 1);
                    ZET_TRANSFER_SHADOW(o); UNITY_TRANSFER_FOG(o, o.pos); stream.Append(o);
                }
                stream.RestartStrip();
                // Hologram Speaker Rings
                // (Removed from ForwardAdd pass entirely to save geometry fill rate!
                // fragAdd automatically returns black for rings (i.fx.w > 0.5), so emitting them here is wasted math.)
            }
            fixed4 fragAdd(g2f i, fixed facing : VFACE) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
//ifex _DebugView==0
                // ForwardAdd blends additively over the base pass, so every extra
                // realtime light would wash colour across a debug view that is
                // supposed to show one isolated term. Contribute nothing instead.
                if (_DebugView > 0.5) return fixed4(0, 0, 0, 0);
//endex
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
                bool alAvail = AudioLinkIsAvailable();
                if (i.fx.w > 0.5) return float4(0,0,0,1); 
                if (_DissolveEnable > 0.5) {
                    float dNoise = _DissolveTex.Sample(sampler_LinearRepeat, i.uv).r;
                    float alD = alAvail ? ALEnv((uint)_DissolveBand) : 0.0;
                    clip(dNoise - saturate((_DissolveAmount * 0.01) + (alD * (_DissolveAL * 0.01)))); 
                }
                if (i.fx.x < -0.5 || (facing < 0 && i.fx.x > 0.001)) return float4(0,0,0,1);
                float bFade = _BreakFade; if (_BreakManual < 0.5) { float _bg = _BreakCoreGlow; ApplyBreakStyle(_BreakStyle, _bg, bFade); }
                if (bFade > 0.001 && i.fx.x > 0.001) { float fadeN = hash2(i.uv * 97.0); clip(fadeN - saturate(i.fx.x) * bFade); }
                fixed4 albedo = _MainTex.Sample(sampler_MainTex, i.uv);
                if (_DetailEnable > 0.5) {
                    half dMask = _DetailMask.Sample(sampler_LinearRepeat, i.uv).r;
                    if (dMask > 0.001) {
                        half3 dAlb = _DetailAlbedo.Sample(sampler_LinearRepeat, i.uv * _DetailTiling.xy + _DetailTiling.zw).rgb;
                        albedo.rgb *= lerp(half3(1, 1, 1), dAlb * 2.0, _DetailAlbedoStrength * dMask);   // 2x: mid grey is neutral
                    }
                }
                if (_AlphaMode > 0.5) {
                    half op = GetOpacity(albedo.a, i.uv);
                    if (_AlphaMode > 1.5) albedo.rgb *= saturate(op);   // additive light respects coverage when transparent
                    else clip(op - _Cutoff);
                }
                if (i.fx.z > 0.001) {
                    float2 split = float2(_GlitchRGBSplit * i.fx.z, 0);
                    albedo.r = _MainTex.Sample(sampler_MainTex, i.uv + split).r; albedo.b = _MainTex.Sample(sampler_MainTex, i.uv - split).b;
                    if (_GlitchHue > 0.001) {
                        float3 voxel = floor(i.wPos * _GlitchSlices); float2 seed = float2(voxel.x * 3.1 + voxel.z * 7.3, voxel.y * 5.1 + floor(_Time.y * 15.0));
                        if (step(0.7, hash2(seed)) > 0.5) {
                            float rc = hash2(seed + 8.9); half3 neon = rc > 0.66 ? half3(0,1,1) : rc > 0.33 ? half3(0,1,0) : half3(1,0,1);
                            albedo.rgb = lerp(albedo.rgb, neon, saturate(_GlitchHue * i.fx.z));
                        }
                    }
                }
                if (_ColorAdjustEnable > 0.5) {
                    if (_BaseHueShift > 0.0 || _BaseHueShiftAL > 0.5) {
                        float hueAmt = _BaseHueShift + (alAvail ? ALEnv((uint)_BaseHueBand) * _BaseHueShiftAL : 0.0);
                        albedo.rgb = hueShift(albedo.rgb, hueAmt * 6.28318);
                    }
                    half3 gray = dot(albedo.rgb, half3(0.299, 0.587, 0.114)).xxx;
                    albedo.rgb = lerp(gray, albedo.rgb, _Saturation);
                    albedo.rgb *= _Brightness;
                    albedo.rgb = pow(max(albedo.rgb, 0), _Gamma);
                }
                half3 decalEmiss = 0;
                if (_DecalsEnable > 0.5) {
                    if (_Decal0Enable > 0.5 && _Decal0Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal0Tex, sampler_LinearClamp, float2(_Decal0PosX, _Decal0PosY), _Decal0Scale, _Decal0Rotation, _Decal0Color, _Decal0Opacity, _Decal0Blend, _Decal0Emit, float4(_Decal0FlipCols, _Decal0FlipRows, _Decal0FlipFPS, _Decal0Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #if defined(ZET_DEC1)
                    if (_Decal1Enable > 0.5 && _Decal1Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal1Tex, sampler_LinearClamp, float2(_Decal1PosX, _Decal1PosY), _Decal1Scale, _Decal1Rotation, _Decal1Color, _Decal1Opacity, _Decal1Blend, _Decal1Emit, float4(_Decal1FlipCols, _Decal1FlipRows, _Decal1FlipFPS, _Decal1Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #endif
                    #if defined(ZET_DEC2)
                    if (_Decal2Enable > 0.5 && _Decal2Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal2Tex, sampler_LinearClamp, float2(_Decal2PosX, _Decal2PosY), _Decal2Scale, _Decal2Rotation, _Decal2Color, _Decal2Opacity, _Decal2Blend, _Decal2Emit, float4(_Decal2FlipCols, _Decal2FlipRows, _Decal2FlipFPS, _Decal2Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #endif
                    #if defined(ZET_DEC3)
                    if (_Decal3Enable > 0.5 && _Decal3Overlay < 0.5) albedo.rgb = ApplyDecal(_Decal3Tex, sampler_LinearClamp, float2(_Decal3PosX, _Decal3PosY), _Decal3Scale, _Decal3Rotation, _Decal3Color, _Decal3Opacity, _Decal3Blend, _Decal3Emit, float4(_Decal3FlipCols, _Decal3FlipRows, _Decal3FlipFPS, _Decal3Flipbook), i.uv, albedo.rgb, decalEmiss);
                    #endif
                }
                half4 packed = SamplePackedMap(i.uv);
                half metRaw = packed.r;
                half smoSrc = (_PackMode > 0.5) ? packed.a : packed.b;
                half smoRaw = (_InvSmooth > 0.5) ? (1.0 - smoSrc) : smoSrc;
                half metallic   = lerp(_MetallicMin, _Metallic, metRaw);   // floor 0 makes this metRaw * _Metallic
                half smoothness = lerp(_SmoothnessMin, _Smoothness, smoRaw);
                float3 nTS = UnpackScaleNormal(_BumpMap.Sample(sampler_MainTex, i.uv), _BumpScale);
                if (_DetailEnable > 0.5) {
                    half dMaskN = _DetailMask.Sample(sampler_LinearRepeat, i.uv).r;
                    float3 dTS = UnpackScaleNormal(_DetailNormal.Sample(sampler_LinearRepeat, i.uv * _DetailTiling.xy + _DetailTiling.zw), _DetailNormalStrength * dMaskN);
                    nTS = normalize(float3(nTS.xy + dTS.xy, nTS.z * dTS.z));   // whiteout blend
                }
                if (_HeightToNormalEnable > 0.5) {
                    float2 ts = float2(0.002, 0.002);
                    float hC = _HeightMap.Sample(sampler_MainTex, i.uv).r;
                    float hR = _HeightMap.Sample(sampler_MainTex, i.uv + float2(ts.x, 0)).r;
                    float hU = _HeightMap.Sample(sampler_MainTex, i.uv + float2(0, ts.y)).r;
                    float3 heightNorm = normalize(float3((hC - hR) * _HeightStrength, (hC - hU) * _HeightStrength, 1.0));
                    nTS = normalize(float3(nTS.xy + heightNorm.xy, nTS.z));
                }
                float3 wN = normalize(i.wNrm);
                float3 T = normalize(i.wTan.xyz);
                float3 B = cross(wN, T) * (i.wTan.w * unity_WorldTransformParams.w);
                if (facing < 0) { wN = -wN; B = -B; }   // v64: flip the frame, not the bumped result
                float3 n = normalize(T * nTS.x + B * nTS.y + wN * nTS.z);
                float dither = (frac(52.9829189 * frac(dot(i.pos.xy, float2(0.06711056, 0.00583715)))) - 0.5) * _ShadowDither;
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - i.wPos * _WorldSpaceLightPos0.w);
                float3 H = normalize(lightDir + viewDir);
                float ndl = dot(n, lightDir);
                #if defined(SHADOWS_SHADOWMASK) && !defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON)
                    float atten = 1.0;
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.wPos);
                #endif
                atten = lerp(1.0, atten, _ReceiveShadows);
                
                half ramp;
                if (_LightingModel < 0.5) {
                    ramp = smoothstep(_ShadowEdge - _ShadowSoft, _ShadowEdge + _ShadowSoft, (ndl * 0.5 + 0.5) + dither) * atten;
                } else if (_LightingModel < 1.5) {
                    ramp = saturate(ndl) * atten;
                } else {
                    // Cloth: wrapped diffuse - fibers scatter light past the terminator
                    ramp = saturate((ndl + _ClothWrap) / (1.0 + _ClothWrap)) * atten;
                }
                float3 lightCol = _LightColor0.rgb;
                float lum = dot(lightCol, float3(0.299, 0.587, 0.114));
                lightCol = lerp(lightCol, float3(lum, lum, lum), _GrayscaleLighting);
                lightCol = clamp(lightCol, _MinBrightness, _MaxBrightness);
                half3 diffuseCol = albedo.rgb * (1.0 - metallic);
                half3 direct  = lightCol * lerp(_ShadowTint.rgb, half3(1, 1, 1), ramp);
                fixed4 col = fixed4(diffuseCol * direct, 1.0);
                // Subsurface Scattering for this light (no ambient term in Add pass)
                if (_SSSEnable > 0.5) {
                    half sssMask = _SSSMask.Sample(sampler_LinearRepeat, i.uv).r;
                    if (sssMask > 0.001) {
                        half3 sssTint = ZetSSSTint(albedo.rgb);
                        float hLam = ndl * 0.5 + 0.5;
                        float edgeMid = (_LightingModel < 0.5) ? _ShadowEdge : 0.5;
                        float sssW = _SSSTermWidth * 0.5 + 1e-3;
                        float band = smoothstep(edgeMid - sssW, edgeMid, hLam) * (1.0 - smoothstep(edgeMid, edgeMid + sssW, hLam));
                        half3 sssAdd = lightCol * atten * band * (_SSSTermStrength * sssMask) * sssTint;
                        half thin = (1.0 - _SSSThicknessMap.Sample(sampler_LinearRepeat, i.uv).r) * sssMask;
                        if (thin > 0.001) {
                            float3 vLTraw = lightDir + n * _SSSTransDistortion;
                            float3 vLT = vLTraw * rsqrt(max(dot(vLTraw, vLTraw), 1e-6));
                            float lt = pow(saturate(dot(viewDir, -vLT)), _SSSTransPower);
                            sssAdd += lightCol * atten * lt * (thin * _SSSTransStrength) * sssTint;
                        }
                        col.rgb += diffuseCol * sssAdd;
                    }
                }
                half spec = pow(saturate(dot(n, H)), exp2(smoothness * 9.0 + 1.0));
                half3 specCol = lerp(half3(0.04, 0.04, 0.04), albedo.rgb, metallic);
                
                half3 anisoAdd = 0;
                if (_AnisoEnable > 0.5) {
                    float3 anisoDir;
                    if (_AnisoDirMode > 1.5) {
                        float3 odir = _AnisoObjectMap.Sample(sampler_LinearRepeat, i.uv).rgb * 2.0 - 1.0;
                        float3 owdir = mul((float3x3)unity_ObjectToWorld, odir);
                        anisoDir = (dot(odir, odir) > 1e-5) ? normalize(owdir) : T;
                    } else if (_AnisoDirMode > 0.5) {
                        float2 aflow = _AnisoFlowMap.Sample(sampler_LinearRepeat, i.uv).rg * 2.0 - 1.0;
                        float3 fdir = aflow.x * T + aflow.y * B;
                        anisoDir = (dot(fdir, fdir) > 1e-5) ? normalize(fdir) : T;
                    } else {
                        anisoDir = _AnisoDir > 0.5 ? B : T;
                    }
                    anisoDir = normalize(anisoDir + n * _AnisoShift);
                    float dotDH = dot(anisoDir, H);
                    float sinDH = sqrt(max(0.0, 1.0 - dotDH * dotDH)); 
                    float anisoSpec = pow(sinDH, exp2(smoothness * 9.0 + 1.0 + (_AnisoPower - 5.0) * 0.5)) * _AnisoStrength;
                    anisoSpec *= _AnisoMask.Sample(sampler_LinearRepeat, i.uv).r;
                    // additive tinted anisotropic lobe, weighted toward reflective (smooth/metallic) areas
                    anisoAdd = _AnisoColor.rgb * anisoSpec * lerp(0.5, 1.0, saturate(smoothness + metallic));
                }
                
                if (_LightingModel < 0.5) {
                    col.rgb += specCol * lightCol * smoothstep(0.5 - _SpecEdge, 0.5 + _SpecEdge, spec) * ramp;
                } else if (_LightingModel < 1.5) {
                    col.rgb += specCol * lightCol * spec * ramp;
                } else {
                    // Charlie sheen (Estevez-Kulla NDF, Neubelt-Pettineo visibility):
                    // an inverted-Gaussian lobe that peaks at grazing angles - the
                    // velvet halo - instead of a mirror-direction hotspot.
                    float clothA = max(1.0 - smoothness, 0.07);
                    float sNoH = saturate(dot(n, H)); sNoH *= sNoH;
                    float dSheen = (2.0 + 1.0 / clothA) * pow(1.0 - sNoH, 0.5 / clothA) / (2.0 * UNITY_PI);
                    float sNoV = saturate(dot(n, viewDir));
                    float sNoL = saturate(ndl);
                    float visSheen = 1.0 / (4.0 * (sNoL + sNoV - sNoL * sNoV) + 1e-4);
                    col.rgb += _SheenColor.rgb * lightCol * (dSheen * visSheen * sNoL * atten);
                }
                col.rgb += anisoAdd * lightCol * ramp;
                if (_StyleSpecEnable > 0.5) {
                    float ssNdh = saturate(dot(n, H));
                    float ssMask = _StyleSpecMask.Sample(sampler_LinearRepeat, i.uv).r;
                    float ssLayers =
                        smoothstep(1.0 - _SS1Size - _SS1Feather, 1.0 - _SS1Size + _SS1Feather, ssNdh) * _SS1Strength +
                        smoothstep(1.0 - _SS2Size - _SS2Feather, 1.0 - _SS2Size + _SS2Feather, ssNdh) * _SS2Strength +
                        smoothstep(1.0 - _SS3Size - _SS3Feather, 1.0 - _SS3Size + _SS3Feather, ssNdh) * _SS3Strength;
                    half3 ssCol = _StyleSpecTint.rgb * ((_StyleSpecUseLight > 0.5) ? lightCol : half3(1, 1, 1));
                    col.rgb += ssCol * ssLayers * ssMask * ramp;
                }
                
                if (_Spec2Enable > 0.5) {
                    float spec2Mask = _Spec2Mask.Sample(sampler_LinearRepeat, i.uv).r;
                    half spec2 = pow(saturate(dot(n, H)), exp2(_Spec2Smoothness * 9.0 + 1.0));
                    
                    if (_LightingModel < 0.5) {
                        col.rgb += _Spec2Color.rgb * smoothstep(0.5 - _SpecEdge, 0.5 + _SpecEdge, spec2) * spec2Mask * lightCol * ramp;
                    } else {
                        col.rgb += _Spec2Color.rgb * spec2 * spec2Mask * lightCol * ramp;
                    }
                }
                if (_RoomEnable > 0.5) {
                    float rMaskA = smoothstep(0.5 - _RoomEdge, 0.5 + _RoomEdge, _RoomMask.Sample(sampler_MainTex, i.uv).r);
                    col.rgb *= (1.0 - rMaskA);
                }
                if (_ScreenEnable > 0.5) {
                    float scrMaskA = _ScreenMask.Sample(sampler_MainTex, i.uv).r;
                    col.rgb *= (1.0 - scrMaskA);
                }
//ifex _RefractEnable==0
                if (_RefractEnable > 0.5) {
                    float rfMaskA = _RefractMask.Sample(sampler_MainTex, i.uv).r;
                    col.rgb *= (1.0 - rfMaskA * _RefractBlend);
                }
//endex
                UNITY_APPLY_FOG(i.fogCoord, col);
                return fixed4(col.rgb, 1.0);
            }
            ENDCG
        }
        // ==============================================================================
        // PASS 3: SHADOWCASTER
        // ==============================================================================
        
        Pass
        {
            Tags { "LightMode" = "ShadowCaster" }
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster
            struct appdata_shadow {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct v2f_shadow { 
                V2F_SHADOW_CASTER; 
                float2 uv : TEXCOORD1; 
                float heightW : TEXCOORD2; 
                UNITY_VERTEX_OUTPUT_STEREO
            };
            v2f_shadow vertShadow(appdata_shadow v) {
                v2f_shadow o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                if (ZetUVTileDiscarded(v.texcoord.xy, v.uv1) > 0.5) v.vertex = asfloat(0x7FC00000).xxxx;   // hidden parts cast no shadows
                
                float2 stUV = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                float3 zp = v.vertex.xyz; float3 zn = v.normal; float3 zt = float3(1, 0, 0);
                ZetApplyVertexAL(zp, zn, zt, v.texcoord.xy, stUV);
                
                v.vertex.xyz = zp;
                v.normal = zn;
                
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o); // Added the critical semicolon here
                
                o.uv = stUV;
                o.heightW = mul(unity_ObjectToWorld, v.vertex).y - unity_ObjectToWorld._m13;
                return o;
            }
            float4 fragShadow(v2f_shadow i) : SV_Target {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                bool alAvail = AudioLinkIsAvailable();
                
                if (_DissolveEnable > 0.5) {
                    float dNoise = _DissolveTex.Sample(sampler_LinearRepeat, i.uv).r;
                    float alD = 0; if (alAvail) alD = ALEnv((uint)_DissolveBand);
                    float dLevel = saturate((_DissolveAmount * 0.01) + (alD * (_DissolveAL * 0.01)));
                    clip(dNoise - dLevel); 
                }
                if (_BreakEnable > 0.5) {
                    float bMask = _MaskTex.Sample(sampler_LinearClamp, i.uv).r;
                    float drive;
                    if (_BreakDrive > 0.5) {
                        float rnd = hash2(i.uv * 57.31);
                        float ph = _Time.y * _FloatSpeed + rnd * 6.2831 * _FloatStagger;
                        drive = smoothstep(0.0, 1.0, sin(ph) * 0.5 + 0.5) * _FloatReach * bMask;
                    } else {
                        float audio = 0; if (alAvail) audio = _BreakMode < 0.5 ? ALEnv((uint)_Band) : AudioLinkLerp(ALPASS_AUDIOLINK + float2(saturate((i.heightW - _WaveBottom) / max(_WaveTop - _WaveBottom, 0.001)) * 127.0, (uint)_Band)).r;
                        drive = saturate((audio * bMask - _Threshold) / max(1.0 - _Threshold, 0.0001));
                    }
                    clip(0.5 - drive);
                    float bFade = _BreakFade; if (_BreakManual < 0.5) { float _bg = _BreakCoreGlow; ApplyBreakStyle(_BreakStyle, _bg, bFade); }
                    if (bFade > 0.001) { float fadeN = hash2(i.uv * 97.0); clip(fadeN - drive * bFade); }
                }
                
                if (_AlphaMode > 0.5) clip(GetOpacity(_MainTex.Sample(sampler_MainTex, i.uv).a, i.uv) - _Cutoff);
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    CustomEditor "Zetph.FancyShader.EditorUI.ZetMaterialInspector"
}
