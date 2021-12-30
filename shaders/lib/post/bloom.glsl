float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
	float scale = exp2(lod);
	float resScale = 1.25 * min(360.0, viewHeight) / viewHeight;

	vec2 centerOffset = vec2(0.25 * pw, 0.25 * ph);
	vec3 bloom = texture2D(colortex1, (coord / scale + offset) * resScale + centerOffset).rgb;

	return pow(bloom, vec3(4.0)) * 64.0;
}

void Bloom(inout vec3 color, vec2 coord) {
	float strength = BLOOM_STRENGTH;

	#ifdef BLOOM_BALANCING
	strength *= 1.00 - eBS * 0.50;
	float isEnd = 1.0;
	#ifdef END
	isEnd = 0.25;
	#endif
	strength *= isEnd;
	#endif

	vec3 blur1 = GetBloomTile(1.0, coord, vec2(0.0      , 0.0   )) * 1.5;
	vec3 blur2 = GetBloomTile(2.0, coord, vec2(0.51     , 0.0   )) * 1.2;
	vec3 blur3 = GetBloomTile(3.0, coord, vec2(0.51     , 0.26  ));
	vec3 blur4 = GetBloomTile(4.0, coord, vec2(0.645    , 0.26  ));
	vec3 blur5 = GetBloomTile(5.0, coord, vec2(0.7175   , 0.26  ));
	vec3 blur6 = GetBloomTile(6.0, coord, vec2(0.645    , 0.3325)) * 0.9;
	vec3 blur7 = GetBloomTile(7.0, coord, vec2(0.670625 , 0.3325)) * 0.7;

	#if BLOOM_RADIUS == 1
	vec3 blur = blur1 * 0.667;
	#elif BLOOM_RADIUS == 2
	vec3 blur = (blur1 + blur2) * 0.37;
	#elif BLOOM_RADIUS == 3
	vec3 blur = (blur1 + blur2 + blur3) * 0.27;
	#elif BLOOM_RADIUS == 4
	vec3 blur = (blur1 + blur2 + blur3 + blur4) * 0.212;
	#elif BLOOM_RADIUS == 5
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5) * 0.175;
	#elif BLOOM_RADIUS == 6
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6) * 0.151;
	#elif BLOOM_RADIUS == 7
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7) * 0.137;
	#endif

	#ifdef BLOOM_FLICKERING
    float jitter = 1.0 - sin(frameTimeCounter + cos(frameTimeCounter)) * BLOOM_FLICKERING_STRENGTH;
    strength *= jitter;
	#endif

	#if BLOOM_CONTRAST == 0
	color = mix(color, blur, 0.25 * strength);
	#else
	
	vec3 bloomContrast = vec3(exp2(BLOOM_CONTRAST * 0.25));
	color = pow(color, bloomContrast);
	blur = pow(blur, bloomContrast);

	vec3 bloomStrength = pow(vec3(0.2 * strength), bloomContrast);
	color = mix(color, blur, bloomStrength);
	color = pow(color, 1.0 / bloomContrast);
	#endif
}