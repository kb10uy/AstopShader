#ifndef ASTOP_FRAGMENT_INCLUDE
#define ASTOP_FRAGMENT_INCLUDE

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
    #ifdef ASTOP_FORWARD_BASE
        float light_atten = 1.0;
    #else
        UNITY_LIGHT_ATTENUATION(light_atten, fi, normal_mapped);
    #endif
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
    light_main *= lerp(1.0, M_PI, _UnityCompatibility);
    light_sum.rgb += light_main;

    #ifdef ASTOP_FORWARD_BASE
        // 頂点ライティング
        float3 light_vertex = fi.light_vertex * brdf_diffuse(rho_ss, f0);
        light_vertex *= lerp(1.0, M_PI, _UnityCompatibility);
        light_sum.rgb += light_vertex;

        // Reflection Probe
        float3 reflection = get_reflection(view_dir, fi.position_world, normals, roughness);
        float3 f_reflection = float3(
            fresnel_schlick(normals[2].xyz, view_dir, f0.r),
            fresnel_schlick(normals[2].xyz, view_dir, f0.g),
            fresnel_schlick(normals[2].xyz, view_dir, f0.b)
        );
        float3 light_reflection = f_reflection * reflection;
        light_sum.rgb += light_reflection;
    #endif

    return float4(light_sum, 1.0);
}

#endif
