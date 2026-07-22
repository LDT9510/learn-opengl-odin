#version 330 core
out vec4 out_frag_color;

in vec3 v_frag_pos;
in vec3 v_normal;
in vec2 v_tex_coords;

struct Material {
    sampler2D diffuse;
    sampler2D specular;
    float shininess;
};

// struct DirectionalLight {
//     vec3 direction;
//
//     vec3 ambient;
//     vec3 diffuse;
//     vec3 specular;
// }

struct Light {
    vec3 direction;
    vec3 position;
    float cutoff;
    float outer_cutoff;

    float constant;
    float linear;
    float quadratic;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

uniform vec3 u_view_pos;
uniform Material u_material;
uniform Light u_light;

float calc_attenuation(Light light, vec3 fragment_position);
// vec3 calc_dir_light(DirectionalLight light, vec3 normal, vec3 view_dir);

void main()
{
    vec3 norm = normalize(v_normal);
    vec3 sampled_specular = vec3(texture(u_material.specular, v_tex_coords));
    vec3 sampled_diffuse = vec3(texture(u_material.diffuse, v_tex_coords));

    // ambient component
    vec3 ambient = u_light.ambient * sampled_diffuse;

    // diffuse component
    vec3 light_dir = normalize(u_light.position - v_frag_pos);
    float diffuse_contrib = max(dot(norm, light_dir), 0.0);
    vec3 diffuse = u_light.diffuse * diffuse_contrib * sampled_diffuse;

    // specular component
    vec3 viewDir = normalize(u_view_pos - v_frag_pos);
    vec3 reflectDir = reflect(-light_dir, norm);
    float specular_contrib = pow(max(dot(viewDir, reflectDir), 0.0), u_material.shininess);
    vec3 specular = u_light.specular * specular_contrib * sampled_specular;

    // spotlight with soft edges
    float theta = dot(light_dir, normalize(-u_light.direction));
    float epsilon = (u_light.cutoff - u_light.outer_cutoff);
    float intensity = clamp((theta - u_light.outer_cutoff) / epsilon, 0.0, 1.0);
    diffuse *= intensity;
    specular *= intensity;

    // attenuation
    float attenuation = calc_attenuation(u_light, v_frag_pos);
    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;

    vec3 result = ambient + diffuse + specular;

    out_frag_color = vec4(result, 1.0);
}

float calc_attenuation(Light light, vec3 fragment_position) {
    float d = length(u_light.position - fragment_position);
    float Kc = u_light.constant;
    float Kl = u_light.linear;
    float Kq = u_light.quadratic;

    return 1.0 / (Kc + (Kl * d) + (Kq * (d * d)));
}

// vec3 calc_u_dir_light(DirectionalLight light, vec3 normal, vec3 view_dir) {}
