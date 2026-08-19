#version 330 core
out vec4 out_frag_color;

in vec3 v_tex_coords;

uniform samplerCube u_skybox;

void main()
{
    vec4 tex_color = texture(u_skybox, v_tex_coords);
    out_frag_color = tex_color;
}
