using UnityEngine;
using UnityEngine.Rendering.Universal;


[DisallowMultipleRendererFeature("Screen Space Reflection RendererFeature")]
public class ScreenSpaceReflectionRendererFeature : ScriptableRendererFeature
{
    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
    [SerializeField] private Shader ssrShader;
    private Material _ssrMaterial;

    private ScreenSpaceReflectionPass _screenSpaceReflectionPass;

    public override void Create()
    {
        ssrShader ??= Shader.Find("Hidden/CustomScreenSpaceReflection");
        _screenSpaceReflectionPass = new ScreenSpaceReflectionPass(ssrShader)
        {
            renderPassEvent = renderPassEvent
        };
        //Application.targetFrameRate = 120;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_screenSpaceReflectionPass != null)
        {
            renderer.EnqueuePass(_screenSpaceReflectionPass);
        }
    }

    protected override void Dispose(bool disposing)
    {
        _screenSpaceReflectionPass.Dispose();
    }
}