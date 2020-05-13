#version 330 compatibility

out vec2 texUV;

void main()
{
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texUV = gl_Vertex.xy;
}