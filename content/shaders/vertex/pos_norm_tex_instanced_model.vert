#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_tex_coords;
layout(location = 3) in mat4 in_instance_matrix;

out VS_OUT {
    vec3 frag_pos;
    vec3 normal;
} vs_out;

out vec2 v_tex_coords;

layout(std140) uniform Matrices {
    uniform mat4 u_projection;
    uniform mat4 u_view;
};

void main()
{
    vs_out.frag_pos = vec3(in_instance_matrix * vec4(in_position, 1.0));
    vs_out.normal = mat3(transpose(inverse(in_instance_matrix))) * in_normal;
    v_tex_coords = in_tex_coords;

    gl_Position = u_projection * u_view * vec4(vs_out.frag_pos, 1.0);
    gl_PointSize = gl_Position.z;
}
