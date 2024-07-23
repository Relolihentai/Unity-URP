using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FaceVector : MonoBehaviour
{
    private Transform HeadTransform;
    private Transform HeadForward;
    private Transform HeadRight;
    public Renderer Renderer;
    private MaterialPropertyBlock materialPropertyBlock;
    void Start()
    {
        HeadTransform = transform.Find("Armature/Hips/Spine/Chest/Neck/Head").transform;
        HeadForward = transform.Find("Armature/Hips/Spine/Chest/Neck/Head/HeadForward").transform;
        HeadRight = transform.Find("Armature/Hips/Spine/Chest/Neck/Head/HeadRight").transform;
        materialPropertyBlock = new MaterialPropertyBlock();
        Renderer.GetPropertyBlock(materialPropertyBlock);
        Update();
    }

    void Update()
    {
        Vector3 forwardVector = HeadForward.position - HeadTransform.position;
        Vector3 rightVector = HeadRight.position - HeadTransform.position;
        forwardVector = forwardVector.normalized;
        rightVector = rightVector.normalized;
        materialPropertyBlock.SetVector("_ForwardVector", forwardVector);
        materialPropertyBlock.SetVector("_RightVector", rightVector);
        Renderer.SetPropertyBlock(materialPropertyBlock);
    }
}
