#ifndef RANDOM_HLSL
#define RANDOM_HLSL

float Hash(float2 p)//随机函数, 返回值float[0, 1]
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

#endif