#version 330 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;

out vec3 FragPos;
out vec3 Normal;
out vec3 LightPos;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform vec3 lightPos;

void main()
{
    mat4 viewModel = view * model;

    // model position in view space
    FragPos = vec3(viewModel * vec4(aPos, 1.0));

    // normal matrix, fix normals when non-uniform scale is applied
    // prefer doing this in the CPU
    // also in view space
    Normal = mat3(transpose(inverse(viewModel))) * aNormal;

    // light position in view space
    LightPos = vec3(view * vec4(lightPos, 1.0));

    gl_Position = projection * vec4(FragPos, 1.0);
}
