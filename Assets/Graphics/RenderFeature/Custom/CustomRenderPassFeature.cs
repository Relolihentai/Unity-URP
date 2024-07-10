using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct CustomSetting
{
    public Material Material;
    public RenderPassEvent RenderPassEvent;
}
public class CustomRenderPassFeature : ScriptableRendererFeature
{
    CustomRenderPass m_ScriptablePass;
    public CustomSetting setting;
    public override void Create()
    {
        m_ScriptablePass = new CustomRenderPass();
        m_ScriptablePass.renderPassEvent = setting.RenderPassEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.Setup(renderer.cameraColorTargetHandle, setting.Material);
    }
    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass.Dispose();
    }
    
    
    class CustomRenderPass : ScriptableRenderPass
    {
        private Material _material;
        private string _passTag = "CustomPass";

        private RenderTextureDescriptor _descriptor;
        private RTHandle _sourceRT;
        private RTHandle _tmpRT;
        public void Setup(RTHandle source, Material material)
        {
            _sourceRT = source;
            _material = material;
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
                Debug.LogError("Custom Render Feature '_material' is null");
                return;
            }

            var cmd = CommandBufferPool.Get(_passTag);

            if (_sourceRT == null)
            {
                Debug.LogError("source RT is null");
                return;
            }
            
            Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT, _material, 0);
            Blitter.BlitCameraTexture(cmd, _tmpRT, _sourceRT);
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            
        }
        public void Dispose()
        {
            _tmpRT?.Release();
        }
    }
}


