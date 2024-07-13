Shader "Hidden/CustomScreenSpaceReflection"
{
    HLSLINCLUDE
    #pragma target 2.0
    #include "CustomScreenSpaceReflection.HLSL"
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
            Name "SSR"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment SSRPassFragment
            ENDHLSL
        }
    }
}