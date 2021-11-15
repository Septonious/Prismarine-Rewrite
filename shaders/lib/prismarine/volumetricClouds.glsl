


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
	
	float noisedl = rand2D(flr);
	float noisedr = rand2D(flr + vec2(1.0, 0.0));
	float noiseul = rand2D(flr + vec2(0.0, 1.0));
	float noiseur = rand2D(flr + vec2(1.0, 1.0));
	float noise = mix(mix(noisedl, noisedr, frc.x),
			          mix(noiseul, noiseur, frc.x), frc.y);
	return noise;
}

float getCloudNoise(vec3 pos) {
	pos /= 16.0;
	pos.xz *= 0.3;

	vec3 u = floor(pos);
	vec3 v = fract(pos);

	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord1 = uv / 64.0;
	vec2 coord2 = uv / 64.0 + 0.25;
		
	float a = texture2D(noisetex, coord1).x;
	float b = texture2D(noisetex, coord2).x;

	return mix(a, b, v.y);
}

float getCloudSample(vec3 pos){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

    float noise  = 0.50000 * getCloudNoise(pos * 0.50000 * VCLOUDS_SAMPLES);
		  noise += 0.25000 * getCloudNoise(pos * 0.25000 * VCLOUDS_SAMPLES);
		  noise += 0.12500 * getCloudNoise(pos * 0.12500 * VCLOUDS_SAMPLES);
		  noise += 0.06250 * getCloudNoise(pos * 0.06250 * VCLOUDS_SAMPLES);
		  noise += 0.03125 * getCloudNoise(pos * 0.03125 * VCLOUDS_SAMPLES);
	
	float ymult = pow(abs(VCLOUDS_HEIGHT - pos.y) / VCLOUDS_VERTICAL_THICKNESS, VCLOUDS_VERTICAL_THICKNESS);
	float amount = CalcTotalAmount(CalcDayAmount(VCLOUDS_AMOUNT_MORNING, VCLOUDS_AMOUNT_DAY, VCLOUDS_AMOUNT_EVENING), VCLOUDS_AMOUNT_NIGHT) * (0.9 + rainStrength * 0.1) * 24;

	noise *= 1.0 - exp(-VCLOUDS_VERTICAL_THICKNESS * noise);
	noise = clamp(noise * amount - (8.0 + 4.0 * ymult), 0.0, 1.0);

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
	vec4 finalColor = vec4(0.0);
	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

	float depth = GetLinearDepth2(pixeldepth1);
	float maxDist = 256.0 * VCLOUDS_RANGE;
	float minDist = 0.01 + (dither * VCLOUDS_QUALITY);

	float VoL = dot(normalize(viewPos), lightVec);
	float scattering = pow(VoL * 0.75 * (2.0 * sunVisibility - 1.0) + 0.25, 4.0);

	for (minDist; minDist < maxDist; minDist += VCLOUDS_QUALITY) {
		if (depth < minDist || finalColor.a > 0.999){
			break;
		}

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

		if (length(wpos.xz) < maxDist && depth > minDist){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float vh = getHeightNoise((wpos.xz + cameraPosition.xz + vec2(frametime * VCLOUDS_SPEED, 0.0)) * 0.01);
			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, -vh * 24.0, 0.0);

			float noise = getCloudSample(wpos.xyz);
			noise = clamp(noise, noise, noise * 0.9);

			vec4 cloudsColor = vec4(mix(vcloudsCol * vcloudsCol * (2.0 + scattering), vcloudsDownCol, noise), noise);
			cloudsColor.w = clamp(cloudsColor.w, 0.75, cloudsColor.w);
			cloudsColor.rgb *= cloudsColor.a;

			finalColor += cloudsColor * (1.0 - finalColor.a);
		}
	}

	return finalColor;
}

/* this noise is from bsl 6.2, dont wanna use it because it looks kinda crong
float getnoise(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float getCloudNoise(vec3 pos){
	pos /= 16.0;
	pos.xz *= 0.5;
	vec3 flr = floor(pos);
	vec3 frc = fract(pos);
	float yadd = 32.0;
	frc = frc*frc*(3.0-2.0*frc);
	
	float noisebdl = getnoise(flr.xz+flr.y*yadd);
	float noisebdr = getnoise(flr.xz+flr.y*yadd+vec2(1.0,0.0));
	float noisebul = getnoise(flr.xz+flr.y*yadd+vec2(0.0,1.0));
	float noisebur = getnoise(flr.xz+flr.y*yadd+vec2(1.0,1.0));
	float noisetdl = getnoise(flr.xz+flr.y*yadd+yadd);
	float noisetdr = getnoise(flr.xz+flr.y*yadd+yadd+vec2(1.0,0.0));
	float noisetul = getnoise(flr.xz+flr.y*yadd+yadd+vec2(0.0,1.0));
	float noisetur = getnoise(flr.xz+flr.y*yadd+yadd+vec2(1.0,1.0));
	float noise= mix(mix(mix(noisebdl,noisebdr,frc.x),mix(noisebul,noisebur,frc.x),frc.z),mix(mix(noisetdl,noisetdr,frc.x),mix(noisetul,noisetur,frc.x),frc.z),frc.y);
	return noise;
}
*/