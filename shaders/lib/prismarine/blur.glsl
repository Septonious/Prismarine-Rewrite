vec3 BoxBlur(sampler2D colortex, int steps, float strength) {
	vec3 blur = vec3(0.0);

	float weight = 0.0;
	for(int i = -steps; i <= steps; i++) {
		for(int j = -steps; j <= steps; j++){
			vec2 offset = vec2(i, j) * strength * vec2(1.0 / aspectRatio, 1.0);
			blur += texture2D(colortex, texCoord + offset).rgb;
			weight += 1.0;
		}
	}
	blur /= weight;

	return blur;
}