Shader "ShaderTemplate/Cel_Face"
{
    Properties
    {
        _BaseTex ("Base Tex", 2D) = "white" {}
        _AmbientColor ("Ambient Color", Color) = (1,1,1,1)
        _AmbientFac("Ambient Fac", Range(0, 1)) = 0
        
        _SDF_Tex("SDF Tex", 2D) = "white" {}
        _FaceShadow_Tex("Face Shadow Tex", 2D) = "white" {}
        _Face_Mask_Tex("Face Mask Tex", 2D) = "white" {}
        _SkinTex ("Skin Tex", 2D) = "white" {}
        _MatcapFac("Matcap Fac", Range(0, 1)) = 0
        _RampTex ("Ramp Tex", 2D) = "white" {}
        _ShadowColor("Shadow Color", Color) = (1, 1, 1, 1)
        
        _OutlineShadowColor("Outline Shadow Color", Color) = (1, 1, 1, 1)
        _OutlineOffset("Outline Offset", Range(0, 10)) = 8
        
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
        float4 _BaseTex_ST, _AmbientColor, _ShadowColor, _RimColor,
                _OutlineShadowColor;
        vector _ForwardVector, _RightVector;
        float _MatcapFac, _AmbientFac, _RimFac,
                _OutlineOffset, _RimOffset, _RimThreshold, _RimStrength;
        CBUFFER_END

        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_SDF_Tex);
            SAMPLER(sampler_SDF_Tex);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            TEXTURE2D(_SkinTex);
            SAMPLER(sampler_SkinTex);
            TEXTURE2D(_FaceShadow_Tex);
            SAMPLER(sampler_FaceShadow_Tex);
            
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
                OUT.scrPos = ComputeScreenPos(OUT.position);
                OUT.worldPos = vertex_position_inputs.positionWS;
                OUT.worldNormal = vertex_normal_inputs.normalWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
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
                float3 viewNormal = mul(unity_WorldToCamera, IN.worldNormal);
                float3 halfDir = normalize(viewDir + lightDir);
                float nol = dot(IN.worldNormal, lightDir);
                float noh = dot(IN.worldNormal, halfDir);
                float nov = dot(IN.worldNormal, viewDir);
                
                //Lambert HalfLambert
                float Lambert = max(0, nol);
                float HalfLambert = nol * 0.5 + 0.5;

                //Ramp采样用 HalfLambert_Ramp
                
                float HalfLambert_Ramp = smoothstep(0.0, 0.5, HalfLambert);

                //DarkRamp平滑用 LambertStep
                float LambertStep = smoothstep(0.423, 0.465, HalfLambert);

                //BaseColor
                float4 BaseTexColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, IN.uv);
                
                //MatcapUV
                float2 MatcapUV = viewNormal.xy * 0.5 + 0.5;
                
                //SkinColor
                float3 SkinColor = SAMPLE_TEXTURE2D(_SkinTex, sampler_SkinTex, MatcapUV);


                //BaseColor
                float3 BaseColor = lerp(BaseTexColor, BaseTexColor * SkinColor, _MatcapFac);
                BaseColor = lerp(BaseColor, BaseColor * _AmbientColor, _AmbientFac);
                

                //IsDay
                float IsDay = (lightDir.y + 1) / 2;
                
                //RampColor
                //采样Ramp时，HalfLmabert * AO可以得到带 AO的 RampColor
                float3 DayRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, 0.85));
                float3 NightRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, 0.35));
                float3 RampColor = lerp(NightRampColor, DayRampColor, IsDay);

                //SDF
                float3 UpVector = cross(_ForwardVector, _RightVector);
                //float3 LpU=  length(LightDir) * (dot(LightDir, UpVector) / (length(LightDir) * length(UpVector))) * (UpVector / length(UpVector));
                float3 LpU = dot(lightDir, UpVector) / pow(length(UpVector), 2) * UpVector;
                float3 LpHeadHorizon = lightDir - LpU;
                float value = acos(dot(normalize(LpHeadHorizon), normalize(_RightVector))) / PI;
                float exposeRight = step(value, 0.5);
                float value_R = pow(1 - value * 2, 3);
                float value_L = pow(value * 2 - 1, 3);
                float mixValue = lerp(value_L, value_R, exposeRight);
                float sdfRembrandtLeft = SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, float2(1 - IN.uv.x, IN.uv.y)).r;
                float sdfRembrandtRight = SAMPLE_TEXTURE2D(_SDF_Tex, sampler_SDF_Tex, IN.uv).r;
                float mixSDF = lerp(sdfRembrandtRight, sdfRembrandtLeft, exposeRight);
                float SDF = step(mixValue, mixSDF);
                SDF = lerp(0, SDF, step(0, dot(normalize(LpHeadHorizon), normalize(_ForwardVector))));

                float4 FaceShadowTex = SAMPLE_TEXTURE2D(_FaceShadow_Tex, sampler_FaceShadow_Tex, IN.uv);
                SDF *= FaceShadowTex.g;
                SDF = lerp(SDF, 1, FaceShadowTex.a);
                
                float3 FinalShadowColor = BaseColor * _ShadowColor;
                float3 Diffuse = lerp(FinalShadowColor, BaseColor, SDF);
                float3 Albedo = Diffuse;

                float rimMax = 0.3;

                float rawDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos.xy);
                float linearDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                
                float Offset = lerp(-1, 1, step(0, viewNormal.x)) * _RimOffset / _ScreenParams.x;
                //float Offset = lerp(-1, 1, step(0, viewNormal.x)) * rimOffset / _ScreenParams.x / max(1, pow(linearDepth, 0.5));
                float4 screenOffset = float4(Offset, 0, 0, 0);
                float offsetDepth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, scrPos + screenOffset.xy);
                float offsetLinearDepth = LinearEyeDepth(offsetDepth, _ZBufferParams);

                float rim = saturate(offsetLinearDepth - linearDepth);
                rim = step(_RimThreshold, rim) * clamp(rim * _RimStrength, 0, rimMax);

                float fresnelPower = 6;
                float fresnelClamp = 0.8;
                float fresnel = 1 - saturate(nov);
                fresnel = pow(fresnel, fresnelPower);
                fresnel = fresnel * fresnelClamp + (1 - fresnelClamp);

                Albedo = 1 - (1 - rim * fresnel * _RimColor * BaseTexColor * _RimFac) * (1 - Albedo);
                
                return float4(Albedo, 1);
            }
            
            ENDHLSL
        }
        Pass
        {
            Name "DrawOutline"
            Tags {"RenderPipeline" = "UniversalPipeline"}
            Cull Front
            
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            TEXTURE2D(_Face_Mask_Tex);
            SAMPLER(sampler_Face_Mask_Tex);

            float GetCameraFOV()
            {
                //https://answers.unity.com/questions/770838/how-can-i-extract-the-fov-information-from-the-pro.html
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
                float4 uv7 : TEXCOORD7;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                
                float FaceMask = SAMPLE_TEXTURE2D_LOD(_Face_Mask_Tex, sampler_Face_Mask_Tex, float4(IN.uv, 0, 0), 0).a;
                
                _OutlineOffset = lerp(0, _OutlineOffset, FaceMask);
                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.vertex.xyz);
                OUT.position = vertex_position_inputs.positionCS;
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, IN.normal.xyz);
                //将法线变换到NDC空间，乘以w，消除透视影响
                float3 ndcNormal = normalize(TransformWViewToHClip(viewNormal.xyz)) * OUT.position.w;
                //将近裁剪面右上角的位置的顶点变换到观察空间
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
                //求得屏幕宽高比
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);
                ndcNormal.x *= aspect;
                OUT.position.xy += 0.001 * clamp(_OutlineOffset * ndcNormal.xy, -50, 50);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
                
                return OUT;
            }
            float4 frag(v2f IN) : SV_Target
            {

                //Context
                Light light = GetMainLight();
                float3 lightDir = light.direction;
                
                //BaseColor
                float4 BaseTexColor = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, IN.uv);
                

                //IsDay
                float IsDay = (lightDir.y + 1) / 2;
                
                //RampColor
                float3 DayRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, 0.85));
                float3 NightRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, 0.35));
                float3 RampColor = lerp(NightRampColor, DayRampColor, IsDay);
                
                return float4(BaseTexColor * RampColor * _OutlineShadowColor, 1);
            }
            ENDHLSL
        }
        Pass 
        {
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
    CustomEditor "CelFaceShaderGUI"
}
