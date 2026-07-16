#version 330 core
out vec4 FragColor;

in vec3 FragPos;
in vec3 Normal;

uniform vec3 lightPos;
uniform vec3 viewPos;
uniform vec3 lightColor;
uniform vec3 objectColor;

uniform float ambient_strength;
uniform float diffuse_strength;
uniform float specular_strength;
uniform int shininess;

void main()
{
    vec3 norm = normalize(Normal);

    // ambient component
    vec3 ambient = ambient_strength * lightColor;

    // diffuse component
    vec3 light_dir = normalize(lightPos - FragPos);
    float light_contrib = max(dot(norm, light_dir), 0.0);
    vec3 diffuse = light_contrib * lightColor * diffuse_strength;

    // specular component
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-light_dir, norm);
    float specular_contrib = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
    vec3 specular = specular_contrib * specular_strength * lightColor;

    vec3 result = (ambient + diffuse + specular) * objectColor;
    FragColor = vec4(result, 1.0);
}
