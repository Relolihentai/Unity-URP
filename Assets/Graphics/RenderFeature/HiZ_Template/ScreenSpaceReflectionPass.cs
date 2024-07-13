using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ScreenSpaceReflectionPass : ScriptableRenderPass
{
    private static readonly int CameraParamsID = Shader.PropertyToID("_CameraProjectionParams");
    private static readonly int CameraViewTopLeftCornerID = Shader.PropertyToID("_CameraViewTopLeftCorner");
    private static readonly int CameraViewXExtentID = Shader.PropertyToID("_CameraViewXExtent");
    private static readonly int CameraViewYExtentID = Shader.PropertyToID("_CameraViewYExtent");
    private static readonly int SourceSizeID = Shader.PropertyToID("_SourceSize");
    
    private static readonly int MinSmoothnessID = Shader.PropertyToID("_MinSmoothness");
    private static readonly int DitheringID = Shader.PropertyToID("_Dithering");
    private static readonly int ObjectThicknessID = Shader.PropertyToID("_ObjectThickness");
    private static readonly int MaxRayStepsID = Shader.PropertyToID("_MaxRaySteps");
    private static readonly int StrideID = Shader.PropertyToID("_Stride");

    private readonly Shader _ssrShader;
    private Material _ssrMaterial;
    private RTHandle _ssrRTHandle;
    private RenderTextureDescriptor _ssrRTDescriptor;

    private ScreenSpaceReflectionVolumeCompact _screenSpaceReflectionVolumeCompact;

    public ScreenSpaceReflectionPass(Shader ssrShader)
    {
        _ssrShader = ssrShader;
        _ssrRTDescriptor = new RenderTextureDescriptor(Screen.width, Screen.height, RenderTextureFormat.RGB111110Float, 0);
    }

    public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
    {
        _ssrRTDescriptor.width = cameraTextureDescriptor.width;
        _ssrRTDescriptor.height = cameraTextureDescriptor.height;
        RenderingUtils.ReAllocateIfNeeded(ref _ssrRTHandle, _ssrRTDescriptor, FilterMode.Bilinear, TextureWrapMode.Mirror);
        _screenSpaceReflectionVolumeCompact = VolumeManager.instance.stack.GetComponent<ScreenSpaceReflectionVolumeCompact>();
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        if(_screenSpaceReflectionVolumeCompact is null) return;
        
        Matrix4x4 viewMatrix = renderingData.cameraData.GetViewMatrix();
        Matrix4x4 projectionMatrix = renderingData.cameraData.GetProjectionMatrix();

        // 将camera view space 的平移置为0，用来计算world space下相对于相机的vector
        Matrix4x4 cameraViewSpaceMatrix = viewMatrix;
        cameraViewSpaceMatrix.SetColumn(3, new Vector4(0.0f, 0.0f, 0.0f, 1.0f));
        Matrix4x4 cameraViewProjection = projectionMatrix * cameraViewSpaceMatrix;

        // 计算viewProj逆矩阵，即从裁剪空间变换到世界空间
        Matrix4x4 inverseCameraVp = cameraViewProjection.inverse;

        // 计算世界空间下，近平面四个角的坐标
        Vector4 topLeftCorner = inverseCameraVp.MultiplyPoint(new Vector4(-1.0f, 1.0f, -1.0f, 1.0f));
        Vector4 topRightCorner = inverseCameraVp.MultiplyPoint(new Vector4(1.0f, 1.0f, -1.0f, 1.0f));
        Vector4 bottomLeftCorner = inverseCameraVp.MultiplyPoint(new Vector4(-1.0f, -1.0f, -1.0f, 1.0f));
        // 计算相机近平面上方向向量
        Vector4 cameraXExtent = topRightCorner - topLeftCorner;
        Vector4 cameraYExtent = bottomLeftCorner - topLeftCorner;

        // 传递参数
        float near = renderingData.cameraData.camera.nearClipPlane;
        if (_ssrMaterial is null || _ssrMaterial.IsDestroyed())
            _ssrMaterial = new Material(_ssrShader);
        _ssrMaterial.SetVector(CameraViewTopLeftCornerID, topLeftCorner);
        _ssrMaterial.SetVector(CameraViewXExtentID, cameraXExtent);
        _ssrMaterial.SetVector(CameraViewYExtentID, cameraYExtent);
        _ssrMaterial.SetVector(CameraParamsID, new Vector4(1.0f / near, 0, 0, 0));
        _ssrMaterial.SetVector(SourceSizeID, new Vector4(_ssrRTDescriptor.width, _ssrRTDescriptor.height, 1.0f / _ssrRTDescriptor.width, 1.0f / _ssrRTDescriptor.height));
        _ssrMaterial.SetFloat(MinSmoothnessID, _screenSpaceReflectionVolumeCompact.minimumSmoothness.value);
        _ssrMaterial.SetFloat(DitheringID, _screenSpaceReflectionVolumeCompact.dithering.value);
        _ssrMaterial.SetFloat(ObjectThicknessID, _screenSpaceReflectionVolumeCompact.objectThickness.value);
        _ssrMaterial.SetInt(MaxRayStepsID, _screenSpaceReflectionVolumeCompact.maxRaySteps.value);
        _ssrMaterial.SetInt(StrideID, _screenSpaceReflectionVolumeCompact.stride.value);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if(_screenSpaceReflectionVolumeCompact is null || !_screenSpaceReflectionVolumeCompact.isActive.value) return;
        var cameraTargetHandle = renderingData.cameraData.renderer.cameraColorTargetHandle;
        var cmd = CommandBufferPool.Get("SSR");
        if (cameraTargetHandle != null && _ssrRTHandle != null && _ssrMaterial != null && _screenSpaceReflectionVolumeCompact != null)
        {
            Blitter.BlitCameraTexture(cmd, cameraTargetHandle, _ssrRTHandle, _ssrMaterial, 0);
            Blitter.BlitCameraTexture(cmd, _ssrRTHandle, cameraTargetHandle);
        }
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
        _ssrRTHandle?.Release();
    }
}