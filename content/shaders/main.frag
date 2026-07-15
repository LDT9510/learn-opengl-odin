#version 330 core
out vec4 FragColor;

in vec3 FragPos;
in vec3 Normal;

uniform vec3 objectColor;
uniform vec3 lightColor;
uniform vec3 lightPos;
uniform vec3 viewPos;

void main()
{
    vec3 norm = normalize(Normal);

    // ambient component
    float ambient_strength = 0.1;
    vec3 ambient = ambient_strength * lightColor;

    // diffuse component
    vec3 light_dir = normalize(lightPos - FragPos);
    float light_contrib = max(dot(norm, light_dir), 0.0);
    vec3 diffuse = light_contrib * lightColor;

    // specular component
    float specularStrength = 0.5;
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-light_dir, norm);
    float specular_contrib = pow(max(dot(reflectDir, viewDir), 0.0), 32);
    vec3 specular = specular_contrib * specularStrength * lightColor;

    vec3 result = (ambient + diffuse + specular) * objectColor;
    FragColor = vec4(result, 1.0);
}
