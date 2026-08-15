#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;

out vec3 v_normal;
out vec3 v_frag_pos;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_projection;

void main()
{
    // normal matrix, fix normals when non-uniform scale is applied
    v_normal = mat3(transpose(inverse(u_model))) * in_normal;

    v_frag_pos = vec3(u_model * vec4(in_position, 1.0));
    gl_Position = u_projection * u_view * vec4(v_frag_pos, 1.0);
}
