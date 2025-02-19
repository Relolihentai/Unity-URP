Shader "PostProcessingTemplate/VolumetricLight"
{
    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline" 
        }
        HLSLINCLUDE

        #define MAIN_LIGHT_CALCULATE_SHADOWS  //定义阴影采样
        #define _MAIN_LIGHT_SHADOWS_CASCADE //正确地启用级联阴影

        #define MAX_MARCH_LENGTH 50

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
        #include "Assets/Graphics/Shader/Library/Input.hlsl"
        #include "Assets/Graphics/Shader/Library/Random.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _StepCount;
        float _Intensity;
        float _RandomSeed;
        int _FilteringSize;
        float _FilteringRadius;
        CBUFFER_END
        
        TEXTURE2D_X_FLOAT(_CameraNormalsTexture);
        SAMPLER(sampler_CameraNormalsTexture);
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
            
            struct a2v
            {
                #if SHADER_API_GLES
                        float4 positionOS : POSITION;
                        float2 uv : TEXCOORD0;
                #else
                        uint vertexID : SV_VertexID;
                #endif
                        UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                
                #if SHADER_API_GLES
                        float4 pos = v.positionOS;
                        float2 uv  = v.uv;
                #else
                        float4 pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
                        float2 uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                #endif

                OUT.position = pos;
                OUT.uv = uv * _BlitScaleBias.xy + _BlitScaleBias.zw;
                return OUT;
            }

            float GetLightAttenuation(float3 position)
            {
                float4 shadowPos = TransformWorldToShadowCoord(position);
                return MainLightRealtimeShadow(shadowPos); //返回阴影值
            }

            float3 ReconstructViewPos(float2 uv, float linearEyeDepth) {  
                //翻转屏幕
                #ifdef UNITY_UV_STARTS_AT_TOP
                    uv.y = 1 - uv.y;
                #endif

                float zScale = linearEyeDepth / _ProjectionParams.y; // 除以近平面
                float3 viewPos = Toy_CameraViewTopLeftCorner.xyz + Toy_CameraViewXExtent.xyz * uv.x + Toy_CameraViewYExtent.xyz * uv.y;  
                viewPos *= zScale;
                return viewPos;  
            }

            float4 frag(v2f IN): SV_Target
            {
                //棋盘式更新
                float2 channel = floor(IN.position);
                clip(channel.y % 2 * channel.x % 2 + (channel.y + 1) % 2 * (channel.x + 1) % 2 - 0.1f);

                //重建世界坐标
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, IN.uv);
                float linearEyeDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                float3 worldPos = ReconstructViewPos(IN.uv, linearEyeDepth) + GetCameraPositionWS();

                //起点：相机世界坐标
                //终点：像素世界坐标
                float3 cameraPos = _WorldSpaceCameraPos;
                float3 startPos = cameraPos;
                float3 sampleDir = normalize(worldPos - startPos);
                float totalLength = length(worldPos - startPos);
                totalLength = min(totalLength, MAX_MARCH_LENGTH);
                float3 endPos = startPos + sampleDir * totalLength;

                float intensity = 0;
                float2 step = 1 / _StepCount;
                //随机扰动
                step.y *= 0.4;
                float seed = Random(_ScreenParams.y * IN.uv.x + IN.uv.y * _ScreenParams.x);
                for (float i = 0; i < 1; i += step.x)
                {
                    seed = Random(seed);
                    float3 curSamplePos = lerp(startPos, endPos, i + seed * step.y);
                    //用Unity内置函数获取阴影值
                    float atten = GetLightAttenuation(curSamplePos) * _Intensity;
                    intensity += atten;
                }
                intensity /= _StepCount;

                Light light;
                light = GetMainLight();
                return float4(intensity * light.color, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "BilateralFiltering"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_VolumetricLightMap);
            SAMPLER(sampler_VolumetricLightMap);
            
            struct a2v
            {
                #if SHADER_API_GLES
                        float4 positionOS : POSITION;
                        float2 uv : TEXCOORD0;
                #else
                        uint vertexID : SV_VertexID;
                #endif
                        UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                
                #if SHADER_API_GLES
                        float4 pos = v.positionOS;
                        float2 uv  = v.uv;
                #else
                        float4 pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
                        float2 uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                #endif

                OUT.position = pos;
                OUT.uv = uv * _BlitScaleBias.xy + _BlitScaleBias.zw;
                return OUT;
            }
            
            float4 frag(v2f IN): SV_Target
            {
                float4 colorSum = 0;
                for (int i = -_FilteringSize; i < _FilteringSize; i++)
                {
                    for (int j = -_FilteringSize; j < _FilteringSize; j++)
                    {
                        float2 offsetUV = IN.uv + float2(i * _FilteringRadius / _ScreenParams.x, j * _FilteringRadius / _ScreenParams.y);
                        colorSum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, offsetUV);
                    }
                }
                colorSum /= _FilteringSize * _FilteringSize * 4;
                return colorSum;
                
                // float4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.uv);
                // float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, IN.uv);
                // float eyeDepth = Linear01Depth(rawDepth, _ZBufferParams);
                // float weightSum = 0;
                // float4 colorSum = 0;
                // for (int i = -_FilteringSize; i < _FilteringSize; i++)
                // {
                //     for (int j = -_FilteringSize; j < _FilteringSize; j++)
                //     {
                //         float emptySpaceSigma_2 = _EmptySpaceSigma * _EmptySpaceSigma;
                //         float2 offsetUV = IN.uv + float2(i * _FilteringRadius / _ScreenParams.x, j * _FilteringRadius / _ScreenParams.y);
                //         float emptySapceFactor = i * i + j * j;
                //         emptySapceFactor = -emptySapceFactor / (2 * emptySpaceSigma_2);
                //         float emptySpaceWeight = exp(emptySapceFactor) / (2 * PI * emptySpaceSigma_2);
                //         
                //         float valueSpaceSigma_2 = _ValueSpaceSigma * _ValueSpaceSigma;
                //         float offsetRawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, offsetUV);
                //         float offsetEyeDepth = Linear01Depth(offsetRawDepth, _ZBufferParams);
                //         float valueSpaceFactor = abs(eyeDepth - offsetEyeDepth);
                //         valueSpaceFactor = valueSpaceFactor * valueSpaceFactor;
                //         valueSpaceFactor = -valueSpaceFactor / (2 * valueSpaceSigma_2);
                //         float valueSpaceWeight = exp(valueSpaceFactor) / (2 * PI * valueSpaceSigma_2);
                //         float finalWeight = emptySpaceWeight * valueSpaceWeight;
                //         weightSum += finalWeight;
                //         colorSum += sourceColor * finalWeight;
                //     }
                // }
                // return colorSum;
                // if (weightSum > 0) return colorSum / weightSum;
                // return sourceColor;
            }
            ENDHLSL
        }

        Pass
        {
            Name "Blend"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_VolumetricLightMap);
            SAMPLER(sampler_VolumetricLightMap);
            
            struct a2v
            {
                #if SHADER_API_GLES
                        float4 positionOS : POSITION;
                        float2 uv : TEXCOORD0;
                #else
                        uint vertexID : SV_VertexID;
                #endif
                        UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 position: SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                
                #if SHADER_API_GLES
                        float4 pos = v.positionOS;
                        float2 uv  = v.uv;
                #else
                        float4 pos = GetFullScreenTriangleVertexPosition(IN.vertexID);
                        float2 uv = GetFullScreenTriangleTexCoord(IN.vertexID);
                #endif

                OUT.position = pos;
                OUT.uv = uv * _BlitScaleBias.xy + _BlitScaleBias.zw;
                return OUT;
            }
            
            float4 frag(v2f IN): SV_Target
            {
                return SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.uv)
                        + SAMPLE_TEXTURE2D(_VolumetricLightMap, sampler_VolumetricLightMap, IN.uv);
            }
            ENDHLSL
        }
    }
}
