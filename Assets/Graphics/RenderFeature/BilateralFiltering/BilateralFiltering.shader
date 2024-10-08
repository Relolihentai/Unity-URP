Shader "PostProcessingTemplate/BilateralFiltering"
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
        float filteringFactor;
        float filteringRadius;
        CBUFFER_END
        
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
            float2 delta : TEXCOORD1;
        };
        
        float CompareNormal(float3 nor1,float3 nor2)
        {
        	return smoothstep(filteringFactor, 1.0, dot(nor1,nor2));
        }
        float GetWorldNormal(float2 uv)
        {
            return SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, uv);
        }
        
        float4 fragBilateral(v2f IN) : SV_Target
        {
            float2 uv = IN.uv;
            float2 delta = IN.delta;
            float2 uv0a = IN.uv - delta;
            float2 uv0b = IN.uv + delta;	
            float2 uv1a = IN.uv - 2.0 * delta;
            float2 uv1b = IN.uv + 2.0 * delta;
            float2 uv2a = IN.uv - 3.0 * delta;
            float2 uv2b = IN.uv + 3.0 * delta;
            
            float3 normal = GetWorldNormal(uv);
            float3 normal0a = GetWorldNormal(uv0a);
            float3 normal0b = GetWorldNormal(uv0b);
            float3 normal1a = GetWorldNormal(uv1a);
            float3 normal1b = GetWorldNormal(uv1b);
            float3 normal2a = GetWorldNormal(uv2a);
            float3 normal2b = GetWorldNormal(uv2b);
            
            float4 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
            float4 col0a = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv0a);
            float4 col0b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv0b);
            float4 col1a = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv1a);
            float4 col1b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv1b);
            float4 col2a = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv2a);
            float4 col2b = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv2b);
            
            float w = 0.37004405286;
            float w0a = CompareNormal(normal, normal0a) * 0.31718061674;
            float w0b = CompareNormal(normal, normal0b) * 0.31718061674;
            float w1a = CompareNormal(normal, normal1a) * 0.19823788546;
            float w1b = CompareNormal(normal, normal1b) * 0.19823788546;
            float w2a = CompareNormal(normal, normal2a) * 0.11453744493;
            float w2b = CompareNormal(normal, normal2b) * 0.11453744493;
            
            float3 result = w * col.rgb;
            result += w0a * col0a.rgb;
            result += w0b * col0b.rgb;
            result += w1a * col1a.rgb;
            result += w1b * col1b.rgb;
            result += w2a * col2a.rgb;
            result += w2b * col2b.rgb;
            
            result /= w + w0a + w0b + w1a + w1b + w2a + w2b;
            return float4(result, 1.0);
        }
        ENDHLSL
        

        Pass
        {
            Name "BilateralFilteringPass"
            
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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
                OUT.delta = 0;
                return OUT;
            }

            float4 frag(v2f IN): SV_Target
            {
                float4 colorSum = 0;
                for (int i = -2; i < 2; i++)
                {
                    for (int j = -2; j < 2; j++)
                    {
                        float2 offsetUV = IN.uv + float2(i / _ScreenParams.x, j / _ScreenParams.y);
                        colorSum += SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, offsetUV);
                    }
                }
                colorSum /= 16;
                return colorSum;
                
                // float4 curColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.uv);
                // float4 curNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, IN.uv);
                // float weightSum = 0;
                // float4 colorSum = 0;
                // for (int i = -filteringSize; i <= filteringSize; i++)
                // {
                //     for (int j = -filteringSize; j <= filteringSize; j++)
                //     {
                //         float emptySpaceSigma_2 = emptySpaceSigma * emptySpaceSigma;
                //         float2 offsetUV = IN.uv + float2(i * filteringRadius / _ScreenParams.x, j * filteringRadius / _ScreenParams.y);
                //         float emptySapceFactor = i * i + j * j;
                //         emptySapceFactor = -emptySapceFactor / (2 * emptySpaceSigma_2);
                //         float emptySpaceWeight = exp(emptySapceFactor) / (2 * PI * emptySpaceSigma_2);
                //
                //         float valueSpaceSigma_2 = valueSpaceSigma * valueSpaceSigma;
                //         float4 offsetNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, offsetUV);
                //         float valueSpaceFactor = distance(curNormal, offsetNormal);
                //         valueSpaceFactor = valueSpaceFactor * valueSpaceFactor;
                //         valueSpaceFactor = -valueSpaceFactor / (2 * valueSpaceSigma_2);
                //         float valueSpaceWeight = exp(valueSpaceFactor) / (2 * PI * valueSpaceSigma_2);
                //         float finalWeight = emptySpaceWeight * valueSpaceWeight;
                //         weightSum += finalWeight;
                //         colorSum += curColor * finalWeight;
                //     }
                // }
                // if (weightSum > 0) return colorSum / weightSum;
                // return curColor;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "Bilateral_V"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex vert_V
            #pragma fragment fragBilateral
            
            v2f vert_V(a2v IN)
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
                OUT.delta = float2(filteringRadius, 0) / _ScreenParams.xy;
                return OUT;
            }
            
            ENDHLSL
        }

        Pass
        {
            Name "Bilateral_H"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM
            #pragma vertex vert_H
            #pragma fragment fragBilateral
            
            v2f vert_H(a2v IN)
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
                OUT.delta = float2(0, filteringRadius) / _ScreenParams.xy;
                return OUT;
            }
            
            ENDHLSL
        }
    }
}
