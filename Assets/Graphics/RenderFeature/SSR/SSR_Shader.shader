Shader "Custom/SSR_Shader"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "white" {}
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
        float4 _MainTex_ST;
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

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            struct a2v
            {
                float4 vertex: POSITION;
                float3 normal: NORMAL;
                float2 uv: TEXCOORD0;
            };

            struct v2f
            {
                float4 position: SV_POSITION;
                float2 scrUV: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
                float3 worldNormal: TEXCOORD2;
                float3 viewDir: TEXCOORD3;
            };

            v2f vert(a2v IN)
            {
                v2f OUT;
                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.vertex.xyz);
                VertexNormalInputs vertex_normal_inputs = GetVertexNormalInputs(IN.vertex.xyz);
                OUT.position = vertex_position_inputs.positionCS;
                OUT.worldPos = vertex_position_inputs.positionWS;
                OUT.worldNormal = vertex_normal_inputs.normalWS;
                OUT.viewDir = GetCameraPositionWS() - OUT.worldPos;

                float4 ndcPosition = OUT.position * 0.5f;
                float4 ndcTmp;
                ndcTmp.xy = float2(ndcPosition.x, ndcPosition.y * _ProjectionParams.x) + ndcPosition.w;
                ndcTmp.zw = OUT.position.zw;
                OUT.scrUV = ndcTmp.xyz / ndcTmp.w;
                return OUT;
            }

            float4 frag(v2f IN): SV_Target
            {
                float4 finalColor = float4(1, 1, 1, 1);
                return finalColor;
            }
            
            ENDHLSL
        }
    }
}
