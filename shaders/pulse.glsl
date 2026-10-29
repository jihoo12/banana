// Edge glow that brightens with terminal activity. The `activity` plugin sets
// iParam[0] between 0 (idle) and 1 (busy).

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    float level = clamp(iParam[0], 0.0, 1.0);
    vec2 edge = min(uv, 1.0 - uv) * iResolution.xy;
    float d = min(edge.x, edge.y);
    float breathe = 0.75 + 0.25 * sin(iTime * 2.0);
    float glow = exp(-d / (6.0 + 18.0 * level)) * (0.15 + 0.6 * level) * breathe;
    fragColor = vec4(base.rgb + iAccent * glow, max(base.a, glow));
}
