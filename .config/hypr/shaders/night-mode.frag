#version 300 es

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;

layout(location = 0) out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    
    // Warm night light filter (~3500K warmth):
    // Preserve red (1.0), soften green (0.84), filter blue (0.52)
    c.g *= 0.84;
    c.b *= 0.52;
    
    fragColor = c;
}
