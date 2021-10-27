float GetLogarithmicDepth(float dist) {
	return (far * (dist - near)) / (dist * (far - near));
}

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}

vec4 GetWorldSpace(float shadowdepth, vec2 texCoord) {
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, shadowdepth, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec4 wpos = gbufferModelViewInverse * viewPos;
	wpos /= wpos.w;
	
	return wpos;
}

#if defined FIREFLIES || defined LIGHTSHAFT_CLOUDY_NOISE
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

float getVolumetricNoise(vec3 pos){
	float baseNoise  = getNoise1(pos) * 0.1;
		  baseNoise += getNoise1(pos) * 0.2;
		  baseNoise += getNoise1(pos) * 0.3;
		  baseNoise += getNoise1(pos) * 0.4;
		  baseNoise += getNoise1(pos) * 0.5;

	return baseNoise;
}

float getSmokeSample(vec3 pos, float samples){
	float noise = 0.0;
	float ymult = pow(abs(70 - pos.y) / 32, 32);
	vec3 wind = vec3(frametime * 0.5, 0, 0);
	
	if (ymult < 2.0){
		float thickness = 8;
		noise+= getVolumetricNoise(pos * samples * 0.5 - wind * 0.5) * 1.5 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.25 - wind * 0.4) * 2.5 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.125 - wind * 0.3) * 4.5 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.0625 - wind * 0.2) * 5.5 * thickness;
        noise *= 8;
	}
	noise = clamp(mix(noise, 21.0, 0.25) - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec3 GetNetherSmoke(float pixeldepth0, vec3 color, float dither) {
	vec3 s = vec3(0.0);

	float depth0 = GetLinearDepth2(pixeldepth0);
	vec4 worldposition = vec4(0.0);

	for(int i = 0; i < 8; i++) {
		float minDist = (i + dither) * 8; 

		worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

		if (length(worldposition.xz) < 128 && depth0 > minDist){
			vec3 col = vec3(1);

			if (depth0 < minDist) col *= color;
				
			float noise = getSmokeSample(worldposition.xyz + cameraPosition.xyz, 2);

			col *= noise;

			s += col;
		}
	}
	
	return s;
}