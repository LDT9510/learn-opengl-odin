#version 330 core
out vec4 FragColor;

in vec3 FragPos;
in vec3 Normal;

uniform vec3 lightPos;
uniform vec3 viewPos;

struct Light {
    vec3 position;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};
uniform Light light;

struct Material {
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    float shininess;
};
uniform Material material;

void main()
{
    vec3 norm = normalize(Normal);

    // ambient component
    vec3 ambient = light.ambient * material.ambient;

    // diffuse component
    vec3 light_dir = normalize(lightPos - FragPos);
    float diffuse_contrib = max(dot(norm, light_dir), 0.0);
    vec3 diffuse = light.diffuse * (diffuse_contrib * material.diffuse);

    // specular component
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-light_dir, norm);
    float specular_contrib = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    vec3 specular = light.specular * (specular_contrib * material.specular);

    vec3 result = ambient + diffuse + specular;
    FragColor = vec4(result, 1.0);
}
