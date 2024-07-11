using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct SSR_Setting
{
    public Material Material;
    public RenderPassEvent RenderPassEvent;
}
public class SSR : ScriptableRendererFeature
{
    SSRPass m_ScriptablePass;
    public SSR_Setting setting;
    public override void Create()
    {
        m_ScriptablePass = new SSRPass();
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

    class SSRPass : ScriptableRenderPass
    {
        private string _passTag = "SSR_Pass";
        private Material _material;
        private RenderTextureDescriptor _descriptor;
        private RTHandle _sourceRT;
        private RTHandle _tmpRT;

        private int mCameraViewTopLeftCornerID = Shader.PropertyToID("_CameraViewTopLeftCorner");
        private int mCameraViewXExtentID = Shader.PropertyToID("_CameraViewXExtent");
        private int mCameraViewYExtentID = Shader.PropertyToID("_CameraViewYExtent");
        private int mProjectionParams2ID = Shader.PropertyToID("_ProjectionParams2");
        public void Setup(RTHandle source, SSR_Setting setting)
        {
            _material = setting.Material;
            _sourceRT = source;
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            //创建临时纹理
            _descriptor = renderingData.cameraData.cameraTargetDescriptor;
            _descriptor.depthBufferBits = 0;

            RenderingUtils.ReAllocateIfNeeded(ref _tmpRT, _descriptor, FilterMode.Bilinear);
            
            ConfigureTarget(_tmpRT);
            ConfigureClear(ClearFlag.All, Color.clear);
            
            //材质传参
            Matrix4x4 view = renderingData.cameraData.GetViewMatrix();  
            Matrix4x4 proj = renderingData.cameraData.GetProjectionMatrix();  
            Matrix4x4 vp = proj * view;  

            // 将camera view space 的平移置为0，用来计算world space下相对于相机的vector  
            Matrix4x4 cview = view;  
            cview.SetColumn(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));  
            Matrix4x4 cviewProj = proj * cview;  

            // 计算viewProj逆矩阵，即从裁剪空间变换到世界空间  
            Matrix4x4 cviewProjInv = cviewProj.inverse;  

            // 计算世界空间下，近平面四个角的坐标  
            var near = renderingData.cameraData.camera.nearClipPlane;  
            // Vector4 topLeftCorner = cviewProjInv * new Vector4(-near, near, -near, near);  
            // Vector4 topRightCorner = cviewProjInv * new Vector4(near, near, -near, near);
            // Vector4 bottomLeftCorner = cviewProjInv * new Vector4(-near, -near, -near, near);
            Vector4 topLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1.0f, 1.0f, -1.0f, 1.0f));  
            Vector4 topRightCorner = cviewProjInv.MultiplyPoint(new Vector4(1.0f, 1.0f, -1.0f, 1.0f));  
            Vector4 bottomLeftCorner = cviewProjInv.MultiplyPoint(new Vector4(-1.0f, -1.0f, -1.0f, 1.0f));  

            // 计算相机近平面上方向向量  
            Vector4 cameraXExtent = topRightCorner - topLeftCorner;  
            Vector4 cameraYExtent = bottomLeftCorner - topLeftCorner;  

            near = renderingData.cameraData.camera.nearClipPlane;  

            _material.SetVector(mCameraViewTopLeftCornerID, topLeftCorner);  
            _material.SetVector(mCameraViewXExtentID, cameraXExtent);  
            _material.SetVector(mCameraViewYExtentID, cameraYExtent);  
            _material.SetVector(mProjectionParams2ID, new Vector4(1.0f / near, renderingData.cameraData.worldSpaceCameraPos.x, renderingData.cameraData.worldSpaceCameraPos.y, renderingData.cameraData.worldSpaceCameraPos.z));  
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_material == null)
            {
                Debug.LogError("SSR Render Feature '_material' is null");
                return;
            }

            var cmd = CommandBufferPool.Get(_passTag);

            if (_sourceRT == null)
            {
                Debug.LogError("SSR source RT is null");
                return;
            }
            
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
}


