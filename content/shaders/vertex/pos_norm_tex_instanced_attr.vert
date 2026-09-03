#version 330 core
layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec2 in_tex_coords;
layout(location = 3) in vec3 in_offset;

out VS_OUT {
    vec3 frag_pos;
    vec3 normal;
} vs_out;

out vec2 v_tex_coords;

layout(std140) uniform Matrices {
    uniform mat4 u_projection;
    uniform mat4 u_view;
};
uniform mat4 u_model;

void main()
{
    float new_scale = gl_InstanceID / 100.0;
    vec3 scaled_pos = in_position * new_scale;
    vs_out.frag_pos = vec3(u_model * vec4(scaled_pos, 1.0));
    v_tex_coords = in_tex_coords;

    gl_Position = u_projection * u_view * vec4(vs_out.frag_pos + in_offset, 1.0);
    // the closer to the screen, the bigger the points
    gl_PointSize = gl_Position.z;
}
