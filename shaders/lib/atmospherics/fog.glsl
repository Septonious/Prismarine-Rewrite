#if (WATER_MODE == 1 || WATER_MODE == 3) && !defined SKY_VANILLA && !defined NETHER
uniform vec3 fogColor;
#endif

#ifdef OVERWORLD
uniform float playerMood;
vec3 fogcolorMorning    = vec3(FOGCOLOR_MR,   FOGCOLOR_MG,   FOGCOLOR_MB)   * FOGCOLOR_MI / 255.0;
vec3 fogcolorDay        = vec3(FOGCOLOR_DR,   FOGCOLOR_DG,   FOGCOLOR_DB)   * FOGCOLOR_DI / 255.0;
vec3 fogcolorEvening    = vec3(FOGCOLOR_ER,   FOGCOLOR_EG,   FOGCOLOR_EB)   * FOGCOLOR_EI / 255.0;
vec3 fogcolorNight      = vec3(FOGCOLOR_NR,   FOGCOLOR_NG,   FOGCOLOR_NB)   * FOGCOLOR_NI * 0.3 / 255.0;

vec3 fogcolorSun    = CalcSunColor(fogcolorMorning, fogcolorDay, fogcolorEvening);
vec3 fogColorC    	= CalcLightColor(fogcolorSun, fogcolorNight, weatherCol.rgb);
#endif

#include "/lib/atmospherics/clouds.glsl"

float mefade0 = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade0 = 1.0 - timeBrightness;

float CalcFogDensity(float morning, float day, float evening) {
	float me = mix(morning, evening, mefade0);
	return mix(me, day, 1.0 - dfade0 * sqrt(dfade0));
}

float CalcDensity(float sun, float night) {
	float c = mix(night, sun, sunVisibility);
	return c * c;
}

#ifdef OVERWORLD
vec3 GetFogColor(vec3 viewPos, float fogType) {
	vec3 nViewPos = normalize(viewPos);
	float lViewPos = length(viewPos) / 64.0;
	lViewPos = 1.0 - exp(-lViewPos * lViewPos);
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	worldPos.xyz /= worldPos.w;
	vec2 pos = (cameraPosition.xz + worldPos.xz);
	float dither = Bayer64(gl_FragCoord.xy);

    float VoU = clamp(dot(nViewPos,  upVec), -1.0, 1.0);
    float VoL = clamp(dot(nViewPos, sunVec), -1.0, 1.0);

	float densitySun = CalcFogDensity(MORNING_FOG_DENSITY, DAY_FOG_DENSITY, EVENING_FOG_DENSITY);
	float density = CalcDensity(densitySun, NIGHT_FOG_DENSITY) * FOG_DENSITY;
	if (fogType == 0) density *= FIRST_LAYER_DENSITY;
	if (fogType == 1) density *= SECOND_LAYER_DENSITY;
	if (isEyeInWater == 1) density *= 0.0;
    float nightDensity = NIGHT_FOG_DENSITY;
    float weatherDensity = WEATHER_FOG_DENSITY;
    float exposure = exp2(timeBrightness * 0.75 - 1.00);
    float nightExposure = exp2(-3.5);

	float baseGradient = exp(-(VoU * 0.5 + 0.5) * 0.5 / density);

	vec3 fog = vec3(0);

        #if FOG_COLOR_MODE == 1
        fog = fogCol * baseGradient / (SKY_I * SKY_I);
        #elif FOG_COLOR_MODE == 0
        fog = GetSkyColor(viewPos, false) * baseGradient / (SKY_I * SKY_I);
        #elif FOG_COLOR_MODE == 2
        fog = getBiomeColor(fogColorC * 2.0) * baseGradient / (SKY_I * SKY_I);
        #endif

	#ifdef TF
	fog = GetSkyColor(viewPos, false) * baseGradient / (SKY_I * SKY_I);
	#endif

	#ifdef COLORED_FOG
		float CLr = texture2D(noisetex, 0.0002 * pos).r;
		float CLg = texture2D(noisetex, 0.0004 * pos).r;
		float CLb = texture2D(noisetex, 0.0008 * pos).r;
		fog = vec3(CLr, CLg, CLb) * vec3(CLr, CLg, CLb);
		fog *= 10;
		fog *= baseGradient;
	#endif
	
    fog = fog / sqrt(fog * fog + 1.0) * exposure * sunVisibility * (SKY_I * SKY_I);

	float sunMix = (VoL * 0.5 + 0.5) * pow(clamp(1.0 - VoU, 0.0, 1.0), 2.0 - sunVisibility) *
                   pow(1.0 - timeBrightness * 0.6, 3.0);
    float horizonMix = pow(1.0 - abs(VoU), 2.5) * 0.125 * (1.0 - timeBrightness * 0.5);
    float lightMix = (1.0 - (1.0 - sunMix) * (1.0 - horizonMix)) * lViewPos;

	vec3 lightFog = vec3(0);

        #if FOG_COLOR_MODE == 1
        lightFog = pow(fogcolorSun * vec3(FOG_R, FOG_G, FOG_B) * FOG_I, vec3(4.0 - sunVisibility)) * baseGradient;
        #elif FOG_COLOR_MODE == 0
        lightFog = pow(GetSkyColor(viewPos, false), vec3(4.0 - sunVisibility)) * baseGradient;
        #elif FOG_COLOR_MODE == 2
        lightFog = pow(getBiomeColor(fogColorC * 2.0), vec3(4.0 - sunVisibility)) * baseGradient;
        #endif

	#ifdef TF
	lightFog = pow(GetSkyColor(viewPos, false) / 2.0, vec3(4.0 - sunVisibility)) * baseGradient;
	#endif

	#ifdef COLORED_FOG
		lightFog = vec3(CLr, CLg, CLb) * vec3(CLr, CLg, CLb);
		lightFog *= 10;
		lightFog *= baseGradient;
	#endif

	lightFog = lightFog / (1.0 + lightFog * rainStrength);

    fog = mix(
        sqrt(fog * (1.0 - lightMix)), 
        sqrt(lightFog), 
        lightMix
    );
    fog *= fog;

    float scattering = pow(VoL * shadowFade * 0.5 + 0.5, 6.0);

	float nightGradient = exp(-(VoU * 0.5 + 0.5) * 0.35 / nightDensity);
    vec3 nightFog = fogcolorNight * fogcolorNight * nightGradient * nightExposure;
    fog = mix(nightFog, fog, sunVisibility * sunVisibility);

    float rainGradient = exp(-(VoU * 0.5 + 0.5) * 0.125 / weatherDensity);
    vec3 weatherFog = weatherCol.rgb * weatherCol.rgb;
    weatherFog *= GetLuminance(ambientCol / (weatherFog)) * (0.2 * sunVisibility + 0.2) * (1 + scattering);
    fog = mix(fog, weatherFog * rainGradient, rainStrength);

	return fog;
}
#endif

void NormalFog(inout vec3 color, vec3 viewPos, float fogType) {
	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos, 1.0);
	worldPos.xyz /= worldPos.w;
	float dither = Bayer64(gl_FragCoord.xy);

	#if DISTANT_FADE > 0
	#if DISTANT_FADE_STYLE == 0
	float fogFactor = length(viewPos);
	#else
	float fogFactor = length(worldPos.xz);
	#endif
	#endif

	#ifdef OVERWORLD
	float densitySun = CalcFogDensity(MORNING_FOG_DENSITY, DAY_FOG_DENSITY, EVENING_FOG_DENSITY);
	float density = CalcDensity(densitySun, NIGHT_FOG_DENSITY) * FOG_DENSITY;
	density *= 1 - playerMood;
	if (fogType == 0) density *= FIRST_LAYER_DENSITY;
	if (fogType == 1) density *= SECOND_LAYER_DENSITY;

	float fog = length(viewPos) * density / 64.0;
	float clearDay = sunVisibility * (1.0 - rainStrength);
	fog *= (0.5 * rainStrength + 1.0) / (4.0 * clearDay + 1.0);
	fog = 1.0 - exp(-2.0 * pow(fog, 0.15 * clearDay + 1.25));

	if (isEyeInWater == 0){
		vec3 pos = worldPos.xyz + cameraPosition.xyz + 1000;
		float height;
		if (fogType == 0){
			height = (pos.y - FOG_FIRST_LAYER_ALTITUDE) * 0.001;
		}else{
			height = (pos.y - FOG_SECOND_LAYER_ALTITUDE) * 0.001;
		}
			height = pow(height, 8);
			height = clamp(height, 0, 1);
		fog *= 1 - height;
	} else {
		fog *= 0.0;
	}

	vec3 fogColor = vec3(0);
	fogColor = GetFogColor(viewPos, fogType);

	#if DISTANT_FADE == 1 || DISTANT_FADE == 3
	if (isEyeInWater != 2.0){
		float vanillaFog = 1.0 - (far - (fogFactor + 20.0)) * 4.0 / ((FOG_DENSITY + isEyeInWater + isEyeInWater) * far);
		vanillaFog = clamp(vanillaFog, 0.0, 1.0);
		if (isEyeInWater == 1) vanillaFog *= 0.0;
	
		if (vanillaFog > 0.0){
			vec3 vanillaFogColor = vec3(0.0);
			vanillaFogColor = GetSkyColor(viewPos, false);
			vanillaFogColor *= (4.0 - 3.0) * (1.0 + nightVision);

			fogColor *= fog;
			
			fog = mix(fog, 1.0, vanillaFog);
			if (fog > 0.0) fogColor = mix(fogColor, vanillaFogColor, vanillaFog) / fog;
		}
	}
	#endif
	#endif

	#ifdef NETHER
	float viewLength = length(viewPos);
	float fog = 2.0 * pow(viewLength * NETHER_FOG_DENSITY / 256.0, 1.5);

	#if DISTANT_FADE == 2 || DISTANT_FADE == 3
	fog += 6.0 * pow(fogFactor * 1.5 / far, 4.0);
	#endif

	fog = 1.0 - exp(-fog);

	vec3 fogColor = netherCol.rgb * 0.04;
	#endif

	#ifdef END
	#if DISTANT_FADE == 2 || DISTANT_FADE == 3
	float fog = length(viewPos) * END_FOG_DENSITY / 128.0;
	fog += 6.0 * pow(fogFactor * 1 / far, 6.0);
	fog = 1.0 - exp(-0.8 * fog * fog);
	vec3 fogColor = endCol.rgb * 0.03;
	#endif
	#endif

	#if (defined OVERWORLD || defined NETHER) || (defined END && (DISTANT_FADE == 2 || DISTANT_FADE == 3))
	color = mix(color, fogColor, fog);
	#endif
}

void BlindFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * (blindFactor * 0.2);
	fog = (1.0 - exp(-6.0 * fog * fog * fog)) * blindFactor;
	color = mix(color, vec3(0.0), fog);
}

vec3 denseFogColor[2] = vec3[2](
	vec3(1.0, 0.3, 0.01),
	vec3(0.1, 0.16, 0.2)
);

void DenseFog(inout vec3 color, vec3 viewPos) {
	float fog = length(viewPos) * 0.5;
	fog = (1.0 - exp(-4.0 * fog * fog * fog));
	color = mix(color, denseFogColor[isEyeInWater - 2], fog);
}

void Fog(inout vec3 color, vec3 viewPos) {
	NormalFog(color, viewPos, 0);
	NormalFog(color, viewPos, 1);
	if (isEyeInWater > 1) DenseFog(color, viewPos);
	if (blindFactor > 0.0) BlindFog(color, viewPos);
}