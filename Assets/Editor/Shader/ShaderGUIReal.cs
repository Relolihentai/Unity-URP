using System.Collections;
using UnityEngine;
using UnityEditor;
using System;

enum ShaderTexTag
{
    _MetallicTex, _RoughTex,
}

public class ShaderGUIReal : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        base.OnGUI(materialEditor, properties);
        Material targetMat = materialEditor.target as Material;
        foreach (var texTag in Enum.GetValues(typeof(ShaderTexTag)))
        {
            String tag = texTag.ToString();
            Texture mainTex = targetMat.GetTexture(tag);
            if (mainTex != null)
                targetMat.EnableKeyword(tag + "On");
            else
                targetMat.DisableKeyword(tag + "On");
        }
    }
}