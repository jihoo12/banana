// Slow aurora light drifting behind the text. Only the background moves;
// text, selection and the cursor stay crisp.

float wave(vec2 p, float t) {
    return sin(p.x * 1.7 + t * 0.21 + sin(p.y * 2.3 + t * 0.17) * 1.3) *
        sin(p.y * 1.1 - t * 0.13 + sin(p.x * 0.9 + t * 0.11) * 1.7);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec2 p = fragCoord / iResolution.y * 2.0;
    float t = iTime;
    float a = wave(p, t) * 0.5 + 0.5;
    float b = wave(p * 1.3 + 4.0, t * 1.4) * 0.5 + 0.5;
    vec3 light = mix(iAccent, vec3(0.45, 0.35, 0.95), b) * pow(a, 3.0);
    light *= smoothstep(0.0, 1.0, uv.y) * 0.22;
    // Pixels close to the theme background are background.
    float is_background = 1.0 - smoothstep(0.04, 0.12, distance(base.rgb, iBackground * base.a));
    fragColor = vec4(base.rgb + light * is_background * base.a, base.a);
}
