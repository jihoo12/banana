// Soft bloom: bright text and the cursor bleed light into the background.

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 base = texture(iChannel0, uv);
    vec2 px = 1.0 / iResolution.xy;
    vec3 sum = vec3(0.0);
    float weight = 0.0;
    // A sparse disc of samples: wide glow at a modest cost.
    for (int ring = 1; ring <= 4; ring++) {
        float radius = float(ring) * 3.0;
        for (int k = 0; k < 8; k++) {
            float a = float(k) * 0.785398 + float(ring) * 0.4;
            vec3 s = texture(iChannel0, uv + vec2(cos(a), sin(a)) * radius * px).rgb;
            // Only light brighter than the background blooms.
            float luma = dot(s, vec3(0.299, 0.587, 0.114));
            float w = 1.0 / float(ring);
            sum += s * smoothstep(0.35, 0.9, luma) * w;
            weight += w;
        }
    }
    vec3 bloom = sum / weight;
    fragColor = vec4(base.rgb + bloom * 0.9, base.a);
}
