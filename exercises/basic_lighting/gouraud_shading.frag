#version 330 core
out vec4 FragColor;

in vec3 GouraudColor;

void main()
{
    FragColor = vec4(GouraudColor, 1.0);
}
