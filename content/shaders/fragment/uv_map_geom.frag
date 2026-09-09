#version 330 core
out vec4 out_frag_color;

// this comes from the geometry shader
in vec2 geom_tex_coords;

uniform sampler2D u_texture_diffuse1;

void main()
{
    vec4 tex_color = texture(u_texture_diffuse1, geom_tex_coords);

    out_frag_color = tex_color;
}
