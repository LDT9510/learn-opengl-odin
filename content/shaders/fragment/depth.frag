#version 330 core
out vec4 out_frag_color;

uniform float u_near;
uniform float u_far;

float linearize_depth(float depth) {
    float ndc = depth * 2.0 - 1.0;
    return (2.0 * u_near * u_far) / (u_far + u_near - ndc * (u_far - u_near));
}

void main()
{
    float depth = linearize_depth(gl_FragCoord.z) / u_far;
    out_frag_color = vec4(vec3(depth), 1.0);
}
