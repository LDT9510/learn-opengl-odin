#version 330 core
out vec4 FragColor;

uniform vec3 lightDiffuse;

void main()
{
    FragColor = vec4(max(lightDiffuse, vec3(0.03, 0.03, 0.03)) * 3.0, 1.0);
}
