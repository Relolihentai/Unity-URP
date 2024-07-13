Shader "Hidden/CustomHiZBuffer"
{
    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

    float4 _BlitTexture_TexelSize;
    
    half4 GetSource(half2 uv, float2 offset) {
        offset *= _BlitTexture_TexelSize.zw;
        return SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_PointRepeat, uv + offset);
    }

    half4 HiZFragment(Varyings input) : SV_Target {
        float2 uv = input.texcoord;
        half4 minDepth = half4(
            GetSource(uv, float2(-0.5, -0.5)).r,
            GetSource(uv, float2(-0.5,  0.5)).r,
            GetSource(uv, float2( 0.5, -0.5)).r,
            GetSource(uv, float2( 0.5,  0.5)).r
        );
        return max(max(minDepth.r, minDepth.g), max(minDepth.b, minDepth.a));
    }
    
    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"
        }
        
        LOD 100
        ZWrite Off ZTest Always Blend Off Cull Off
        
        Pass
        {
            Name "HiZBuffer"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment HiZFragment
            ENDHLSL
        }
    }
}