#version 330 core
out vec4 FragColor;

in vec3 FragPos;
in vec3 Normal;
in vec2 TexCoords;

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
    sampler2D diffuse;
    sampler2D specular;
    float shininess;
};
uniform Material material;

void main()
{
    vec3 norm = normalize(Normal);
    vec3 sampled_diffuse = vec3(texture(material.diffuse, TexCoords));
    vec3 sampled_specular = vec3(texture(material.specular, TexCoords));

    // ambient component
    vec3 ambient = light.ambient * sampled_diffuse;

    // diffuse component
    vec3 light_dir = normalize(lightPos - FragPos);
    float diffuse_contrib = max(dot(norm, light_dir), 0.0);
    vec3 diffuse = light.diffuse * (diffuse_contrib * sampled_diffuse);

    // specular component
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-light_dir, norm);
    float specular_contrib = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    vec3 inverted_specular_sample = 1.0f - sampled_specular;
    vec3 specular = light.specular * (specular_contrib * inverted_specular_sample);

    vec3 result = ambient + diffuse + specular;
    FragColor = vec4(result, 1.0);
}
