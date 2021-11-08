#ifndef KUSAKA_PBR_INCLUDE
#define KUSAKA_PBR_INCLUDE

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#define F0_DIELECTRIC 0.04

// なす角が π/2 以下(内積が正)の場合 1 を、それ以外の場合 0 を返す。
float towards_similar(float3 x, float3 y)
{
    return dot(x, y) >= 0 ? 1.0 : 0.0;
}

// Fresnel --------------------------------------------------------------------

// Fresnel 反射率の Schlick の近似を求める。
float fresnel_schlick(float3 normal, float3 light, float f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - max(0.0, dot(normal, light)), 5.0);
}

// Microfacet Distribution Function  ------------------------------------------

// Beckmann 法線分布関数の値を求める。
float d_beckmann(float3 halfway, float4x4 normals, float roughness)
{
    float3 normal = normals[2].xyz;
    float alpha_b2 = max(0.000001, pow(roughness, 4.0));

    float reflects = towards_similar(halfway, normal);
    float dot_nh = dot(normal, halfway);
    float dot_nh2 = dot_nh * dot_nh;
    float exponential_term = exp((dot_nh2 - 1.0) / (alpha_b2 * dot_nh2));
    return (reflects / (UNITY_PI * alpha_b2 * dot_nh2 * dot_nh2)) * exponential_term;
}

// GGX 法線分布関数の値を求める。
// normals は接空間行列(tangent, binormal, normal)。
float d_ggx(float3 halfway, float4x4 normals, float roughness)
{
    float3 normal = normals[2].xyz;
    float alpha_g2 = max(0.000001, pow(roughness, 4.0));

    float normal_term = dot(normal, halfway) / 1.0;
    float r = 1.0 + normal_term * normal_term * (alpha_g2 - 1.0);

    return alpha_g2 / (UNITY_PI * r * r);
}

// Anisotropic GGX 法線分布関数の値を求める。
// normals は接空間行列(tangent, binormal, normal)。
float d_ggx_anisotropy(float3 halfway, float4x4 normals, float roughness, float anisotropy)
{
    float3 tangent = normals[0].xyz;
    float3 binormal = normals[1].xyz;
    float3 normal = normals[2].xyz;

    float aspect = sqrt(1.0 - 0.9 * anisotropy);
    float alpha_x = max(0.000001, roughness * roughness / aspect);
    float alpha_y = max(0.000001, roughness * roughness * aspect);

    float tangent_term = dot(tangent, halfway) / alpha_x;
    float binormal_term = dot(binormal, halfway) / alpha_y;
    float normal_term = dot(normal, halfway) / 1.0;
    float anisotropic_roughness =
        tangent_term * tangent_term +
        binormal_term * binormal_term +
        normal_term * normal_term;

    return 1.0 / (UNITY_PI * alpha_x * alpha_y * anisotropic_roughness * anisotropic_roughness);
}

// Masking/Shadowing Function  ------------------------------------------------

// Anisotropic GGX の Λ 関数に使う a の値を求める。
float lambda_a2_ggx_anisotropy(float3 view, float4x4 normals, float roughness, float anisotropy)
{
    float3 tangent = normals[0].xyz;
    float3 binormal = normals[1].xyz;
    float3 normal = normals[2].xyz;

    float aspect = sqrt(1.0 - 0.9 * anisotropy);
    float alpha_x = max(0.000001, roughness * roughness / aspect);
    float alpha_y = max(0.000001, roughness * roughness * aspect);

    float dot_ns = dot(normal, view);
    float dot_ts = dot(tangent, view);
    float dot_bs = dot(binormal, view);

    return (dot_ns * dot_ns) / (alpha_x * alpha_x * dot_ts * dot_ts + alpha_y * alpha_y * dot_bs * dot_bs);
}

// G2 DDX マスキング関数の値を求める。
float g2_ddx(float3 view, float3 light, float4x4 normals, float roughness)
{
    float3 halfway = normalize(view + light);
    float dot_vn = dot(view, normals[2].xyz);
    float dot_ln = dot(light, normals[2].xyz);
    float alpha2 = max(0.000001, roughness * roughness * roughness * roughness);
    float lambda = (sqrt(1.0 + 1.0 / alpha2) - 1.0) / 2.0;

    return 1.0 / (1.0 + lambda * 2.0 + 1.0);
}

// Anisotropic G2 DDX マスキング関数の値を求める。
float g2_ddx_anisotropy(float3 view, float3 light, float4x4 normals, float roughness, float anisotropy)
{
    float3 halfway = normalize(view + light);
    float dot_vn = dot(view, normals[2].xyz);
    float dot_ln = dot(light, normals[2].xyz);
    float alpha2 = lambda_a2_ggx_anisotropy(view, normals, roughness, anisotropy);
    float lambda = (sqrt(1.0 + 1.0 / alpha2) - 1.0) / 2.0;

    return 1.0 / (1.0 + lambda * 2.0 + 1.0);
}

// BRDFs ----------------------------------------------------------------------

// Specular BRDF を計算する。
float3 brdf_specular_anisotropic(float3 view_dir, float3 light_dir, float4x4 normals, float roughness, float anisotropy, float3 f0)
{
    float3 normal = normals[2].xyz;
    float3 halfway = normalize(view_dir + light_dir);

    float d = d_ggx_anisotropy(halfway, normals, roughness, anisotropy);
    float g = g2_ddx_anisotropy(view_dir, light_dir, normals, roughness, anisotropy);
    float3 f_spec = float3(
        fresnel_schlick(halfway, light_dir, f0.r),
        fresnel_schlick(halfway, light_dir, f0.g),
        fresnel_schlick(halfway, light_dir, f0.b)
    );

    float denominator = 4.0 * abs(dot(normal, light_dir) * dot(normal, view_dir));
    return d * g * f_spec / denominator;
}

// Diffuse BRDF を計算する。
float3 brdf_diffuse(float3 color, float3 f0)
{
    return (1.0 - f0) * (color / UNITY_PI);
}

#endif
