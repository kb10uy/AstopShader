#ifndef ASTOP_COMMON_INCLUDE
#define ASTOP_COMMON_INCLUDE

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#define ROUGHNESS_REFLECTION_STEP 6.0

// Vertex Shader 入力
struct VertexInput
{
    float4 position : POSITION;
    float3 normal   : NORMAL;
    float4 tangent  : TANGENT;
    float2 uv       : TEXCOORD0;
};

// Fragment Shader 入力
struct FragmentInput
{
    float4 position_clip  : SV_Position;
    float3 position_world : POSITION1;
    float3 normal_world   : NORMAL0;
    float3 tangent_world  : NORMAL1;
    // float3 binormal_world : NORMAL2;
    float2 uv_texture     : TEXCOORD0;
    float3 light_vertex   : COLOR0;
    UNITY_FOG_COORDS(1)
    LIGHTING_COORDS(2, 3)
};

// _WorldSpaceLightPos0 のライトベクトルを求める。
float3 world_light0_direction(float3 position_world)
{
    if (_WorldSpaceLightPos0.w > 0) {
        // それ以外
        return normalize(_WorldSpaceLightPos0.xyz - position_world.xyz);
    } else {
        // Directional
        return normalize(_WorldSpaceLightPos0.xyz);
    }
}

// ReflectionProbe の内容を取得する。
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

#endif
