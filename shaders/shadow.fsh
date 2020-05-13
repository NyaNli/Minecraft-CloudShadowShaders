#version 330 compatibility

uniform sampler2D texture;

in vec4 color;
in vec4 texpos;

const int shadowMapResolution = 1024; // [1024 2048 3072 4096]
const float sunPathRotation = -30.0f;
const float shadowIntervalSize = 0.001f; // 不用这个云影会跑偏

#define SHADOW_MAP_BIAS 0.9

void main()
{
    gl_FragColor = texture2D(texture, texpos.xy) * color;
}