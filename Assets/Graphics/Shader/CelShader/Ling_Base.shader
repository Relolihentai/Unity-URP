Shader "ShaderTemplate/Ling_Base"
{
    Properties
    {
        _BaseTex ("Base Tex", 2D) = "white" {}
        _AmbientColor ("Ambient Color", Color) = (1,1,1,1)
        _AmbientFac("Ambient Fac", Range(0, 1)) = 0
        
        _MaskTex ("Mask Tex", 2D) = "white" {}
        
        _RampTex ("Ramp Tex", 2D) = "white" {}
        
        _ToonTex ("Toon Tex", 2D) = "white" {}
        _SkinTex ("Skin Tex", 2D) = "white" {}
        _MatcapFac("Matcap Fac", Range(0, 1)) = 0
        
        _ShadowColor ("Shadow Color", Color) = (1, 1, 1, 1)
        
        _EmStrength ("Em Strength", Range(0, 3)) = 1
        
        _MetalTex("Metal Tex", 2D) = "white" {}
        _Gloss("Gloss", Float) = 50
        _KsMetallic("Metallic", Range(0, 1)) = 1
        _KsNonMetallic("Non Metallic", Range(0, 1)) = 1
        
        normalizeViewNormalScaleX ("Normal Scale X", Float) = 0
        normalizeViewNormalScaleY ("Normal Scale Y", Float) = 0
        EyeDepthRemapOldRange ("Eye Depth Remap Old Range", Vector) = (0, 0, 0, 0)
        EyeDepthRemapNewRange ("Eye Depth Remap New Range", Vector) = (0, 0, 0, 0)
        EyeDepthInNewRangeMulti1 ("Eye Depth In New Range Multi1", Float) = 0
        EyeDepthInNewRangeMulti2 ("Eye Depth In New Range Multi2", Float) = 0
        EyeDepthInNewRangeMulti_0_01 ("Eye Depth In New Range 0_01", Float) = 0
        ViewSpaceSnapVertexDirScale ("View Space Snap Vertex Dir Scale", Float) = 0
        AffectProjectionXYWhenLessThan_0_95 ("Affect Projection XY When Less Than 0.95", Float) = 1
        OutlineScreenOffsetWZ ("Out line Screen Offset WZ", Vector) = (0, 0, 0, 0)
        _Slope_ScaledBias ("_Slope_ScaledBias", Range(0, 4)) = 0
        _DepthBias ("_DepthBias", Range(0, 1)) = 0
        
        _OutlineOffset("Outline Width", Range(0, 20)) = 3
        _OutlineColor0 ("Outline Color 0", Color) = (1, 1, 1, 1)
        _OutlineColor1 ("Outline Color 1", Color) = (1, 1, 1, 1)
        _OutlineColor2 ("Outline Color 2", Color) = (1, 1, 1, 1)
        _OutlineColor3 ("Outline Color 3", Color) = (1, 1, 1, 1)
        
        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimOffset ("Rim Offset", Range(0, 20)) = 13
        _RimThreshold ("Rim Threshold", Range(0, 0.1)) = 0.08
        _RimStrength ("Rim Strength", Range(0, 1)) = 0.6
        _RimFac ("Rim Fac", Range(0, 10)) = 0
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline" 
            "Queue"="Geometry"
            "RenderType"="Opaque"
        }
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _AmbientColor, _ShadowColor, _RimColor, _OutlineShadowColor,
                _OutlineColor0, _OutlineColor1, _OutlineColor2, _OutlineColor3;
        float _MatcapFac, _AmbientFac, _Gloss, _KsNonMetallic, _KsMetallic, _RimFac, _RimOffset, _RimThreshold, _RimStrength,
                _OutlineOffset, _EmStrength;
        float normalizeViewNormalScaleX, normalizeViewNormalScaleY;
        float EyeDepthInNewRangeMulti1, EyeDepthInNewRangeMulti2, EyeDepthInNewRangeMulti_0_01,
                ViewSpaceSnapVertexDirScale, AffectProjectionXYWhenLessThan_0_95;
        float4 OutlineScreenOffsetWZ,
                EyeDepthRemapOldRange, EyeDepthRemapNewRange;
        CBUFFER_END

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);

        TEXTURE2D(_MaskTex);
        SAMPLER(sampler_MaskTex);
        TEXTURE2D(_BaseTex);
        SAMPLER(sampler_BaseTex);
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_ToonTex);
            SAMPLER(sampler_ToonTex);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            TEXTURE2D(_SkinTex);
            SAMPLER(sampler_SkinTex);
            TEXTURE2D(_SphereTex);
            SAMPLER(sampler_SphereTex);
            TEXTURE2D(_MetalTex);
            SAMPLER(sampler_MetalTex);
            
            struct a2v
            {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
                float2 uv: TEXCOORD0;
                float4 uv7 : TEXCOORD7;
            };

            struct v2f
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
                float3 worldNormal: TEXCOORD2;
                float4 scrPos : TEXCOORD3;
                float4 uv7 : TEXCOORD4;
                float3 worldTanget : TEXCOORD5;
                float3 worldBitTangent : TEXCOORD6;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.vertex.xyz);
                VertexNormalInputs vertex_normal_inputs = GetVertexNormalInputs(IN.normal.xyz);
                OUT.position = vertex_position_inputs.positionCS;
                OUT.worldPos = vertex_position_inputs.positionWS;
                OUT.worldNormal = vertex_normal_inputs.normalWS;
                OUT.worldTanget = vertex_normal_inputs.tangentWS;
                OUT.worldBitTangent = vertex_normal_inputs.bitangentWS;
                OUT.uv = IN.uv;
                OUT.uv7 = IN.uv7;
                OUT.scrPos = ComputeScreenPos(OUT.position);
                return OUT;
            }

            float4 frag(v2f IN): SV_Target
            {
                float3x3 tbn = float3x3(IN.worldTanget, IN.worldBitTangent, IN.worldNormal);
                return float4(mul(IN.uv7.xyz, tbn), 1);
                // Context
                Light light = GetMainLight();
                float3 lightDir = light.direction;
                float3 lightColor = light.color;
                float2 scrPos = (IN.scrPos / IN.scrPos.w).xy;
                float3 viewDir = normalize(GetCameraPositionWS() - IN.worldPos);
                float3 viewNormal = mul(unity_WorldToCamera, float4(IN.worldNormal, 0)).xyz;
                float3 halfDir = normalize(viewDir + lightDir);
                float nol = dot(IN.worldNormal, lightDir);
                float noh = dot(IN.worldNormal, halfDir);
                float nov = dot(IN.worldNormal, viewDir);

                //Lambert HalfLambert
                float lambert = saturate(nol);
                float halfLambert = nol * 0.5 + 0.5;
                float halfLambert_Ramp = smoothstep(0.0, 0.5, halfLambert);
                float lambertStep = smoothstep(0.423, 0.465, halfLambert);

                //BaseTex
                float4 BaseTexColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, IN.uv);

                //RedMask
                float4 MaskTexColor = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, IN.uv);
                float Mask_R = MaskTexColor.r;
                float Mask_G = MaskTexColor.g;
                float Mask_B = MaskTexColor.b;
                float Mask_A = MaskTexColor.a;
                
                return float4(BaseTexColor.xyz, 1);

                //MatcapUV
                float2 matcapUV = (viewNormal * 0.5 + 0.5).xy;
                //ToonColor SkinColor
                float3 ToonColor = SAMPLE_TEXTURE2D(_ToonTex, sampler_ToonTex, matcapUV).xyz;
                float3 SkinColor = SAMPLE_TEXTURE2D(_SkinTex, sampler_SkinTex, matcapUV).xyz;

                //IsDay
                float IsDay = (lightDir.y + 1) / 2;

                //BlinnPhong
                float3 HalfDir = normalize(viewDir + lightDir);
                float NOH = dot(IN.worldNormal, HalfDir);
                float BlinnPhong = step(0, nol) * pow(max(0, NOH), _Gloss);

                float3 EmColor = BaseTexColor.xyz * BaseTexColor.a * _EmStrength;

                float rimMax = 0.3;
                
                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos).x;
                float linearDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                
                float Offset = lerp(-1, 1, step(0, viewNormal.x)) * _RimOffset / _ScreenParams.x;
                float4 screenOffset = float4(Offset, 0, 0, 0);
                float offsetDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos + screenOffset.xy).x;
                float offsetLinearDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);

                float rim = saturate(offsetLinearDepth - linearDepth);
                rim = step(_RimThreshold, rim) * clamp(rim * _RimStrength, 0, rimMax);

                float fresnelPower = 6;
                float fresnelClamp = 0.8;
                float fresnel = 1 - saturate(nov);
                fresnel = pow(fresnel, fresnelPower);
                fresnel = fresnel * fresnelClamp + (1 - fresnelClamp);
            }
            ENDHLSL
        }
        Pass
        {
            Name "DrawOutline"
            Tags {"RenderPipeline" = "UniversalPipeline" }
            
            Cull Front
            ZTest Less
            Offset [_Slope_ScaledBias], [_DepthBias]
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            float GetCameraFOV()
            {
                float t = unity_CameraProjection._m11;
                float Rad2Deg = 180 / 3.1415;
                float fov = atan(1.0f / t) * 2.0 * Rad2Deg;
                return fov;
            }
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
                float4 uv2 : TEXCOORD2;
                float4 uv7 : TEXCOORD7;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float EyeDepthRemap(float In, float2 InMinMax, float2 OutMinMax)
            {
                return OutMinMax.x + saturate((In - InMinMax.x) / max(InMinMax.y - InMinMax.x, 0.0001)) * (OutMinMax.y - OutMinMax.x);
            }

            v2f vert(a2v IN)
            {
                v2f OUT;
                
                // Z 是前后偏移控制 0.5 表示中间，逆向模型的 Z 都是 0.5
                // W 是 eyeDepth 缩放控制，逆向模型大部分是 0.5，也有 0.4，0 的
                float4 Vertex_FrontBackOffsetZ_DepthScaleW = float4(0, 0, IN.uv2.xy);
                Vertex_FrontBackOffsetZ_DepthScaleW = float4(0, 0, 0.5, 0.5);

                //世界空间相对于摄像机的坐标
                float4 worldPosButSnapToCamera = mul(unity_ObjectToWorld, IN.vertex);
                worldPosButSnapToCamera.xyz -= GetCameraPositionWS();

                //观察空间坐标
                float3 viewPos = mul((float3x3)unity_MatrixV, worldPosButSnapToCamera.xyz);

                VertexNormalInputs vertex_normal_inputs = GetVertexNormalInputs(IN.normal, IN.tangent);
                float3x3 tbn = float3x3(vertex_normal_inputs.tangentWS, vertex_normal_inputs.bitangentWS, vertex_normal_inputs.normalWS);
                //世界空间法线
                float3 worldNormal = mul(IN.uv7.xyz, tbn);
                worldNormal = TransformObjectToWorldNormal(worldNormal);
                //观察空间法线
                float3 viewNormal = mul((float3x3)unity_MatrixV, worldNormal);

                //Z值被舍弃，固定0.01
                float3 fixViewNormal;
                fixViewNormal.xy = viewNormal.xy;
                fixViewNormal.z = 0.01;

                //标准化的观察空间法线，加一个缩放
                float2 normalizeViewNormalXY = normalize(fixViewNormal).xy;
                normalizeViewNormalXY *= float2(normalizeViewNormalScaleX, normalizeViewNormalScaleY);

                // cot( 0.5*45° ) = 2.414
                // UNITY_MATRIX_P[1u].y = cot( 0.5 * FOV )
                // FOV 越小，cot( 0.5 * FOV ) 越大，2.414 / UNITY_MATRIX_P[1u].y; 越小
                //   FOV 越小，人物越大，描边在3D空间上变小，最终屏幕上粗度相应保持不变
                float fov45AdaptScale = 2.414 / UNITY_MATRIX_P[1u].y;

                //观察空间Z值（正的）
                float eyeDepth_ofSnapToCamera = -viewPos.z;

                bool eyeDepth_is_small = eyeDepth_ofSnapToCamera * fov45AdaptScale < EyeDepthRemapOldRange.y;
                float2 eyeDepthParams_oldRange = eyeDepth_is_small ? EyeDepthRemapOldRange.xy : EyeDepthRemapOldRange.yz;
                float2 eyeDepthParams_newRange = eyeDepth_is_small ? EyeDepthRemapNewRange.xy : EyeDepthRemapNewRange.yz;

                float eyeDepthInNewRange = EyeDepthRemap(-viewPos.z * fov45AdaptScale, eyeDepthParams_oldRange, eyeDepthParams_newRange);
                float eyeDepthInNewRangeScale = eyeDepthInNewRange;
                eyeDepthInNewRangeScale *= EyeDepthInNewRangeMulti1 * EyeDepthInNewRangeMulti2;
                eyeDepthInNewRangeScale *= 100.0 * EyeDepthInNewRangeMulti_0_01;
                eyeDepthInNewRangeScale *= 0.414250195026397705078125;
                eyeDepthInNewRangeScale *= Vertex_FrontBackOffsetZ_DepthScaleW.w;

                float3 viewPos_normalize = normalize(viewPos);

                float3 viewSpaceDir_a_little;
                viewSpaceDir_a_little = viewPos_normalize * ViewSpaceSnapVertexDirScale;
                viewSpaceDir_a_little *= EyeDepthInNewRangeMulti_0_01;

                float3 viewPos_bias = viewSpaceDir_a_little * (Vertex_FrontBackOffsetZ_DepthScaleW.z - 0.5) + viewPos;

                float3 normalBiasViewPos = viewPos_bias;
                normalBiasViewPos.xy += normalizeViewNormalXY * eyeDepthInNewRangeScale;

                float4 clipPos = mul(UNITY_MATRIX_P, float4(normalBiasViewPos, 1.0));

                float2 clipPosXYOffset;
                clipPosXYOffset.x = clipPos.w * OutlineScreenOffsetWZ.z;
                clipPosXYOffset.y = clipPos.w * OutlineScreenOffsetWZ.w * _ProjectionParams.x;
                float2 clipPosApplyXYOffset = clipPosXYOffset.xy * 2.0 + clipPos.xy;

                clipPos.xy = AffectProjectionXYWhenLessThan_0_95 < 0.95 ? clipPosApplyXYOffset : clipPos.xy;

                OUT.position = clipPos;
                OUT.uv = IN.uv;
                return OUT;
            }
            float4 frag(v2f IN) : SV_Target
            {

                //Context
                Light light = GetMainLight();
                float3 lightDir = light.direction;
                
                //BaseColor
                float4 BaseTexColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, IN.uv);
                
                float4 MaskTexColor = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, IN.uv);
                float Mask_R = MaskTexColor.r;
                float Mask_G = MaskTexColor.g;
                float Mask_B = MaskTexColor.b;
                float Mask_A = MaskTexColor.a;

                float3 OutlineColor = lerp(_OutlineColor0,
                    lerp(_OutlineColor1,
                        lerp(_OutlineColor2, _OutlineColor3,
                            step(0.5, Mask_R)), step(0.25, Mask_R)), step(0.10, Mask_R));
                

                return float4(BaseTexColor.xyz * OutlineColor, BaseTexColor.a);
            }
            ENDHLSL
        }

        Pass {
            Name "DepthNormals"
            Tags {
                "LightMode" = "DepthNormals"
            }

            HLSLPROGRAM
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }
}
