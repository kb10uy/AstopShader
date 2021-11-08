Shader "KusakaFactory/AstopAniosotropy"
{
    Properties
    {
        // BaseColor
        [MainColor]
        _Color              ("Color",                     Color           ) = (1, 1, 1, 1)
        [MainTexture]
        _BaseColor          ("BaseColor",                 2D              ) = "white" {}

        // Metallic
        _Metallic           ("Metallic",                  Range (0.0, 1.0)) = 1.0
        _MetallicMap        ("Metallic Map",              2D              ) = "white" {}

        // Roughness
        _Roughness          ("Roughness",                 Range (0.0, 1.0)) = 0.0
        _RoughnessMap       ("Roughness Map",             2D              ) = "white" {}

        // 異方性
        [Normal]
        _NormalMap          ("Normal Map",                2D              ) = "bump" {}
        _Anisotropy         ("Anisotropy",                Range (0.0, 1.0)) = 0.0
        _TangentMap         ("Tangent Map",               2D              ) = "red" {}
        _IsAngleMap         ("Enable Angle Map",          Range (0.0, 1.0)) = 0.0

        // Unity 互換性倍率
        _UnityCompatibility ("Unity compatible lighting", Range (0.0, 1.0)) = 1.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 1000

        Pass
        {
            Name "Astop Opaque: ForwardBase"
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex vertex_main
            #pragma fragment fragment_main
            #pragma multi_compile_fog
            #pragma multi_compile_fwdbase
            #define ASTOP_FORWARD_BASE

            #include "KusakaPBR.hlsli"
            #include "AstopCommon.hlsli"
            #include "AstopVariables.hlsli"
            #include "AstopVertex.hlsli"
            #include "AstopFragment.hlsli"
            ENDCG
        }

        Pass
        {
            Name "Astop Opaque: ForwardAdd"
            Tags { "LightMode"="ForwardAdd" }
            Blend One One
            ZWrite Off

            CGPROGRAM
            #pragma vertex vertex_main
            #pragma fragment fragment_main
            #pragma multi_compile_fog
            #pragma multi_compile_fwdadd

            #include "KusakaPBR.hlsli"
            #include "AstopCommon.hlsli"
            #include "AstopVariables.hlsli"
            #include "AstopVertex.hlsli"
            #include "AstopFragment.hlsli"
            ENDCG
        }
    }

    Fallback "Diffuse"

    CustomEditor "KusakaFactory.AstopAnisotropyShaderGUI"
}
