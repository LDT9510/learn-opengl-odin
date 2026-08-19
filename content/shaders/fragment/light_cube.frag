#version 330 core
out vec4 out_frag_color;

uniform vec3 u_color;

void main()
{
    out_frag_color = vec4(u_color, 1.0);
}
