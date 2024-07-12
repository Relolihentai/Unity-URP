using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct GaussainBlurSetting
{
    public Material Material;
    
    [Range(0.1f, 10)]
    public float _BlurRadius;
    [Range(0, 10)]
    public int downSample;
    [Range(0, 10)]
    public int iteration;
    
    public RenderPassEvent RenderPassEvent;
}
public class GaussainBlur : ScriptableRendererFeature
{
    GaussainBlurPass m_ScriptablePass;
    public GaussainBlurSetting setting;
    public override void Create()
    {
        m_ScriptablePass = new GaussainBlurPass();
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
    
    
    class GaussainBlurPass : ScriptableRenderPass
    {
        private GaussainBlurSetting _setting;
        private string _passTag = "GaussainPass";

        private RenderTextureDescriptor _descriptor;
        private RTHandle _sourceRT;
        private RTHandle _tmpRT1;
        private RTHandle _tmpRT2;
        
        private int blurRadiusID = Shader.PropertyToID("_BlurRadius");
        public void Setup(RTHandle source, GaussainBlurSetting setting)
        {
            _sourceRT = source;
            _setting = setting;
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            _descriptor = renderingData.cameraData.cameraTargetDescriptor;
            _descriptor.width >>= _setting.downSample;
            _descriptor.height >>= _setting.downSample;
            _descriptor.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(ref _tmpRT1, _descriptor, FilterMode.Bilinear);
            ConfigureTarget(_tmpRT1);
            
            RenderingUtils.ReAllocateIfNeeded(ref _tmpRT2, _descriptor, FilterMode.Bilinear);
            ConfigureTarget(_tmpRT2);
            
            ConfigureClear(ClearFlag.All, Color.clear);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_setting.Material == null)
            {
                Debug.LogError("GaussainBlur Render Feature '_material' is null");
                return;
            }

            var cmd = CommandBufferPool.Get(_passTag);

            if (_sourceRT == null)
            {
                Debug.LogError("source RT is null");
                return;
            }
            
            _setting.Material.SetFloat(blurRadiusID, _setting._BlurRadius);
            
            Blitter.BlitCameraTexture(cmd, _sourceRT, _tmpRT1, _setting.Material, 1);
            for (int i = 0; i < _setting.iteration; i++)
            {
                Blitter.BlitCameraTexture(cmd, _tmpRT1, _tmpRT2, _setting.Material, 0);
                Blitter.BlitCameraTexture(cmd, _tmpRT2, _tmpRT1, _setting.Material, 1);
            }
            Blitter.BlitCameraTexture(cmd, _tmpRT1, _sourceRT, _setting.Material, 0);
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        public void Dispose()
        {
            _tmpRT1?.Release();
            _tmpRT2?.Release();
        }
    }
}


