using System;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

public class HiZBufferPass : ScriptableRenderPass
{
    private static readonly int MaxHiZBufferMipLevelID = Shader.PropertyToID("_MaxHiZBufferMipLevel");
    private static readonly int HiZSourceSizeID = Shader.PropertyToID("_HiZSourceSize");
    private static readonly int HiZBufferTextureID = Shader.PropertyToID("_HiZBuffer");

    private HiZSettings _hiZSettings;
    private Material _hiZMaterial;

    private RTHandle _hiZBuffer;
    private RenderTextureDescriptor _hiZBufferDescriptor;

    private RTHandle[] _hiZBufferTempRT;
    private RenderTextureDescriptor[] _hiZBufferTempRTDescriptors;

    private RTHandle _cameraDepthRTHandle;

    private ProfilingSampler _profilingSampler;


    public HiZBufferPass(HiZSettings hiZSettings)
    {
        _hiZSettings = hiZSettings;
        _hiZBufferTempRTDescriptors = new RenderTextureDescriptor[hiZSettings.mipCount];
        _hiZBufferTempRT = new RTHandle[hiZSettings.mipCount];
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var renderer = renderingData.cameraData.renderer;
        // 分配RTHandle
        var desc = renderingData.cameraData.cameraTargetDescriptor;
        // 把高和宽变换为2的整次幂 然后除以2
        var width = Math.Max((int)Math.Ceiling(Mathf.Log(desc.width, 2)), 1);
        var height = Math.Max((int)Math.Ceiling(Mathf.Log(desc.height, 2)), 1);
        width = 1 << width;
        height = 1 << height;

        _hiZBufferDescriptor = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat, 0, _hiZSettings.mipCount);
        _hiZBufferDescriptor.msaaSamples = 1;
        _hiZBufferDescriptor.useMipMap = true;
        _hiZBufferDescriptor.sRGB = false; // linear

        for (int i = 0; i < _hiZSettings.mipCount; i++)
        {
            _hiZBufferTempRTDescriptors[i] = new RenderTextureDescriptor(width, height, RenderTextureFormat.RFloat);
            _hiZBufferTempRTDescriptors[i].msaaSamples = 1;
            _hiZBufferTempRTDescriptors[i].useMipMap = false;
            _hiZBufferTempRTDescriptors[i].sRGB = false;
            width = Math.Max(width / 2, 1);
            height = Math.Max(height / 2, 1);
            RenderingUtils.ReAllocateIfNeeded(ref _hiZBufferTempRT[i], _hiZBufferTempRTDescriptors[i]);
        }

        RenderingUtils.ReAllocateIfNeeded(ref _hiZBuffer, _hiZBufferDescriptor);
        _hiZMaterial = new Material(_hiZSettings.hiZBufferShader);

        // 配置目标和清除
        ConfigureTarget(renderer.cameraColorTargetHandle);
        ConfigureClear(ClearFlag.None, Color.white);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (_hiZMaterial == null)
        {
            Debug.LogErrorFormat("{0}.Execute(): Missing material", GetType().Name);
            return;
        }

        var cmd = CommandBufferPool.Get("HiZ");

        _cameraDepthRTHandle = renderingData.cameraData.renderer.cameraDepthTargetHandle;

        //性能分析
        using (new ProfilingScope(cmd, _profilingSampler))
        {
            // mip 0
            Blitter.BlitCameraTexture(cmd, _cameraDepthRTHandle, _hiZBufferTempRT[0]);
            cmd.CopyTexture(_hiZBufferTempRT[0], 0, 0, _hiZBuffer, 0, 0);

            // mip 1~max
            for (int i = 1; i < _hiZSettings.mipCount; i++)
            {
                Blitter.BlitCameraTexture(cmd, _hiZBufferTempRT[i-1], _hiZBufferTempRT[i], _hiZMaterial, 0);
                cmd.CopyTexture(_hiZBufferTempRT[i], 0, 0, _hiZBuffer, 0, i);
            }

            // set global hiz texture
            cmd.SetGlobalFloat(MaxHiZBufferMipLevelID, _hiZSettings.mipCount - 1);
            cmd.SetGlobalTexture(HiZBufferTextureID, _hiZBuffer);
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
        _hiZBuffer?.Release();
        foreach (var tempRT in _hiZBufferTempRT)
        {
            tempRT?.Release();
        }
    }
}