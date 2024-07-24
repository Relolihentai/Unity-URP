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
        EyeDepthRemap0ldRangeX ("Eye Depth Remap Range X", Range(0, 1)) = 0
        EyeDepthRemap0ldRangeY ("Eye Depth Remap Range Y", Float) = 0
        EyeDepthRemap0ldRangeZ ("Eye Depth Remap Range Z", Float) = 0
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
        float EyeDepthRemap0ldRangeX, EyeDepthRemap0ldRangeY, EyeDepthRemap0ldRangeZ;
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
            };

            struct v2f
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
                float3 worldNormal: TEXCOORD2;
                float4 scrPos : TEXCOORD3;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.vertex.xyz);
                VertexNormalInputs vertex_normal_inputs = GetVertexNormalInputs(IN.normal.xyz);
                OUT.position = vertex_position_inputs.positionCS;
                OUT.worldPos = vertex_position_inputs.positionWS;
                OUT.worldNormal = vertex_normal_inputs.normalWS;
                OUT.uv = IN.uv;
                OUT.scrPos = ComputeScreenPos(OUT.position);
                return OUT;
            }

            float4 frag(v2f IN): SV_Target
            {
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

                float4 worldPosButSnapToCamera = mul(unity_ObjectToWorld, IN.vertex);
                worldPosButSnapToCamera.xyz -= GetCameraPositionWS();
                float3 viewPos = mul((float3x3)unity_MatrixV, worldPosButSnapToCamera.xyz);
                float3 normal = IN.uv7.xyz;
                float3 worldNormal = mul((float3x3)unity_ObjectToWorld, normal);
                float3 viewNormal = mul((float3x3)unity_MatrixV, worldNormal);

                float3 fixViewNormal;
                fixViewNormal.xy = viewNormal.xy;
                fixViewNormal.z = 0.01;

                float2 normalizeViewNormalXY = normalize(fixViewNormal).xy;
                normalizeViewNormalXY *= float2(normalizeViewNormalScaleX, normalizeViewNormalScaleY);

                float fov45AdaptScale = 2.414 / UNITY_MATRIX_P[1u].y;

                float eyeDepth_ofSnapToCamera = -viewPos.z;

                EyeDepthRemap0ldRangeX *= 0.01;
                bool eyeDepth_is_small = eyeDepth_ofSnapToCamera * fov45AdaptScale < EyeDepthRemap0ldRangeY;
                float2 eyeDepthParams_oldRange = eyeDepth_is_small ? float2(EyeDepthRemap0ldRangeX, EyeDepthRemap0ldRangeY) : float2(EyeDepthRemap0ldRangeY, EyeDepthRemap0ldRangeZ);
                float2 eyeDepthParams_newRange = eyeDepth_is_small ? float2(EyeDepthRemap0ldRangeX, EyeDepthRemap0ldRangeY) : float2(EyeDepthRemap0ldRangeY, EyeDepthRemap0ldRangeZ);

                float eyeDepthInNewRange = EyeDepthRemap(-viewPos.z * fov45AdaptScale, eyeDepthParams_oldRange, eyeDepthParams_newRange);
                float eyeDepthInNewRangeScale = eyeDepthInNewRange * 0.02 * IN.uv2.y;
                float3 normalBiasViewPos = viewPos;
                viewPos.xy += normalizeViewNormalXY * eyeDepthInNewRange;
                OUT.position = mul(UNITY_MATRIX_P, float4(viewPos, 1.0));
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
