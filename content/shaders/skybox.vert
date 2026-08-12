#version 330 core
layout(location = 0) in vec3 in_position;

out vec3 v_tex_coords;

uniform mat4 u_view;
uniform mat4 u_projection;
 
void main()
{
    v_tex_coords = in_position;

    gl_Position = u_projection * u_view * vec4(in_position, 1.0);
}
