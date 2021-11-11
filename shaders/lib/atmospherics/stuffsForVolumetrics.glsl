float GetLogarithmicDepth(float dist) {
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

float InterleavedGradientNoiseVL() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 6.0);
}

vec4 GetWorldSpace(float shadowdepth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, shadowdepth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

#if defined FIREFLIES || defined LIGHTSHAFT_CLOUDY_NOISE || defined VOLUMETRIC_FOG
float rand(vec3 p) {
    return fract(sin(dot(p, vec3(12.345, 67.89, 412.12))) * 42123.45) * 2.0 - 1.0;
}

float getCloudNoise(vec3 pos) {
	pos /= 8.0;
	pos.xz *= 0.50;

	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = (v * v) * (3.0 - 2.0 * v);
	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord1 = uv / 64.0;
	vec2 coord2 = uv / 64.0 + 16.0 / 64.0;
		
	float a = texture2D(noisetex, coord1).x * LIGHTSHAFT_HORIZONTAL_THICKNESS;
	float b = texture2D(noisetex, coord2).x * LIGHTSHAFT_HORIZONTAL_THICKNESS;
		
	return mix(a, b, v.y);
}
#endif

#if ((defined LIGHTSHAFT_CLOUDY_NOISE || defined VOLUMETRIC_FOG) && defined OVERWORLD) || (defined NETHER_SMOKE && defined NETHER)
float getFogSample(vec3 pos, float height, float verticalThickness, float samples, float amount){
	float ymult = pow(abs(height - pos.y) / verticalThickness, LIGHTSHAFT_VERTICAL_THICKNESS);
	vec3 wind = vec3(frametime * 0.25, 0, 0);
	float noise = getCloudNoise(pos * samples * 1.00000 - wind * 0.30);
		  noise+= getCloudNoise(pos * samples * 0.50000 + wind * 0.25);
          noise+= getCloudNoise(pos * samples * 0.25000 - wind * 0.20);
          noise+= getCloudNoise(pos * samples * 0.12500 + wind * 0.15);
          noise+= getCloudNoise(pos * samples * 0.06250 - wind * 0.10);
	noise = clamp(noise * LIGHTSHAFT_AMOUNT * amount - (1.0 + ymult), 0.0, 1.0);
	return noise;
}
#endif