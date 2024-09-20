using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct TAASetting
{
    public RenderPassEvent RenderPassEvent;
}
public class TAA : ScriptableRendererFeature
{
    TAARenderPass m_ScriptablePass;
    public TAASetting setting;
    public override void Create()
    {
        m_ScriptablePass = new TAARenderPass();
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

class TAARenderPass : ScriptableRenderPass
{
    private Material _material;
    private string _passTag = "TAA_Pass";

    private RenderTextureDescriptor _descriptor;
    private RTHandle _sourceRT;
    private RTHandle _tmpRT;
    public void Setup(RTHandle source, TAASetting setting)
    {
        _sourceRT = source;
        if (_material == null)
            _material = new Material(Shader.Find("PostProcessingTemplate/TAA"));
    }
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var renderer = renderingData.cameraData.renderer;
        _descriptor = renderingData.cameraData.cameraTargetDescriptor;
        _descriptor.depthBufferBits = 0;

        RenderingUtils.ReAllocateIfNeeded(ref _tmpRT, _descriptor, FilterMode.Bilinear);
        
        ConfigureTarget(_tmpRT);
        ConfigureClear(ClearFlag.All, Color.clear);
    }
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_material == null)
        {
            _material = new Material(Shader.Find("PostProcessingTemplate/TAA"));
            return;
        }
        if (_sourceRT == null)
        {
            Debug.LogError("TAA Render Feature source RT is null");
            return;
        }

        var cmd = CommandBufferPool.Get(_passTag);
        
        Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT, _material, 0);
        Blitter.BlitCameraTexture(cmd, _tmpRT, _sourceRT);
        
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
    public void Dispose()
    {
        _tmpRT?.Release();
    }
}


