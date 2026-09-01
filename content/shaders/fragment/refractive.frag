#version 330 core
out vec4 out_frag_color;

in VS_OUT {
    vec3 frag_pos;
    vec3 normal;
} fs_in;

uniform vec3 u_camera_position;
uniform samplerCube u_skybox_texture;

#define AIR_REFRACTION_INDEX 1.00
#define GLASS_REFRACTION_INDEX 1.52

void main()
{
    vec3 view_vector = normalize(fs_in.frag_pos - u_camera_position);
    vec3 norm = normalize(fs_in.normal);
    vec3 refracted = refract(view_vector, norm, AIR_REFRACTION_INDEX / GLASS_REFRACTION_INDEX);
    vec4 tex_color = texture(u_skybox_texture, refracted);
    out_frag_color = vec4(tex_color.rgb, 1.0);
}
