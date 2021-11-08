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

            #include "KusakaPBR.hlsli"
            #include "AstopCommon.hlsli"

            float4 _Color;
            sampler2D _BaseColor;

            float _Metallic;
            sampler2D _MetallicMap;

            float _Roughness;
            sampler2D _RoughnessMap;

            float _Anisotropy;
            sampler2D _NormalMap;
            sampler2D _TangentMap;
            float _IsAngleMap;

            float _UnityCompatibility;

            float3 get_reflection(float3 virw_dir, float3 position_world, float4x4 normals, float roughness)
            {
                float3 ray_reflected = normalize(reflect(-virw_dir, normals[2].xyz));

                // Box projection
                #if UNITY_SPECCUBE_BOX_PROJECTION
                if (unity_SpecCube0_ProbePosition.w > 0) {
                    float deltaX = ((ray_reflected.x > 0 ? unity_SpecCube0_BoxMax.x : unity_SpecCube0_BoxMin.x) - position_world.x) / ray_reflected.x;
                    float deltaY = ((ray_reflected.y > 0 ? unity_SpecCube0_BoxMax.y : unity_SpecCube0_BoxMin.y) - position_world.y) / ray_reflected.y;
                    float deltaZ = ((ray_reflected.z > 0 ? unity_SpecCube0_BoxMax.z : unity_SpecCube0_BoxMin.z) - position_world.z) / ray_reflected.z;
                    float delta = min(min(deltaX, deltaY), deltaZ);
                    ray_reflected = ray_reflected * delta + (position_world - unity_SpecCube0_ProbePosition.xyz);
                }
                #endif

                return DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, ray_reflected, roughness * ROUGHNESS_REFLECTION_STEP), unity_SpecCube0_HDR);
            }

            float4 fragment_main(FragmentInput fi) : SV_Target
            {
                float3 normal = normalize(fi.normal_world);
                float3 tangent = normalize(fi.tangent_world);
                float3 binormal = cross(tangent, normal);
                float3 basecolor = tex2D(_BaseColor, fi.uv_texture).rgb * _Color.rgb;
                float metallic = tex2D(_MetallicMap, fi.uv_texture).r * _Metallic;
                float roughness = tex2D(_RoughnessMap, fi.uv_texture).r * _Roughness;
                float3 normal_move = UnpackNormal(tex2D(_NormalMap, fi.uv_texture));
                float anisotropy = _Anisotropy;

                // ノーマルマップ w/ Gram-Schmidt 正規直交化
                float3x3 small_normals = transpose(float3x3(tangent, binormal, normal));
                float3 normal_mapped = normalize(mul(small_normals, normal_move));
                float3 tangent_mapped = normalize(tangent - dot(tangent, normal_mapped) * normal_mapped);
                float3 binormal_mapped = cross(tangent_mapped, normal_mapped);

                // 異方性接空間
                float theta_tangent;
                if (_IsAngleMap > 0.5) {
                    theta_tangent = tex2D(_TangentMap, fi.uv_texture).r * UNITY_TWO_PI;
                } else {
                    float2 tangent_vector = normalize(tex2D(_TangentMap, fi.uv_texture).rg * 2.0 - 1.0);
                    theta_tangent = atan2(tangent_vector.y, tangent_vector.x);
                }
                float3 tangent_aniso =
                    tangent_mapped * cos(theta_tangent) +
                    (1.0 - cos(theta_tangent)) * dot(tangent_mapped, normal_mapped) * normal_mapped +
                    cross(normal_mapped, tangent_mapped) * sin(theta_tangent);
                float3 binormal_aniso = cross(tangent_aniso, normal_mapped);
                float4x4 normals = float4x4(
                    float4(tangent_aniso, 0.0),
                    float4(binormal_aniso, 0.0),
                    float4(normal_mapped, 0.0),
                    float4(0.0, 0.0, 0.0, 1.0)
                );

                // 各種ベクトル
                UNITY_LIGHT_ATTENUATION(light_atten, fi, normal_mapped);
                float3 light_color = _LightColor0.rgb * light_atten;
                float3 light_dir = world_light0_direction(fi.position_world);
                float3 view_dir = normalize(UnityWorldSpaceViewDir(fi.position_world));
                float cosine_term = max(0.0, dot(light_dir, normal_mapped));
                float3 rho_ss = lerp(
                    basecolor,
                    float3(0.0, 0.0, 0.0),
                    metallic
                );
                float3 f0 = lerp(
                    float3(F0_DIELECTRIC, F0_DIELECTRIC, F0_DIELECTRIC),
                    basecolor,
                    metallic
                );

                float3 light_sum = 0.0;

                // 頂点ライティング
                float3 light_vertex = fi.light_vertex * brdf_diffuse(rho_ss, f0);
                light_vertex *= lerp(1.0, UNITY_PI, _UnityCompatibility);
                light_sum.rgb += light_vertex;

                // メインのライティング
                float3 light_main = light_color * cosine_term * (
                    brdf_specular_anisotropic(view_dir, light_dir, normals, roughness, anisotropy, f0) +
                    brdf_diffuse(rho_ss, f0)
                );
                light_main *= lerp(1.0, UNITY_PI, _UnityCompatibility);
                light_sum.rgb += light_main;

                // Reflection Probe
                float3 reflection = get_reflection(view_dir, fi.position_world, normals, roughness);
                float3 f_reflection = float3(
                    fresnel_schlick(normals[2].xyz, view_dir, f0.r),
                    fresnel_schlick(normals[2].xyz, view_dir, f0.g),
                    fresnel_schlick(normals[2].xyz, view_dir, f0.b)
                );
                float3 light_reflection = f_reflection * reflection;
                light_sum.rgb += light_reflection;

                return float4(light_sum, 1.0);
            }
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

            float4 _Color;
            sampler2D _BaseColor;

            float _Metallic;
            sampler2D _MetallicMap;

            float _Roughness;
            sampler2D _RoughnessMap;

            float _Anisotropy;
            sampler2D _NormalMap;
            sampler2D _TangentMap;
            float _IsAngleMap;

            float _UnityCompatibility;

            float4 fragment_main(FragmentInput fi) : SV_Target
            {
                float3 normal = normalize(fi.normal_world);
                float3 tangent = normalize(fi.tangent_world);
                float3 binormal = cross(tangent, normal);
                float3 basecolor = tex2D(_BaseColor, fi.uv_texture).rgb * _Color.rgb;
                float metallic = tex2D(_MetallicMap, fi.uv_texture).r * _Metallic;
                float roughness = tex2D(_RoughnessMap, fi.uv_texture).r * _Roughness;
                float3 normal_move = UnpackNormal(tex2D(_NormalMap, fi.uv_texture));
                float anisotropy = _Anisotropy;

                // ノーマルマップ w/ Gram-Schmidt 正規直交化
                float3x3 small_normals = transpose(float3x3(tangent, binormal, normal));
                float3 normal_mapped = normalize(mul(small_normals, normal_move));
                float3 tangent_mapped = normalize(tangent - dot(tangent, normal_mapped) * normal_mapped);
                float3 binormal_mapped = cross(tangent_mapped, normal_mapped);

                // 異方性接空間
                float theta_tangent;
                if (_IsAngleMap > 0.5) {
                    theta_tangent = tex2D(_TangentMap, fi.uv_texture).r * UNITY_TWO_PI;
                } else {
                    float2 tangent_vector = normalize(tex2D(_TangentMap, fi.uv_texture).rg * 2.0 - 1.0);
                    theta_tangent = atan2(tangent_vector.y, tangent_vector.x);
                }
                float3 tangent_aniso =
                    tangent_mapped * cos(theta_tangent) +
                    (1.0 - cos(theta_tangent)) * dot(tangent_mapped, normal_mapped) * normal_mapped +
                    cross(normal_mapped, tangent_mapped) * sin(theta_tangent);
                float3 binormal_aniso = cross(tangent_aniso, normal_mapped);
                float4x4 normals = float4x4(
                    float4(tangent_aniso, 0.0),
                    float4(binormal_aniso, 0.0),
                    float4(normal_mapped, 0.0),
                    float4(0.0, 0.0, 0.0, 1.0)
                );

                // 各種ベクトル
                UNITY_LIGHT_ATTENUATION(light_atten, fi, normal_mapped);
                float3 light_color = _LightColor0.rgb * light_atten;
                float3 light_dir = world_light0_direction(fi.position_world);
                float3 view_dir = normalize(UnityWorldSpaceViewDir(fi.position_world));
                float cosine_term = max(0.0, dot(light_dir, normal_mapped));
                float3 rho_ss = lerp(
                    basecolor,
                    float3(0.0, 0.0, 0.0),
                    metallic
                );
                float3 f0 = lerp(
                    float3(F0_DIELECTRIC, F0_DIELECTRIC, F0_DIELECTRIC),
                    basecolor,
                    metallic
                );

                float3 light_sum = 0.0;

                // メインのライティング
                float3 light_main = light_color * cosine_term * (
                    brdf_specular_anisotropic(view_dir, light_dir, normals, roughness, anisotropy, f0) +
                    brdf_diffuse(rho_ss, f0)
                );
                light_main *= lerp(1.0, UNITY_PI, _UnityCompatibility);
                light_sum.rgb += light_main;

                return float4(light_sum, 1.0);
            }
            ENDCG
        }
    }

    Fallback "Diffuse"

    CustomEditor "KusakaFactory.AstopAnisotropyShaderGUI"
}
