Shader "Custom/SSR_Shader"
{
    SubShader
    {
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline" 
        }
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _CameraViewTopLeftCorner, _CameraViewXExtent, _CameraViewYExtent, _ProjectionParams2;
        CBUFFER_END
        
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

            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D_X_FLOAT(_CameraNormalsTexture);
            SAMPLER(sampler_CameraNormalsTexture);
            
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

            half3 ReconstructViewPos(float2 uv, float linearEyeDepth)
            {
                // Screen is y-inverted
                uv.y = 1.0 - uv.y;

                float zScale = linearEyeDepth * _ProjectionParams2.x; // divide by near plane
                float3 viewPos = _CameraViewTopLeftCorner.xyz + _CameraViewXExtent.xyz * uv.x + _CameraViewYExtent.xyz * uv.y;
                viewPos *= zScale;

                return viewPos;
            }
            //float4 _ProjectionParams
            // x = 1 or -1 (-1 if projection is flipped)
            // y = near plane
            // z = far plane
            // w = 1 / far plane
            
            float4 TransformViewToScreen(float3 viewPos)
            {
                float4 clipPos = mul(UNITY_MATRIX_P, viewPos);
                clipPos.xy = (float2(clipPos.x, clipPos.y * _ProjectionParams.x) / clipPos.w * 0.5 + 0.5) * _ScreenSize.xy;
                return clipPos;
            }
            // 从视角空间坐标片元uv和深度  
            void ReconstructUVAndDepth(float3 wpos, out float2 uv, out float depth)
            {  
                float4 cpos = mul(UNITY_MATRIX_VP, wpos);  
                uv = float2(cpos.x, cpos.y * _ProjectionParams.x) / cpos.w * 0.5 + 0.5;
                depth = cpos.w;
            }
            float4 GetSource(float2 uv)
            {  
                return SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, _BlitMipLevel);  
            }
            float GetDepth(float2 uv)
            {
                return SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
            }
            float3 GetNormal(float2 uv)
            {
                return SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv);
            }

            void swap(inout float v0, inout float v1)
            {  
                float tmp = v0;  
                v0 = v1;    
                v1 = tmp;
            } 
            
            #define MAXDISTANCE 100
            #define STRIDE 5
            #define STEP_COUNT 200
            #define BINARY_COUNT 1
            // 能反射和不可能的反射之间的界限  
            #define THICKNESS 0.4

            float4 frag(v2f IN): SV_Target
            {
                float depth = GetDepth(IN.uv);
                float depthValue = LinearEyeDepth(depth, _ZBufferParams);
                float3 viewPos = ReconstructViewPos(IN.uv, depthValue);
                float3 worldPos = _WorldSpaceCameraPos + viewPos;
                
                float3 vnormal = GetNormal(IN.uv);
                //return float4(vnormal, 1);
                float3 viewDir = normalize(viewPos);
                //下面的操作都在视角空间中进行
                float3 reflectDir = TransformWorldToViewDir(normalize(reflect(viewDir, vnormal)));

                //根据最大距离求出步进端点
                float magnitude = MAXDISTANCE;
                float3 startPoint = TransformWorldToView(worldPos);
                float end = (startPoint + reflectDir * magnitude).z;
                //end = startPoint.z + reflectDir.x * magnitude;
                if (end > -_ProjectionParams.y)
                    magnitude = (-_ProjectionParams.y - startPoint.z) / reflectDir.z;
                float3 endPoint = startPoint + reflectDir * magnitude;

                float4 startFullScrPos = TransformViewToScreen(startPoint);
                float4 endFullScrPos = TransformViewToScreen(endPoint);
                
                //屏幕空间
                float2 startScrPos = startFullScrPos.xy;
                float2 endScrPos = endFullScrPos.xy;
                
                float2 delta = endScrPos - startScrPos;
                bool permute = false;
                
                if (abs(delta.x) < abs(delta.y))
                {
                    permute = true;
                    delta = delta.yx;
                    startScrPos = startScrPos.yx;
                    endScrPos = endScrPos.yx;
                }

                float2 screenStep = delta / abs(delta.x) * STRIDE;

                // 缓存当前深度和位置
                float curFac = 0.0;
                float lastFac = 0.0;
                float oriFac = 0.0;

                static float dither[16] =
                {
                    0.0, 0.5, 0.125, 0.625,
                    0.75, 0.25, 0.875, 0.375,
                    0.187, 0.687, 0.0625, 0.562,
                    0.937, 0.437, 0.812, 0.312
                };

                float2 screenSamplePoint = startScrPos;
                UNITY_LOOP
                for (int j = 0; j < BINARY_COUNT; j++)
                {
                    bool isHit = false;
                    float viewDepth = _ProjectionParams.x * startPoint.z;
                    float screenDepth = _ProjectionParams.x * startPoint.z;
                    float2 screenHitUV;

                    //dither
                    float2 ditherUV = fmod(screenSamplePoint, 4);
                    float jitter = dither[ditherUV.x * 4 + ditherUV.y];
                    screenSamplePoint += screenStep * jitter;
                    
                    for (int i = 0; i < STEP_COUNT && distance(screenSamplePoint, startScrPos) <= distance(endScrPos, startScrPos); i++)
                    {
                        // 步近
                        screenSamplePoint += screenStep;
                        screenHitUV = permute ? screenSamplePoint.yx : screenSamplePoint;
                        screenHitUV /= _ScreenSize.xy;
                        if (any(screenHitUV < 0.0) || any(screenHitUV > 1.0))
                            break;
                        screenDepth = LinearEyeDepth(GetDepth(screenHitUV), _ZBufferParams);
                        
                        // 得到步近前后两点的深度
                        lastFac = oriFac;
                        curFac = clamp((screenSamplePoint.x - startScrPos.x) / delta.x, 0, 1);
                        oriFac = curFac;

                        viewDepth = _ProjectionParams.x * (startPoint.z * endPoint.z) / lerp(endPoint.z, startPoint.z, curFac);
                        float lastViewDepth = _ProjectionParams.x * (startPoint.z * endPoint.z) / lerp(endPoint.z, startPoint.z, lastFac);
                        if (lastViewDepth > viewDepth)
                         swap(lastViewDepth, viewDepth);
                        
                        if (lastViewDepth - screenDepth > 0.1)
                        {
                            isHit = true;
                            break;
                        }
                    }
                    if (isHit)
                    {
                        if (viewDepth - screenDepth < THICKNESS)
                            return GetSource(screenHitUV) + GetSource(IN.uv);
                        screenSamplePoint -= screenStep;
                        screenStep *= 0.5;
                    }
                    else
                        return GetSource(IN.uv);
                }
                return GetSource(IN.uv);
            }
            ENDHLSL
        }

        UsePass "PostProcessingTemplate/GaussainBlur/GAUSSIAN_BLUR_VERTICAL"
        UsePass "PostProcessingTemplate/GaussainBlur/GAUSSIAN_BLUR_HORIZONTAL"

        Pass {
            Name "SSR Addtive Pass"

            ZTest NotEqual
            ZWrite Off
            Cull Off
            Blend One One, One Zero

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag

            float4 frag(Varyings input) : SV_Target {
                return float4(SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, input.texcoord, _BlitMipLevel).rgb, 1.0);  
            }
            ENDHLSL
        }

        Pass {
            Name "SSR Balance Pass"

            ZTest NotEqual
            ZWrite Off
            Cull Off
            Blend SrcColor OneMinusSrcColor, One Zero
            
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment frag
            float4 frag(Varyings input) : SV_Target {
                return float4(SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, input.texcoord, _BlitMipLevel).rgb, 1.0);  
            }
            ENDHLSL
        }
    }
}
