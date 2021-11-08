#ifndef ASTOP_VERTEX_INCLUDE
#define ASTOP_VERTEX_INCLUDE

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

// 共通 Vertex Shader 処理
FragmentInput vertex_main(VertexInput vi)
{
    FragmentInput fi;
    fi.position_clip = UnityObjectToClipPos(vi.position);
    fi.position_world = mul(unity_ObjectToWorld, vi.position).xyz;

    fi.normal_world = UnityObjectToWorldNormal(vi.normal);
    fi.tangent_world = UnityObjectToWorldDir(vi.tangent.xyz);

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
