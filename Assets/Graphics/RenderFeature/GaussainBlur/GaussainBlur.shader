Shader "PostProcessingTemplate/GaussainBlur"
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
        float _BlurRadius;
        CBUFFER_END

        struct appdata
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
            float4 vertex : SV_POSITION;
            float2 uvs[5] : TEXCOORD1;
        };
        float4 GetSource(float2 uv)
        {
            return SAMPLE_TEXTURE2D_X_LOD(_BlitTexture, sampler_LinearRepeat, uv, _BlitMipLevel);  
        }
        v2f vert_VerticalBlur(appdata v)
        {
            v2f o;
            #if SHADER_API_GLES
                float4 pos = v.positionOS;
                float2 uv  = v.uv;
            #else
                float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(v.vertexID);
            #endif
            
            o.vertex = pos;
            uv = uv * _BlitScaleBias.xy + _BlitScaleBias.zw;

            o.uvs[0] = uv;
            o.uvs[1] = uv + float2(0, _ScreenSize.w * 1) * _BlurRadius;
            o.uvs[2] = uv + float2(0, _ScreenSize.w * -1) * _BlurRadius;
            o.uvs[3] = uv + float2(0, _ScreenSize.w * 2) * _BlurRadius;
            o.uvs[4] = uv + float2(0, _ScreenSize.w * -2) * _BlurRadius;
            return o;
        }
        v2f vert_HorizontalBlur(appdata v)
        {
            v2f o;
            #if SHADER_API_GLES
                float4 pos = v.positionOS;
                float2 uv  = v.uv;
            #else
                float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
                float2 uv = GetFullScreenTriangleTexCoord(v.vertexID);
            #endif
            
            o.vertex = pos;
            uv = uv * _BlitScaleBias.xy + _BlitScaleBias.zw;

            o.uvs[0] = uv;
            o.uvs[1] = uv + float2(_ScreenSize.z * 1, 0) * _BlurRadius;
            o.uvs[2] = uv + float2(_ScreenSize.z * -1, 0) * _BlurRadius;
            o.uvs[3] = uv + float2(_ScreenSize.z * 2, 0) * _BlurRadius;
            o.uvs[4] = uv + float2(_ScreenSize.z * -2, 0) * _BlurRadius;
            return o;
        }
        float4 fragBlur (v2f i) : SV_Target
        {
            half weight[3] = {0.4026, 0.2442, 0.0545};
            float4 col = GetSource(i.uvs[0]) * weight[0];
            for(int j = 1; j < 3; j++)
            {
                col += GetSource(i.uvs[2 * j - 1]) * weight[j];
                col += GetSource(i.uvs[2 * j]) * weight[j];
            }
            return col;
        }
        
        ENDHLSL
        
        ZTest Always
        Cull Off
        ZWrite Off
        
        Pass
        {
            NAME "GAUSSIAN_BLUR_VERTICAL"

            HLSLPROGRAM
            #pragma vertex vert_VerticalBlur
            #pragma fragment fragBlur
            ENDHLSL
        }

        Pass
        {
            NAME "GAUSSIAN_BLUR_HORIZONTAL"

            HLSLPROGRAM
            #pragma vertex vert_HorizontalBlur
            #pragma fragment fragBlur
            ENDHLSL
        }
    }
}
