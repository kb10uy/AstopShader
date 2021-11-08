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

// 共通 Vertex Shader 処理
FragmentInput vertex_main(VertexInput vi)
{
    FragmentInput fi;
    fi.position_clip = UnityObjectToClipPos(vi.position);
    fi.position_world = mul(unity_ObjectToWorld, vi.position).xyz;

    fi.normal_world = UnityObjectToWorldNormal(vi.normal);
    fi.tangent_world = UnityObjectToWorldDir(vi.tangent.xyz);
    // float tangent_sign = vi.tangent.w * unity_WorldTransformParams.w;
    // fi.binormal_world = cross(fi.normal_world, fi.tangent_world) * tangent_sign;

    fi.uv_texture = vi.uv;

    // Vertex Lighting
    fi.light_vertex = 0.0;
    #if UNITY_SHOULD_SAMPLE_SH
        #if defined(VERTEXLIGHT_ON)
            fi.light_vertex += Shade4PointLights(
                unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                unity_4LightAtten0, fi.position_world, fi.normal_world
            );
        #endif
        fi.light_vertex += float4(max(0.0, ShadeSH9(float4(fi.normal_world, 1.0))), 1.0);
    #endif

    // Fog
    UNITY_TRANSFER_FOG(fi,fi.position_clip);

    return fi;
}

#endif
