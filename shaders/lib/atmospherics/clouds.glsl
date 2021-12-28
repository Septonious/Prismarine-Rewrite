#include "/lib/color/auroraColor.glsl"

#if defined PLANAR_CLOUDS && defined OVERWORLD
vec3 vcMorning    = vec3(VCLOUD_MR,   VCLOUD_MG,   VCLOUD_MB)   * VCLOUD_MI / 255;
vec3 vcDay        = vec3(VCLOUD_DR,   VCLOUD_DG,   VCLOUD_DB)   * VCLOUD_DI / 255;
vec3 vcEvening    = vec3(VCLOUD_ER,   VCLOUD_EG,   VCLOUD_EB)   * VCLOUD_EI / 255;
vec3 vcNight      = vec3(VCLOUD_NR,   VCLOUD_NG,   VCLOUD_NB)   * VCLOUD_NI * 0.3 / 255;

vec3 vcDownMorning    = vec3(VCLOUDDOWN_MR,   VCLOUDDOWN_MG,   VCLOUDDOWN_MB)   * VCLOUDDOWN_MI / 255;
vec3 vcDownDay        = vec3(VCLOUDDOWN_DR,   VCLOUDDOWN_DG,   VCLOUDDOWN_DB)   * VCLOUDDOWN_DI / 255;
vec3 vcDownEvening    = vec3(VCLOUDDOWN_ER,   VCLOUDDOWN_EG,   VCLOUDDOWN_EB)   * VCLOUDDOWN_EI / 255;
vec3 vcDownNight      = vec3(VCLOUDDOWN_NR,   VCLOUDDOWN_NG,   VCLOUDDOWN_NB)   * VCLOUDDOWN_NI / 255;

#ifdef PERBIOME_CLOUDS_COLOR
vec3 vcSun = CalcSunColor(vcMorning, vcDay * getBiomeColor(vcDay), vcEvening);
vec3 vcDownSun = CalcSunColor(vcDownMorning, vcDownDay * getBiomeColor(vcDownDay), vcDownEvening);
#else
vec3 vcSun = CalcSunColor(vcMorning, vcDay, vcEvening);
vec3 vcDownSun = CalcSunColor(vcDownMorning, vcDownDay, vcDownEvening);
#endif

vec3 vcloudsCol     = CalcLightColor(vcSun, vcNight, weatherCol.rgb * 0.4);
vec3 vcloudsDownCol = CalcLightColor(vcDownSun, vcDownNight, weatherCol.rgb * 0.4);

float getCloudSample(vec2 coord, float VoU, float coverage){
	coord = floor(coord * 5.0);

	float noise = texture2D(noisetex, coord * 1.0).x;
		  noise+= texture2D(noisetex, coord * 0.50).x * 2.0;
		  noise+= texture2D(noisetex, coord * 0.25).x * 3.0;
		  noise+= texture2D(noisetex, coord * 0.125).x * 4.0;
		  noise+= texture2D(noisetex, coord * 0.0625).x * 5.0;

	float noiseFade = clamp(sqrt(VoU * 8.0), 0.0, 1.0);
	float noiseCoverage = (coverage * coverage) + CLOUD_AMOUNT;
	float multiplier = 1.0 + 0.50 * rainStrength;

	return max(noise * noiseFade - noiseCoverage, 0.0) * multiplier;
}

vec4 DrawCloud(vec3 viewPos, float dither, vec3 lightCol, vec3 ambientCol){
	float VoU = dot(normalize(viewPos), upVec);
	float VoL = dot(normalize(viewPos), lightVec);

	float cloud = 0.0;
	float cloudGradient = 0.0;
	float gradientMix = dither * 0.1;
	float colorMultiplier = CLOUD_BRIGHTNESS * (0.5 - 0.25 * (1.0 - sunVisibility) * (1.0 - rainStrength * 0.50)) * 2.0;
	float scattering = pow(VoL * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 6.0);

	float cloudHeightFactor = max(1.15 - 0.0025 * cameraPosition.y, 0.0);
	float cloudHeight = CLOUD_HEIGHT * cloudHeightFactor * cloudHeightFactor;

	vec3 cloudColor = vec3(0.0);

	vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
	for(int i = 0; i < 10; i++) {
		vec2 planeCoord = wpos.xz * ((cloudHeight + (i + dither) * 4.0) / wpos.y) * 0.02;
		vec2 coord = cameraPosition.xz * 0.001 + planeCoord + vec2(frametime * 0.0025, 0.0);

		float coverage = float(i - 2.5 + dither) * 0.6;
		float noise = getCloudSample(coord, VoU, coverage) * CLOUD_AMOUNT;
			  noise = noise / pow(pow(noise, 2.5) + 1.0, 0.4);

		cloudGradient = mix(
			cloudGradient,
			mix(gradientMix * gradientMix, 1.0 - noise, 0.25),
			noise * (1.0 - cloud * cloud)
		);
		cloud = mix(cloud, 1.0, noise);
		gradientMix += 0.15;
	}
	cloudColor = mix(
		vcloudsDownCol * 0.5,
		vcloudsCol * (1.25 + scattering),
		cloudGradient * cloud
	);
	cloud *= sqrt(sqrt(clamp(VoU * 8.0 - 1.0, 0.0, 1.0)));

	return vec4(cloudColor * colorMultiplier, cloud * cloud * CLOUD_OPACITY);
}
#endif

float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

void DrawStars(inout vec3 color, vec3 viewPos) {
	vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos, 1.0));
	vec3 planeCoord = wpos / (wpos.y + length(wpos.xz));
	vec2 wind = vec2(frametime, 0.0);
	vec2 coord = planeCoord.xz * 0.4 + cameraPosition.xz * 0.0001 + wind * 0.00125;
	coord = floor(coord * 1024.0) / 1024.0;
	
	float VoU = clamp(dot(normalize(viewPos), normalize(upVec)), 0.0, 1.0);
	float multiplier = sqrt(sqrt(VoU)) * 5.0 * (1.0 - rainStrength);
	
	float star = 1.25 * STARS_AMOUNT;
	if (VoU > 0.0) {
		star *= GetNoise(coord.xy);
		star *= GetNoise(coord.xy + 0.10);
		star *= GetNoise(coord.xy + 0.23);
	}
	star = clamp(star - 0.7125, 0.0, 1.0) * multiplier;
	
	star *= 0.5 * STARS_BRIGHTNESS;

	#ifdef DAY_STARS
	color += star * vec3(0.75, 0.85, 1.00);
	#else
	if (moonVisibility > 0.0) color += star * pow(vec3(1.75, 1.85, 2.00), vec3(0.8));
	#endif

	#ifdef END
	color += star * vec3(1.15, 0.85, 1.00) * 100.0 * endCol.rgb;
	#endif
}

void DrawBigStars(inout vec3 color, vec3 viewPos) {
	vec3 wpos = vec3(gbufferModelViewInverse * vec4(viewPos, 1.0));
	vec3 planeCoord = wpos / (wpos.y + length(wpos.xz));
	vec2 wind = vec2(frametime, 0.0);
	vec2 coord = planeCoord.xz * 1.2 + cameraPosition.xz * 0.0001 + wind * 0.00125;
	coord = floor(coord * 1024.0) / 1024.0;
	
	float VoU = clamp(dot(normalize(viewPos), normalize(upVec)), 0.0, 1.0);
	float multiplier = sqrt(sqrt(VoU)) * 3.0 * (1.0 - rainStrength);
	
	float star = 1.25 * STARS_AMOUNT;
	if (VoU > 0.0) {
		star *= GetNoise(coord.xy);
		star *= GetNoise(coord.xy + 0.10);
		star *= GetNoise(coord.xy + 0.20);
	}
	star = clamp(star - 0.7125, 0.0, 1.0) * multiplier;
		
	star *= 0.5 * STARS_BRIGHTNESS;

	#ifdef DAY_STARS
	color += star * vec3(0.75, 0.85, 1.00);
	#else
	if (moonVisibility > 0.0) color += star * vec3(0.75, 0.85, 1.00);
	#endif

	#ifdef END
	color += star * vec3(1.15, 0.85, 1.00) * 128.0 * endCol.rgb;
	#endif
}

#ifdef AURORA
float AuroraSample(vec2 coord, vec2 wind, float VoU) {
	float noise = texture2D(noisetex, coord * 0.12500 + wind * 0.25).b * 0.5;
		  noise+= texture2D(noisetex, coord * 0.06250 + wind * 0.15).b * 1.0;
		  noise+= texture2D(noisetex, coord * 0.03125 + wind * 0.05).b * 2.0;
		  noise+= texture2D(noisetex, coord * 0.01575 + wind * 0.05).b * 3.0;

	noise = max(1.0 - 4.0 * (0.5 * VoU + 0.5) * abs(noise - 3.0), 0.0);

	return noise;
}

vec3 DrawAurora(vec3 viewPos, float dither, int samples) {
	float sampleStep = 1.0 / samples;
	float currentStep = dither * sampleStep;

	float VoU = dot(normalize(viewPos), upVec);

	float visibility = moonVisibility * (1.0 - rainStrength);

	#ifdef WEATHER_PERBIOME
	visibility *= isCold * isCold;
	#endif

	vec2 wind = vec2(
		frametime * 0.0001,
		sin(frametime * 0.05) * 0.00025
	);

	vec3 aurora = vec3(0.0);

	if (VoU > 0.0 && visibility > 0.0) {
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < samples; i++) {
			vec3 planeCoord = wpos * ((2.0 + currentStep * 6.0) / wpos.y) * 0.02;
			vec2 coord = cameraPosition.xz * 0.00004 + planeCoord.xz;

			float noise = AuroraSample(coord, wind, VoU);
			
			if (noise > 0.0) {
				noise *= texture2D(noisetex, coord * 0.125 + wind * 0.25).b;
				noise *= 0.5 * texture2D(noisetex, coord + wind * 16.0).b + 0.75;
				noise = noise * noise * 3.0 * sampleStep;
				noise *= max(sqrt(1.0 - length(planeCoord.xz) * 3.75), 0.0);

				vec3 auroraColor = mix(auroraLowCol, auroraHighCol, pow(currentStep, 0.4));
				aurora += noise * auroraColor * exp2(-6.0 * i * sampleStep);
			}
			currentStep += sampleStep;
		}
	}

	return aurora * visibility;
}
#endif

#if (defined OVERWORLD && NIGHT_SKY_MODE == 1) || (defined END && END_SKY == 1)
float nebulaSample(vec2 coord, vec2 wind, float VoU) {
	#ifdef OVERWORLD
	float noise = texture2D(noisetex, coord * 1.0000 - wind * 0.25).b * -6.0;
		  noise+= texture2D(noisetex, coord * 0.5000 + wind * 0.20).b * 2.0;
		  noise+= texture2D(noisetex, coord * 0.2500 - wind * 0.15).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.1250 + wind * 0.10).b * -4.0;	
		  noise+= texture2D(noisetex, coord * 0.0625 - wind * 0.05).b * 6.0;
	#else
	float noise = texture2D(noisetex, coord * 2.0000  + wind * 0.30).b;
		  noise+= texture2D(noisetex, coord * 1.0000  - wind * 0.25).b;
		  noise+= texture2D(noisetex, coord * 0.5000  + wind * 0.20).b;
		  noise+= texture2D(noisetex, coord * 0.2500  - wind * 0.15).b;
		  noise+= texture2D(noisetex, coord * 0.1250  + wind * 0.10).b;	
		  noise+= texture2D(noisetex, coord * 0.0625  - wind * 0.05).b;
		  noise+= texture2D(noisetex, coord * 0.03125).b;
	#endif
	noise *= NEBULA_AMOUNT;

	#ifdef OVERWORLD
	noise *= 2.0;
	#endif
	
	noise = max(1.0 - 2.0 * (0.5 * VoU + 0.5) * abs(noise - 3.5), 0.0);

	return noise;
}

#ifdef END
float InterleavedGradientNoiseVL() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	#ifdef TAA
	n = fract(n + frameCounter / 32.0);
	#endif
	return n;
}
#endif

vec3 DrawRift(vec3 viewPos, float dither, int samples, float nebulaType) {
	#ifdef END
	dither = InterleavedGradientNoiseVL();
	#endif

	dither *= NEBULA_DITHERING_STRENGTH;

	float auroraVisibility = 0.0;
	float visFactor = 1.0;

	#ifdef NEBULA_AURORA_CHECK
	#if defined AURORA && defined WEATHER_PERBIOME && defined OVERWORLD
	auroraVisibility = isCold * isCold;
	#endif
	#endif

	#ifdef OVERWORLD
	visFactor = (moonVisibility - rainStrength) * (moonVisibility - auroraVisibility) * (1 - auroraVisibility);
	#endif

	#ifdef END
	float VoU = abs(dot(normalize(viewPos.xyz), upVec));
	#else
	float VoU = dot(normalize(viewPos.xyz), upVec);
	#endif

	float sampleStep = 1.0 / samples;
	float currentStep = dither * sampleStep;

	vec2 wind = vec2(
		frametime * NEBULA_SPEED * 0.000125,
		sin(frametime * NEBULA_SPEED * 0.05) * 0.00125
	);

	vec3 nebula = vec3(0.0);
	vec3 nebulaColor = vec3(0.0);

	#ifdef END
	if (visFactor > 0){
	#else
	if (visFactor > 0 && VoU > 0){
	#endif
		vec3 wpos = normalize((gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz);
		for(int i = 0; i < samples; i++) {
			#ifdef END
			vec3 planeCoord = wpos * (16.0 + currentStep * -8.0) * 0.001 * NEBULA_STRETCHING;
			#else
			vec3 planeCoord = wpos * ((6.0 + currentStep * -2.0) / wpos.y) * 0.0025 * NEBULA_STRETCHING;
			#endif
			vec2 coord = (cameraPosition.xz * 0.0000225 * NEBULA_OFFSET_FACTOR + planeCoord.xz);

			#ifdef NETHER
			coord = cameraPosition.xz * 0.000025 + planeCoord.xz;
			#endif

			if (nebulaType == 0){
				#ifdef END
				coord += vec2(coord.y, -coord.x) * 1.00 * NEBULA_DISTORTION;
				#endif

				coord += cos(mix(vec2(cos(currentStep * 1), sin(currentStep * 2.00)), vec2(cos(currentStep * 3.0), sin(currentStep * 4.00)), currentStep) * 0.005);
				coord += sin(mix(vec2(cos(currentStep * 2), sin(currentStep * 2.50)), vec2(cos(currentStep * 3.0), sin(currentStep * 3.50)), currentStep) * 0.010);
				coord += cos(mix(vec2(cos(currentStep * 3), sin(currentStep * 3.75)), vec2(cos(currentStep * 4.5), sin(currentStep * 5.25)), currentStep) * 0.015);
			}else{
				#ifdef END
				coord += vec2(coord.y, -coord.x) * 2.00 * NEBULA_DISTORTION;
				#endif
				
				coord += cos(mix(vec2(cos(currentStep * 0.50), sin(currentStep * 1.00)), vec2(cos(currentStep * 1.50), sin(currentStep * 2.00)), currentStep) * 0.020);
				coord += sin(mix(vec2(cos(currentStep * 1.00), sin(currentStep * 2.00)), vec2(cos(currentStep * 3.00), sin(currentStep * 4.00)), currentStep) * 0.015);
				coord += cos(mix(vec2(cos(currentStep * 1.50), sin(currentStep * 3.00)), vec2(cos(currentStep * 4.50), sin(currentStep * 6.00)), currentStep) * 0.010);
			}

			float noise = nebulaSample(coord, wind, VoU);

			#if defined NEBULA_STARS && defined END
			vec3 planeCoordstar = wpos / (wpos.y + length(wpos.xz));
			vec2 starcoord = planeCoordstar.xz * 0.4 + cameraPosition.xz * 0.0001 + wind * 0.00125;
			starcoord = floor(starcoord * 1024.0) / 1024.0;
			
			float multiplier = sqrt(sqrt(VoU)) * (1.0 - rainStrength) * STARS_AMOUNT;
			
			float star = 1.0;

			if (VoU > 0.0) {
				star *= GetNoise(starcoord.xy);
				star *= GetNoise(starcoord.xy + 0.10);
				star *= GetNoise(starcoord.xy + 0.23);
			}

			star = clamp(star - 0.7125, 0.0, 1.0) * multiplier * 2.0;
			star * vec3(0.75, 0.85, 1.00);
			star *= STARS_BRIGHTNESS * 128.0;
			#endif
			
			if (noise > 0.0) {
				noise *= texture2D(noisetex, coord * 0.25 + wind * 0.25).b;
				noise *= 1.0 * texture2D(noisetex, coord + wind * 16.0).b + 0.75;
				noise = noise * noise * 4.0 * sampleStep;
				noise *= max(sqrt(1.0 - length(planeCoord.xz) * 2.5), 0.0);
				if (nebulaType == 0){
					#if defined END
					nebulaColor = mix(endCol.rgb, endCol.rgb * 1.25, pow(currentStep, 0.4));
					#elif defined OVERWORLD
					nebulaColor = mix(nebulaLowCol, nebulaHighCol, pow(currentStep, 0.4));
					#elif defined NETHER
					nebulaColor = mix(netherCol.rgb, netherCol.rgb, pow(currentStep, 0.4)) * 0.4;
					#endif
				}else{
					#if defined END
					nebulaColor = mix(vec3(endCol.r * 1.5, endCol.g, endCol.b) * 0.75, vec3(endCol.r * 1.75, endCol.g, endCol.b), pow(currentStep, 0.4));
					#elif defined OVERWORLD
					nebulaColor = mix(secondnebulaLowCol, secondnebulaHighCol, pow(currentStep, 0.4));
					#elif defined NETHER
					nebulaColor = mix(netherCol.rgb, netherCol.rgb, pow(currentStep, 0.4));
					#endif
				}
				#if defined NEBULA_STARS && defined END
				nebulaColor += star;
				#endif

				#ifdef NEBULA_STARS
				#endif

				nebula += noise * nebulaColor * exp2(-4.0 * i * sampleStep);
			}
			currentStep += sampleStep;
		}
	}

	return nebula * NEBULA_BRIGHTNESS * visFactor;
}
#endif