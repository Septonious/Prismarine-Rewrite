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
vec3 GetLightShafts(float pixeldepth0, float pixeldepth1, vec3 color, float dither, float visibility) {
	vec3 vl = vec3(0.0);

	#ifdef LIGHTSHAFT_CLOUDY_NOISE
	#endif

	vec3 screenPos = vec3(texCoord, pixeldepth0);
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord, pixeldepth0, 1.0) * 2.0 - 1.0);
		viewPos /= viewPos.w;
	
	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
	vec3 nViewPos = normalize(viewPos.xyz);
	float VoL = dot(nViewPos, lightVec);
	float scatter = pow(VoL * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 8.0) * 2.0;

	#ifdef OVERWORLD
	float visfactor = 0.05 * (-0.1 * timeBrightness + 1.0) * (1.0 - rainStrength);
	float invvisfactor = 1.0 - visfactor;

	visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
	visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
	visibility = clamp(visibility + isEyeInWater, 0.0, 1.0);
	visibility = mix(1.0, visibility, 0.25 * 1 + 0.75) * 0.14285 * float(pixeldepth0 > 0.56);
	#endif

	#ifdef NETHER
	float visibility = 0.0;
	#endif

	if (visibility > 0.0) {
		float maxDist = LIGHTSHAFT_MAX_DISTANCE;
		
		float depth0 = GetLinearDepth2(pixeldepth0);
		float depth1 = GetLinearDepth2(pixeldepth1);
		vec4 worldposition = vec4(0.0);
		vec4 shadowposition = vec4(0.0);
		
		vec3 watercol = vec3(LIGHTSHAFT_WR, LIGHTSHAFT_WG, LIGHTSHAFT_WB) * LIGHTSHAFT_WI / 255.0 * LIGHTSHAFT_WI;
		
		for(int i = 0; i <= LIGHTSHAFT_SAMPLES; i++) {
			float minDist = (i + dither) * LIGHTSHAFT_MIN_DISTANCE;
				  minDist *= 1.0 - (isEyeInWater * 0.75);

			if (minDist >= maxDist) break;
			if (depth1 < minDist || (depth0 < minDist && color == vec3(0.0))) break;

			#ifndef LIGHTSHAFT_WATER
			if (isEyeInWater == 1.0) break;
			#endif

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);
			shadowposition = GetShadowSpace(worldposition);
			shadowposition.z += 0.0512 / shadowMapResolution;

			if (length(shadowposition.xy * 2.0 - 1.0) < 1.0) {
				float shadow0 = shadow2D(shadowtex0, shadowposition.xyz).z;
				
				vec3 shadowCol = vec3(0.0);
				#ifdef SHADOW_COLOR
				if (shadow0 < 1.0) {
					float shadow1 = shadow2D(shadowtex1, shadowposition.xyz).z * COLORED_SHADOW_BRIGHTNESS;
					if (shadow1 > 0.0) {
						shadowCol = texture2D(shadowcolor0, shadowposition.xy).rgb;
						shadowCol *= shadowCol * shadow1;
					}
				}
				#endif
				vec3 shadow = shadowCol * (1.0 - shadow0) + shadow0;

				if (depth0 < minDist && cameraPosition.y < LIGHTSHAFT_HEIGHT + 25) shadow *= color;
				else if (isEyeInWater == 1.0) shadow *= watercol * 64.0;

				vec3 pos = worldposition.xyz + cameraPosition.xyz;

				#if defined LIGHTSHAFT_CLOUDY_NOISE && defined OVERWORLD
				if (isEyeInWater != 1.0){
					#ifdef WORLD_CURVATURE
					if (length(worldposition.xz) < WORLD_CURVATURE_SIZE) worldposition.y += length(worldposition.xz) * length(worldposition.xyz) / WORLD_CURVATURE_SIZE;
					else break;
					#endif

					float noise = getFogSample(pos.xyz, LIGHTSHAFT_HEIGHT + 5, LIGHTSHAFT_VERTICAL_THICKNESS * (3.0 - isEyeInCave), 0.60, LIGHTSHAFT_HORIZONTAL_THICKNESS * (2.0 - isEyeInCave));
					shadow *= noise;
				}
				#else
				float sampleHeight = pow(abs(100.0 - pos.y) / 16.0, 2.0);
					  sampleHeight = clamp(2.0 - (1.0 + sampleHeight), 0.0, 1.0);
				shadow *= sampleHeight * 0.05;
				#endif

				vl += shadow;
			}
		}

		vl = sqrt(vl * visibility);
	}
	
	return vl * (1.0 + scatter);
}