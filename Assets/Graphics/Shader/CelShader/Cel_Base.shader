Shader "ShaderTemplate/Cel_Base"
{
    Properties
    {
        _BaseTex ("Base Tex", 2D) = "white" {}
        _AmbientColor ("Ambient Color", Color) = (1,1,1,1)
        _AmbientFac("Ambient Fac", Range(0, 1)) = 0
        
        _ILM_Tex("ILM Tex", 2D) = "white" {}
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
        
        _OutlineOffset("Outline Width", Range(0, 20)) = 3
        _OutlineShadowColor("Outline Shadow", Color) = (1, 1, 1, 1)
        
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
        float4 _AmbientColor, _ShadowColor, _RimColor,
                _OutlineShadowColor;
        float _MatcapFac, _AmbientFac, _Gloss, _KsNonMetallic, _KsMetallic, _RimFac, _RimOffset, _RimThreshold, _RimStrength,
                _OutlineOffset, _EmStrength;
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
            
            Cull Back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ToonTex);
            SAMPLER(sampler_ToonTex);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            TEXTURE2D(_SkinTex);
            SAMPLER(sampler_SkinTex);
            TEXTURE2D(_SphereTex);
            SAMPLER(sampler_SphereTex);
            TEXTURE2D(_ILM_Tex);
            SAMPLER(sampler_ILM_Tex);
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
                float3 normal : TEXCOORD5;
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
                OUT.uv7 = IN.uv7;
                OUT.scrPos = ComputeScreenPos(OUT.position);
                OUT.normal = IN.normal;
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

                //MatcapUV
                float2 matcapUV = (viewNormal * 0.5 + 0.5).xy;
                //ToonColor SkinColor
                float3 ToonColor = SAMPLE_TEXTURE2D(_ToonTex, sampler_ToonTex, matcapUV).xyz;
                float3 SkinColor = SAMPLE_TEXTURE2D(_SkinTex, sampler_SkinTex, matcapUV).xyz;

                //ILM
                float4 ILM_RGBA = SAMPLE_TEXTURE2D(_ILM_Tex, sampler_ILM_Tex, IN.uv);
                float ILM_R = ILM_RGBA.x;
                float ILM_G = ILM_RGBA.y;
                float ILM_B = ILM_RGBA.z;
                float ILM_A = ILM_RGBA.w;

                //NightRamp_V
                float ILM_Alpha_0 = 0.15;
                float ILM_Alpha_1 = 0.40;
                float ILM_Alpha_2 = 0.60;
                float ILM_Alpha_3 = 0.85;
                float ILM_Alpha_4 = 1.0;
                float ILM_Value_0 = 1.0;
                float ILM_Value_1 = 4.0;
                float ILM_Value_2 = 3.0;
                float ILM_Value_3 = 5.0;
                float ILM_Value_4 = 2.0;
                ILM_Value_0 = 0.55 - ILM_Value_0 / 10;
                ILM_Value_1 = 0.55 - ILM_Value_1 / 10;
                ILM_Value_2 = 0.55 - ILM_Value_2 / 10;
                ILM_Value_3 = 0.55 - ILM_Value_3 / 10;
                ILM_Value_4 = 0.55 - ILM_Value_4 / 10;
                float NightRamp_V = lerp(ILM_Value_4, ILM_Value_3, step(ILM_A, ILM_Alpha_3));
                NightRamp_V = lerp(NightRamp_V, ILM_Value_2, step(ILM_A, ILM_Alpha_2));
                NightRamp_V = lerp(NightRamp_V, ILM_Value_1, step(ILM_A, ILM_Alpha_1));
                NightRamp_V = lerp(NightRamp_V, ILM_Value_0, step(ILM_A, ILM_Alpha_0));

                float3 MatcapColor = lerp(ToonColor, SkinColor, step(ILM_Alpha_3, ILM_A));
                float3 BaseColor = lerp(BaseTexColor.xyz, BaseTexColor.xyz * MatcapColor, _MatcapFac);
                BaseColor = lerp(BaseColor, BaseColor * _AmbientColor.xyz, _AmbientFac);

                //DayRamp_V
                float DayRamp_V = NightRamp_V + 0.5;

                //IsDay
                float IsDay = (lightDir.y + 1) / 2;
                
                //RampColor
                //采样Ramp时，HalfLmabert * AO可以得到带 AO的 RampColor
                float3 DayRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(halfLambert_Ramp, DayRamp_V)).xyz;
                float3 DayDarkRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, DayRamp_V)).xyz;
                float3 NightRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(halfLambert_Ramp, NightRamp_V)).xyz;
                float3 NightDarkRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, NightRamp_V)).xyz;
                float3 RampColor = lerp(NightRampColor, DayRampColor, IsDay);
                float3 DarkRampColor = lerp(NightDarkRampColor, DayDarkRampColor, IsDay);

                //Diffuse
                //使用 LambertStep平滑
                float3 Diffuse = lerp(BaseColor * RampColor * _ShadowColor.xyz, BaseColor, lambertStep);
                Diffuse = lerp(BaseColor * DarkRampColor * _ShadowColor.xyz, Diffuse, 1);
                //AO使用Ramp图最左侧颜色
                //ILM_G范围为 0-0.5，大于等于0.5的部分为非AO部分，故映射为 0-1
                Diffuse = lerp(BaseColor * DarkRampColor * _ShadowColor.xyz, Diffuse, ILM_G * 2);

                //BlinnPhong
                float3 HalfDir = normalize(viewDir + lightDir);
                float NOH = dot(IN.worldNormal, HalfDir);
                float BlinnPhong = step(0, nol) * pow(max(0, NOH), _Gloss);

                //IsMetallic
                float IsMetallic = step(0.95, ILM_R);

                //Specular
                float NonMetallic_Specular = BlinnPhong * ILM_B * _KsNonMetallic;
                float3 KsMetallic_Specular = BlinnPhong * ILM_B * (lambertStep * 0.8 + 0.2) * BaseColor * _KsMetallic;
                
                float3 Specular = lerp(NonMetallic_Specular, KsMetallic_Specular, IsMetallic);
                //Metallic
                float3 Metallic = lerp(0, SAMPLE_TEXTURE2D(_MetalTex, sampler_MetalTex, matcapUV).r * BaseColor, IsMetallic);
                //return float4(Specular + Metallic, 1);

                float3 EmColor = BaseTexColor.xyz * BaseTexColor.a * _EmStrength;
                
                //Albedo
                float3 Albedo = Diffuse + Specular + Metallic + EmColor;

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

                Albedo = 1 - (1 - rim * fresnel * _RimColor.xyz * BaseTexColor.xyz * _RimFac) * (1 - Albedo);
                
                float4 FinalColor = float4(Albedo, 1);
                
                return FinalColor;
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

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ILM_Tex);
            SAMPLER(sampler_ILM_Tex);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            
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
                VertexNormalInputs vertex_normal_inputs = GetVertexNormalInputs(IN.normal, IN.tangent);
                
                float4 BaseTexColor = SAMPLE_TEXTURE2D_LOD(_BaseTex, sampler_BaseTex, IN.uv, 0);
                _OutlineOffset = lerp(0, _OutlineOffset, step(BaseTexColor.a, 0.85));

                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.vertex.xyz);
                //OUT.position = vertexPositionInputs.positionCS;
                float3 worldPos = vertex_position_inputs.positionWS;

                float3x3 tbn = float3x3(vertex_normal_inputs.tangentWS, vertex_normal_inputs.bitangentWS, vertex_normal_inputs.normalWS);
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, IN.uv7.xyz);

                worldPos += mul(IN.uv7.xyz, tbn) * _OutlineOffset * 0.001f;
                
                //float3 ndcNormal = normalize(TransformWViewToHClip(viewNormal.xyz)) * OUT.position.w;//将法线变换到NDC空间
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角的位置的顶点变换到观察空间
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
                //ndcNormal.x *= aspect;

                float zCurve = pow(1 / OUT.position.w, 0.5);
                float fovCurve = pow(GetCameraFOV(), 0.7f);
                //OUT.position.xy += 0.001f * _OutlineOffset * IN.color.a * ndcNormal.xy;
                OUT.position = TransformWorldToHClip(worldPos);
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
                
                float4 ILM_RGBA = SAMPLE_TEXTURE2D(_ILM_Tex, sampler_ILM_Tex, IN.uv);
                float ILM_A = ILM_RGBA.w;
                
                //NightRamp_V
                float ILM_Alpha_0 = 0.15;
                float ILM_Alpha_1 = 0.40;
                float ILM_Alpha_2 = 0.60;
                float ILM_Alpha_3 = 0.85;
                float ILM_Alpha_4 = 1.0;
                float ILM_Value_0 = 1.0;
                float ILM_Value_1 = 4.0;
                float ILM_Value_2 = 3.0;
                float ILM_Value_3 = 5.0;
                float ILM_Value_4 = 2.0;
                ILM_Value_0 = 0.55 - ILM_Value_0 / 10;
                ILM_Value_1 = 0.55 - ILM_Value_1 / 10;
                ILM_Value_2 = 0.55 - ILM_Value_2 / 10;
                ILM_Value_3 = 0.55 - ILM_Value_3 / 10;
                ILM_Value_4 = 0.55 - ILM_Value_4 / 10;
                float NightRamp_V = lerp(ILM_Value_4, ILM_Value_3, step(ILM_A, ILM_Alpha_3));
                NightRamp_V = lerp(NightRamp_V, ILM_Value_2, step(ILM_A, ILM_Alpha_2));
                NightRamp_V = lerp(NightRamp_V, ILM_Value_1, step(ILM_A, ILM_Alpha_1));
                NightRamp_V = lerp(NightRamp_V, ILM_Value_0, step(ILM_A, ILM_Alpha_0));
                
                //DayRamp_V
                float DayRamp_V = NightRamp_V + 0.5;

                //IsDay
                float IsDay = (lightDir.y + 1) / 2;
                
                //RampColor
                float3 DayDarkRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, DayRamp_V));
                float3 NightDarkRampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.003, NightRamp_V));
                float3 DarkRampColor = lerp(NightDarkRampColor, DayDarkRampColor, IsDay);

                return float4(BaseTexColor * DarkRampColor * _OutlineShadowColor, 1);
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
    CustomEditor "CelShaderGUI"
}
