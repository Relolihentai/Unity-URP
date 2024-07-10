using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthNormal : ScriptableRendererFeature
{
    public bool NoSSAO = false;
    DepthNormalPass m_ScriptablePass;
    public override void Create()
    {
        m_ScriptablePass = new DepthNormalPass();
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (NoSSAO) renderer.EnqueuePass(m_ScriptablePass);
    }
    class DepthNormalPass : ScriptableRenderPass
    {
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) { }
    }
}


