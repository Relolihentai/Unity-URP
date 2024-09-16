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
        float emptySpaceSigma;
        float valueSpaceSigma;
        int filteringRadius;
        CBUFFER_END
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
                float4 curColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, IN.uv);
                float weightSum = 0;
                float4 colorSum = 0;
                for (int i = -filteringRadius; i <= filteringRadius; i++)
                {
                    for (int j = -filteringRadius; j <= filteringRadius; j++)
                    {
                        float emptySpaceSigma_2 = emptySpaceSigma * emptySpaceSigma;
                        float2 offsetUV = IN.uv + float2(i / _ScreenParams.x, j / _ScreenParams.y);
                        float emptySapceFactor = i * i + j * j;
                        emptySapceFactor = -emptySapceFactor / (2 * emptySpaceSigma_2);
                        float emptySpaceWeight = 1 / (2 * PI * emptySpaceSigma_2) * exp(emptySapceFactor);

                        float valueSpaceSigma_2 = valueSpaceSigma * valueSpaceSigma;
                        float4 offsetColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, offsetUV);
                        float valueSpaceFactor = distance(curColor, offsetColor);
                        valueSpaceFactor = valueSpaceFactor * valueSpaceFactor;
                        valueSpaceFactor = -valueSpaceFactor / (2 * valueSpaceSigma_2);
                        float valueSpaceWeight = 1 / (2 * PI * valueSpaceSigma_2) * exp(valueSpaceFactor);
                        float finalWeight = emptySpaceWeight * valueSpaceWeight;
                        weightSum += finalWeight;
                        colorSum += offsetColor * finalWeight;
                    }
                }
                if (weightSum > 0) return colorSum / weightSum;
                return curColor;
            }
            ENDHLSL
        }
    }
}
