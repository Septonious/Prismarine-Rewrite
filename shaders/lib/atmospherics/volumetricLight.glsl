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
#endif	

#ifdef FIREFLIES
float getFireflyNoise(vec3 pos, float height){
	float noise = 0.0;
	float ymult = pow(abs(height - pos.y) / 32, 32);
	
	if (ymult < 2.0){
		noise+= getNoise1(pos) * 10.05;
	}
    
	noise = clamp(noise - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec3 GetFireflies(float pixeldepth0, vec3 color, float dither) {
	vec3 ff = vec3(0.0);
	dither *= 2;
	float visibility = (1 - sunVisibility) * (1 - rainStrength) * (0 + eBS);

	if (visibility > 0.0) {
		float depth0 = GetLinearDepth2(pixeldepth0);
		vec4 worldposition = vec4(0.0);

		for(int i = 0; i < 8; i++) {
			float minDist = (i + dither) * 8; 

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

			if (length(worldposition.xz) < 128 && depth0 > minDist){
				vec3 col = vec3(1);

				if (depth0 < minDist) col *= color;
				
				float noise = getFireflyNoise(worldposition.xyz + cameraPosition.xyz, 50);

				col *= noise;

				ff += col;
			}
		}
		ff = sqrt(ff * visibility);
	} else discard;
	
	return ff;
}
#endif

#if defined LIGHTSHAFT_CLOUDY_NOISE && defined OVERWORLD
float getVolumetricNoise(vec3 pos){
	float baseNoise  = getNoise1(pos) * 0.1;
		  baseNoise += getNoise1(pos) * 0.2;
		  baseNoise += getNoise1(pos) * 0.3;
		  baseNoise += getNoise1(pos) * 0.4;
		  baseNoise += getNoise1(pos) * 0.5;

	return baseNoise;
}

float getFogSample(vec3 pos, float height, float verticalThickness, float samples, float amount){
	float noise = 0.0;
	float ymult = pow(abs(height - pos.y) / verticalThickness, LIGHTSHAFT_VERTICAL_THICKNESS);
	vec3 wind = vec3(frametime * 0.5, 0, 0);
	
	if (ymult < 2.0){
		float thickness = LIGHTSHAFT_HORIZONTAL_THICKNESS * 3;
		noise+= getVolumetricNoise(pos * samples * 0.5 - wind * 0.5) * 0.5 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.25 - wind * 0.4) * 2.0 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.125 - wind * 0.3) * 3.5 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.0625 - wind * 0.2) * 5.0 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.03125 - wind * 0.1) * 6.5 * thickness;
		noise+= getVolumetricNoise(pos * samples * 0.016125) * 8 * thickness;
	}
	noise = clamp(mix(noise * LIGHTSHAFT_AMOUNT * amount * 0.225, 21.0, 0.25) - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}
#endif

vec4 DistortShadow(vec4 shadowpos, float distortFactor) {
	shadowpos.xy *= 1.0 / distortFactor;
	shadowpos.z = shadowpos.z * 0.2;
	shadowpos = shadowpos * 0.5 + 0.5;

	return shadowpos;
}

vec4 GetShadowSpace(vec4 wpos) {
	wpos = shadowModelView * wpos;
	wpos = shadowProjection * wpos;
	wpos /= wpos.w;
	
	float distb = sqrt(wpos.x * wpos.x + wpos.y * wpos.y);
	float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
	wpos = DistortShadow(wpos,distortFactor);
	
	return wpos;
}

//Light shafts from Robobo1221 (modified)
vec3 GetLightShafts(float pixeldepth0, float pixeldepth1, vec3 color, float dither) {
	vec3 vl = vec3(0.0);

	#ifdef END_VOLUMETRIC_FOG
	#endif
	
	#ifdef LIGHTSHAFT_CLOUDY_NOISE
	#endif

	vec3 screenPos = vec3(texCoord, pixeldepth0);
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, pixeldepth0, 1.0) * 2.0 - 1.0);
		viewPos /= viewPos.w;
	
	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
	vec3 nViewPos = normalize(viewPos.xyz);
	float VoL = dot(nViewPos, lightVec);
	float VoU = dot(nViewPos, upVec);

	#ifdef OVERWORLD	
	float visfactor = 0.05 * (-0.1 * timeBrightness + 1.0) * (1.0 - rainStrength);
	float invvisfactor = 1.0 - visfactor;
	float dayVis, nightVis;
	
	#ifdef LIGHTSHAFT_NIGHT
	nightVis = 1;
	#endif

	#ifdef LIGHTSHAFT_DAY
	dayVis = 1;
	#endif

	if (isEyeInWater == 1){
		dayVis = 1;
		nightVis = 1;
	}

	float visibility = CalcTotalAmount(CalcDayAmount(1, dayVis, 1), nightVis) * (1 - rainStrength);

	visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
	visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
	visibility = mix(1.0, visibility, 0.25 * 1 + 0.75) * 0.14285 * float(pixeldepth0 > 0.56);
	#endif
	
	#ifdef END
	bool isThereADragon = gl_Fog.start / far < 0.5; //yes emin thanks for telling people about this in shaderlabs
	float dragonFactor;
	if (isThereADragon) dragonFactor = 0.5;
	else dragonFactor = 0;

	VoL = pow(VoL * 0.5 + 0.5, 16.0) * 0.75 + 0.25;
	float visibility = VoL;
	visibility *= (0.1 + dragonFactor);
	#endif

	#ifdef NETHER
	float visibility = 0;
	#endif

	if (visibility > 0.0) {
		float maxDist = LIGHTSHAFT_MAX_DISTANCE;
		
		float depth0 = GetLinearDepth2(pixeldepth0);
		float depth1 = GetLinearDepth2(pixeldepth1);
		vec4 worldposition = vec4(0.0);
		vec4 shadowposition = vec4(0.0);
		
		vec3 watercol = vec3(LIGHTSHAFT_WR, LIGHTSHAFT_WG, LIGHTSHAFT_WB) * LIGHTSHAFT_WI / 255.0 * LIGHTSHAFT_WI;
		
		for(int i = 0; i < LIGHTSHAFT_SAMPLES; i++) {
			float minDist = (i + dither) * LIGHTSHAFT_MIN_DISTANCE;

			if (isEyeInWater == 1){
				minDist = (exp2(i + dither) - 0.95) * 4;
				maxDist = 16;
			}
			
			#ifdef END
			minDist = (exp2(i + dither) - 0.95) * 2;
			#endif

			if (minDist >= maxDist) break;
			if (depth1 < minDist || (depth0 < minDist && color == vec3(0.0))) break;

			#ifndef LIGHTSHAFT_WATER
			if (isEyeInWater == 1.0) break;
			#endif

			#if defined END && !defined END_VOLUMETRIC_FOG
			break;
			#endif

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);
			shadowposition = GetShadowSpace(worldposition);
			shadowposition.z += 0.0512 / shadowMapResolution;

			if (length(shadowposition.xy * 2.0 - 1.0) < 1.0) {
				float shadow0 = shadow2D(shadowtex0, shadowposition.xyz).z;
				
				vec3 shadowCol = vec3(0.0);
				#ifdef SHADOW_COLOR
				if (shadow0 < 1.0) {
					float shadow1 = shadow2D(shadowtex1, shadowposition.xyz).z;
					if (shadow1 > 0.0) {
						shadowCol = texture2D(shadowcolor0, shadowposition.xy).rgb;
						shadowCol *= shadowCol * shadow1;
					}
				}
				#endif
				vec3 shadow = clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));

				if (depth0 < minDist) shadow *= color;
				else if (isEyeInWater == 1.0) shadow *= watercol * 64;

				vec3 npos = worldposition.xyz + cameraPosition.xyz;

				vec3 col = vec3(0.0);

				#if defined END_VOLUMETRIC_FOG && defined END
				if (isEyeInWater != 1){
					float n3da = texture2D(noisetex, npos.xz / 1024.0 + floor(npos.y / 3.0) * 0.30).r;
					float n3db = texture2D(noisetex, npos.xz / 2048.0 + floor(npos.y / 3.0 + 1.0) * 0.35).r;
					float noise = mix(n3da, n3db, fract(npos.y / 3.0));
					noise = sin(noise * 16.0 + frametime) * 0.25 + 0.5;
					shadow *= noise;
				}
				#elif defined LIGHTSHAFT_CLOUDY_NOISE && defined OVERWORLD
				col = lightshaftCola.rgb;
				if (depth0 < minDist) col *= color;

				if (isEyeInWater != 1){
					#ifdef WORLD_CURVATURE
					if (length(worldposition.xz) < WORLD_CURVATURE_SIZE) worldposition.y += length(worldposition.xz) * length(worldposition.xyz) / WORLD_CURVATURE_SIZE;
					else break;
					#endif

					col *= getFogSample(npos.xyz, LIGHTSHAFT_HEIGHT / 2, LIGHTSHAFT_VERTICAL_THICKNESS, 0.75, 1.3);
					shadow *= getFogSample(npos.xyz, LIGHTSHAFT_HEIGHT / 2, LIGHTSHAFT_VERTICAL_THICKNESS, 1.00, 1.2);
				}
				#endif

				#ifdef OVERWORLD
				VoU = clamp(VoU, 0, 1);
				col *= 1 - VoU;
				shadow *= 1 - VoU;
				#endif

				col *= eBS;

				#if defined LIGHTSHAFT_CLOUDY_NOISE && defined OVERWORLD
				vl += col;
				#endif

				vl += shadow;
			}
		}
		vl = sqrt(vl * visibility);
		if(dot(vl, vl) > 0.0) vl += (dither - 0.25) / 128.0;
	}
	
	return vl;
}
/*
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
			noise+= getVolumetricNoise(pos * samples * 0.125 - wind * 0.3) * 64 * thickness;
			amount *= 0.35;
		}
	}
	noise = clamp(mix(noise * amount, 21.0, 0.25 * rainStrengthLowered) - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec3 GetVC(float pixeldepth0, float pixeldepth1, vec3 color, float dither) {
	vec3 vc = vec3(0.0);

	float maxDist = 1444;
		
	float depth0 = GetLinearDepth2(pixeldepth0);
	float depth1 = GetLinearDepth2(pixeldepth1);
	vec4 wpos = vec4(0.0);
		
	for(int i = 0; i < 16; i++) {
		float minDist = (i + dither) * 16 * VCLOUDS_RANGE; 

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

		if (length(wpos.xz) < maxDist && depth0 > minDist){
			vec3 col = vec3(1);

			float vh = getHeightNoise((wpos.xz + cameraPosition.xz + (1.0 - sin(frameTimeCounter + cos(frameTimeCounter)) * VCLOUDS_SPEED)) * 0.015);

			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float offset = 32;
			if (VCLOUDS_NOISE_QUALITY == 0) offset = 1;

			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, -vh * offset, 0.0);

			float height = VCLOUDS_HEIGHT + (VCLOUDS_HEIGHT_ADJ_FACTOR * timeBrightness);
			float vertThickness = VCLOUDS_VERTICAL_THICKNESS * VCLOUDS_THICKNESS_FACTOR + timeBrightness;
			float noise = getCloudSample(wpos.xyz, height, 46, VCLOUDS_SAMPLES, VCLOUDS_NOISE_QUALITY);
			col *= noise;

			vc += col;
		}
	}
	
	return vc;
}
*/