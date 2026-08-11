#version 330 core
out vec4 out_frag_color;

in vec2 v_tex_coords;

uniform sampler2D u_screen_texture;

void main()
{
    vec4 c = texture(u_screen_texture, v_tex_coords);
    float average = (c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722);
    // or simply
    // float average = (c.r + c.g + c.b) / 3.0;
    out_frag_color = vec4(vec3(average), 1.0);
}
