#ifndef ASTOP_VARIABLES_INCLUDE
#define ASTOP_VARIABLES_INCLUDE

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

#endif
