Shader "Custom/SSSR_Shader"
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
        
        CBUFFER_END
        
        float4 _CameraViewTopLeftCorner, _CameraViewXExtent, _CameraViewYExtent, _ProjectionParams2;
        float _MaxMipLevel,
                _MinSmoothness, _Dithering, _Thickness;
        int _MaxStepCount, _Stride;
        
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
            TEXTURE2D_X_FLOAT(_HizDepthTexture);
            SAMPLER(sampler_HizDepthTexture);
            TEXTURE2D(_GBuffer2);
            SAMPLER(sampler_GBuffer2);
            
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
                return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearRepeat, uv);  
            }
            float4 GetHitRes(float2 hitUV, float2 uv)
            {
                half4 hit = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, hitUV);
                half4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, uv);
                half smoothness = smoothstep(_MinSmoothness, 1.0, SAMPLE_TEXTURE2D_X(_CameraNormalsTexture, sampler_LinearClamp, uv).a);
                return lerp(color, hit, smoothness);
            }
            float GetHizDepth(float2 uv, float mipLevel = 0.0)
            {
                #if UNITY_REVERSED_Z
                    float rawDepth = SAMPLE_TEXTURE2D_X_LOD(_HizDepthTexture, sampler_PointClamp, uv, mipLevel);
                #else
                    float rawDepth = lerp(UNITY_NEAR_CLIP_VALUE, 1,SAMPLE_TEXTURE2D_X_LOD(_HiZBuffer, sampler_PointClamp, uv, mipLevel));
                #endif
                return rawDepth;
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

            float GetRoughness(float2 uv)
            {
                return SAMPLE_TEXTURE2D_X(_GBuffer2, sampler_GBuffer2, uv).a;
            }
            float RadicalInverse_VdC(uint bits) 
            {
                bits = (bits << 16u) | (bits >> 16u);
                bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
                bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
                bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
                bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
                return float(bits) * 2.3283064365386963e-10; // / 0x100000000
            }
            float2 Hammersley(int i, int n)
            {
                return float2(float(i) / float(n), RadicalInverse_VdC(i));
            }
            float4 ImportanceSampleGGX(float2 E, float Roughness)
            {
	            float m = Roughness * Roughness;
	            float m2 = m * m;

	            float Phi = 2 * PI * E.x;
	            float CosTheta = sqrt( (1 - E.y) / ( 1 + (m2 - 1) * E.y) );
	            float SinTheta = sqrt(1 - CosTheta * CosTheta);

	            float3 H = float3( SinTheta * cos(Phi), SinTheta * sin(Phi), CosTheta );
			            
	            float d = (CosTheta * m2 - CosTheta) * CosTheta + 1;
	            float D = m2 / (PI * d * d);
			            
	            float PDF = D * CosTheta;
	            return float4(H, PDF);
            }
            float3 TangentToWorld(float3 vec, float3 normal)
            {
                float3 up = abs(normal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
                float3 tangent = normalize(cross(up, normal));
                float3 bitangent = cross(normal, tangent);
                float3x3 TBN = {tangent, bitangent, normal};
                return mul(vec, TBN);
            }
            float4 TangentToWorld(float4 vec, float3 normal)
            {
                float3 tmp = TangentToWorld(vec.xyz, normal);
                return float4(tmp, vec.a);
            }

            #define MAXDISTANCE 15

            float4 frag(v2f IN): SV_Target
            {
                static float dither[16] =
                {
                    0.0, 0.5, 0.125, 0.625,
                    0.75, 0.25, 0.875, 0.375,
                    0.187, 0.687, 0.0625, 0.562,
                    0.937, 0.437, 0.812, 0.312
                };
                
                float depth = GetDepth(IN.uv);
                float depthValue = LinearEyeDepth(depth, _ZBufferParams);

                float roughness = 1 - GetRoughness(IN.uv);
                
                float3 viewPos = ReconstructViewPos(IN.uv, depthValue);
                float3 worldPos = _WorldSpaceCameraPos + viewPos;
                
                float3 vnormal = GetNormal(IN.uv);
                //return float4(vnormal, 1);

                float4 hNormal = float4(vnormal, 1);
                if (roughness > 0.1)
                {
                    hNormal = TangentToWorld(ImportanceSampleGGX(Hammersley(1, 4096), roughness), float4(vnormal, 1));
                }
                
                //return float4(hNormal.xyz, 1);
                
                float3 viewDir = normalize(viewPos);
                //下面的操作都在视角空间中进行
                float3 reflectDir = TransformWorldToViewDir(normalize(reflect(viewDir, hNormal.xyz)));

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

                float2 screenStep = delta / abs(delta.x) * _Stride;

                // 缓存当前深度和位置
                float curFac = 0.0;
                float lastFac = 0.0;
                float oriFac = 0.0;
                
                float2 screenSamplePoint = startScrPos;

                //dither
                float2 ditherUV = fmod(screenSamplePoint, 4);
                float jitter = lerp(1, dither[ditherUV.x * 3 + ditherUV.y], _Dithering);
                
                screenSamplePoint += screenStep * jitter;

                //HiZ
                float mipLevel = 0.0;
                
                UNITY_LOOP
                for (int i = 0; i < _MaxStepCount; i++)
                {
                    // 步近
                    screenSamplePoint += screenStep * exp2(mipLevel);
                    
                    float2 screenHitUV = permute ? screenSamplePoint.yx : screenSamplePoint;
                    screenHitUV /= _ScreenSize.xy;
                    
                    if (any(screenHitUV < 0.0) || any(screenHitUV > 1.0))
                    {
                        if (mipLevel == 0)
                        {
                            return float4(0, 0, 0, 1);
                        }
                            
                        screenSamplePoint -= screenStep * exp2(mipLevel);
                        mipLevel--;
                        break;
                    }

                    //采样mipmap
                    float screenDepth = LinearEyeDepth(GetHizDepth(screenHitUV, mipLevel), _ZBufferParams);
                    
                    // 得到步近前后两点的深度
                    lastFac = oriFac;
                    curFac = clamp((screenSamplePoint.x - startScrPos.x) / delta.x, 0, 1);
                    oriFac = curFac;
                    
                    float viewDepth = _ProjectionParams.x * (startPoint.z * endPoint.z) / lerp(endPoint.z, startPoint.z, curFac);
                    float lastViewDepth = _ProjectionParams.x * (startPoint.z * endPoint.z) / lerp(endPoint.z, startPoint.z, lastFac);
                    if (lastViewDepth > viewDepth)
                        swap(lastViewDepth, viewDepth);
                    
                    if (lastViewDepth - screenDepth > 0.01)
                    {
                        if (mipLevel == 0)
                        {
                            if (abs(viewDepth - screenDepth) < _Thickness)
                                return GetHitRes(screenHitUV, IN.uv) * roughness;
                        }
                        else
                        {
                            screenSamplePoint -= screenStep * exp2(mipLevel);
                            mipLevel--;
                        }
                    }
                    else
                    {
                        mipLevel = min(mipLevel + 1, _MaxMipLevel);
                    }
                }
                return float4(0, 0, 0, 1);
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
            Blend SrcColor OneMinusSrcColor, One Zero

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
            //Blend DstColor Zero, One Zero
            
            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment frag

            TEXTURE2D_X(_OriBlitTexture);
            SAMPLER(sampler_OriBlitTexture);
            
            float4 frag(Varyings input) : SV_Target {
                float4 blurColor = float4(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearRepeat, input.texcoord).rgb, 1.0);
                float4 sourceColor = float4(SAMPLE_TEXTURE2D_X(_OriBlitTexture, sampler_OriBlitTexture, input.texcoord).rgb, 1.0);
                return float4(blurColor.rgb + sourceColor.rgb, 1);
            }
            ENDHLSL
        }

//        Pass
//        {
//            Name "SSSR Combine Pass"
//            
//            HLSLPROGRAM
//            #pragma vertex Vert
//            #pragma fragment frag
//
//            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
//            SAMPLER(sampler_CameraDepthTexture);
//            TEXTURE2D_X_FLOAT(_CameraNormalsTexture);
//            SAMPLER(sampler_CameraNormalsTexture);
//            TEXTURE2D_X(_OriBlitTexture);
//            SAMPLER(sampler_OriBlitTexture);
//            TEXTURE2D(_GBuffer1);
//            SAMPLER(sampler_GBuffer1);
//            TEXTURE2D(_PreintegratedGF_LUT);
//            SAMPLER(sampler_PreintegratedGF_LUT);
//            TEXTURE2D(_CameraReflectionsTexture);
//            SAMPLER(sampler_CameraReflectionsTexture);
//
//            half3 ReconstructViewPos(float2 uv, float linearEyeDepth)
//            {
//                // Screen is y-inverted
//                uv.y = 1.0 - uv.y;
//
//                float zScale = linearEyeDepth * _ProjectionParams2.x; // divide by near plane
//                float3 viewPos = _CameraViewTopLeftCorner.xyz + _CameraViewXExtent.xyz * uv.x + _CameraViewYExtent.xyz * uv.y;
//                viewPos *= zScale;
//
//                return viewPos;
//            }
//            float4 TransformViewToScreen(float3 viewPos)
//            {
//                float4 clipPos = mul(UNITY_MATRIX_P, viewPos);
//                clipPos.xy = (float2(clipPos.x, clipPos.y * _ProjectionParams.x) / clipPos.w * 0.5 + 0.5) * _ScreenSize.xy;
//                return clipPos;
//            }
//            // 从视角空间坐标片元uv和深度  
//            void ReconstructUVAndDepth(float3 wpos, out float2 uv, out float depth)
//            {  
//                float4 cpos = mul(UNITY_MATRIX_VP, wpos);  
//                uv = float2(cpos.x, cpos.y * _ProjectionParams.x) / cpos.w * 0.5 + 0.5;
//                depth = cpos.w;
//            }
//            float4 PreintegratedDGF_LUT(Texture2D PreintegratedLUT, inout float3 EnergyCompensation, float3 SpecularColor, float Roughness, float NoV)
//            {
//                float3 Enviorfilter_GFD = SAMPLE_TEXTURE2D( PreintegratedLUT, sampler_PreintegratedGF_LUT, float4(Roughness, NoV, 0.0, 0.0)).rgb;
//                float3 ReflectionGF = lerp( saturate(50.0 * SpecularColor.g) * Enviorfilter_GFD.ggg, Enviorfilter_GFD.rrr, SpecularColor );
//
//                #if Multi_Scatter
//                    EnergyCompensation = 1.0 + SpecularColor * (1.0 / Enviorfilter_GFD.r - 1.0);
//                #else
//                    EnergyCompensation = 1.0;
//                #endif
//
//                return float4(ReflectionGF, Enviorfilter_GFD.b);
//            }
//            
//            float4 frag(Varyings input) : SV_Target
//            {
//                float2 uv = input.texcoord.xy;
//
//	            float4 WorldNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv) * 2 - 1;
//	            float4 SpecularColor = SAMPLE_TEXTURE2D(_GBuffer1, sampler_GBuffer1, uv);
//	            float Roughness = clamp(1 - SpecularColor.a, 0.02, 1);
//
//	            float depth = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
//                float depthValue = LinearEyeDepth(depth, _ZBufferParams);
//                float3 viewPos = ReconstructViewPos(uv, depthValue);
//                float3 viewDir = normalize(viewPos);
//
//	            float NoV = saturate(dot(WorldNormal, -viewDir));
//	            float3 EnergyCompensation;
//	            float4 PreintegratedGF = half4(PreintegratedDGF_LUT(_PreintegratedGF_LUT, EnergyCompensation, SpecularColor.rgb, Roughness, NoV).rgb, 1);
//
//	            float ReflectionOcclusion = saturate( tex2D(_SSAO_GTOTexture2SSR_RT, uv).g );
//
//                
//	            //ReflectionOcclusion = ReflectionOcclusion == 0.5 ? 1 : ReflectionOcclusion;
//	            //half ReflectionOcclusion = 1;
//
//                float4 sceneColor = SAMPLE_TEXTURE2D(_OriBlitTexture, sampler_OriBlitTexture, uv);
//	            float4 CubemapColor = SAMPLE_TEXTURE2D(_CameraReflectionsTexture, sampler_CameraReflectionsTexture, uv) * ReflectionOcclusion;
//	            sceneColor.rgb = max(1e-5, sceneColor.rgb - CubemapColor.rgb);
//
//	            float4 SSRColor = tex2D(_SSR_TemporalCurr_RT, uv);
//	            float SSRMask = sqrt(SSRColor.a);
//	            float4 ReflectionColor = (CubemapColor * (1 - SSRMask)) + (SSRColor * PreintegratedGF * SSRMask * ReflectionOcclusion);
//
//	            return sceneColor + ReflectionColor;
//            }
//            ENDHLSL
//            
//        }
    }
}
