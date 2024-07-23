using UnityEditor;
using UnityEngine;

public class CelFaceShaderGUI : ShaderGUI
{
    private Material targetMat;
    private MaterialProperty _BaseTex;
    private MaterialProperty _AmbientColor;
    private MaterialProperty _AmbientFac;
    private MaterialProperty _SDF_Tex;
    private MaterialProperty _FaceShadow_Tex;
    private MaterialProperty _Face_Mask_Tex;
    private MaterialProperty _SkinTex;
    private MaterialProperty _MatcapFac;
    private MaterialProperty _RampTex;
    private MaterialProperty _ShadowColor;
    private MaterialProperty _OutlineShadowColor;
    private MaterialProperty _OutlineOffset;
    private MaterialProperty _RimColor;
    private MaterialProperty _RimOffset;
    private MaterialProperty _RimThreshold;
    private MaterialProperty _RimStrength;
    private MaterialProperty _RimFac;

    private bool _BaseTextures = true;
    private bool _Outline = true;
    private bool _Rim = true;
    
    void FinProperties(MaterialProperty[] properties)
    {
        _BaseTex = FindProperty("_BaseTex", properties, true);
        _AmbientColor = FindProperty("_AmbientColor", properties, true);
        _AmbientFac = FindProperty("_AmbientFac", properties, true);
        _SDF_Tex = FindProperty("_SDF_Tex", properties, true);
        _FaceShadow_Tex = FindProperty("_FaceShadow_Tex", properties, true);
        _Face_Mask_Tex = FindProperty("_Face_Mask_Tex", properties, true);
        _SkinTex = FindProperty("_SkinTex", properties, true);
        _MatcapFac = FindProperty("_MatcapFac", properties, true);
        _RampTex = FindProperty("_RampTex", properties, true);
        _ShadowColor = FindProperty("_ShadowColor", properties, true);
        _OutlineShadowColor = FindProperty("_OutlineShadowColor", properties, true);
        _OutlineOffset = FindProperty("_OutlineOffset", properties, true);
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
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_SDF_Tex), _SDF_Tex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_FaceShadow_Tex), _FaceShadow_Tex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_Face_Mask_Tex), _Face_Mask_Tex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_RampTex), _RampTex);
            materialEditor.TexturePropertySingleLine(ShaderGUI_Helper.GetGUIContext(_SkinTex), _SkinTex, _MatcapFac);
            materialEditor.ColorProperty(_ShadowColor, "Shadow Color");
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
            materialEditor.ColorProperty(_RimColor, "Rim Color");
            materialEditor.RangeProperty(_RimOffset, "Rim Offset");
            materialEditor.RangeProperty(_RimThreshold, "Rim Threshold");
            materialEditor.RangeProperty(_RimStrength, "Rim Strength");
            materialEditor.RangeProperty(_RimFac, "Rim Fac");
        }
        EditorGUILayout.EndVertical();
    }
}
