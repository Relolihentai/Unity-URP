using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable]
public struct HiZ_SSR_Setting
{
    public Material Material;
    [Range(0.1f, 10)] public float BlurRadius;
    [Range(0, 10)] public int DownSample;
    [Range(0, 10)] public int Iteration;

    [Range(0, 1)] public float HitResMinSmooth;
    [Range(0, 1)] public float Dithering;
    [Range(0, 512)] public int MaxStepCount;
    [Range(0, 10)] public int Stride;
    [Range(0, 1)] public float Thickness;
    
    public RenderPassEvent RenderPassEvent;
}
public class HiZ_SSR : ScriptableRendererFeature
{
    HiZ_SSRPass m_ScriptablePass;
    public HiZ_SSR_Setting setting;
    public override void Create()
    {
        m_ScriptablePass = new HiZ_SSRPass();
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

    class HiZ_SSRPass : ScriptableRenderPass
    {
        private string _passTag = "SSR_Pass";
        private Material _material;
        private RenderTextureDescriptor _descriptor;
        
        private RTHandle _sourceRT;
        private RTHandle _oriSourceRT;
        private RTHandle _gaussainBlurRT1;
        private RTHandle _gaussainBlurRT2;

        private float _blurSize;
        private int _downSample;
        private int _iteration;

        private float _hitResMinSmooth;
        private float _dithering;
        private int _maxStepCount;
        private int _stride;
        private float _thickness;

        private int mCameraViewTopLeftCornerID = Shader.PropertyToID("_CameraViewTopLeftCorner");
        private int mCameraViewXExtentID = Shader.PropertyToID("_CameraViewXExtent");
        private int mCameraViewYExtentID = Shader.PropertyToID("_CameraViewYExtent");
        private int mProjectionParams2ID = Shader.PropertyToID("_ProjectionParams2");
        private int mBlurRadiusID = Shader.PropertyToID("_BlurRadius");
        private int mHitResMinSmoothID = Shader.PropertyToID("_MinSmoothness");
        private int mDitheringID = Shader.PropertyToID("_Dithering");
        private int mMaxStepCountID = Shader.PropertyToID("_MaxStepCount");
        private int mStrideID = Shader.PropertyToID("_Stride");
        private int mThicknessID = Shader.PropertyToID("_Thickness");

        private int mOriBlitTextureID = Shader.PropertyToID("_OriBlitTexture");
        public void Setup(RTHandle source, HiZ_SSR_Setting setting)
        {
            _material = setting.Material;
            _sourceRT = source;
            _blurSize = setting.BlurRadius;
            _downSample = setting.DownSample;
            _iteration = setting.Iteration;
            
            _hitResMinSmooth = setting.HitResMinSmooth;
            _dithering = setting.Dithering;
            _maxStepCount = setting.MaxStepCount;
            _stride = setting.Stride;
            _thickness = setting.Thickness;
        }
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            var renderer = renderingData.cameraData.renderer;
            //创建临时纹理
            var cameraDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            _descriptor = new RenderTextureDescriptor(cameraDescriptor.width >> _downSample, cameraDescriptor.height >> _downSample);
            _descriptor.depthBufferBits = 0;
            
            RenderingUtils.ReAllocateIfNeeded(ref _oriSourceRT, _descriptor, FilterMode.Bilinear);
            RenderingUtils.ReAllocateIfNeeded(ref _gaussainBlurRT1, _descriptor, FilterMode.Bilinear);
            RenderingUtils.ReAllocateIfNeeded(ref _gaussainBlurRT2, _descriptor, FilterMode.Bilinear);
            ConfigureTarget(renderer.cameraColorTargetHandle);
            ConfigureClear(ClearFlag.None, Color.white);
            
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
            _material.SetFloat(mBlurRadiusID, _blurSize);
            _material.SetFloat(mHitResMinSmoothID, _hitResMinSmooth);
            _material.SetFloat(mDitheringID, _dithering);
            _material.SetInt(mMaxStepCountID, _maxStepCount);
            _material.SetInt(mStrideID, _stride);
            _material.SetFloat(mThicknessID, _thickness);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_material == null)
            {
                Debug.LogError("SSR Render Feature '_material' is null");
                return;
            }
            if (_sourceRT == null)
            {
                Debug.LogError("SSR source RT is null");
                return;
            }
            
            var cmd = CommandBufferPool.Get(_passTag);
            
            Blitter.BlitCameraTexture(cmd, _sourceRT, _oriSourceRT);
            cmd.SetGlobalTexture(mOriBlitTextureID, _oriSourceRT);
            
            Blitter.BlitCameraTexture(cmd, _sourceRT, _gaussainBlurRT1, _material, 0);
            for (int i = 0; i < _iteration; i++)
            { 
                Blitter.BlitCameraTexture(cmd, _gaussainBlurRT1, _gaussainBlurRT2, _material, 1); 
                Blitter.BlitCameraTexture(cmd, _gaussainBlurRT2, _gaussainBlurRT1, _material, 2);
            }
            Blitter.BlitCameraTexture(cmd, _gaussainBlurRT1, _sourceRT, _material, 4);
            
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }
        public void Dispose()
        {
            _gaussainBlurRT1?.Release();
            _gaussainBlurRT2?.Release();
        }
    }
}


