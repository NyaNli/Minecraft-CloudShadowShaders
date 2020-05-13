#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texUV;

layout(location = 0) out vec4 frag;

void main()
{
    frag = texture(colortex0, texUV);
}