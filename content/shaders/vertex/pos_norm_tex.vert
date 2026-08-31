#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_tex_coords;

out vec3 v_frag_pos;
out vec3 v_normal;
out vec2 v_tex_coords;

layout(std140) uniform Matrices {
    uniform mat4 u_projection;
    uniform mat4 u_view;
};
uniform mat4 u_model;

void main()
{
    v_frag_pos = vec3(u_model * vec4(in_position, 1.0));
    // normal matrix, fix normals when non-uniform scale is applied
    // prefer doing this in the CPU
    v_normal = mat3(transpose(inverse(u_model))) * in_normal;

    v_tex_coords = in_tex_coords;

    gl_Position = u_projection * u_view * vec4(v_frag_pos, 1.0);

    // the closer to the screen, the bigger the points
    gl_PointSize = gl_Position.z;
}
