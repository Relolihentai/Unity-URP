using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct SSAO_Setting
{
    public Material Material;
    public RenderPassEvent RenderPassEvent;
    [Range(0.1f, 0.3f)]public float SphereRadius;
    [Range(0, 100)]public int SampleCount;
    [Range(1, 10)] public float OffsetBound;
    [Range(0, 2)] public float SelfCheckBound;

    [Range(0, 3)] public float Intensity;
    // [Range(0, 1)] public float FilteringFactor;
    // [Range(0, 10)] public float FilteringRadius;
    // [Range(0.01f, 1)] public float EmptySpaceSigma;
    // [Range(0.01f, 1)] public float ValueSpaceSigma;
    // [Range(0, 10)] public float FilteringRadius;
    // [Range(0, 10)] public int FilteringSize;
}
public class SSAO : ScriptableRendererFeature
{
    SSAOPass m_ScriptablePass;
    public SSAO_Setting setting;
    public override void Create()
    {
        m_ScriptablePass = new SSAOPass();
        m_ScriptablePass.renderPassEvent = setting.RenderPassEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTargetHandle, setting);
    }

    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass.Dispose();
    }
}

class SSAOPass : ScriptableRenderPass
{
    private string _passTag = "SSAO_Pass";
    private Material _material;
    private RTHandle _sourceRT;
    private RTHandle _tmpRT0;
    private RTHandle _tmpRT1;
    private RenderTextureDescriptor _descriptor;

    private int Toy_MATRIX_InvPID = Shader.PropertyToID("Toy_MATRIX_InvP");
    private int sphereRadiusID = Shader.PropertyToID("sphereRadius");
    private int sampleCountID = Shader.PropertyToID("sampleCount");
    private int offsetBoundID = Shader.PropertyToID("offsetBound");
    private int selfCheckBoundID = Shader.PropertyToID("selfCheckBound");
    private int intensityID = Shader.PropertyToID("intensity");
    
    private int filteringFactorID = Shader.PropertyToID("filteringFactor");
    private int filteringRadiusID = Shader.PropertyToID("filteringRadius");
    
    // private int emptySpaceSigmaID = Shader.PropertyToID("emptySpaceSigma");
    // private int valueSpaceSigmaID = Shader.PropertyToID("valueSpaceSigma");
    // private int filteringRadiusID = Shader.PropertyToID("filteringRadius");
    // private int filteringSizeID = Shader.PropertyToID("filteringSize");
    
    private int _SSAO_MapID = Shader.PropertyToID("_SSAO_Map");
    public void Setup(RTHandle source, SSAO_Setting setting)
    {
        _sourceRT = source;
        _material = setting.Material;
        _material.SetFloat(sphereRadiusID, setting.SphereRadius);
        _material.SetInt(sampleCountID, setting.SampleCount);
        _material.SetFloat(offsetBoundID, setting.OffsetBound);
        _material.SetFloat(selfCheckBoundID, setting.SelfCheckBound);
        _material.SetFloat(intensityID, setting.Intensity);
        // _material.SetFloat(filteringFactorID, setting.FilteringFactor);
        // _material.SetFloat(filteringRadiusID, setting.FilteringRadius);
        // _material.SetFloat(emptySpaceSigmaID, setting.EmptySpaceSigma);
        // _material.SetFloat(valueSpaceSigmaID, setting.ValueSpaceSigma);
        // _material.SetFloat(filteringRadiusID, setting.FilteringRadius);
        // _material.SetInt(filteringSizeID, setting.FilteringSize);
        
    }
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var renderer = renderingData.cameraData.renderer;
        _descriptor = renderingData.cameraData.cameraTargetDescriptor;
        _descriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _tmpRT0, _descriptor, FilterMode.Bilinear);
        RenderingUtils.ReAllocateIfNeeded(ref _tmpRT1, _descriptor, FilterMode.Bilinear);
        ConfigureTarget(renderer.cameraColorTargetHandle);
        ConfigureClear(ClearFlag.None, Color.white);
    }
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_material == null)
        {
            Debug.LogError("SSAO Render Feature Material is null");
            return;
        }

        if (_sourceRT == null)
        {
            Debug.LogError("SSAO Render Feature SourceRT is null");
            return;
        }

        var cmd = CommandBufferPool.Get(_passTag);
        cmd.SetGlobalMatrix(Toy_MATRIX_InvPID, renderingData.cameraData.GetProjectionMatrix().inverse);
        //SSAO
        Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT0, _material, 0);
        //Bilateral
        // Blitter.BlitCameraTexture(cmd, _tmpRT0, _tmpRT1, _material, 1);
        // Blitter.BlitCameraTexture(cmd, _tmpRT1, _tmpRT0, _material, 2);
        Blitter.BlitCameraTexture(cmd, _tmpRT0, _tmpRT1, _material, 3);
        //Blend
        cmd.SetGlobalTexture(_SSAO_MapID, _tmpRT1);
        Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT0, _material, 4);
        Blitter.BlitCameraTexture(cmd, _tmpRT0, _sourceRT);
        
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
    public void Dispose()
    {
        _tmpRT0?.Release();
        _tmpRT1?.Release();
    }
}


