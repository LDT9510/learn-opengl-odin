#version 330 core
layout(triangles) in;
layout(triangle_strip, max_vertices = 3) out;

in VS_OUT {
    vec3 frag_pos;
    vec3 normal;
} gs_in[];

in vec2 v_tex_coords[];
out vec2 geom_tex_coords;

uniform float u_time;

vec4 explode(vec4 position, vec3 normal)
{
    float magnitude = 2.0;
    vec3 direction = normal * ((sin(u_time) + 1.0) / 2.0) * magnitude;
    return position + vec4(direction.xy, 0.0, 0.0);
}

vec3 get_normal()
{
    vec3 a = vec3(gl_in[0].gl_Position) - vec3(gl_in[1].gl_Position);
    vec3 b = vec3(gl_in[2].gl_Position) - vec3(gl_in[1].gl_Position);
    return normalize(cross(a, b));
}

void main() {
    vec3 normal = get_normal();

    gl_Position = explode(gl_in[0].gl_Position, normal);
    geom_tex_coords = v_tex_coords[0];
    EmitVertex();
    gl_Position = explode(gl_in[1].gl_Position, normal);
    geom_tex_coords = v_tex_coords[1];
    EmitVertex();
    gl_Position = explode(gl_in[2].gl_Position, normal);
    geom_tex_coords = v_tex_coords[2];
    EmitVertex();
    EndPrimitive();
}
