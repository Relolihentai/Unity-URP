Shader "Custom/HiZ_Mipmap_Shader"
{
    SubShader
    {
        LOD 100
        Tags 
        {
            "RenderPipeline" = "UniversalPipeline" 
        }
        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        float4 _BlitTexture_TexelSize;
        
        ENDHLSL

        ZWrite Off ZTest Always Blend Off Cull Off
        
        Pass
        {
            Tags
            {
                "RenderPipeline" = "UniversalPipeline"
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

            float4 GetSource(float2 uv, float2 offset = 0.0)
            {  
                offset *= _BlitTexture_TexelSize.zw;
                return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointRepeat, uv + offset);
            }

            float4 frag(v2f IN): SV_Target
            {
                float2 uv = IN.uv;

                half4 minDepth = half4(
                    GetSource(uv, float2(-0.5, -0.5)).r,
                    GetSource(uv, float2(-0.5, 0.5)).r,
                    GetSource(uv, float2(0.5, -0.5)).r,
                    GetSource(uv, float2(0.5, 0.5)).r
                );

                return max(max(minDepth.r, minDepth.g), max(minDepth.b, minDepth.a));
            }
            ENDHLSL
        }
    }
}
