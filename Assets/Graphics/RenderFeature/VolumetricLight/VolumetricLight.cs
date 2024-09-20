using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Random = UnityEngine.Random;

[Serializable]
public struct VolumeLightSetting
{
    public RenderPassEvent RenderPassEvent;
    [Range(0, 64)] public int StepCount;
    [Range(0, 3)] public float Intensity;
    [Range(0, 5)] public int DownSample;
    [Range(0, 5)] public int FilteringSize;
    [Range(0, 10)] public float FilteringRadius;
}
public class VolumetricLight : ScriptableRendererFeature
{
    VolumetricLightRenderPass m_ScriptablePass;
    public VolumeLightSetting setting;
    public override void Create()
    {
        m_ScriptablePass = new VolumetricLightRenderPass();
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

class VolumetricLightRenderPass : ScriptableRenderPass
{
    private Material _material;
    private string _passTag = "VolumetricLight_Pass";

    private RenderTextureDescriptor _descriptor;
    private RTHandle _sourceRT;
    private RTHandle _tmpRT;
    private RTHandle _tmpRT1;

    private int _stepCount;
    private float _intensity;
    private int _downSample;
    private int _filteringSize;
    private float _filteringRadius;
    private int StepCountID = Shader.PropertyToID("_StepCount");
    private int IntensityID = Shader.PropertyToID("_Intensity");
    private int RandomSeedID = Shader.PropertyToID("_RandomSeed");
    private int FilteringSizeID = Shader.PropertyToID("_FilteringSize");
    private int FilteringRadiusID = Shader.PropertyToID("_FilteringRadius");
    private int VolumetricLightMapID = Shader.PropertyToID("_VolumetricLightMap");
    public void Setup(RTHandle source, VolumeLightSetting setting)
    {
        _sourceRT = source;
        if (_material == null)
            _material = new Material(Shader.Find("PostProcessingTemplate/VolumetricLight"));
        _stepCount = setting.StepCount;
        _intensity = setting.Intensity;
        _downSample = setting.DownSample;
        _filteringSize = setting.FilteringSize;
        _filteringRadius = setting.FilteringRadius;
    }
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var renderer = renderingData.cameraData.renderer;
        _descriptor = renderingData.cameraData.cameraTargetDescriptor;
        _descriptor.depthBufferBits = 0;
        _descriptor.width /= 1 << _downSample;
        _descriptor.height /= 1 << _downSample;

        RenderingUtils.ReAllocateIfNeeded(ref _tmpRT, _descriptor, FilterMode.Bilinear);
        RenderingUtils.ReAllocateIfNeeded(ref _tmpRT1, _descriptor, FilterMode.Bilinear);
        
        _material.SetInt(FilteringSizeID, _filteringSize);
        _material.SetFloat(FilteringRadiusID, _filteringRadius);
        
        ConfigureTarget(_tmpRT);
        ConfigureClear(ClearFlag.All, Color.clear);
    }
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_material == null)
        {
            Debug.LogError("VolumetricLight Render Feature _material is null");
            return;
        }
        if (_sourceRT == null)
        {
            Debug.LogError("VolumetricLight Render Feature source RT is null");
            return;
        }

        var cmd = CommandBufferPool.Get(_passTag);
        
        _material.SetInt(StepCountID, _stepCount);
        _material.SetFloat(IntensityID, _intensity);
        _material.SetFloat(RandomSeedID, Random.Range(0, 10));
        Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT, _material, 0);
        Blitter.BlitCameraTexture(cmd, _tmpRT, _tmpRT1, _material, 1);
        cmd.SetGlobalTexture(VolumetricLightMapID, _tmpRT1);
        Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT, _material, 2);
        Blitter.BlitCameraTexture(cmd, _tmpRT, _sourceRT);
        
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
    public void Dispose()
    {
        _tmpRT?.Release();
        _tmpRT1?.Release();
    }
}


