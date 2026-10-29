// A curved CRT tube: barrel distortion, scanlines, an aperture grille,
// slight color fringing and a soft glow around bright text.
// Uniforms: see shaders/README.md.

const float CURVE = 0.045;
const float SCANLINES = 0.18;

vec2 bend(vec2 uv) {
    vec2 c = uv * 2.0 - 1.0;
    c *= 1.0 + CURVE * dot(c.yx, c.yx);
    return c * 0.5 + 0.5;
}

vec4 sample_screen(vec2 uv) {
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
    return texture(iChannel0, uv);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = bend(fragCoord / iResolution.xy);
    vec2 px = 1.0 / iResolution.xy;
    float r = sample_screen(uv + vec2(px.x * 0.8, 0.0)).r;
    vec4 base = sample_screen(uv);
    float b = sample_screen(uv - vec2(px.x * 0.8, 0.0)).b;
    vec3 color = vec3(r, base.g, b);
    // Cheap glow: a few wide taps.
    vec3 glow = vec3(0.0);
    for (int i = -2; i <= 2; i++) {
        for (int j = -2; j <= 2; j++) {
            glow += sample_screen(uv + vec2(i, j) * px * 2.5).rgb;
        }
    }
    color += glow / 25.0 * 0.35;
    float line = sin(fragCoord.y * 3.14159) * 0.5 + 0.5;
    color *= 1.0 - SCANLINES * line;
    float grille = mod(fragCoord.x, 3.0);
    color *= vec3(grille < 1.0 ? 1.05 : 0.97, grille >= 1.0 && grille < 2.0 ? 1.05 : 0.97, grille >= 2.0 ? 1.05 : 0.97);
    // Rounded tube edges.
    vec2 edge = smoothstep(0.0, 0.012, uv) * smoothstep(0.0, 0.012, 1.0 - uv);
    float mask = edge.x * edge.y;
    vec2 v = uv * 2.0 - 1.0;
    color *= 1.0 - 0.25 * dot(v, v);
    fragColor = vec4(color * mask, max(base.a, iOpacity) * mask);
}
