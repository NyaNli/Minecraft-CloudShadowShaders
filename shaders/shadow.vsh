#version 330 compatibility

#define SHADOW_MAP_BIAS 0.9

out vec4 color;
out vec4 texpos;

void main()
{
    vec4 viewpos = gl_ModelViewMatrix * gl_Vertex;
    gl_Position = gl_ProjectionMatrix * viewpos;
    float dist = length(gl_Position.xy);
    float distortFactor = mix(1.0, dist, SHADOW_MAP_BIAS);
    gl_Position.xy /= distortFactor;

    color = gl_Color;
    texpos = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}