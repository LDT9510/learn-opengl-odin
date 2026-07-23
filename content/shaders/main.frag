#version 330 core

#define MAX_POINT_LIGHTS 4

out vec4 out_frag_color;

in vec3 v_frag_pos;
in vec3 v_normal;
in vec2 v_tex_coords;

struct Material {
    sampler2D diffuse;
    sampler2D specular;
    float shininess;
};

struct DirectionalLight {
    vec3 direction;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct PointLight {
    vec3 position;

    float constant;
    float linear;
    float quadratic;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct SpotLight {
    vec3 position;
    vec3 direction;

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
uniform DirectionalLight u_dir_light;
uniform PointLight u_point_lights[MAX_POINT_LIGHTS];
uniform SpotLight u_spot_light;

vec3 calc_directional_light(DirectionalLight light, vec3 normal, vec3 view_dir);
vec3 calc_point_light(PointLight light, vec3 normal, vec3 frag_pos, vec3 view_dir);
vec3 calc_spot_light(SpotLight light, vec3 normal, vec3 frag_pos, vec3 view_dir);

void main()
{
    vec3 norm = normalize(v_normal);
    vec3 view_dir = normalize(u_view_pos - v_frag_pos);

    vec3 result = calc_directional_light(u_dir_light, norm, view_dir);

    for (int i = 0; i < MAX_POINT_LIGHTS; i++) {
        result += calc_point_light(u_point_lights[i], norm, v_frag_pos, view_dir);
    }

    result += calc_spot_light(u_spot_light, norm, v_frag_pos, view_dir);

    out_frag_color = vec4(result, 1.0);
}

vec3 calc_directional_light(DirectionalLight light, vec3 normal, vec3 view_dir) {
    vec3 light_dir = normalize(-light.direction);
    float diff = max(dot(normal, light_dir), 0.0);
    vec3 reflect_dir = reflect(-light_dir, normal);
    float spec = pow(max(dot(view_dir, reflect_dir), 0.0), u_material.shininess);

    vec3 ambient = light.ambient * texture(u_material.diffuse, v_tex_coords).rgb;
    vec3 diffuse = light.diffuse * diff * texture(u_material.diffuse, v_tex_coords).rgb;
    vec3 specular = light.specular * spec * texture(u_material.specular, v_tex_coords).rgb;

    return ambient + diffuse + specular;
}

vec3 calc_point_light(PointLight light, vec3 normal, vec3 frag_pos, vec3 view_dir) {
    vec3 light_dir = normalize(light.position - frag_pos);
    float diff = max(dot(normal, light_dir), 0.0);
    vec3 reflect_dir = reflect(-light_dir, normal);
    float spec = pow(max(dot(view_dir, reflect_dir), 0.0), u_material.shininess);

    float d = length(light.position - frag_pos);
    float Kc = light.constant;
    float Kl = light.linear;
    float Kq = light.quadratic;
    float attenuation = 1.0 / (Kc + (Kl * d) + (Kq * (d * d)));

    vec3 ambient = light.ambient * texture(u_material.diffuse, v_tex_coords).rgb * attenuation;
    vec3 diffuse = light.diffuse * diff * texture(u_material.diffuse, v_tex_coords).rgb * attenuation;
    vec3 specular = light.specular * spec * texture(u_material.specular, v_tex_coords).rgb * attenuation;

    return ambient + diffuse + specular;
}

vec3 calc_spot_light(SpotLight light, vec3 normal, vec3 frag_pos, vec3 view_dir) {
    vec3 light_dir = normalize(light.position - frag_pos);
    float diff = max(dot(normal, light_dir), 0.0);
    vec3 reflect_dir = reflect(-light_dir, normal);
    float spec = pow(max(dot(view_dir, reflect_dir), 0.0), u_material.shininess);

    float d = length(light.position - frag_pos);
    float Kc = light.constant;
    float Kl = light.linear;
    float Kq = light.quadratic;
    float attenuation = 1.0 / (Kc + (Kl * d) + (Kq * (d * d)));

    float theta = dot(light_dir, normalize(-light.direction));
    float epsilon = light.cutoff - light.outer_cutoff;
    float intensity = clamp((theta - light.outer_cutoff) / epsilon, 0.0, 1.0);

    vec3 ambient = light.ambient * texture(u_material.diffuse, v_tex_coords).rgb * attenuation;
    vec3 diffuse = light.diffuse * diff * texture(u_material.diffuse, v_tex_coords).rgb * attenuation * intensity;
    vec3 specular = light.specular * spec * texture(u_material.specular, v_tex_coords).rgb * attenuation * intensity;

    return ambient + diffuse + specular;
}
