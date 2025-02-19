using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct FeatureInputSetting
{
    public RenderPassEvent RenderPassEvent;
}
public class FeatureInput : ScriptableRendererFeature
{
    class FeatureInputPass : ScriptableRenderPass
    {
        private int Toy_CameraViewTopLeftCornerID = Shader.PropertyToID("Toy_CameraViewTopLeftCorner");
        private int Toy_CameraViewXExtentID = Shader.PropertyToID("Toy_CameraViewXExtent");
        private int Toy_CameraViewYExtentID = Shader.PropertyToID("Toy_CameraViewYExtent");
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // 发送参数
            Matrix4x4 view = renderingData.cameraData.GetViewMatrix();
            Matrix4x4 proj = renderingData.cameraData.GetProjectionMatrix();

            // 将camera view space 的平移置为0，用来计算world space下相对于相机的vector
            Matrix4x4 cview = view;
            cview.SetColumn(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
            Matrix4x4 cviewProj = proj * cview;

            // 计算viewProj逆矩阵，即从裁剪空间变换到世界空间
            Matrix4x4 cviewProjInv = cviewProj.inverse;

            // 计算世界空间下，近平面四个角的坐标
            Vector4 topLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1.0f, 1.0f, -1.0f, 1.0f));
            Vector4 topRightCorner = cviewProjInv.MultiplyPoint(new Vector4(1.0f, 1.0f, -1.0f, 1.0f));
            Vector4 bottomLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1.0f, -1.0f, -1.0f, 1.0f));

            // 计算相机近平面上方向向量
            Vector4 cameraXExtent = topRightCorner - topLeftCorner;
            Vector4 cameraYExtent = bottomLeftCorner - topLeftCorner;

            // 发送ReconstructViewPos参数
            Shader.SetGlobalVector(Toy_CameraViewTopLeftCornerID, topLeftCorner);
            Shader.SetGlobalVector(Toy_CameraViewXExtentID, cameraXExtent);
            Shader.SetGlobalVector(Toy_CameraViewYExtentID, cameraYExtent);
            
            // 配置目标和清除
            ConfigureClear(ClearFlag.All, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            
        }
    }

    private FeatureInputPass m_ScriptablePass;
    public FeatureInputSetting setting;

    public override void Create()
    {
        m_ScriptablePass = new FeatureInputPass();
        m_ScriptablePass.renderPassEvent = setting.RenderPassEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}


