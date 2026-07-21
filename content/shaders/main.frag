#version 330 core
out vec4 FragColor;

struct Material {
    sampler2D diffuse;
    sampler2D specular;
    float shininess;
};

struct Light {
    vec3 position;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;

    float constant;
    float linear;
    float quadratic;
};

in vec3 FragPos;
in vec3 Normal;
in vec2 TexCoords;

uniform vec3 viewPos;
uniform Material material;
uniform Light light;

float calculate_attenuation(Light light, vec3 fragment_position) {
    float d = length(light.position - fragment_position);
    float Kc = light.constant;
    float Kl = light.linear;
    float Kq = light.quadratic;

    return 1.0 / (Kc + (Kl * d) + (Kq * (d * d)));
}

void main()
{
    vec3 norm = normalize(Normal);
    vec3 sampled_diffuse = vec3(texture(material.diffuse, TexCoords));
    vec3 sampled_specular = vec3(texture(material.specular, TexCoords));

    // ambient component
    vec3 ambient = light.ambient * sampled_diffuse;

    // diffuse component
    vec3 light_dir = normalize(light.position - FragPos);
    float diffuse_contrib = max(dot(norm, light_dir), 0.0);
    vec3 diffuse = light.diffuse * diffuse_contrib * sampled_diffuse;

    // specular component
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-light_dir, norm);
    float specular_contrib = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    vec3 specular = light.specular * specular_contrib * sampled_specular;

    float attenuation = calculate_attenuation(light, FragPos);
    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;

    vec3 result = ambient + diffuse + specular;
    FragColor = vec4(result, 1.0);
}
