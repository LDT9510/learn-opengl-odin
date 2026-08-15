#version 330 core
out vec4 out_frag_color;

in vec3 v_normal;
in vec3 v_frag_pos;

uniform vec3 u_camera_position;
uniform samplerCube u_skybox_texture;

void main()
{
    vec3 view_vector = normalize(v_frag_pos - u_camera_position);
    vec3 norm = normalize(v_normal);
    vec3 reflected = reflect(view_vector, norm);
    vec4 tex_color = texture(u_skybox_texture, reflected);
    out_frag_color = vec4(tex_color.rgb, 1.0);
}
