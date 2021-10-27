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

//credits: https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289(((x * 34.0) + 1.0) * x);}

float getNoise1(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}
//credits: https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83

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

float getVolumetricNoise(vec3 pos){
	float baseNoise  = getNoise1(pos) * 0.1;
		  baseNoise += getNoise1(pos) * 0.2;
		  baseNoise += getNoise1(pos) * 0.3;
		  baseNoise += getNoise1(pos) * 0.4;
		  baseNoise += getNoise1(pos) * 0.5;

	return baseNoise;
}

float getCloudSample(vec3 pos, float height, float verticalThickness, float samples, float quality){
	if (quality == 0) samples = 0.2;
	if (quality == 1) samples = 0.5;

	float noise = 0.0;
	float ymult = pow(abs(height - pos.y) / verticalThickness, VCLOUDS_VERTICAL_THICKNESS);
	vec3 wind = vec3(frametime * VCLOUDS_SPEED * 1.5, 0.0, 0.0);
	float rainStrengthLowered = rainStrength / 8.0;
	float amount = CalcTotalAmount(CalcDayAmount(VCLOUDS_AMOUNT_MORNING, VCLOUDS_AMOUNT_DAY, VCLOUDS_AMOUNT_EVENING), VCLOUDS_AMOUNT_NIGHT);
	float thickness = VCLOUDS_HORIZONTAL_THICKNESS + (VCLOUDS_THICKNESS_FACTOR * timeBrightness);

	if (ymult < 2.0){
		if (quality == 2){
			noise += getVolumetricNoise(pos * samples * 0.5 - wind * 1) * 0.25 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.25 - wind * 0.9) * 0.75 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.125 - wind * 0.8) * 1.0 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.0625 - wind * 0.7) * 1.75 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.03125 - wind * 0.6) * 2.0 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.016125 - wind * 0.5) * 2.75 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.00862 - wind * 0.4) * 3.0 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.00431 - wind * 0.3) * 3.25 * thickness;
			noise += getVolumetricNoise(pos * samples * 0.00216 - wind * 0.2) * 4.0 * thickness;
			amount *= 0.8;
		}else if (quality == 1){
			thickness *= 3;
			noise+= getVolumetricNoise(pos * samples * 0.5 - wind * 0.5) * 0.5 * thickness;
			noise+= getVolumetricNoise(pos * samples * 0.25 - wind * 0.4) * 2.0 * thickness;
			noise+= getVolumetricNoise(pos * samples * 0.125 - wind * 0.3) * 3.5 * thickness;
			noise+= getVolumetricNoise(pos * samples * 0.0625 - wind * 0.2) * 5.0 * thickness;
			noise+= getVolumetricNoise(pos * samples * 0.03125 - wind * 0.1) * 6.5 * thickness;
			noise+= getVolumetricNoise(pos * samples * 0.016125) * 8 * thickness;
			amount *= 0.175;
		} else if (quality == 0){
			noise+= getNoise1(pos * samples * 0.125 - wind * 0.3) * 64 * thickness;
			amount *= 0.35;
		}
	}
	noise = clamp(mix(noise * amount, 21.0, 0.25 * rainStrengthLowered) - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec2 getVolumetricCloud(float pixeldepth0, float pixeldepth1, float heightAdjFactor, float vertThicknessFactor, float dither) {
	vec2 vc = vec2(0);
	float maxDist = 512;
	
	float depth0 = GetLinearDepth2(pixeldepth0);
	float depth1 = GetLinearDepth2(pixeldepth1);
	vec4 wpos = vec4(0.0);
		
	for(int i = 0; i < 32; i++) {
		float minDist = (i + dither) * 8 * VCLOUDS_RANGE; 

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

		if (length(wpos.xz) < maxDist && depth0 > minDist){
			float vh = getHeightNoise((wpos.xz + cameraPosition.xz + (1.0 - sin(frameTimeCounter + cos(frameTimeCounter)) * VCLOUDS_SPEED)) * 0.015);

			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float offset = 32;
			if (VCLOUDS_NOISE_QUALITY == 0) offset = 1;

			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, -vh * offset, 0.0);

			float height = VCLOUDS_HEIGHT + (heightAdjFactor * timeBrightness);
			float vertThickness = VCLOUDS_VERTICAL_THICKNESS * vertThicknessFactor + timeBrightness;
			float noise = getCloudSample(wpos.xyz, height, vertThickness, VCLOUDS_SAMPLES, VCLOUDS_NOISE_QUALITY);

			float col = pow(smoothstep(height - vertThickness * noise, height + vertThickness * noise, wpos.y), 2);
			vc.x = max(noise * col, vc.x);
			vc.y = max(noise, vc.y);
		}
	}
	
	return vc;
}
#endif