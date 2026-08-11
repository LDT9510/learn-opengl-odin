#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 2) in vec2 in_tex_coords;

out vec2 v_tex_coords;

void main()
{
    v_tex_coords = in_tex_coords;

    gl_Position = vec4(in_position.x, in_position.y, 0.0, 1.0);
}
