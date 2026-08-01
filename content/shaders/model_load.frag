#version 330 core
out vec4 out_frag_color;

in vec2 v_tex_coords;

uniform sampler2D u_texture_diffuse1;

void main()
{
    out_frag_color = texture(u_texture_diffuse1, v_tex_coords);
}
