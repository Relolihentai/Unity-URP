using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct SSAO_Setting
{
    public Material Material;
    public RenderPassEvent RenderPassEvent;
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
    private RenderTextureDescriptor _descriptor;

    private int Toy_MATRIX_InvPID = Shader.PropertyToID("Toy_MATRIX_InvP");
    public void Setup(RTHandle source, SSAO_Setting setting)
    {
        _sourceRT = source;
        _material = setting.Material;
    }
    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var renderer = renderingData.cameraData.renderer;
        _descriptor = renderingData.cameraData.cameraTargetDescriptor;
        _descriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _tmpRT0, _descriptor, FilterMode.Bilinear);
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
        Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT0, _material, 0);
        Blitter.BlitCameraTexture(cmd, _tmpRT0, _sourceRT);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
    public void Dispose()
    {
        _tmpRT0?.Release();   
    }
}


