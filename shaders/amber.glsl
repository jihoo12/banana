// A monochrome amber phosphor monitor with faint scanlines and flicker.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec2 px = 1.0 / iResolution.xy;
    float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
    // Phosphor persistence spreads light a little.
    float halo = 0.0;
    for (int i = -2; i <= 2; i++) {
        vec3 s = texture(iChannel0, uv + vec2(float(i) * 1.5 * px.x, 0.0)).rgb;
        halo += dot(s, vec3(0.299, 0.587, 0.114));
    }
    luma = max(luma, halo / 5.0 * 0.9);
    vec3 amber = vec3(1.0, 0.68, 0.22);
    vec3 color = amber * pow(luma, 0.9) * 1.25 + vec3(0.025, 0.012, 0.0);
    color *= 0.92 + 0.08 * sin(fragCoord.y * 3.14159);
    color *= 0.985 + 0.015 * sin(iTime * 60.0);
    fragColor = vec4(color, base.a);
}
