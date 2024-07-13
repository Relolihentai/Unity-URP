using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct HiZ_Mipmap_Setting
{
    public Material Material;
    [Range(1, 6)] 
    public int MipCount;
    
    public RenderPassEvent RenderPassEvent;
}
public class HiZ_Mipmap : ScriptableRendererFeature
{
    HiZ_MipmapPass m_ScriptablePass;
    public HiZ_Mipmap_Setting setting;
    public override void Create()
    {
        m_ScriptablePass = new HiZ_MipmapPass(setting);
        m_ScriptablePass.renderPassEvent = setting.RenderPassEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        m_ScriptablePass.Setup();
    }
    protected override void Dispose(bool disposing)
    {
        m_ScriptablePass.Dispose();
    }

    class HiZ_MipmapPass : ScriptableRenderPass
    {
        private string _passTag = "HiZ_MipmapPass";
        private Material _material;
        
        private RTHandle _depthRT;

        private int _mipCount;
        private RenderTextureDescriptor _descriptor;
        private RenderTextureDescriptor[] _mipDescriptors;
        private RTHandle _mipRT;
        private RTHandle[] _mipRTs;
        
        private int _hizMipmapDepthTexID = Shader.PropertyToID("_HizDepthTexture");
        private int _maxMipmapLevelID = Shader.PropertyToID("_MaxMipLevel");

        public HiZ_MipmapPass(HiZ_Mipmap_Setting setting)
        {
            _material = setting.Material;
            _mipCount = setting.MipCount;
            _mipDescriptors = new RenderTextureDescriptor[_mipCount];
            _mipRTs = new RTHandle[_mipCount];
        }
        public void Setup()
        {
            
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var renderer = renderingData.cameraData.renderer;
            
            var cameraDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            // 把高和宽变换为2的整次幂 然后除以2
            var width = Math.Max((int)Math.Ceiling(Mathf.Log(cameraDescriptor.width, 2)), 1);
            var height = Math.Max((int)Math.Ceiling(Mathf.Log(cameraDescriptor.height, 2)), 1);
            width = 1 << width;
            height = 1 << height;
            

            _descriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat, 0, _mipCount);
            _descriptor.msaaSamples = 1;
            _descriptor.useMipMap = true;
            _descriptor.sRGB = false;// linear
            
            for (int i = 0; i < _mipCount; i++) {
                _mipDescriptors[i] = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat);
                _mipDescriptors[i].msaaSamples = 1;
                _mipDescriptors[i].useMipMap = false;
                _mipDescriptors[i].sRGB = false;// linear
                RenderingUtils.ReAllocateIfNeeded(ref _mipRTs[i], _mipDescriptors[i]);
                // generate mipmap
                width = Math.Max(width / 2, 1);
                height = Math.Max(height / 2, 1);
            }
            
            RenderingUtils.ReAllocateIfNeeded(ref _mipRT, _descriptor);
            
            ConfigureTarget(renderer.cameraColorTargetHandle);
            ConfigureClear(ClearFlag.None, Color.white);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_material == null)
            {
                Debug.LogError("SSR Render Feature '_material' is null");
                return;
            }
            
            var cmd = CommandBufferPool.Get(_passTag);
            _depthRT = renderingData.cameraData.renderer.cameraDepthTargetHandle;
            
            Blitter.BlitCameraTexture(cmd, _depthRT, _mipRTs[0]);
            cmd.CopyTexture(_mipRTs[0], 0, 0, _mipRT, 0, 0);
            
            for (int i = 1; i < _mipCount; i++) 
            {
                Blitter.BlitCameraTexture(cmd, _mipRTs[i - 1], _mipRTs[i], _material, 0);
                cmd.CopyTexture(_mipRTs[i], 0, 0, _mipRT, 0, i);
            }

            cmd.SetGlobalFloat(_maxMipmapLevelID, _mipCount - 1);
            cmd.SetGlobalTexture(_hizMipmapDepthTexID, _mipRT);
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        public void Dispose()
        {
            _mipRT?.Release();
            foreach (var mipRT in _mipRTs)
            {
                mipRT?.Release();
            }
        }
    }
}


