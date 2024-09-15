Shader "PostProcessingTemplate/SSAO"
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
        #include "Assets/Graphics/Shader/Library/Input.hlsl"
        #include "Assets/Graphics/Shader/Library/Random.hlsl"

        CBUFFER_START(Unity_PerMaterial)
        float sphereRadius;
        float sampleCount;
        float offsetBound;
        CBUFFER_END
        
        TEXTURE2D_X_FLOAT(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);
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

            float3 GetOffsetDirInHalfSphere(float2 uv)
            {
                float3 offsetDir = float3(Hash(uv) * 2 - 1, Hash(uv * uv) * 2 - 1, Hash(uv * uv * uv) / 0.8 + 0.2);
                return offsetDir;
            }

            float3 GetRandomVec(float2 p)
            {
                float3 vec = float3(0, 0, 0);
                vec.x = Hash(p) * 2 - 1;
                vec.y = Hash(p * p) * 2 - 1;
                vec.z = Hash(p * p * p) * 2 - 1;
                return normalize(vec);
            }

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
                float3 worldNormal = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture, IN.uv);
                worldNormal = normalize(worldNormal);

                float3 tangent = GetRandomVec(IN.uv);
                float3 bitangent = normalize(cross(tangent, worldNormal));
                tangent = normalize(cross(bitangent, worldNormal));
                float3x3 TBN = float3x3(tangent, bitangent, worldNormal);
                
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, IN.uv);
                float depth = Linear01Depth(rawDepth, _ZBufferParams);
                float4 ndcPos = float4(IN.uv * 2 - 1, rawDepth, 1);
                float far = _ProjectionParams.z;
                float3 clipVec = float3(ndcPos.x, ndcPos.y, 1.0) * far;
                float3 viewVec = mul(Toy_MATRIX_InvP, clipVec.xyzz).xyz;
                float3 viewPos = viewVec * depth;
                float3 worldPos = mul(UNITY_MATRIX_I_V, float4(viewPos, 1.0)).xyz;

                float ssao = 0;
                for (int i = 1; i <= sampleCount; i++)
                {
                    float3 offsetDir = GetOffsetDirInHalfSphere(IN.uv * i);
                    offsetDir = mul(offsetDir, TBN);
                    float scale = i / sampleCount;
                    scale = lerp(0.01, 1, scale * scale);
                    offsetDir *= scale * sphereRadius;
                    float4 samplePointClipPos = TransformWorldToHClip(worldPos + offsetDir);
                    float2 samplePointScr = samplePointClipPos.xy / samplePointClipPos.w;
                    samplePointScr = samplePointScr * 0.5 + 0.5;
                    samplePointScr.y = 1 - samplePointScr.y;
                    float samplePointDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, samplePointScr);
                    samplePointDepth = LinearEyeDepth(samplePointDepth, _ZBufferParams);
                    float sampleDepthRealDepth = samplePointClipPos.w;
                    float offset = abs(sampleDepthRealDepth - samplePointDepth);
                    float rangeCheck = smoothstep(0, offsetBound, sphereRadius / offset);
                    ssao += (sampleDepthRealDepth > samplePointDepth ? 1 : 0) * rangeCheck;
                }
                ssao /= sampleCount;
                ssao = 1 - min(ssao, 1);
                return ssao;
                
                float4 finalColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearRepeat, IN.uv);
                return finalColor * ssao;
            }
            ENDHLSL
        }
    }
}
