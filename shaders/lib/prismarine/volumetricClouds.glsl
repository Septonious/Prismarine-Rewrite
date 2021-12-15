


#ifdef VOLUMETRIC_CLOUDS
#endif

float getCloudNoise(vec3 pos){
	#if VCLOUDS_NOISE_MODE == 1
	pos *= 0.50;
	pos.xz *= 0.30;
	#endif

	vec3 u = floor(pos);
	vec3 v = fract(pos);

	v = v * v * (3.0 - 2.0 * v);
	
	#if VCLOUDS_NOISE_MODE == 0
	float noisebdl = rand2D(u.xz + u.y * 32.0);
	float noisebdr = rand2D(u.xz + u.y * 32.0 + vec2(1.0, 0.0));
	float noisebul = rand2D(u.xz + u.y * 32.0 + vec2(0.0, 1.0));
	float noisebur = rand2D(u.xz + u.y * 32.0 + vec2(1.0, 1.0));
	float noisetdl = rand2D(u.xz + u.y * 32.0 + 32.0);
	float noisetdr = rand2D(u.xz + u.y * 32.0 + 32.0 + vec2(1.0, 0.0));
	float noisetul = rand2D(u.xz + u.y * 32.0 + 32.0 + vec2(0.0, 1.0));
	float noisetur = rand2D(u.xz + u.y * 32.0 + 32.0 + vec2(1.0, 1.0));

	float noise = mix(mix(mix(noisebdl, noisebdr, v.x), mix(noisebul, noisebur, v.x), v.z), mix(mix(noisetdl, noisetdr, v.x), mix(noisetul, noisetur, v.x), v.z), v.y);
	return noise;

	#elif VCLOUDS_NOISE_MODE == 1
	vec2 uv = u.xz + v.xz + u.y * 16.0;

	vec2 coord = uv / 64.0;
	float a = texture2DLod(noisetex, coord, 2.0).r;
	float b = texture2DLod(noisetex, coord + 0.25, 2.0).r;
		
	return mix(a, b, v.y);
	#endif
}

float getCloudSample(vec3 pos, float height, float stretching){
	vec3 wind = vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

	float amount = CalcTotalAmount(CalcDayAmount(VCLOUDS_AMOUNT_MORNING, VCLOUDS_AMOUNT_DAY, VCLOUDS_AMOUNT_EVENING), VCLOUDS_AMOUNT_NIGHT) * (0.8 + rainStrength * 0.1);
	
	float noiseA = getCloudNoise(pos / VCLOUDS_SAMPLES * 0.500000 - wind * 0.5) * 2.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.250000 - wind * 0.4) * 3.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.125000 - wind * 0.3) * 4.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.062500 - wind * 0.2) * 5.0 * VCLOUDS_HORIZONTAL_THICKNESS;
		  noiseA+= getCloudNoise(pos / VCLOUDS_SAMPLES * 0.031250 - wind * 0.1) * 6.0 * VCLOUDS_HORIZONTAL_THICKNESS;

	//Sample vertical thickness and height
	float sampleHeight = abs(height - pos.y) / stretching;

	//Shaping
	float noiseB = clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
	float density = pow(smoothstep(height + stretching * noiseB, height - stretching * noiseB, pos.y), 0.25);
	sampleHeight = pow(sampleHeight, 8.0 * (1.5 - density) * (1.5 - density));

	//Output
	return clamp(noiseA * amount - (10.0 + 5.0 * sampleHeight), 0.0, 1.0);
}

void getVolumetricCloud(float pixeldepth1, float pixeldepth0, float dither, inout vec3 color, vec4 translucent, float scattering){
	//Here we set up the color of bottom and upper parts of the clouds
	vec3 vcMorning    = vec3(VCLOUD_MR,   VCLOUD_MG,   VCLOUD_MB)   * VCLOUD_MI / 255;
	vec3 vcDay        = vec3(VCLOUD_DR,   VCLOUD_DG,   VCLOUD_DB)   * VCLOUD_DI / 255;
	vec3 vcEvening    = vec3(VCLOUD_ER,   VCLOUD_EG,   VCLOUD_EB)   * VCLOUD_EI / 255;
	vec3 vcNight      = vec3(VCLOUD_NR,   VCLOUD_NG,   VCLOUD_NB)   * VCLOUD_NI * 0.3 / 255;

	vec3 vcDownMorning    = vec3(VCLOUDDOWN_MR,   VCLOUDDOWN_MG,   VCLOUDDOWN_MB)   * VCLOUDDOWN_MI / 255;
	vec3 vcDownDay        = vec3(VCLOUDDOWN_DR,   VCLOUDDOWN_DG,   VCLOUDDOWN_DB)   * VCLOUDDOWN_DI / 255;
	vec3 vcDownEvening    = vec3(VCLOUDDOWN_ER,   VCLOUDDOWN_EG,   VCLOUDDOWN_EB)   * VCLOUDDOWN_EI / 255;
	vec3 vcDownNight      = vec3(VCLOUDDOWN_NR,   VCLOUDDOWN_NG,   VCLOUDDOWN_NB)   * VCLOUDDOWN_NI * 0.4 / 255;

	#ifndef PERBIOME_CLOUDS_COLOR
	vec3 vcSun = CalcSunColor(vcMorning, vcDay, vcEvening);
	vec3 vcDownSun = CalcSunColor(vcDownMorning, vcDownDay, vcDownEvening);
	#else
	vec3 vcSun = CalcSunColor(vcMorning, vcDay * getBiomeColor(vcDownDay), vcEvening);
	vec3 vcDownSun = CalcSunColor(vcDownMorning, vcDownDay * getBiomeColor(vcDownDay), vcDownEvening);
	#endif

	vec3 vcloudsCol     = CalcLightColor(vcSun, vcNight, weatherCol.rgb * 0.3);
	vec3 vcloudsDownCol = CalcLightColor(vcDownSun, vcDownNight, weatherCol.rgb * 0.3);



	//Here we begin to march
	vec4 wpos = vec4(0.0);
	vec4 finalColor = vec4(0.0);

	float depth0 = GetLinearDepth2(pixeldepth0);
	float depth1 = GetLinearDepth2(pixeldepth1);

	float maxDist = 256.0 * VCLOUDS_RANGE;
	float minDist = 0.01 + (dither * VCLOUDS_QUALITY);

	for (minDist; minDist < maxDist; minDist += VCLOUDS_QUALITY) {
		if (depth1 < minDist){
			break;
		}

		wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.xy);

		if (length(wpos.xz) < maxDist){
			#ifdef WORLD_CURVATURE
			if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
			else break;
			#endif

			float cloudWave = getCloudWave((wpos.xz + cameraPosition.xz + vec2(frametime * VCLOUDS_SPEED, 0.0)) * 0.01);
			wpos.xyz += cameraPosition.xyz + vec3(frametime * VCLOUDS_SPEED, 0.0, 0.0);

			//Cloud noise
			float stretching = VCLOUDS_VERTICAL_THICKNESS;

			#if VCLOUDS_NOISE_MODE == 1
			stretching *= 1.25;
			#endif

			float height = VCLOUDS_HEIGHT * (1.0 + rainStrength * 0.2);
			float noise = getCloudSample(wpos.xyz, height, stretching);

			//This finds the density of cloud noise at different positions
			float density = pow(smoothstep(height + stretching * noise, height - stretching * noise, wpos.y), 0.4);

			//Color calculation and lighting
			vec4 cloudsColor = vec4(mix(vcloudsCol * (1.0 + scattering) * vcloudsCol, vcloudsDownCol, noise * density), noise);
			cloudsColor.a *= 1.0 - isEyeInWater * 0.5;
			cloudsColor.rgb *= cloudsColor.a * VCLOUDS_OPACITY;

			//Translucency blending, works half correct
			if (depth0 < minDist && cameraPosition.y < VCLOUDS_HEIGHT - 10){
				finalColor *= translucent;
			}

			finalColor += cloudsColor * (1.0 - finalColor.a);
		}

	}

	//Output
	color = mix(color, finalColor.rgb, finalColor.a);
}