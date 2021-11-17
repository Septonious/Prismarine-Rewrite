


#ifdef VOLUMETRIC_CLOUDS
#endif

float GetLogarithmicDepth(float dist){
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

float rand2D(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getHeightNoise(vec2 pos){
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


float getCloudNoise(vec3 pos){
	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = v * v * (3.0 - 2.0 * v);
	
	float noisebdl = rand2D(u.xz+u.y*32.0);
	float noisebdr = rand2D(u.xz+u.y*32.0+vec2(1.0,0.0));
	float noisebul = rand2D(u.xz+u.y*32.0+vec2(0.0,1.0));
	float noisebur = rand2D(u.xz+u.y*32.0+vec2(1.0,1.0));
	float noisetdl = rand2D(u.xz+u.y*32.0+32.0);
	float noisetdr = rand2D(u.xz+u.y*32.0+32.0+vec2(1.0,0.0));
	float noisetul = rand2D(u.xz+u.y*32.0+32.0+vec2(0.0,1.0));
	float noisetur = rand2D(u.xz+u.y*32.0+32.0+vec2(1.0,1.0));
	float noise= mix(mix(mix(noisebdl,noisebdr,v.x),mix(noisebul,noisebur,v.x),v.z),mix(mix(noisetdl,noisetdr,v.x),mix(noisetul,noisetur,v.x),v.z),v.y);
	return noise;
}

float getCloudSample(vec3 pos){
	float noise = 0.0;
	float ymult = pow(abs(VCLOUDS_HEIGHT - pos.y)/VCLOUDS_VERTICAL_THICKNESS,2.0);
	vec3 wind = vec3(frametime,0.0,0.0);
	
	if (ymult < 2.0){
		noise+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.500000 - wind * 0.5);
		noise+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.250000 - wind * 0.4) * 2.0;
		noise+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.125000 - wind * 0.3) * 3.0;
		noise+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.062500 - wind * 0.2) * 4.0;
		noise+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.031250 - wind * 0.1) * 5.0;
		noise+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.016125) * 6.0;
	}

	float amount = CalcTotalAmount(CalcDayAmount(VCLOUDS_AMOUNT_MORNING, VCLOUDS_AMOUNT_DAY, VCLOUDS_AMOUNT_EVENING), VCLOUDS_AMOUNT_NIGHT) * (0.9 + rainStrength * 0.1) * 2.0;
	noise = clamp(noise * amount - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}
void getVolumetricCloud(float pixeldepth1, float dither, inout vec3 color){
	//Here we set up the color of bottom and upper parts of the clouds
	vec3 vcMorning    = vec3(VCLOUD_MR,   VCLOUD_MG,   VCLOUD_MB)   * VCLOUD_MI / 255;
	vec3 vcDay        = vec3(VCLOUD_DR,   VCLOUD_DG,   VCLOUD_DB)   * VCLOUD_DI / 255;
	vec3 vcEvening    = vec3(VCLOUD_ER,   VCLOUD_EG,   VCLOUD_EB)   * VCLOUD_EI / 255;
	vec3 vcNight      = vec3(VCLOUD_NR,   VCLOUD_NG,   VCLOUD_NB)   * VCLOUD_NI * 0.3 / 255;

	vec3 vcDownMorning    = vec3(VCLOUDDOWN_MR,   VCLOUDDOWN_MG,   VCLOUDDOWN_MB)   * VCLOUDDOWN_MI / 255;
	vec3 vcDownDay        = vec3(VCLOUDDOWN_DR,   VCLOUDDOWN_DG,   VCLOUDDOWN_DB)   * VCLOUDDOWN_DI / 255;
	vec3 vcDownEvening    = vec3(VCLOUDDOWN_ER,   VCLOUDDOWN_EG,   VCLOUDDOWN_EB)   * VCLOUDDOWN_EI / 255;
	vec3 vcDownNight      = vec3(VCLOUDDOWN_NR,   VCLOUDDOWN_NG,   VCLOUDDOWN_NB)   * VCLOUDDOWN_NI * 0.3 / 255;

	#ifndef PERBIOME_CLOUDS_COLOR
	vec3 vcSun = CalcSunColor(vcMorning, vcDay , vcEvening);
	vec3 vcDownSun = CalcSunColor(vcDownMorning, vcDownDay, vcDownEvening);
	#else
	vec3 vcSun = CalcSunColor(vcMorning, vcDay * getBiomeColor(vcDownDay), vcEvening);
	vec3 vcDownSun = CalcSunColor(vcDownMorning, vcDownDay * getBiomeColor(vcDownDay), vcDownEvening);
	#endif

	vec3 vcloudsCol     = CalcLightColor(vcSun, vcNight, weatherCol.rgb * 0.4);
	vec3 vcloudsDownCol = CalcLightColor(vcDownSun, vcDownNight, weatherCol.rgb * 0.4);



	//Here we begin to march
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	vec2 alpha = vec2(0.0);

	float depth = GetLinearDepth2(pixeldepth1);
	float maxDist = 256.0 * VCLOUDS_RANGE;
	float minDist = 0.01 + (dither * VCLOUDS_QUALITY);

	for (minDist; minDist < maxDist; minDist += VCLOUDS_QUALITY) {
		if (depth < minDist){
			break;
		}

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.xy);

		if (length(wpos.xz) < maxDist && depth > minDist){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float vh = getHeightNoise((wpos.xz + cameraPosition.xz + vec2(frametime * VCLOUDS_SPEED, 0.0)) * 0.01);
			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, -vh * 24.0, 0.0);

			float noise = getCloudSample(wpos.xyz);
				  noise = clamp(noise, 1.00, noise * 2.00);

			vec4 cloudsColor = vec4(mix(vcloudsCol * vcloudsCol * 2.0, vcloudsDownCol, noise), noise);
			cloudsColor.rgb *= cloudsColor.a;
			finalColor += cloudsColor * (1.0 - finalColor.a);
		}
	}

	color = mix(color, finalColor.rgb, finalColor.a);
}