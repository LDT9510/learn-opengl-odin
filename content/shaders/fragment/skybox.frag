#version 330 core
out vec4 out_frag_color;

in VS_OUT {
    vec3 tex_coords;
} fs_in;

uniform samplerCube u_skybox;

void main()
{
    vec4 tex_color = texture(u_skybox, fs_in.tex_coords);
    out_frag_color = tex_color;
}
