#version 330 core
out vec4 out_frag_color;

in GS_OUT {
	vec3 color;
} fs_in; 

void main()
{
    out_frag_color = vec4(fs_in.color, 1.0);
}
