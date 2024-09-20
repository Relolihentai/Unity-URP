#ifndef RANDOM_HLSL
#define RANDOM_HLSL

float Hash(float2 seed)//随机函数, 返回值float[0, 1]
{
    return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
}

float Random(float2 seed)
{
    return sin(seed * 641.5467987313875 + 1.943856175);
}

float2 Hash2(float2 seed)
{
    return float2(Hash(seed), Hash(seed * seed));
}

#endif