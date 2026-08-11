#version 330 core
out vec4 out_frag_color;

in vec2 v_tex_coords;

uniform sampler2D u_screen_texture;

// Kernel effect

#define OFFSET 1.0 / 300.0

void main()
{
    vec2 offsets[9] = vec2[](
            vec2(-OFFSET, OFFSET), // top-left
            vec2(0.0f, OFFSET), // top-center
            vec2(OFFSET, OFFSET), // top-right
            vec2(-OFFSET, 0.0f), // center-left
            vec2(0.0f, 0.0f), // center-center
            vec2(OFFSET, 0.0f), // center-right
            vec2(-OFFSET, -OFFSET), // bottom-left
            vec2(0.0f, -OFFSET), // bottom-center
            vec2(OFFSET, -OFFSET) // bottom-right
        );

    float kernel[9] = float[](
            -1, -1, -1,
            -1,  9, -1,
            -1, -1, -1
        );

    vec3 sample_tex[9];
    for (int i = 0; i < 9; i++)
    {
        sample_tex[i] = vec3(texture(u_screen_texture, v_tex_coords.st + offsets[i]));
    }

    vec3 col = vec3(0.0);
    for (int i = 0; i < 9; i++) {
        col += sample_tex[i] * kernel[i];
    }

    out_frag_color = vec4(col, 1.0);
}
