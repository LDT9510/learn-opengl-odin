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
    sampler2D emission;
    float shininess;
};
uniform Material material;

void main()
{
    vec3 norm = normalize(Normal);
    vec3 sampled_diffuse = vec3(texture(material.diffuse, TexCoords));
    vec3 sampled_specular = vec3(texture(material.specular, TexCoords));
    vec3 sampled_emission = vec3(texture(material.emission, TexCoords));

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
    vec3 specular = light.specular * (specular_contrib * sampled_specular);

    // emission
    vec3 emission = 0.6f * (1.0f - sign(sampled_specular)) * sampled_emission;

    vec3 result = ambient + diffuse + specular + emission;
    FragColor = vec4(result, 1.0);
}
