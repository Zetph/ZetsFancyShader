// ==============================================================================
// ZetsFancyEyeShader - Eye Variant
// Version: v0.6.2
// Features: Convex-correct Reflections, Wetness Mask, Parallax,
// Anisotropic Highlights, Stylized Anime Specular, PBR specular lobe,
// LTCGI, and VRC Light Volumes (ambient + speculars).
//
// Optional integrations - neither is required to compile:
//   - LTCGI (at.pimaker.ltcgi)
//   - VRC Light Volumes 2.1.3+ (red.sim.lightvolumes)
// ZetIntegrationGenerator detects what is installed and writes
// Runtime/Generated/ZetIntegrations.cginc accordingly. Missing packages leave
// their feature inert rather than breaking the build.
// ==============================================================================
Shader "Zetph/ZetsFancyEyeShader"
{
    Properties
    {
        [HideInInspector] shader_master_label ("ZetsFancyEyeShader", Float) = 0
        [ZetLockButton] _ShaderOptimizerEnabled ("Lock / Optimize", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Culling Mode", Float) = 2
        [Group(base)] _MainTex ("Base Texture (Albedo)", 2D) = "white" {}
        [Normal] [Group(base)] _BumpMap ("Normal Map", 2D) = "bump" {}
        [Group(base)] _BumpScale ("Normal Strength", Range(0, 2)) = 1
        [Enum(Toon Ramp, 0, Realistic PBR, 1)] [Group(lighting)] _LightingModel ("Lighting Model", Float) = 0
        [ToggleUI] [Group(lighting)] _EyeWrapLight ("Wrapped Eye Lighting", Float) = 0
        [Group(lighting)] _MaxBrightness ("Max Light Brightness", Range(0, 5)) = 1.0
        [Group(lighting)] _MinBrightness ("Min Light Brightness", Range(0, 1)) = 0.0
        [Group(lighting)] _ReceiveShadows ("Receive Casted Shadows", Range(0, 1)) = 1.0
            [Group(lighting_toon)] _ShadowEdge ("Shadow Edge", Range(0, 1)) = 0.5
            [Group(lighting_toon)] _ShadowSoft ("Shadow Softness", Range(0.001, 0.5)) = 0.01
        [ToggleUI] [Group(lighting_toon)] _ProbeDirLight ("Shade From Probes", Float) = 1
        [Group(lighting_toon)] [ShowIf(_ProbeDirLight)] _ProbeDirStrength ("Probe Shading Strength", Range(0, 2)) = 1
            [Group(lighting_toon)] _ShadowDither ("Shadow Dithering", Range(0, 0.1)) = 0
            [Group(lighting_toon)] _ShadowTint ("Shadow Tint", Color) = (0.5, 0.5, 0.5, 1)
        [Enum(ZFS Packed, 0, Unity MetalSmooth, 1)] [Group(reflspec)] _PackMode ("Packed Map Format", Float) = 0
        [NoScaleOffset] [Group(reflspec)] _PackedMap ("Packed Map", 2D) = "white" {}
        [ToggleUI] [Group(reflspec)] _InvSmooth ("Map uses Roughness", Float) = 0
        [Group(reflspec)] _Metallic ("Metallic", Range(0, 1)) = 0
        [Group(reflspec)] _EyeSmoothness ("Smoothness", Range(0, 1)) = 0.5
        [Group(reflspec)] _OcclusionStrength ("AO Strength", Range(0, 1)) = 1
        [ZetMapPacker] [Group(reflspec)] _MapPackerUI ("Map Packer", Float) = 0
        [Group(reflspec)] [ShowIf(_LightingModel)] _SpecStrength ("PBR Specular Strength", Range(0, 4)) = 1
            [ToggleUI] [GroupToggle(reflspec_refl)] _UseEnvReflections ("Enable Reflection Probes", Float) = 1
            [NoScaleOffset] [Group(reflspec_refl)] _BakedCubemap ("Reflection Fallback Cubemap", Cube) = "black" {}
            [Group(reflspec_refl)] _FallbackCubemapStrength ("Fallback Strength", Range(0, 2)) = 1
            [HideInInspector] [Group(reflspec_refl)] _HasBakedCubemap ("", Float) = 0
            [Group(reflspec_refl)] _ReflStrength ("Reflection Strength", Range(0, 2)) = 1
            [ToggleUI] [Group(reflspec_refl)] _ReflFlipX ("Reflection Flip X (horizontal)", Float) = 0
            [ToggleUI] [Group(reflspec_refl)] _ReflFlipY ("Reflection Flip Y (vertical)", Float) = 1
            [ToggleUI] [GroupToggle(reflspec_aniso)] _AnisoEnable ("Enable Anisotropic Highlights", Float) = 0
            [HDR] [Group(reflspec_aniso)] _AnisoColor ("Anisotropic Color", Color) = (1, 1, 1, 1)
            [Enum(Tangent, 0, Bitangent, 1)] [Group(reflspec_aniso)] _AnisoDir ("Highlight Direction", Float) = 1
            [Group(reflspec_aniso)] _AnisoShift ("Highlight Offset", Range(-1, 1)) = 0
            [Group(reflspec_aniso)] _AnisoPower ("Highlight Sharpness", Range(0, 10)) = 5.0
            [Group(reflspec_aniso)] _AnisoStrength ("Highlight Strength", Range(0, 5)) = 1.0
            [ToggleUI] [GroupToggle(reflspec_stylespec)] _StyleSpecEnable ("Enable Stylized Specular", Float) = 0
            [HDR] [Group(reflspec_stylespec)] _StyleSpecTint ("Highlight Tint", Color) = (1, 1, 1, 1)
            [ToggleUI] [Group(reflspec_stylespec)] _StyleSpecUseLight ("Use Light Color", Float) = 1
            [Group(reflspec_stylespec)] _StyleSpecMask ("Highlight Mask", 2D) = "white" {}
            [Group(reflspec_stylespec)] _SS1Size ("Layer 1 Size", Range(0, 1)) = 0.3
            [Group(reflspec_stylespec)] _SS1Feather ("Layer 1 Feather", Range(0, 1)) = 0.1
            [Group(reflspec_stylespec)] _SS1Strength ("Layer 1 Strength", Range(0, 4)) = 1
            [Group(reflspec_stylespec)] _SS2Size ("Layer 2 Size", Range(0, 1)) = 0.15
            [Group(reflspec_stylespec)] _SS2Feather ("Layer 2 Feather", Range(0, 1)) = 0.05
            [Group(reflspec_stylespec)] _SS2Strength ("Layer 2 Strength", Range(0, 4)) = 0
            [Group(reflspec_stylespec)] _SS3Size ("Layer 3 Size", Range(0, 1)) = 0.07
            [Group(reflspec_stylespec)] _SS3Feather ("Layer 3 Feather", Range(0, 1)) = 0.02
            [Group(reflspec_stylespec)] _SS3Strength ("Layer 3 Strength", Range(0, 4)) = 0
        [HideInInspector] [Group(reflspec)] m_eye_fx ("Eye FX", Float) = 0
            [ToggleUI] [GroupToggle(reflspec_parallax)] _ParallaxEnable ("Enable Parallax Heightmapping", Float) = 0
            [Group(reflspec_parallax)] _HeightMap ("Height Map (B&W)", 2D) = "black" {}
            [Group(reflspec_parallax)] _ParallaxMask ("Parallax Mask", 2D) = "white" {}
            [Group(reflspec_parallax)] _ParallaxStrength ("Strength", Range(0, 0.2)) = 0.02
            [Group(reflspec_parallax)] _ParallaxOffset ("Offset (Height Bias)", Range(-1, 1)) = 0
            [Group(reflspec_parallax)] _ParallaxMipBias ("Mip Bias", Range(-2, 2)) = 0
            [ToggleUI] [GroupToggle(reflspec_wetness)] _WetnessEnable ("Enable Wetness/Tearline", Float) = 0
            [Group(reflspec_wetness)] _WetnessMask ("Wetness Mask", 2D) = "black" {}
            [HDR] [Group(reflspec_wetness)] _WetnessColor ("Wetness Color", Color) = (1, 1, 1, 1)
            [Group(reflspec_wetness)] _WetnessStrength ("Strength", Range(0, 1)) = 0.5
            [ToggleUI] [GroupToggle(reflspec_emission)] _EmissionEnable ("Enable Emission", Float) = 0
            [Group(reflspec_emission)] _EmissionMap ("Emission Texture", 2D) = "white" {}
            [Group(reflspec_emission)] _EmissionMask ("Emission Mask", 2D) = "white" {}
            [HDR] [Group(reflspec_emission)] _EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)
            [Group(reflspec_emission)] _EmissionStrength ("Emission Strength", Range(0, 8)) = 1
            [ToggleUI] [Group(reflspec_emission)] _EmissionAlbedoTint ("Tint by Albedo", Float) = 0
            [Enum(Pulse, 0, Sweep Up, 1, Center Out Pulse, 2)] [Group(reflspec_emission_emal)] [ShowIf(_EmALEnable)] _EmMode ("Audio Mode", Float) = 0
            [Group(reflspec_emission_emal)] [ShowIf(_EmMode, 2)] _EmPulseScale ("Center-Out Ring Spacing", Range(0, 20)) = 5
            [Group(reflspec_emission_emal)] [ShowIf(_EmMode, 2)] _EmCenter ("Pulse Center (UV)", Vector) = (0.5, 0.5, 0, 0)
            [ToggleUI] [Group(alenv)] _ALMasterEnable ("AudioLink Enabled", Float) = 1
            [ToggleUI] [Group(alenv)] _ALEnvEnable ("Enable AudioLink Smoothing", Float) = 1
            [Group(alenv)] [ShowIf(_ALEnvEnable)] _ALEnvRelease ("Release / Tail", Range(0, 1)) = 0.45
            [ToggleUI] [GroupToggle(reflspec_emission_emal)] [ShowIf(_EmissionEnable)] _EmALEnable ("Enable AudioLink Reactivity", Float) = 0
            [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(reflspec_emission_emal)] [ShowIf(_EmALEnable)] _EmBand ("Primary AL Band", Float) = 0
            [Group(reflspec_emission_emal)] [ShowIf(_EmALEnable)] _EmAL ("AL Boost (reactive brightness)", Range(0, 8)) = 2
            [ToggleUI] [Group(reflspec_emission_emal)] [ShowIf(_EmALEnable)] _EmHueOn ("AL Hue Shift", Float) = 0
            [ToggleUI] [Group(reflspec_emission_emal)] [ShowIf(_EmALEnable)] _EmVolBoost ("Boost by Overall Volume", Float) = 0
            [Group(reflspec_emission_emal)] [ShowIf(_EmVolBoost)] _EmVolAmt ("Volume Boost Amount", Range(0, 4)) = 1
            [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(reflspec_emission_emal_adj)] [ShowIf(_EmALEnable)] _EmMultBand ("Multiplier Band", Float) = 0
            [Group(reflspec_emission_emal_adj)] [ShowIf(_EmALEnable)] _EmMultAmt ("Multiplier Amount", Range(0, 4)) = 0
            [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] [Group(reflspec_emission_emal_adj)] [ShowIf(_EmALEnable)] _EmAddBand ("Additive Band", Float) = 3
            [Group(reflspec_emission_emal_adj)] [ShowIf(_EmALEnable)] _EmAddAmt ("Additive Amount", Range(0, 4)) = 0
            [ToggleUI] [GroupToggle(reflspec_emission_emlb)] [ShowIf(_EmissionEnable)] _EmLightBased ("Enable Light-Based Emission", Float) = 0
            [Group(reflspec_emission_emlb)] [ShowIf(_EmLightBased)] _EmMinEmiss ("Emission in Shadow", Range(0, 4)) = 1
            [Group(reflspec_emission_emlb)] [ShowIf(_EmLightBased)] _EmMaxEmiss ("Emission in Light", Range(0, 4)) = 1
            [Group(reflspec_emission_emlb)] [ShowIf(_EmLightBased)] _EmMinLight ("Min Lighting", Range(0, 1)) = 0
            [Group(reflspec_emission_emlb)] [ShowIf(_EmLightBased)] _EmMaxLight ("Max Lighting", Range(0, 1)) = 1
            [ToggleUI] [GroupToggle(reflspec_emission_emblink)] [ShowIf(_EmissionEnable)] _EmBlink ("Enable Blinking", Float) = 0
            [Group(reflspec_emission_emblink)] [ShowIf(_EmBlink)] _EmBlinkSpeed ("Blink Speed", Range(0, 20)) = 3
            [Group(reflspec_emission_emblink)] [ShowIf(_EmBlink)] _EmBlinkMin ("Blink Floor", Range(0, 1)) = 0
            [ToggleUI] [GroupToggle(reflspec_emission_emscan)] [ShowIf(_EmissionEnable)] _EmScan ("Enable Scan / Sweep", Float) = 0
            [Enum(UV, 0, Object Space, 1)] [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanSpace ("Sweep Space", Float) = 0
            [Enum(Linear, 0, Radial, 1, Angular, 2)] [Group(reflspec_emission_emscan)] [ShowIf(_EmScanSpace, 0)] _EmScanStyle ("Sweep Style", Float) = 0
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScanSpace, 0)] _EmScanAngle ("Sweep Angle", Range(0, 360)) = 0
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScanSpace, 0)] _EmScanCenter ("Sweep Center (UV)", Vector) = (0.5, 0.5, 0, 0)
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScanSpace, 1)] _EmScanAxis ("Sweep Direction (XYZ)", Vector) = (0, 1, 0, 0)
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScanSpace, 1)] _EmScanExtent ("Sweep Length (m)", Range(0.01, 4)) = 2
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScanSpace, 1)] _EmScanOrigin ("Sweep Start (m)", Range(-4, 4)) = -1
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanPhase ("Phase Offset", Range(-1, 1)) = 0
            [Enum(Loop, 0, Ping Pong, 1)] [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanMode ("Motion", Float) = 0
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanSpeed ("Speed", Range(0, 10)) = 1
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanWidth ("Band Width", Range(0.01, 1)) = 0.15
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanSoft ("Edge Softness", Range(0, 0.5)) = 0.05
            [Group(reflspec_emission_emscan)] [ShowIf(_EmScan)] _EmScanFloor ("Outside-Band Glow", Range(0, 1)) = 0
        [Toggle(LTCGI)] [GroupToggle(ltcgi)] _LTCGI ("LTCGI System", Float) = 0
        [Group(ltcgi)] [ShowIf(_LTCGI)] _LTCGIStrength ("LTCGI Strength", Range(0, 2)) = 1
        [ToggleUI] [Group(ltcgi)] [ShowIf(_LTCGI)] _LTCGITintOn ("Tint LTCGI", Float) = 0
        [Group(ltcgi)] [ShowIf(_LTCGI)] [ShowIf(_LTCGITintOn)] _LTCGIDiffuseTint ("LTCGI Diffuse Tint", Color) = (1, 1, 1, 1)
        [Group(ltcgi)] [ShowIf(_LTCGI)] [ShowIf(_LTCGITintOn)] _LTCGISpecularTint ("LTCGI Specular Tint", Color) = (1, 1, 1, 1)
        [Group(ltcgi)] [ShowIf(_LTCGI)] _LTCGIOcclusion ("LTCGI Occlusion", Range(0, 1)) = 1
        [Toggle(ZET_LIGHT_VOLUMES)] [GroupToggle(lightvolumes)] _LightVolumes ("Light Volumes System", Float) = 1
        [Group(lightvolumes)] _LightVolumesStrength ("Light Volumes Strength", Range(0, 2)) = 1
        [ToggleUI] [Group(lightvolumes)] _LightVolumesSpec ("Light Volume Speculars", Float) = 1
        [Group(lightvolumes)] _LVPointShading ("Point Light Shaping", Range(0, 4)) = 1
        // --- VRSL GI -------------------------------------------------------
        // No package required: the world publishes _Udon_VRSL_GI_LightTexture as
        // a global, like AudioLink's _AudioTexture. Unbound in worlds without it,
        // so the light count reads 0 and the loop never runs.
        [Toggle(ZET_VRSLGI)] [GroupToggle(vrslgi)] _VRSLGI ("VRSL GI System", Float) = 0
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGIStrength ("VRSL GI Strength", Range(0, 4)) = 1
        [ToggleUI] [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGISpecular ("VRSL GI Speculars", Float) = 1
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGISpecularMult ("Specular Multiplier", Range(0, 4)) = 1
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGISpecularClamp ("Specular Clamp", Range(0, 8)) = 2
        [Group(vrslgi)] [ShowIf(_VRSLGI)] _VRSLGIOcclusion ("Apply AO", Range(0, 1)) = 1

        // Debug views. Drives an //ifex, so Off strips every line from a locked
        // shader. Options come from ZetsFancyEyeShaderUI.json - see EnumDef.
        [Group(debug)] _DebugView ("Debug View", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" "VRCFallback" = "Toon" }
        Cull [_CullMode]
        CGINCLUDE
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityStandardUtils.cginc"
            // --- VRSL GI light data (world-published global) -------------------
            // Declared as uniform Texture2D<float4>, the same form as the main
            // shader and as _AudioTexture. A bare "Texture2D" declared beside the
            // pass-level slots broke Unity's sampler_MainTex -> _MainTex pairing.
            //
            // Row layout, addressed by Load(int3(x, row, 0)):
            //   row 0 : light colour rgb, .a = range multiplier
            //   row 1 : light position xyz, .w > 180 marks a spotlight
            //   row 2 : Load(int3(0,2,0)).r is the light COUNT
            //   row 3 : spot direction xyz, .w packs cone angle and edge blend
            uniform Texture2D<float4> _Udon_VRSL_GI_LightTexture;
            #define ZET_VRSL_MAX_LIGHTS 64

            Texture2D _MainTex; SamplerState sampler_MainTex;
            SamplerState sampler_LinearClamp;
            SamplerState sampler_LinearRepeat;
            Texture2D _HeightMap; Texture2D _ParallaxMask; Texture2D _BumpMap;
            Texture2D _PackedMap; Texture2D _WetnessMask; Texture2D _StyleSpecMask;
            Texture2D _EmissionMap; Texture2D _EmissionMask;
            TextureCube _BakedCubemap;
            CBUFFER_START(UnityPerMaterial)
            float _ProbeDirLight; float _ProbeDirStrength;
            float _LightingModel; float4 _MainTex_ST; float _BumpScale;
            float _ShadowEdge; float _ShadowSoft; float _ShadowDither; float4 _ShadowTint;
            float _MaxBrightness; float _MinBrightness; float _ReceiveShadows;
            float _UseEnvReflections; float _FallbackCubemapStrength; float _ReflStrength; float _ReflFlipX; float _ReflFlipY;
            float _HasBakedCubemap;
            float _Metallic; float _EyeSmoothness; float _OcclusionStrength; float _InvSmooth; float _SpecStrength; float _PackMode; float _EyeWrapLight;
            float _AnisoEnable; float _AnisoDir; float _AnisoShift; float _AnisoPower; float _AnisoStrength; float4 _AnisoColor;
            float _StyleSpecEnable; float4 _StyleSpecTint; float _StyleSpecUseLight;
            float _SS1Size; float _SS1Feather; float _SS1Strength;
            float _SS2Size; float _SS2Feather; float _SS2Strength;
            float _SS3Size; float _SS3Feather; float _SS3Strength;
            float _ParallaxEnable; float _ParallaxStrength; float _ParallaxOffset; float _ParallaxMipBias;
            float _WetnessEnable; float4 _WetnessColor; float _WetnessStrength;
            float _LTCGIStrength; float _LTCGITintOn; float4 _LTCGIDiffuseTint; float4 _LTCGISpecularTint; float _LTCGIOcclusion;
            float _LightVolumesStrength; float _LightVolumesSpec; float _LVPointShading;
            // [Toggle(KEYWORD)] declares the keyword; the float still needs
            // declaring to be readable at runtime, which is how an UNLOCKED
            // build learns the user switched the feature off (ifex is inert
            // until lock, and the optimizer does not carry keywords as defines).
            float _LightVolumes; float _LTCGI;
            float _DebugView;
            float _VRSLGI; float _VRSLGIStrength; float _VRSLGISpecular;
            float _VRSLGISpecularMult; float _VRSLGISpecularClamp; float _VRSLGIOcclusion;
            float _EmMode; float _EmPulseScale; float4 _EmCenter;
            float _ALMasterEnable; float _ALEnvEnable; float _ALEnvRelease; float _EmALEnable; float _EmBand; float _EmAL; float _EmHueOn; float _EmVolBoost; float _EmVolAmt;
            float _EmMultBand; float _EmMultAmt; float _EmAddBand; float _EmAddAmt;
            float _EmLightBased; float _EmMinEmiss; float _EmMaxEmiss; float _EmMinLight; float _EmMaxLight;
            float _EmBlink; float _EmBlinkSpeed; float _EmBlinkMin;
            float _EmScan; float _EmScanStyle; float _EmScanAngle; float4 _EmScanCenter; float _EmScanSpace; float4 _EmScanAxis; float _EmScanExtent; float _EmScanOrigin; float _EmScanPhase; float _EmScanMode; float _EmScanSpeed; float _EmScanWidth; float _EmScanSoft; float _EmScanFloor;
            float _EmissionEnable; float4 _EmissionMap_ST; float4 _EmissionColor; float _EmissionStrength; float _EmissionAlbedoTint;
            CBUFFER_END
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
            struct appdata { float4 vertex : POSITION; float3 normal : NORMAL; float4 tangent : TANGENT; float2 uv : TEXCOORD0; UNITY_VERTEX_INPUT_INSTANCE_ID };
            struct v2f { float4 pos : SV_POSITION; float2 uv : TEXCOORD0; float3 wNrm : TEXCOORD1; UNITY_FOG_COORDS(2) float3 wPos : TEXCOORD3; float4 wTan : TEXCOORD4; UNITY_SHADOW_COORDS(5) 
                #ifdef VERTEXLIGHT_ON
                float3 vLights : TEXCOORD6;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID UNITY_VERTEX_OUTPUT_STEREO };
            v2f vert(appdata v) {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.wNrm = UnityObjectToWorldNormal(v.normal);
                o.wTan = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
                o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                #ifdef VERTEXLIGHT_ON
                    // Demoted/over-budget point lights land in unity_4LightPos instead
                    // of ForwardAdd. Without this the eye goes black in realtime-lit
                    // worlds with no baked probes - exactly what the body picks up here.
                    o.vLights = Shade4PointLights(
                        unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                        unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                        unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                        unity_4LightAtten0, o.wPos, o.wNrm);
                #endif
                UNITY_TRANSFER_SHADOW(o, o.pos);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }
            float2 ParallaxOcclusion(Texture2D hmap, SamplerState samp, float2 uv, float2 dir, float strength, float offset, float mipBias) {
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
            void ApplyEyeFX(inout float2 uv, float3 viewDir, float3 lightDir, float3 N, float3 T, float3 B) {
                if (_ParallaxEnable > 0.5) {
                    float pMask = _ParallaxMask.Sample(sampler_LinearClamp, uv).r;
                    if (pMask > 0.001) {
                        float2 pdir = float2(dot(viewDir, T), dot(viewDir, B)) / max(dot(viewDir, N), 0.1);
                        uv = lerp(uv, ParallaxOcclusion(_HeightMap, sampler_LinearClamp, uv, pdir, _ParallaxStrength, _ParallaxOffset, _ParallaxMipBias), pMask);
                    }
                }
            }
            // Physically based specular, matching the main shader. Blinn-Phong has no
            // Fresnel and no shadowing term, so it gives a highlight and a lambert
            // gradient and nothing toward the silhouette, which reads flat on a curved
            // surface. GGX adds the Fresnel that carries edge shape.
            // --- AudioLink ---------------------------------------------------------
            // Read straight from the global the world publishes, so nothing needs
            // installing and the shader costs nothing in worlds without it.
            #define ALPASS_AUDIOLINK          uint2(0,0)
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
            bool AudioLinkIsAvailable()
            {
                // Master switch. Every AudioLink read passes through here, so turning
                // this off silences the lot at once. A plain float, so it animates from
                // a menu and can kill a material's reactivity without touching each
                // effect's own toggle.
                if (_ALMasterEnable < 0.5) return false;
                #ifndef ZET_AL_STDIDX
                    int width, height;
                    _AudioTexture.GetDimensions(width, height);
                    return width > 16;
                #else
                    return _AudioTexture_TexelSize.z > 16;
                #endif
            }
            // Matches the main shader's envelope exactly: fast attack, with a tail whose
            // length follows the AudioLink Response settings. Without it an eye set to the
            // same band as bodywork reacts more sharply and drops away faster, so the two
            // visibly disagree on the same music.
            float ALEnv(uint band) {
                float env = AudioLinkData(ALPASS_AUDIOLINK + uint2(0, band)).r;
                if (_ALEnvEnable < 0.5) return env;
                uint stride = (uint)max(1.0, lerp(1.0, 8.0, saturate(_ALEnvRelease)));
                [unroll]
                for (uint k = 1u; k < 12u; k++)
                    env = max(env, AudioLinkData(ALPASS_AUDIOLINK + uint2(k * stride, band)).r * exp2(-(float)k * 0.28));
                return env;
            }

            // Same signal chain as the main shader, so an eye set to a band reacts
            // identically to bodywork set to the same one.
            float ZetALSignal(float enable, float band, float multBand, float multAmt,
                              float addBand, float addAmt, float volBoost, float volAmt)
            {
                if (enable < 0.5 || !AudioLinkIsAvailable()) return 0.0;
                float sig = ALEnv((uint)band);
                sig *= (1.0 + ALEnv((uint)multBand) * multAmt);
                sig += ALEnv((uint)addBand) * addAmt;
                if (volBoost > 0.5) {
                    float vol = (ALEnv(0) + ALEnv(1) + ALEnv(2) + ALEnv(3)) * 0.25;
                    sig *= (1.0 + vol * volAmt);
                }
                return max(sig, 0.0);
            }

            half3 ZetEyeHueShift(half3 c, float a)
            {
                const half3 k = half3(0.57735, 0.57735, 0.57735);
                half co = cos(a);
                return c * co + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - co);
            }

            half3 ZetGGXSpecular(float3 n, float3 viewDir, float3 lightDir, float smoothness, half3 F0)
            {
                float3 H = normalize(viewDir + lightDir);
                float nl = saturate(dot(n, lightDir));
                float nv = saturate(dot(n, viewDir));
                float nh = saturate(dot(n, H));
                float vh = saturate(dot(viewDir, H));
                float rough = max(1.0 - smoothness, 0.045);
                float a = rough * rough;
                float a2 = a * a;
                float d = (nh * nh) * (a2 - 1.0) + 1.0;
                float D = a2 / max(UNITY_PI * d * d, 1e-7);
                float lv = nl * (nv * (1.0 - a) + a);
                float ll = nv * (nl * (1.0 - a) + a);
                float V = 0.5 / max(lv + ll, 1e-5);
                half3 F = F0 + (1.0 - F0) * pow(1.0 - vh, 5.0);
                return D * V * F * nl;
            }

            float3 EvalEmission(float2 baseUV, float3 albedo, float litFactor, float3 wPos) {
                if (_EmissionEnable < 0.5) return 0.0;
                float2 euv = baseUV * _EmissionMap_ST.xy + _EmissionMap_ST.zw;
                float3 tex = _EmissionMap.Sample(sampler_MainTex, euv).rgb;
                float mask = _EmissionMask.Sample(sampler_LinearRepeat, baseUV).r;
                if (mask <= 0.001) return 0.0;

                // AudioLink, using the same chain as the main shader so an eye set to a
                // band reacts identically to bodywork set to the same one.
                float sig = 0.0;
                if (_EmALEnable > 0.5 && AudioLinkIsAvailable()) {
                    if (_EmMode < 1.5) {
                        // Pulse takes the band level directly; Sweep Up walks the band's
                        // history up the eye so the audio travels rather than flashing.
                        sig = (_EmMode < 0.5) ? ALEnv((uint)_EmBand)
                                              : AudioLinkData(uint2(saturate(baseUV.y) * 127.0, (uint)_EmBand)).r;
                    } else {
                        float pulseDist = saturate(length(baseUV - _EmCenter.xy) * _EmPulseScale);
                        sig = AudioLinkData(uint2(pulseDist * 126.0, (uint)_EmBand)).r;
                    }
                    sig *= (1.0 + ALEnv((uint)_EmMultBand) * _EmMultAmt);
                    sig += ALEnv((uint)_EmAddBand) * _EmAddAmt;
                    if (_EmVolBoost > 0.5) {
                        float vol = (ALEnv(0) + ALEnv(1) + ALEnv(2) + ALEnv(3)) * 0.25;
                        sig *= (1.0 + vol * _EmVolAmt);
                    }
                    sig = max(sig, 0.0);
                }

                half3 col = _EmissionColor.rgb;
                if (_EmHueOn > 0.5) col = ZetEyeHueShift(col, saturate(sig) * 6.28318);

                float bright = _EmissionStrength + sig * _EmAL;

                // Light-based: dim or lift the glow by how lit the surface is, so an eye
                // can stay dark in daylight or only light up in the dark.
                if (_EmLightBased > 0.5) {
                    float t = saturate((litFactor - _EmMinLight) / max(_EmMaxLight - _EmMinLight, 1e-4));
                    bright *= lerp(_EmMinEmiss, _EmMaxEmiss, t);
                }
                if (_EmBlink > 0.5) {
                    float b = sin(_Time.y * _EmBlinkSpeed) * 0.5 + 0.5;
                    bright *= lerp(_EmBlinkMin, 1.0, b);
                }
                if (_EmScan > 0.5) {
                    // UV space follows the unwrap; object space sweeps through the eye's
                    // own space, so a band can cross it on any axis and be matched to a
                    // sweep running across the body.
                    float axis;
                    if (_EmScanSpace > 0.5) {
                        float3 op = mul(unity_WorldToObject, float4(wPos, 1.0)).xyz;
                        float3 ax = _EmScanAxis.xyz;
                        if (dot(ax, ax) < 1e-6) ax = float3(0, 1, 0);
                        // Same ruler as the main shader: metres from the avatar's origin,
                        // so an eye set to the same axis, start and length joins the same
                        // wave instead of sweeping its own tiny space.
                        axis = (dot(op, normalize(ax)) - _EmScanOrigin) / max(_EmScanExtent, 0.001);
                    } else {
                        // UV sweep. Linear travels along a freely chosen angle rather than
                        // only the two texture axes. Radial rings outward from a point,
                        // and Angular rotates around it, which are the two shapes an iris
                        // actually wants and neither of which a straight band can give.
                        float2 d2 = baseUV - _EmScanCenter.xy;
                        if (_EmScanStyle < 0.5) {
                            float ra = radians(_EmScanAngle);
                            // Normalised by the projected extent: at a diagonal the
                            // projection spans further than one UV unit, so without this
                            // the band never reaches the corners and part of the surface
                            // is simply never swept.
                            float2 dir = float2(sin(ra), cos(ra));
                            float extent = abs(dir.x) + abs(dir.y);
                            axis = dot(d2, dir) / max(extent, 1e-4) + 0.5;
                        } else if (_EmScanStyle < 1.5) {
                            axis = saturate(length(d2) * 2.0);
                        } else {
                            axis = frac((atan2(d2.y, d2.x) / 6.28318) + 0.5 + _EmScanAngle / 360.0);
                        }
                    }
                    float tt = _Time.y * _EmScanSpeed;
                    float pos = (_EmScanMode > 0.5) ? abs(frac(tt * 0.5) * 2.0 - 1.0) : frac(tt);
                    pos = frac(pos + _EmScanPhase);
                    // Loop wraps, so the distance has to wrap with it: without this the
                    // band reaches the end and vanishes instead of carrying on off one
                    // edge and re-entering from the other. Ping Pong bounces and must not
                    // wrap, or it would jump at the turnaround.
                    float dband = abs(axis - pos);
                    if (_EmScanMode < 0.5) dband = min(dband, 1.0 - dband);
                    float band = 1.0 - smoothstep(_EmScanWidth * 0.5, _EmScanWidth * 0.5 + _EmScanSoft + 1e-4, dband);
                    bright *= lerp(_EmScanFloor, 1.0, band);
                }

                float3 emis = tex * col * bright * mask;
                if (_EmissionAlbedoTint > 0.5) emis *= albedo;
                return emis;
            }
            // Distance attenuation with shadows removable independently. Dividing
            // the shadow term back out of a combined atten over-brightens soft
            // penumbrae; sampling the two separately keeps falloff exact whether
            // or not the surface receives shadows.
        ENDCG
        // ==============================================================================
        // PASS 1: FORWARDBASE
        // ==============================================================================
        // Accumulates VRSL GI point and spot lights. Diffuse and specular are
        // returned separately: diffuse joins the other diffuse terms, specular is
        // added after against specCol, which already carries the F0 tint.
        //
        // NOTE the keyword gate. The texture is only declared when ZET_VRSLGI is
        // set, because this shader shares the main shader's texture budget
        // pressure and an always-declared global costs a slot in every variant.
        CGINCLUDE
        #if defined(ZET_VRSLGI)
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

                // VRSL's own normalisation - matching it keeps eye brightness in
                // step with the world's fixtures and with the body shader.
                half3 lightColor = rawColor.rgb * (0.5 * rawColor.a);

                float3 toLight = lightPos.xyz - wPos;
                float range = length(toLight) * rawColor.a;
                half3 lightDir = normalize(toLight);

                half atten = saturate(dot(lightDir, n));
                float falloff = 1.0 / max(range * range, 0.0001);

                half spec = 0;
                if (_VRSLGISpecular > 0.5)
                {
                    half3 H = normalize(lightDir + viewDir);
                    spec = pow(saturate(dot(n, H)), specPower) * _VRSLGISpecularMult;
                    spec = min(spec, _VRSLGISpecularClamp);
                }

                // Spot cone: lightPos.w over 180 flags a spotlight; row 3 packs
                // the cone angle and edge blend into .w.
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
        ENDCG

        Pass
        {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragBase
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma shader_feature_local _ LTCGI
            #pragma shader_feature_local _ ZET_LIGHT_VOLUMES
            #pragma target 5.0
            #pragma shader_feature_local _ ZET_VRSLGI
            fixed4 fragBase(v2f i, float facing : VFACE) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - i.wPos * _WorldSpaceLightPos0.w);
                // Most worlds have no realtime directional light, leaving the surface lit
                // by near-constant ambient. The probes still carry a direction in their
                // first-order coefficients, so it is recovered and used to shape the eye.
                half3 zProbeCol = 0; float zProbeAmt = 0;
                if (_ProbeDirLight > 0.5) {
                    float3 shDir = unity_SHAr.xyz * 0.3 + unity_SHAg.xyz * 0.59 + unity_SHAb.xyz * 0.11;
                    float shLen = length(shDir);
                    if (shLen > 1e-4) {
                        float3 pDir = shDir / shLen;
                        float realtime = saturate(dot(_LightColor0.rgb, half3(0.3, 0.59, 0.11)) * 4.0);
                        zProbeAmt = (1.0 - realtime) * _ProbeDirStrength;
                        if (zProbeAmt > 0.001) {
                            lightDir = (realtime > 0.001) ? normalize(lerp(pDir, lightDir, realtime)) : pDir;
                            zProbeCol = max(ShadeSH9(half4(pDir, 1)), 0.0);
                        }
                    }
                }
                float3 N = normalize(i.wNrm); float3 T = normalize(i.wTan.xyz); float3 B = cross(N, T) * (i.wTan.w * unity_WorldTransformParams.w);
                if (facing < 0) { N = -N; T = -T; B = -B; }
                ApplyEyeFX(i.uv, viewDir, lightDir, N, T, B);
                float3 tn = UnpackScaleNormal(_BumpMap.Sample(sampler_MainTex, i.uv), _BumpScale);
                float3 n = normalize(T * tn.x + B * tn.y + N * tn.z);
                fixed4 albedo = _MainTex.Sample(sampler_MainTex, i.uv);
                half4 packed = _PackedMap.Sample(sampler_MainTex, i.uv);
                // Channel layout depends on _PackMode. Unity MetallicSmoothness maps carry
                // metallic in R and smoothness in A, with NO AO channel (G/B are unused),
                // so reading AO from G would crush the surface to black - hence AO = 1 there.
                half rawSmooth = (_PackMode > 0.5) ? packed.a : packed.b;
                half metallic  = packed.r * _Metallic;
                half smoothness = (_InvSmooth > 0.5 ? 1.0 - rawSmooth : rawSmooth) * _EyeSmoothness;
                half ao = (_PackMode > 0.5) ? 1.0 : lerp(1.0, packed.g, _OcclusionStrength);
                half3 specCol = lerp(half3(0.04, 0.04, 0.04), albedo.rgb, metallic);
                #if defined(SHADOWS_SHADOWMASK) && !defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON)
                    float atten = 1.0;
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.wPos);
                #endif
                atten = lerp(1.0, atten, _ReceiveShadows);   // body-shader attenuation: UNITY_LIGHT_ATTENUATION already combines distance+shadow correctly
                float dither = (frac(52.9829189 * frac(dot(i.pos.xy, float2(0.06711056, 0.00583715)))) - 0.5) * _ShadowDither;
                float ndl = dot(n, lightDir);
                half litRaw = (_EyeWrapLight > 0.5) ? (ndl * 0.5 + 0.5) : saturate(ndl);   // half-lambert survives wrong-facing eye normals
                half ramp = (_LightingModel < 0.5) ? smoothstep(_ShadowEdge - _ShadowSoft, _ShadowEdge + _ShadowSoft, (ndl * 0.5 + 0.5) + dither) * atten : litRaw * atten;
                float3 lightCol = clamp(_LightColor0.rgb, _MinBrightness, _MaxBrightness);
                bool lvOn    = (_LightVolumes > 0.5);
                bool ltcgiOn = (_LTCGI > 0.5);
                // Debug taps for terms otherwise scoped inside their own blocks.
                half3 dbgLTCGI = 0, dbgRefl = 0;
                half3 vrslDiffuse = 0, vrslSpec = 0;
                half3 ambient = ShadeSH9(half4(n, 1)) * ao;
                // Probe light adds on top of ambient, so world brightness is kept
                // and only the shaping changes.
                ambient += zProbeCol * saturate(dot(n, lightDir)) * zProbeAmt;
                half3 lvSpecAdd = 0;
                #if defined(ZET_LV_OK)
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
                        // ambient already holds the ShadeSH9 value, so no else branch.
                        ambient = LightVolumeEvaluate(n, lvL0, lvL1r, lvL1g, lvL1b) * ao * _LightVolumesStrength;
                        if (_LightVolumesSpec > 0.5)
                            lvSpecAdd = LightVolumeSpecular(specCol, smoothness, n, viewDir, lvL0, lvL1r, lvL1g, lvL1b) * _LightVolumesStrength;
                    }
                #endif
                #ifdef VERTEXLIGHT_ON
                    // Realtime point/vertex lights the volumes/probes don't include.
                    // This is the term that keeps the body lit in realtime worlds;
                    // the eye lacked it, which is why it went black while the face did not.
                    ambient += i.vLights * ao;
                #endif
                // Ambient floor: guarantee a minimum lit level so the eye white cannot
                // crush to black in worlds lit only by spot/point lights (whose light
                // arrives in ForwardAdd, leaving the base pass near-zero). Without this
                // the sclera goes black while an emissive pupil rides through.
                // Guaranteed ambient floor so the eye never fully blacks out when a
                // scene has no directional light reaching it (N.L = 0) - probe/LV
                // ambient plus a Min Brightness floor, applied to the ambient itself
                // so it survives the albedo and metallic multiply below.
                ambient = max(ambient, _MinBrightness.xxx);
                // VRSL GI: point and spot lights, so it belongs with direct light
                // rather than ambient. Runtime-gated as well as keyword-gated for
                // the same reason as LV and LTCGI - //ifex only strips at lock.
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
                half3 baseLight = lightCol * lerp(_ShadowTint.rgb, 1, ramp) + ambient + vrslDiffuse;
                half3 diffuseCol = albedo.rgb * (1.0 - metallic);
                fixed4 col = fixed4(diffuseCol * baseLight, 1.0);
                col.rgb += lvSpecAdd;
                col.rgb += vrslSpec * specCol;
                float3 H = normalize(lightDir + viewDir);
                // PBR direct specular (Realistic mode only): gives a plain eye a catchlight
                if (_LightingModel > 0.5) {
                    // GGX rather than Blinn-Phong: atten not ramp, since the BRDF carries
                    // its own N.L and multiplying by the lambert ramp would square it.
                    col.rgb += specCol * lightCol
                             * ZetGGXSpecular(n, viewDir, lightDir, smoothness, half3(1, 1, 1))
                             * _SpecStrength * atten;
                    // The probe light gets a matching lobe, or a smooth eye in an
                    // ambient-only world has shaped diffuse but no catchlight.
                    if (zProbeAmt > 0.001)
                        col.rgb += specCol * zProbeCol
                                 * ZetGGXSpecular(n, viewDir, lightDir, smoothness, specCol)
                                 * _SpecStrength * zProbeAmt;
                }
                if (_AnisoEnable > 0.5) {
                    float3 anisoDir = normalize((_AnisoDir > 0.5 ? B : T) + n * _AnisoShift);
                    col.rgb += _AnisoColor.rgb * lightCol * pow(sqrt(max(0.0, 1.0 - pow(dot(anisoDir, H), 2))), exp2(smoothness * 9.0 + 1.0 + (_AnisoPower - 5.0) * 0.5)) * _AnisoStrength * ramp;
                }
                if (_StyleSpecEnable > 0.5) {
                    float ssNdh = saturate(dot(n, H));
                    float ssMask = _StyleSpecMask.Sample(sampler_LinearRepeat, i.uv).r;
                    float ssLayers = smoothstep(1.0 - _SS1Size - _SS1Feather, 1.0 - _SS1Size + _SS1Feather, ssNdh) * _SS1Strength +
                                     smoothstep(1.0 - _SS2Size - _SS2Feather, 1.0 - _SS2Size + _SS2Feather, ssNdh) * _SS2Strength +
                                     smoothstep(1.0 - _SS3Size - _SS3Feather, 1.0 - _SS3Size + _SS3Feather, ssNdh) * _SS3Strength;
                    half3 ssCol = _StyleSpecTint.rgb * ((_StyleSpecUseLight > 0.5) ? lightCol : half3(1, 1, 1));
                    col.rgb += ssCol * ssLayers * ssMask * ramp;
                }
                #if defined(ZET_LTCGI)
                if (ltcgiOn) {
                    half3 lDiff = 0, lSpec = 0; LTCGI_Contribution(i.wPos, n, viewDir, 1.0 - smoothness, float2(0, 0), lDiff, lSpec);
                    half3 ltAO = lerp(half3(1,1,1), ao.xxx, _LTCGIOcclusion);
                    if (_LTCGITintOn > 0.5) { lDiff *= _LTCGIDiffuseTint.rgb; lSpec *= _LTCGISpecularTint.rgb; }
                    dbgLTCGI = (diffuseCol * lDiff * ltAO + specCol * lSpec) * _LTCGIStrength;
                    col.rgb += (diffuseCol * lDiff * ltAO + specCol * lSpec) * _LTCGIStrength;
                }
                #endif
                if (_UseEnvReflections > 0.5) {
                    float3 reflDir = reflect(-viewDir, n);
                    // Eye = convex mirror: flips horizontal, stays vertical. The raw
                    // cubemap sample for this surface reads Y-inverted, so Vertical
                    // (the default) negates .y to put sky up / ground down. Both is a
                    // 180 for mirror-authored probes; None is the raw sample.
                    // Convex eye samples the cubemap Y-inverted; Flip Y (default on)
                    // corrects it. X flip is the escape hatch for mirror-authored probes.
                    if (_ReflFlipX > 0.5) reflDir.x = -reflDir.x;
                    if (_ReflFlipY > 0.5) reflDir.y = -reflDir.y;
                    half3 refl = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, (1.0 - smoothness) * 6.0), unity_SpecCube0_HDR);
                    // Unity puts the second-nearest probe in unity_SpecCube1 and the
                    // crossfade weight in unity_SpecCube0_BoxMin.w. Sampling only
                    // SpecCube0 makes the reflection hard-switch the moment you cross
                    // a probe boundary; blending is what the Standard shader does and
                    // what makes walking between rooms look continuous.
                    UNITY_BRANCH
                    if (unity_SpecCube0_BoxMin.w < 0.99999) {
                        half3 refl1 = DecodeHDR(UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflDir, (1.0 - smoothness) * 6.0), unity_SpecCube1_HDR);
                        refl = lerp(refl1, refl, unity_SpecCube0_BoxMin.w);
                    }
                    half fill = saturate(1.0 - dot(refl, half3(0.299, 0.587, 0.114)) * 3.0);
                    dbgRefl = (refl + (_BakedCubemap.SampleLevel(sampler_LinearClamp, reflDir, (1.0 - smoothness) * 6.0).rgb * _FallbackCubemapStrength * fill * _HasBakedCubemap)) * specCol * ao * _ReflStrength;
                    col.rgb += dbgRefl;
                }
                if (_WetnessEnable > 0.5) {
                    col.rgb += _WetnessColor.rgb * _WetnessMask.Sample(sampler_LinearClamp, i.uv).r * _WetnessStrength * max(ramp, 0.2);
                }
                // Lit factor for the light-based option: how bright the world is making
                // this surface, direct plus ambient, matching the main shader's measure.
                half zLit = saturate(dot(baseLight, half3(0.299, 0.587, 0.114)));
                col.rgb += EvalEmission(i.uv, albedo.rgb, zLit, i.wPos);
//ifex _DebugView==0
                // Returns before fog: a debug view should show the raw term, not
                // the term after the world's fog has been mixed into it.
                if (_DebugView > 0.5) {
                    half3 dbg;
                    if      (_DebugView < 1.5)  dbg = albedo.rgb;
                    else if (_DebugView < 2.5)  dbg = n * 0.5 + 0.5;
                    else if (_DebugView < 3.5)  dbg = metallic.xxx;
                    else if (_DebugView < 4.5)  dbg = smoothness.xxx;
                    else if (_DebugView < 5.5)  dbg = ao.xxx;
                    else if (_DebugView < 6.5)  dbg = ambient;
                    else if (_DebugView < 7.5)  dbg = lightCol * ramp;
                    else if (_DebugView < 8.5)  dbg = dbgLTCGI;
                    else if (_DebugView < 9.5)  dbg = lvSpecAdd;
                    else if (_DebugView < 10.5) dbg = dbgRefl;
                    else if (_DebugView < 11.5) dbg = packed.rgb;
                    else if (_DebugView < 12.5) dbg = half3(frac(i.uv), 0);
                    else if (_DebugView < 13.5) dbg = vrslDiffuse;
                    #if defined(ZET_VRSLGI)
                    else                        dbg = ((half) _Udon_VRSL_GI_LightTexture.Load(int3(0, 2, 0)).r / 16.0).xxx;
                    #else
                    // VRSL GI off: no texture to count. Magenta, so "feature off"
                    // is not mistaken for "world publishes nothing".
                    else                        dbg = half3(1, 0, 1);
                    #endif

                    // Keep _MainTex alive. Once _DebugView is baked to a literal
                    // this branch is unconditional, so everything above becomes
                    // dead code - including the albedo sample. Unity then strips
                    // _MainTex while sampler_MainTex is still declared, and
                    // reports the sampler as matching no texture. _Time is a
                    // uniform, so this cannot be folded away; it never executes.
                    if (_Time.w < -1e9) dbg += albedo.rgb;

                    return fixed4(dbg, 1.0);
                }
//endex
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
        // ==============================================================================
        // PASS 2: FORWARDADD
        // ==============================================================================
        Pass
        {
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One
            ZWrite Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment fragAdd
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            #pragma shader_feature_local _ ZET_VRSLGI
            #pragma target 5.0
            fixed4 fragAdd(v2f i, float facing : VFACE) : SV_Target {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
//ifex _DebugView==0
                // ForwardAdd blends additively over the base pass, so any extra
                // realtime light would wash colour across a view meant to isolate
                // one term. Contribute nothing - and keep _MainTex alive, since
                // this return is unconditional once _DebugView is baked.
                if (_DebugView > 0.5) {
                    half3 keep = (_Time.w < -1e9) ? _MainTex.Sample(sampler_MainTex, i.uv).rgb : half3(0, 0, 0);
                    return fixed4(keep, 0);
                }
//endex
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.wPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz - i.wPos * _WorldSpaceLightPos0.w);
                // Most worlds have no realtime directional light, leaving the surface lit
                // by near-constant ambient. The probes still carry a direction in their
                // first-order coefficients, so it is recovered and used to shape the eye.
                half3 zProbeCol = 0; float zProbeAmt = 0;
                if (_ProbeDirLight > 0.5) {
                    float3 shDir = unity_SHAr.xyz * 0.3 + unity_SHAg.xyz * 0.59 + unity_SHAb.xyz * 0.11;
                    float shLen = length(shDir);
                    if (shLen > 1e-4) {
                        float3 pDir = shDir / shLen;
                        float realtime = saturate(dot(_LightColor0.rgb, half3(0.3, 0.59, 0.11)) * 4.0);
                        zProbeAmt = (1.0 - realtime) * _ProbeDirStrength;
                        if (zProbeAmt > 0.001) {
                            lightDir = (realtime > 0.001) ? normalize(lerp(pDir, lightDir, realtime)) : pDir;
                            zProbeCol = max(ShadeSH9(half4(pDir, 1)), 0.0);
                        }
                    }
                }
                float3 N = normalize(i.wNrm); float3 T = normalize(i.wTan.xyz); float3 B = cross(N, T) * (i.wTan.w * unity_WorldTransformParams.w);
                if (facing < 0) { N = -N; T = -T; B = -B; }
                ApplyEyeFX(i.uv, viewDir, lightDir, N, T, B);
                float3 tn = UnpackScaleNormal(_BumpMap.Sample(sampler_MainTex, i.uv), _BumpScale);
                float3 n = normalize(T * tn.x + B * tn.y + N * tn.z);
                fixed4 albedo = _MainTex.Sample(sampler_MainTex, i.uv);
                half4 packed = _PackedMap.Sample(sampler_MainTex, i.uv);
                half rawSmooth = (_PackMode > 0.5) ? packed.a : packed.b;
                half metallic  = packed.r * _Metallic;
                half smoothness = (_InvSmooth > 0.5 ? 1.0 - rawSmooth : rawSmooth) * _EyeSmoothness;
                half3 specCol = lerp(half3(0.04, 0.04, 0.04), albedo.rgb, metallic);
                #if defined(SHADOWS_SHADOWMASK) && !defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON)
                    float atten = 1.0;
                #else
                    UNITY_LIGHT_ATTENUATION(atten, i, i.wPos);
                #endif
                atten = lerp(1.0, atten, _ReceiveShadows);   // body-shader attenuation: UNITY_LIGHT_ATTENUATION already combines distance+shadow correctly
                float dither = (frac(52.9829189 * frac(dot(i.pos.xy, float2(0.06711056, 0.00583715)))) - 0.5) * _ShadowDither;
                float ndl = dot(n, lightDir);
                half litRaw = (_EyeWrapLight > 0.5) ? (ndl * 0.5 + 0.5) : saturate(ndl);   // half-lambert survives wrong-facing eye normals
                half ramp = (_LightingModel < 0.5) ? smoothstep(_ShadowEdge - _ShadowSoft, _ShadowEdge + _ShadowSoft, (ndl * 0.5 + 0.5) + dither) * atten : litRaw * atten;
                float3 lightCol = clamp(_LightColor0.rgb, _MinBrightness, _MaxBrightness);
                fixed4 col = fixed4(albedo.rgb * (1.0 - metallic) * lightCol * ramp, 1.0);
                float3 H = normalize(lightDir + viewDir);
                if (_LightingModel > 0.5) {
                    // GGX rather than Blinn-Phong: atten not ramp, since the BRDF carries
                    // its own N.L and multiplying by the lambert ramp would square it.
                    col.rgb += specCol * lightCol
                             * ZetGGXSpecular(n, viewDir, lightDir, smoothness, half3(1, 1, 1))
                             * _SpecStrength * atten;
                    // The probe light gets a matching lobe, or a smooth eye in an
                    // ambient-only world has shaped diffuse but no catchlight.
                    if (zProbeAmt > 0.001)
                        col.rgb += specCol * zProbeCol
                                 * ZetGGXSpecular(n, viewDir, lightDir, smoothness, specCol)
                                 * _SpecStrength * zProbeAmt;
                }
                if (_AnisoEnable > 0.5) {
                    float3 anisoDir = normalize((_AnisoDir > 0.5 ? B : T) + n * _AnisoShift);
                    col.rgb += _AnisoColor.rgb * lightCol * pow(sqrt(max(0.0, 1.0 - pow(dot(anisoDir, H), 2))), exp2(smoothness * 9.0 + 1.0 + (_AnisoPower - 5.0) * 0.5)) * _AnisoStrength * ramp;
                }
                if (_StyleSpecEnable > 0.5) {
                    float ssNdh = saturate(dot(n, H));
                    float ssMask = _StyleSpecMask.Sample(sampler_LinearRepeat, i.uv).r;
                    float ssLayers = smoothstep(1.0 - _SS1Size - _SS1Feather, 1.0 - _SS1Size + _SS1Feather, ssNdh) * _SS1Strength +
                                     smoothstep(1.0 - _SS2Size - _SS2Feather, 1.0 - _SS2Size + _SS2Feather, ssNdh) * _SS2Strength +
                                     smoothstep(1.0 - _SS3Size - _SS3Feather, 1.0 - _SS3Size + _SS3Feather, ssNdh) * _SS3Strength;
                    half3 ssCol = _StyleSpecTint.rgb * ((_StyleSpecUseLight > 0.5) ? lightCol : half3(1, 1, 1));
                    col.rgb += ssCol * ssLayers * ssMask * ramp;
                }
                if (_WetnessEnable > 0.5) {
                    col.rgb += _WetnessColor.rgb * _WetnessMask.Sample(sampler_LinearClamp, i.uv).r * _WetnessStrength * ramp;
                }
                UNITY_APPLY_FOG_COLOR(i.fogCoord, col, fixed4(0, 0, 0, 0));
                return col;
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
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster
            #pragma target 5.0
            struct v2f_shadow { V2F_SHADOW_CASTER; UNITY_VERTEX_OUTPUT_STEREO };
            v2f_shadow vertShadow(appdata v) { v2f_shadow o; UNITY_SETUP_INSTANCE_ID(v); UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o); TRANSFER_SHADOW_CASTER_NORMALOFFSET(o); return o; }
            float4 fragShadow(v2f_shadow i) : SV_Target { SHADOW_CASTER_FRAGMENT(i) }
            ENDCG
        }
    }
    CustomEditor "Zetph.FancyShader.EditorUI.ZetMaterialInspector"
}
