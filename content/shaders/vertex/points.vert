#version 330 core
layout(location = 0) in vec2 in_positions;

void main()
{
    gl_Position = vec4(in_positions.xy, 0.0, 1.0);
}
