#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
float GetLogarithmicDepth(float dist){
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
  return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

float getNoise(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec4 GetWorldSpace(float shadowdepth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, shadowdepth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

float rand(vec3 p) {
    return fract(sin(dot(p, vec3(12.345, 67.89, 412.12))) * 42123.45) * 2.0 - 1.0;
}

float rand2D(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getHeightNoise(vec2 pos){
	vec2 flr = floor(pos);
	vec2 frc = fract(pos);
	frc = frc * frc * (3 - 2 * frc);
	
	float noisedl = getNoise(flr);
	float noisedr = getNoise(flr + vec2(1.0,0.0));
	float noiseul = getNoise(flr + vec2(0.0,1.0));
	float noiseur = getNoise(flr + vec2(1.0,1.0));
	float noise = mix(mix(noisedl, noisedr, frc.x),
			          mix(noiseul, noiseur, frc.x), frc.y);
	return noise;
}

float perlin(vec3 p) {
    vec3 u = floor(p);
    vec3 v = fract(p);
    vec3 s = smoothstep(0.0, 1.0, v);
    
    float a = rand(u);
    float b = rand(u + vec3(1.0, 0.0, 0.0));
    float c = rand(u + vec3(0.0, 1.0, 0.0));
    float d = rand(u + vec3(1.0, 1.0, 0.0));
    float e = rand(u + vec3(0.0, 0.0, 1.0));
    float f = rand(u + vec3(1.0, 0.0, 1.0));
    float g = rand(u + vec3(0.0, 1.0, 1.0));
    float h = rand(u + vec3(1.0, 1.0, 1.0));
    
    return mix(mix(mix(a, b, s.x), mix(c, d, s.x), s.y),
               mix(mix(e, f, s.x), mix(g, h, s.x), s.y),
               s.z);
}

float getCloudSample(vec3 pos, float height, float verticalThickness, float detail, float quality){
	if (quality == 0) detail *= 0.2;
	if (quality == 1) detail *= 0.5;

	float noise = 0.0;
	float ymult = pow(abs(height - pos.y) / verticalThickness, VCLOUDS_VERTICAL_THICKNESS);
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);
	float amount = CalcTotalAmount(CalcDayAmount(VCLOUDS_AMOUNT_MORNING, VCLOUDS_AMOUNT_DAY, VCLOUDS_AMOUNT_EVENING), VCLOUDS_AMOUNT_NIGHT);
	float thickness = (VCLOUDS_HORIZONTAL_THICKNESS + (VCLOUDS_THICKNESS_FACTOR * timeBrightness)) * 64;

	if (quality == 2){
		noise += perlin(pos * detail * 0.5 - wind * 1) * 0.25 * thickness;
		noise += perlin(pos * detail * 0.25 - wind * 0.9) * 0.75 * thickness;
		noise += perlin(pos * detail * 0.125 - wind * 0.8) * 1.0 * thickness;
		noise += perlin(pos * detail * 0.0625 - wind * 0.7) * 1.75 * thickness;
		noise += perlin(pos * detail * 0.03125 - wind * 0.6) * 2.0 * thickness;
		noise += perlin(pos * detail * 0.016125 - wind * 0.5) * 2.75 * thickness;
		noise += perlin(pos * detail * 0.00862 - wind * 0.4) * 3.0 * thickness;
		noise += perlin(pos * detail * 0.00431 - wind * 0.3) * 3.25 * thickness;
		noise += perlin(pos * detail * 0.00216 - wind * 0.2) * 4.0 * thickness;
		amount *= 0.8;
	} else if (quality == 1){
		thickness *= 3;
		noise+= perlin(pos * detail * 0.5 - wind * 0.5) * 0.5 * thickness;
		noise+= perlin(pos * detail * 0.25 - wind * 0.4) * 2.0 * thickness;
		noise+= perlin(pos * detail * 0.125 - wind * 0.3) * 3.5 * thickness;
		noise+= perlin(pos * detail * 0.0625 - wind * 0.2) * 5.0 * thickness;
		noise+= perlin(pos * detail * 0.03125 - wind * 0.1) * 6.5 * thickness;
		noise+= perlin(pos * detail * 0.016125) * 8 * thickness;
		amount *= 0.175;
	} else if (quality == 0){
		noise+= perlin(pos * detail * 0.125 - wind * 0.3) * 64 * thickness;
		amount *= 0.35;
	}
	noise = clamp(noise * amount - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec2 getVolumetricCloud(float pixeldepth1, float heightAdjFactor, float vertThicknessFactor, float dither) {
	vec2 vc = vec2(0);

	dither *= 8;
	
	float depth1 = GetLinearDepth2(pixeldepth1);
	vec4 wpos = vec4(0.0);

	float maxDist = 256 * VCLOUDS_RANGE;
	float minDist = 0.01 + dither;

	for (minDist; minDist < maxDist; ) {
		if (depth1 < minDist || vc.y > 0.999){
			break;
		}

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

		if (length(wpos.xz) < maxDist && depth1 > minDist){
			float vh = getHeightNoise((wpos.xz + cameraPosition.xz) * 0.0025);

			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float offset = 64;
			if (VCLOUDS_NOISE_QUALITY == 0) offset = 1;

			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, -vh * offset, 0.0);

			float height = VCLOUDS_HEIGHT + (heightAdjFactor * timeBrightness);
			float vertThickness = VCLOUDS_VERTICAL_THICKNESS * vertThicknessFactor + timeBrightness;

			float noise = getCloudSample(wpos.xyz, height, vertThickness, VCLOUDS_SAMPLES, VCLOUDS_NOISE_QUALITY);
			float col = smoothstep(height - vertThickness * noise, height + vertThickness * noise, wpos.y);
			vc.x = max(noise * col, vc.x);
			vc.y = max(noise, vc.y);
		}
		minDist = minDist + 10;
	}
	
	return vc;
}
#endif