vec2 OffsetDist(float x) {
	float n = fract(x * 8.0) * 3.1415;
    return vec2(cos(n), sin(n)) * x;
}

float AmbientOcclusion(float dither) {
	float ao = 0.0;
	
	float depth = texture2D(depthtex0, texCoord).r;
	if(depth >= 1.0) return 1.0;

	float hand = float(depth < 0.56);
	depth = GetLinearDepth(depth);

	#ifdef TAA
	dither = fract(dither + frameTimeCounter * 8.0);
	#endif

	float currentStep = 0.2 * dither + 0.2;

	float radius = 0.35;
	float fovScale = gbufferProjection[1][1] / 1.37;
	float distScale = max((far - near) * depth + near, 5.0);
	vec2 scale = radius * vec2(1.0 / aspectRatio, 1.0) * fovScale / distScale;
	float mult = (0.7 / radius) * (far - near) * (hand > 0.5 ? 1024.0 : 1.0);

	for(int i = 0; i < 4; i++) {
		vec2 offset = OffsetDist(currentStep) * scale;
		float angle = 0.0, dist = 0.0;

		for(int i = 0; i < 2; i++){
			float sampleDepth = GetLinearDepth(texture2D(depthtex0, texCoord + offset).r);
			float sample = (depth - sampleDepth) * mult;
			angle += clamp(0.5 - sample, 0.0, 1.0);
			dist += clamp(0.25 * sample - 1.0, 0.0, 1.0);
			offset = -offset;
		}
		
		ao += clamp(angle + dist, 0.0, 1.0);
		currentStep += 0.2;
	}
	ao *= 0.25;
	
	return ao;
}