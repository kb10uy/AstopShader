using UnityEngine;
using UnityEditor;

namespace KusakaFactory
{
    public class AstopToggleDrawer : MaterialPropertyDrawer
    {
        public override void OnGUI(Rect position, MaterialProperty prop, GUIContent label, MaterialEditor editor)
        {
            bool previousValue = prop.floatValue >= 0.5f;
            bool newValue = EditorGUI.Toggle(position, label, previousValue);
            prop.floatValue = newValue ? 1.0f : 0.0f;
        }
    }

    public class AstopAnisotropyShaderGUI : ShaderGUI
    {
        private MaterialProperty _Color;
        private MaterialProperty _BaseColor;
        private MaterialProperty _Metallic;
        private MaterialProperty _MetallicMap;
        private MaterialProperty _Roughness;
        private MaterialProperty _RoughnessMap;
        private MaterialProperty _Anisotropy;
        private MaterialProperty _NormalMap;
        private MaterialProperty _TangentMap;
        private MaterialProperty _IsAngleMap;
        private MaterialProperty _UnityCompatibility;

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
        {
            _BaseColor = FindProperty("_BaseColor", properties, false);
            _Color = FindProperty("_Color", properties, false);
            _Metallic = FindProperty("_Metallic", properties, false);
            _MetallicMap = FindProperty("_MetallicMap", properties, false);
            _Roughness = FindProperty("_Roughness", properties, false);
            _RoughnessMap = FindProperty("_RoughnessMap", properties, false);
            _Anisotropy = FindProperty("_Anisotropy", properties, false);
            _NormalMap = FindProperty("_NormalMap", properties, false);
            _TangentMap = FindProperty("_TangentMap", properties, false);
            _IsAngleMap = FindProperty("_IsAngleMap", properties, false);
            _UnityCompatibility = FindProperty("_UnityCompatibility", properties, false);

            GUILayout.Label("BaseColor", EditorStyles.boldLabel);
            materialEditor.TexturePropertySingleLine(new GUIContent("BaseColor"), _BaseColor, _Color);
            GUILayout.Space(16);

            GUILayout.Label("Microfacet", EditorStyles.boldLabel);
            materialEditor.TexturePropertySingleLine(new GUIContent("Metallic"), _MetallicMap, _Metallic);
            materialEditor.TexturePropertySingleLine(new GUIContent("Roughness"), _RoughnessMap, _Roughness);
            GUILayout.Space(16);

            GUILayout.Label("Normal and Tangent", EditorStyles.boldLabel);
            materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map"), _NormalMap);
            materialEditor.TexturePropertySingleLine(new GUIContent("Tangent Map"), _TangentMap);
            materialEditor.ShaderProperty(_IsAngleMap, new GUIContent("Tangent Map is Angle Map"));
            materialEditor.ShaderProperty(_Anisotropy, new GUIContent("Anisotropy"));
            GUILayout.Space(16);

            GUILayout.Label("Advanced Setting", EditorStyles.boldLabel);
            materialEditor.ShaderProperty(_UnityCompatibility, new GUIContent("Unity Compatible Lighting"));
            GUILayout.Space(16);
        }
    }
}
