float GetLogarithmicDepth(float dist) {
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

float InterleavedGradientNoiseVL() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	
	#ifdef TAA
	n = fract(n + frameCounter / 8.0);
	#else
	n = fract(n);
	#endif

	return n;
}

vec4 GetWorldSpace(float shadowdepth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, shadowdepth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

float rand2D(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getCloudWave(vec2 pos){
	vec2 u = floor(pos);
	vec2 v = fract(pos);
	
	float noisedl = rand2D(u);
	float noisedr = rand2D(u + vec2(1.0, 0.0));
	float noiseul = rand2D(u + vec2(0.0, 1.0));
	float noiseur = rand2D(u + vec2(1.0, 1.0));
	float noise = mix(mix(noisedl, noisedr, v.x),
			          mix(noiseul, noiseur, v.x), v.y);
	return noise;
}

#if defined FIREFLIES || defined LIGHTSHAFT_CLOUDY_NOISE || defined VOLUMETRIC_FOG
#ifdef FIREFLIES
float getVolumetricNoise0(vec3 pos){
	vec3 flr = floor(pos);
	vec3 frc = fract(pos);
	frc = frc * frc * (3.0 - 2.0 * frc);
	
	float noisebdl = rand2D(flr.xz + (vec2(frametime, 0) * 0.00005) + flr.y * 32);
	float noisebdr = rand2D(flr.xz - (vec2(frametime * 0.00015, 0) * 0.000075) + flr.y * 32 + vec2(1.0,0.0));
	float noisebul = rand2D(flr.xz + (vec2(frametime * 0.00040, 0) * 0.000100) + flr.y * 32 + vec2(0.0,1.0));
	float noisebur = rand2D(flr.xz - (vec2(frametime * 0.00055, 0) * 0.000150) + flr.y * 32 + vec2(1.0,1.0));
	float noisetdl = rand2D(flr.xz + (vec2(frametime * 0.00040, 0) * 0.000175) + flr.y * 32 + 32);
	float noisetdr = rand2D(flr.xz - (vec2(frametime * 0.00035, 0) * 0.000200) + flr.y * 32 + 32 + vec2(1.0,0.0));
	float noisetul = rand2D(flr.xz + flr.y * 32 + 32 + vec2(0.0,1.0));
	float noisetur = rand2D(flr.xz + flr.y * 32 + 32 + vec2(1.0,1.0));
	float noise= mix(mix(mix(noisebdl, noisebdr, frc.x), mix(noisebul, noisebur, frc.x), frc.z),
				 mix(mix(noisetdl, noisetdr, frc.x), mix(noisetul, noisetur, frc.x), frc.z), frc.y);
	return noise;
}
#endif

float getFogNoise(vec3 pos) {
	pos /= 12.0;
	pos.xz *= 0.25;

	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = (v * v) * (3.0 - 2.0 * v);
	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord = uv / 64.0;
	float a = texture2DLod(noisetex, coord, 4.0).r * LIGHTSHAFT_HORIZONTAL_THICKNESS;
	coord = uv / 64.0 + 16.0 / 64.0;
	float b = texture2DLod(noisetex, coord, 4.0).r * LIGHTSHAFT_HORIZONTAL_THICKNESS;
		
	return mix(a, b, v.y);
}
#endif

#if ((defined LIGHTSHAFT_CLOUDY_NOISE || defined VOLUMETRIC_FOG) && defined OVERWORLD) || (defined NETHER_SMOKE && defined NETHER) || (defined END && defined END_SMOKE)
float getFogSample(vec3 pos, float height, float verticalThickness, float samples, float amount){
	float ymult = pow(abs(height - pos.y) / verticalThickness, 2.0);
	vec3 wind = vec3(frametime * 0.25, 0, 0);
	
	#if defined NETHER || defined END
	pos *= 3.0;
	#endif

	float noise = getFogNoise(pos * samples * 1.00000 - wind * 0.30);
		  noise+= getFogNoise(pos * samples * 0.50000 + wind * 0.25);
          noise+= getFogNoise(pos * samples * 0.25000 - wind * 0.20);
          noise+= getFogNoise(pos * samples * 0.12500 + wind * 0.15);
          noise+= getFogNoise(pos * samples * 0.06250 - wind * 0.10);

	#if defined NETHER || defined END
	noise *= 0.5;
	#endif

	noise = clamp(noise * LIGHTSHAFT_AMOUNT * amount - (1.0 + ymult), 0.0, 1.0);
	return noise;
}
#endif