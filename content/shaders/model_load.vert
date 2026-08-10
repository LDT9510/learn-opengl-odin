#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_tex_coords;

out vec2 v_tex_coords;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_projection;

void main()
{
    // flip the textures here instead of in the CPU
    v_tex_coords = vec2(in_tex_coords.x, in_tex_coords.y);

    vec3 frag_pos = vec3(u_model * vec4(in_position, 1.0));
    gl_Position = u_projection * u_view * vec4(frag_pos, 1.0);
}
