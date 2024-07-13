using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;

public class HiZBufferRendererFeature : ScriptableRendererFeature
{
    [SerializeField] 
    private HiZSettings hiZSettings;
    private HiZBufferPass _hiZBufferPass;

    public override void Create()
    {
        hiZSettings.hiZBufferShader = Shader.Find("Custom/HiZ_Mipmap_Shader");
        _hiZBufferPass = new HiZBufferPass(hiZSettings);
        _hiZBufferPass.renderPassEvent = hiZSettings.renderPassEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_hiZBufferPass);
    }

    protected override void Dispose(bool disposing)
    {
        _hiZBufferPass.Dispose();
    }
}

[Serializable]
public class HiZSettings
{
    //在1080P以下最佳设置为3
    //在1080P左右最佳设置为4
    //在4K左右最佳设置为5
    [Range(3,6)]
    public int mipCount = 6;
    public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingGbuffer;
    public Shader hiZBufferShader;
}