#version 330 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;

out vec3 GouraudColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform vec3 lightPos;
uniform float ambient_strength;
uniform float diffuse_strength;
uniform float specular_strength;
uniform int shininess;
uniform vec3 lightColor;
uniform vec3 objectColor;

// calculations done in view space
void main()
{
    mat4 viewModel = view * model;
    vec3 position = vec3(viewModel * vec4(aPos, 1.0));
    vec3 normal = normalize(mat3(transpose(inverse(viewModel))) * aNormal);
    vec3 light_position = vec3(view * vec4(lightPos, 1.0));

    // ambient component
    vec3 ambient = ambient_strength * lightColor;

    // diffuse component
    vec3 light_dir = normalize(light_position - position);
    float light_contrib = max(dot(normal, light_dir), 0.0);
    vec3 diffuse = light_contrib * lightColor * diffuse_strength;

    // specular component
    vec3 view_pos = vec3(0.0);
    vec3 viewDir = normalize(view_pos - position);
    vec3 reflectDir = reflect(-light_dir, normal);
    float specular_contrib = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
    vec3 specular = specular_contrib * specular_strength * lightColor;

    GouraudColor = (ambient + diffuse + specular) * objectColor;

    gl_Position = projection * vec4(position, 1.0);
}
