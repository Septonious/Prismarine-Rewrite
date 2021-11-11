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
	vec2 flr = floor(pos);
	vec2 frc = fract(pos);
	frc = frc * frc * (3 - 2 * frc);
	
	float noisedl = rand2D(flr);
	float noisedr = rand2D(flr + vec2(1.0, 0.0));
	float noiseul = rand2D(flr + vec2(0.0, 1.0));
	float noiseur = rand2D(flr + vec2(1.0, 1.0));
	float noise = mix(mix(noisedl, noisedr, frc.x),
			          mix(noiseul, noiseur, frc.x), frc.y);
	return noise;
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
		
	float a = texture2D(noisetex, coord1).x;
	float b = texture2D(noisetex, coord2).x;
		
	return mix(a, b, v.y);
}

float getCloudSample(vec3 pos, float height, float verticalThickness, float detail){
	float ymult = pow(abs(height - pos.y) / verticalThickness, VCLOUDS_VERTICAL_THICKNESS);
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);
	float amount = CalcTotalAmount(CalcDayAmount(VCLOUDS_AMOUNT_MORNING, VCLOUDS_AMOUNT_DAY, VCLOUDS_AMOUNT_EVENING), VCLOUDS_AMOUNT_NIGHT) * (1.00 + rainStrength * 0.25);

	float noise = getCloudNoise(pos * detail * 0.500000 - wind * 0.5) * 2.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noise+= getCloudNoise(pos * detail * 0.250000 + wind * 0.4) * 3.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noise+= getCloudNoise(pos * detail * 0.125000 - wind * 0.3) * 5.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noise+= getCloudNoise(pos * detail * 0.062500 + wind * 0.2) * 6.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noise+= getCloudNoise(pos * detail * 0.031250 - wind * 0.1) * 8.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noise+= getCloudNoise(pos * detail * 0.016125) * 9.0 * VCLOUDS_HORIZONTAL_THICKNESS;

	noise = clamp(noise * amount - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec4 getVolumetricCloud(float pixeldepth1, float dither, vec3 color, vec3 sunVec, vec3 viewPos){
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
	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
	vec3 cloudColor = vec3(0.0);
	
	float depth = GetLinearDepth2(pixeldepth1);
	float cloudLighting = 0.0, cloud = 0.0;
	
	float VoL = dot(normalize(viewPos), lightVec);
	float maxDist = 256.0 * VCLOUDS_RANGE;
	float minDist = 0.01 + (dither * 8.0);

	for (minDist; minDist < maxDist; minDist += 8.0) {
		if (depth < minDist){
			break;
		}

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

		if (length(wpos.xz) < maxDist && depth > minDist){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float offset = 48.0;

			float vh = getHeightNoise((wpos.xz + cameraPosition.xz + vec2(frametime * 0.25, 0.0)) * 0.005);
			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, -vh * offset, 0.0);

			float height = VCLOUDS_HEIGHT + (VCLOUDS_HEIGHT_ADJ_FACTOR * timeBrightness);
			float vertThickness = VCLOUDS_VERTICAL_THICKNESS * 2.5 + timeBrightness;

			float noise = getCloudSample(wpos.xyz, height, vertThickness, VCLOUDS_SAMPLES);
			float densityFactor = smoothstep(height - vertThickness * noise, height + vertThickness * noise, wpos.y);
			cloud = max(noise, cloud);

			float halfVoL = VoL * shadowFade * 0.5 + 0.5;
			float halfVoLSqr = halfVoL * halfVoL;
			float noiseLightFactor = (2.0 - 1.5 * VoL * shadowFade) * VCLOUDS_VERTICAL_THICKNESS;
			float sampleLighting = pow(cloud, 1.125 * halfVoLSqr + 0.875) * 0.8 + 0.2;
			sampleLighting *= 1.0 - pow(cloud, noiseLightFactor);

			cloudLighting = clamp(mix(cloudLighting, sampleLighting, densityFactor * (1.0 - cloud * cloud)), 0.1, 1.0);
		}
	}
	if (isEyeInWater == 1) cloud *= cameraPosition.y * 0.0075;
	float scattering = pow(VoL * 0.75 * (2.0 * sunVisibility - 1.0) + 0.25, 8.0);
	cloudColor = mix(
		vcloudsDownCol,
		vcloudsCol * (0.75 + scattering),
		cloudLighting
	);

	cloudColor = mix(vec3(0.0), cloudColor, cloud * cloud);

	return vec4(cloudColor, cloud * cloud);
}