using UnityEditor;
using UnityEngine;

public class CelShaderGUI : ShaderGUI
{
    //Context
    private Material targetMat;

    private MaterialProperty _BaseTex;
    private MaterialProperty _AmbientColor;
    private MaterialProperty _AmbientFac;
    private MaterialProperty _ILM_Tex;
    private MaterialProperty _RampTex;
    private MaterialProperty _ToonTex;
    private MaterialProperty _SkinTex;
    private MaterialProperty _MatcapFac;
    private MaterialProperty _ShadowColor;
    private MaterialProperty _EmStrength;
    private MaterialProperty _MetalTex;
    private MaterialProperty _Gloss;
    private MaterialProperty _KsMetallic;
    private MaterialProperty _KsNonMetallic;
    private MaterialProperty _OutlineOffset;
    private MaterialProperty _OutlineShadowColor;
    private MaterialProperty _RimColor;
    private MaterialProperty _RimOffset;
    private MaterialProperty _RimThreshold;
    private MaterialProperty _RimStrength;
    private MaterialProperty _RimFac;

    private bool _BaseTextures = true;
    private bool _Metal = true;
    private bool _Outline = true;
    private bool _Rim = true;

    void FinProperties(MaterialProperty[] properties)
    {
        _BaseTex = FindProperty("_BaseTex", properties, true);
        _AmbientColor = FindProperty("_AmbientColor", properties, true);
        _AmbientFac = FindProperty("_AmbientFac", properties, true);
        _ILM_Tex = FindProperty("_ILM_Tex", properties, true);
        _RampTex = FindProperty("_RampTex", properties, true);
        _ToonTex = FindProperty("_ToonTex", properties, true);
        _SkinTex = FindProperty("_SkinTex", properties, true);
        _MatcapFac = FindProperty("_MatcapFac", properties, true);
        _ShadowColor = FindProperty("_ShadowColor", properties, true);
        _EmStrength = FindProperty("_EmStrength", properties, true);
        _MetalTex = FindProperty("_MetalTex", properties, true);
        _Gloss = FindProperty("_Gloss", properties, true);
        _KsMetallic = FindProperty("_KsMetallic", properties, true);
        _KsNonMetallic = FindProperty("_KsNonMetallic", properties, true);
        _OutlineOffset = FindProperty("_OutlineOffset", properties, true);
        _OutlineShadowColor = FindProperty("_OutlineShadowColor", properties, true);
        _RimColor = FindProperty("_RimColor", properties, true);
        _RimOffset = FindProperty("_RimOffset", properties, true);
        _RimThreshold = FindProperty("_RimThreshold", properties, true);
        _RimStrength = FindProperty("_RimStrength", properties, true);
        _RimFac = FindProperty("_RimFac", properties, true);
    }
    
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        //Context
        targetMat = materialEditor.target as Material;
        FinProperties(properties);
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _BaseTextures = ShaderGUI_Helper.Foldout(_BaseTextures, "Base Textures");
        if (_BaseTextures)
        {
            EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_BaseTex), _BaseTex, _AmbientColor, _AmbientFac);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_ILM_Tex), _ILM_Tex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_RampTex), _RampTex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_ToonTex), _ToonTex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_SkinTex), _SkinTex, _MatcapFac);
            materialEditor.ColorProperty(_ShadowColor, "Shadow Color");
            materialEditor.RangeProperty(_EmStrength, "Emission Strength");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Metal = ShaderGUI_Helper.Foldout(_Metal, "Metal");
        if (_Metal)
        {
            EditorGUI.indentLevel++;
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_MetalTex), _MetalTex, _Gloss);
            materialEditor.RangeProperty(_KsMetallic, "Ks Metallic");
            materialEditor.RangeProperty(_KsNonMetallic, "Ks No Metallic");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Outline = ShaderGUI_Helper.Foldout(_Outline, "Outline");
        if (_Outline)
        {
            EditorGUI.indentLevel++;
            materialEditor.ColorProperty(_OutlineShadowColor, "Outline Color");
            materialEditor.RangeProperty(_OutlineOffset, "Outline Width");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndVertical();
        
        EditorGUILayout.BeginVertical(EditorStyles.helpBox);
        _Rim = ShaderGUI_Helper.Foldout(_Rim, "Rim");
        if (_Rim)
        {
            EditorGUI.indentLevel++;
            materialEditor.ColorProperty(_RimColor, "Rim Color");
            materialEditor.RangeProperty(_RimOffset, "Rim Offset");
            materialEditor.RangeProperty(_RimThreshold, "Rim Threshold");
            materialEditor.RangeProperty(_RimStrength, "Rim Strength");
            materialEditor.RangeProperty(_RimFac, "Rim Fac");
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndVertical();
    }
}
