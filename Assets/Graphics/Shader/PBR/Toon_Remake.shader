Shader "ShaderTemplate/Toon_Remake"
{
    Properties
    {
        _CullOff ("Two Side", Float) = 2.0
        _Transparent ("Transparent", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        
        [Header(FakePBR)]
        [Header(BaseColor)]
        [Space(10)]
        _BaseMap ("Texture", 2D) = "white" {}
        _BaseColor("BaseColor", Color) = (1, 1, 1, 1)
        _BaseColorStrength("BaseColor Strength", Range(0, 10)) = 1
        _EmMap ("Emission Map", 2D) = "white" {}
        [HDR]_EmColor ("Emission Color", Color) = (0, 0, 0, 0)
        _EmStrength ("Emission Strength", Range(0, 10)) = 0
        
        [Header(Normal)]
        [Space(10)]
        _NormalMap("Normal Map", 2D) = "bump" { }
        
        [Header(Metallic Roughness)]
        [Space(10)]
        _AoMap ("Ao Map", 2D) = "white" {}
        _MaskMap ("Metallic Smoothness Map", 2D) = "black" {}
        _Metallic("Metallic", Range(0, 1)) = 0.0
        _Roughness("Roughness", Range(0, 1)) = 0.0
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline"
        }
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST, _BaseColor;
        float4 _EmColor;
        float _EmStrength, _BaseColorStrength;
        
        float _Metallic, _Roughness;
        float _MetallicIntensity, _RoughnessIntensity;
        CBUFFER_END
        
        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_EmMap);
        SAMPLER(sampler_EmMap);
        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
        
        ENDHLSL
        
        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            Cull [_CullOff]
            ZWrite[_ZWrite]
            Blend[_SrcBlend][_DstBlend], [_SrcBlendAlpha][_DstBlendAlpha]
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _USE_FORWARD_PLUS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_CALCULATE_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT

            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            
            #pragma shader_feature _ALPHATEST_ON
            
            #pragma shader_feature _NormalMapOn

            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_AoMap);
            SAMPLER(sampler_AoMap);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);
            
            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float4 lightMapUV : TEXCOORD1;
            };

            struct v2f
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float4 scrPos : TEXCOORD4;
                float4 lightmapUVOrVertexSH : TEXCOORD5;
            };

            float3 IndirectDiffuse( float2 uvStaticLightmap, float3 normalWS )
            {
                #ifdef LIGHTMAP_ON
                return SampleLightmap( uvStaticLightmap, normalWS );
                #else
                return SampleSH(normalWS);
                #endif
            }
            InputData InitializeInputData(v2f IN)
            {
                InputData inputData = (InputData)0;
                inputData.positionWS = IN.worldPos;
                inputData.normalizedScreenSpaceUV = float2(IN.scrPos.xy / IN.scrPos.w);
                return inputData;
            }
            float D_Function(float NdotH, float roughness)
            {
                float a2 = roughness * roughness;
                float NdotH2 = NdotH * NdotH;
                float d = (NdotH2 * (a2 - 1) + 1);
                d = d * d * PI;
                return a2 / d;
            }
            inline float G_subSection(float dot, float k)
            {
	            return dot / lerp(dot, 1, k);
            }
            float G_Function(float NdotL, float NdotV, float roughness)
            {
                float k = pow(1 + roughness, 2) * 0.5;
                return G_subSection(NdotL, k) * G_subSection(NdotV, k);
            }
            inline float3 F0_Function(float3 albedo, float metallic)
            {
                return lerp(0.04, albedo, metallic);
            }
            float3 F_Function(float HdotL, float3 F)
            {
                float Fre = exp2((-5.55473 * HdotL - 6.98316) * HdotL);
                return lerp(Fre, 1, F);
            }
            float3 Indirect_F_Function(float NdotV, float3 F0, float roughness)
            {
                float fre = exp2((-5.55473 * NdotV - 6.98316) * NdotV);
                return F0 + fre * saturate(1 - roughness - F0);
            }
            float3 IndirectSpeCube(float3 reflectDir, float3 worldPos, float2 scrPos, float roughness)
            {
                //roughness = roughness * (1.7 - 0.7 * roughness); // unity 内部不是线性 调整下 拟合曲线求近似，可以再 GGB 可视化曲线
                //float mipmapLevel = roughness * 6; // 把粗糙度 remap 到 0~6 的 7个阶段，然后进行 texture lod 采样
                float3 specularColor = GlossyEnvironmentReflection(reflectDir, worldPos, roughness, 1.0, scrPos);
                return specularColor;
            }
            
            float3 IndirectSpeFactor(float roughness, float smoothness, float3 BRDFspe, float3 F0, float NdotV)
            {
                #ifdef UNITY_COLORSPACE_GAMMA
                float SurReduction = 1 - 0.28 * roughness * roughness;
                #else
                float SurReduction = 1 / (roughness * roughness + 1);
                #endif
                #if defined(SHADER_API_GLES) // Lighting.hlsl 261 行
                float Reflectivity = BRDFspe.x;
                #else
                float Reflectivity = max(max(BRDFspe.x, BRDFspe.y), BRDFspe.z);
                #endif
                float GrazingTSection = saturate(Reflectivity + smoothness);
                float fre = Pow4(1 - NdotV); // Lighting.hlsl 第 501 行
                // float fre = exp2((-5.55473 * NdotV - 6.98316) * NdotV); // Lighting.hlsl 第 501 行，他是 4 次方，我们是 5 次方
                return lerp(F0, GrazingTSection, fre) * SurReduction;
            }

            v2f vert(a2v IN)
            {
                v2f OUT;
                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.vertex.xyz);
                VertexNormalInputs vertex_normal_inputs = GetVertexNormalInputs(IN.normal.xyz, IN.tangent);
                OUT.position = vertex_position_inputs.positionCS;
                OUT.worldPos = vertex_position_inputs.positionWS;
                OUT.worldNormal = vertex_normal_inputs.normalWS;
                OUT.worldTangent = vertex_normal_inputs.tangentWS;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.scrPos = ComputeScreenPos(OUT.position);
                OUTPUT_LIGHTMAP_UV(IN.lightMapUV, unity_LightmapST, OUT.lightmapUVOrVertexSH.xy);
                OUTPUT_SH(OUT.worldNormal, OUT.lightmapUVOrVertexSH.xyz);
                return OUT;
            }

            float4 frag(v2f IN): SV_Target
            {
                float3 worldPos = IN.worldPos;
                float4 baseTexColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                float4 emTexColor = SAMPLE_TEXTURE2D(_EmMap, sampler_EmMap, IN.uv);
                //宏定义
                //当没有贴图时使用参数，有贴图时参数失效
                float3 worldNormal = 0;
                #if _NormalMapOn
                float3 normalTexColor = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv));
                float3 worldBitTangent = cross(IN.worldNormal, IN.worldTangent);
                float3x3 tbn = float3x3(IN.worldTangent, worldBitTangent, IN.worldNormal);
                worldNormal = normalize(mul(normalTexColor, tbn));
                #else
                worldNormal = normalize(IN.worldNormal);
                #endif

                float ao = 1;
                float metallic = 0;
                float roughness = 0;
                float smoothness = 0;
                float4 aoTexColor = SAMPLE_TEXTURE2D(_AoMap, sampler_AoMap, IN.uv);
                float4 maskTexColor = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, IN.uv);
                ao = aoTexColor.r;
                metallic = maskTexColor.g + _Metallic;
                smoothness = maskTexColor.a + _Roughness;
                roughness = 1 - smoothness;
                roughness = pow(roughness, 2);

                //ShadowMask
                //阴影遮罩
                //烘焙时额外烘焙的一张贴图，用作烘焙阴影
                //记录了阴影信息，当在Distance范围内时使用实时阴影，在范围外使用烘焙阴影
                
                float4 shadowMask = float4(1, 1, 1, 1);
                float4 rawShadowMask = SAMPLE_SHADOWMASK(IN.lightmapUVOrVertexSH);
                #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
                shadowMask = rawShadowMask;
                #elif !defined (LIGHTMAP_ON)
                shadowMask = unity_ProbesOcclusion;
                #else
                shadowMask = half4(1, 1, 1, 1);
                #endif
    //             #if defined(SHADOWS_SHADOWMASK) && defined(LIGHTMAP_ON)
				//     half4 shadowMask = inputData.shadowMask;
				// #elif !defined (LIGHTMAP_ON)
				//     half4 shadowMask = unity_ProbesOcclusion;
				// #else
				//     half4 shadowMask = half4(1, 1, 1, 1);
				// #endif

                //Content
                //一些变量
                float2 scrPos = IN.scrPos.xy / IN.scrPos.w;
                float4 shadowCoord = TransformWorldToShadowCoord(worldPos);
                Light light = GetMainLight(shadowCoord, worldPos, shadowMask);
                float3 lightColor = light.color;
                float3 lightDir = light.direction;
                float3 viewDir = normalize(GetWorldSpaceViewDir(worldPos));
                float3 viewNormal = mul(unity_WorldToCamera, float4(IN.worldNormal, 0)).xyz;

                //正常的MatcapUV
                float2 matcapUV = (viewNormal * 0.5 + 0.5).xy;
                //抄的MatcapUV算法，现在用于RoughnessCap采样
                float3 reflectDir = reflect(-normalize(viewDir), worldNormal);
                half3 reflectDirVS = normalize(mul(UNITY_MATRIX_V, reflectDir)); //将反射向量转换到视角空间，平面的反射方向永远包含于球面内。
                float m = 2.82842712474619 * sqrt(reflectDirVS.z + 1.0);//2倍法向量模长
                float2 matcapUV0 = reflectDirVS.xy / m + 0.5;
                
                float nol = saturate(max(dot(worldNormal, lightDir), 1e-5));
                float lambert = dot(worldNormal, lightDir);
                float halfLambert = lambert * 0.5 + 0.5;
                float lambertStep = smoothstep(0.423, 0.465, halfLambert);
                float3 halfDir = normalize(viewDir + lightDir);
                float noh = saturate(max(dot(worldNormal, halfDir), 1e-5));

                float nov = saturate(max(dot(worldNormal, viewDir), 1e-5));
                float hol = saturate(max(dot(halfDir, lightDir), 1e-5));

                //Shadow
                float shadow = lerp(1, light.shadowAttenuation, step(0, lambert));

                //LightMap
                //烘焙贴图 或 光照探针贴图
                float3 lightmapColor = IndirectDiffuse(IN.lightmapUVOrVertexSH.xy, worldNormal);
                MixRealtimeAndBakedGI(light, worldNormal, lightmapColor);

                //BaseColor
                float3 baseColor = baseTexColor * _BaseColor * _BaseColorStrength;
                //baseColor = _ShadowRatio * baseColor * shadow + (1 - _ShadowRatio) * baseColor;
                lightColor *= shadow;
                //Diffuse
                float3 F0 = F0_Function(baseColor, metallic);
                float3 Direct_F = F_Function(hol, F0);
                float3 Ks = Direct_F;
                float3 Kd = (1 - Ks) * (1 - metallic);
                float3 diffuseColor = Kd * baseColor * lightColor * nol;
                
                //Specular
                float Direct_D = D_Function(noh, roughness);
                float Direct_G = G_Function(nol, nov, roughness);
                
                float3 BRDFSpecSection = Direct_D * Direct_G * Direct_F / (4 * nol * nov);
                float3 DirectSpecColor = Ks * BRDFSpecSection * lightColor * nol;
                
                float3 specularColor = DirectSpecColor;

                float3 albedo = diffuseColor + specularColor;
                
                //多光源
                //使用Forward+的写法
                uint addLightsCount = GetAdditionalLightsCount();
                float nol_all = nol;
                float3 pointLightColor = 0;
                float3 BRDFSpecSection_AllAdd = 0;
                InputData inputData = InitializeInputData(IN);
                float occlusion = 1.0;
                #ifdef _OCCLUSIONMAP
                    half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
                    occlusion = LerpWhiteTo(occ, _OcclusionStrength);
                #else
                    occlusion = half(1.0);
                #endif
                AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData.normalizedScreenSpaceUV, occlusion);
                LIGHT_LOOP_BEGIN(addLightsCount)
                {
                    //Context
                    Light addLight = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
                    float3 lightDir_Add = addLight.direction;
                    float3 lightColor_Add = addLight.color;
                    float3 halfDir_Add = normalize(lightDir_Add + viewDir);
                    float hol_Add = saturate(max(dot(halfDir_Add, lightDir_Add), 1e-5));
                    float nol_Add = saturate(max(dot(worldNormal, lightDir_Add), 1e-5));
                    nol_all += nol_Add;
                    float noh_Add = saturate(max(dot(worldNormal, halfDir_Add), 1e-5));
                    float shadow_Add = lerp(1, addLight.distanceAttenuation * addLight.shadowAttenuation, step(0, dot(worldNormal, lightDir_Add)));
                    float3 baseColor_Add = baseTexColor * _BaseColor;
                    //Diffuse
                    float3 F0_Add = F0_Function(baseColor_Add, metallic);
                    float3 Direct_F_Add = F_Function(hol_Add, F0_Add);
                    float3 Ks_Add = Direct_F_Add;
                    float3 Kd_Add = (1 - Ks_Add) * (1 - metallic);
                    float3 diffuse_Add = Kd_Add * baseColor_Add * lightColor_Add * shadow_Add * nol_Add;

                    //Specular
                    float Direct_D_Add = D_Function(noh_Add, roughness);
                    float Direct_G_Add = G_Function(nol_Add, nov, roughness);
                    float3 BRDFSpecSection_Add = Direct_D_Add * Direct_G_Add * Direct_F_Add / (4 * nol_Add * nov);
                    BRDFSpecSection_AllAdd += BRDFSpecSection_Add;
                    float3 specular_Add = Ks_Add * BRDFSpecSection_Add * lightColor_Add * shadow_Add * nol_Add;
                    pointLightColor += diffuse_Add + specular_Add;
                }
                LIGHT_LOOP_END

                //Indirect
                float3 Indirect_Ks = Indirect_F_Function(nov, F0, roughness);
                float3 Indirect_Kd = (1 - Indirect_Ks) * (1 - metallic);
                float3 IndirectDiffColor = lightmapColor * Indirect_Kd * baseColor;

                float3 IndirectSpeCubeColor = IndirectSpeCube(reflectDir, worldPos, scrPos, roughness);
                float3 IndirectSpeCubeFactor = IndirectSpeFactor(roughness, smoothness, BRDFSpecSection_AllAdd, F0, nov);
                
                float3 IndirectSpeColor = IndirectSpeCubeColor * IndirectSpeCubeFactor;

                float3 IndirectColor = IndirectDiffColor + IndirectSpeColor;

                float3 finalColor = albedo + pointLightColor + IndirectColor;

                finalColor += emTexColor.rgb * _EmColor * _EmStrength;
                finalColor *= ao;
                return float4(finalColor, baseTexColor.a * _BaseColor.a);
            }
            
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{ "LightMode" = "ShadowCaster" }
            
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct a2v {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };
            struct v2f {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
            
            float3 _LightDirection;
            
            v2f vert(a2v v)
            {
                v2f o = (v2f)0;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.normal);
                worldPos = ApplyShadowBias(worldPos, normalWS, _LightDirection);
                o.vertex = TransformWorldToHClip(worldPos);
    			//参考 cat like coding 博主的处理方式
                #if UNITY_REVERSED_Z
    			o.vertex.z = min(o.vertex.z, o.vertex.w * UNITY_NEAR_CLIP_VALUE);
                #else
    			o.vertex.z = max(o.vertex.z, o.vertex.w * UNITY_NEAR_CLIP_VALUE);
                #endif
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }
            real4 frag(v2f i) : SV_Target
            {
                #if _ALPHATEST_ON
                float4 col = tex2D(_MainTex, i.uv);
                clip(col.a - 0.001);
                #endif
                return 0;
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
        Pass
        {
            Name "Meta"
            Tags
            {
                "LightMode" = "Meta"
            }
            Cull Off
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UniversalMetaPass.hlsl"

            #pragma vertex UniversalVertexMeta
            #pragma fragment CartoonMetaFragment
            
            half4 CartoonMetaFragment(Varyings i) : SV_Target
            {
                float4 baseTexColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;
                float4 emTexColor = SAMPLE_TEXTURE2D(_EmMap, sampler_EmMap, i.uv);
                MetaInput metaInput;
                metaInput.Albedo = baseTexColor;
                metaInput.Emission = emTexColor * _EmColor * _EmStrength;
                return UniversalFragmentMeta(i, metaInput);
            }
            ENDHLSL
        }
    }
}
