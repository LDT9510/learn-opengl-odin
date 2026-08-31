#version 330 core
out vec4 out_frag_color;

// must match half the screen width to be correct, fixed for now
#define SCREEN_HALF_X 1200 / 2

void main()
{
    if (gl_FrontFacing) {
        if (gl_FragCoord.x < SCREEN_HALF_X) {
            out_frag_color = vec4(1.0, 0.0, 0.0, 1.0);
        } else {
            out_frag_color = vec4(0.0, 1.0, 0.0, 1.0);
        }
    } else {
            out_frag_color = vec4(0.0, 0.0, 1.0, 1.0);
    }
}
