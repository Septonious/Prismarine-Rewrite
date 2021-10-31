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
#endif

#if ((defined LIGHTSHAFT_CLOUDY_NOISE || defined VOLUMETRIC_FOG) && defined OVERWORLD) || (defined NETHER_SMOKE && defined NETHER)
float getFogSample(vec3 pos, float height, float verticalThickness, float samples, float amount){
	float ymult = pow(abs(height - pos.y) / verticalThickness, LIGHTSHAFT_VERTICAL_THICKNESS);
	vec3 wind = vec3(frametime * 0.25, 0, 0);
	float noise = perlin(pos * samples * 1.000 - wind * 0.30) * 1 * LIGHTSHAFT_HORIZONTAL_THICKNESS;
		  noise+= perlin(pos * samples * 0.500 - wind * 0.25) * 2 * LIGHTSHAFT_HORIZONTAL_THICKNESS;
          noise+= perlin(pos * samples * 0.250 - wind * 0.20) * 3 * LIGHTSHAFT_HORIZONTAL_THICKNESS;
          noise+= perlin(pos * samples * 0.125 - wind * 0.15) * 4 * LIGHTSHAFT_HORIZONTAL_THICKNESS;
	noise = clamp(noise * LIGHTSHAFT_AMOUNT * amount - (1.0 + ymult), 0.0, 1.0);
	return noise;
}
#endif