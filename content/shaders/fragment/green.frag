#version 330 core
out vec4 out_frag_color;

void main()
{
    out_frag_color = vec4(fs_in.color, 1.0);
}
