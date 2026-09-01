#version 330 core
layout(location = 0) in vec2 in_position;
layout(location = 1) in vec3 in_color;

out VS_OUT {
	vec3 color;
} vs_out;

void main()
{
    gl_Position = vec4(in_position.xy, 0.0, 1.0);
	vs_out.color = in_color;
}
