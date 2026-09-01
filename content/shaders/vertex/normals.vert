#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;

out VS_OUT {
    vec3 normal;
} vs_out;

layout(std140) uniform Matrices {
    uniform mat4 u_projection;
    uniform mat4 u_view;
};

uniform mat4 u_model;

void main()
{
    gl_Position = u_view * u_model * vec4(in_position, 1.0);
    mat3 normal_matrix = mat3(transpose(inverse(u_view * u_model)));
    vs_out.normal = normalize(vec4(normal_matrix * in_normal, 0.0).xyz);
}
