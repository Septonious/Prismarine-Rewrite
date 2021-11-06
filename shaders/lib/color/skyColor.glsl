#ifdef SKY_VANILLA
uniform vec3 skyColor;
uniform vec3 fogColor;

vec3 skyCol = pow(skyColor, vec3(2.2)) * BASESKY_DI;
vec3 fogCol = pow(fogColor, vec3(2.2)) * BASESKY_DI;
#else
vec3 skyMorning    = vec3(BASESKY_MR,   BASESKY_MG,   BASESKY_MB)   * BASESKY_MI / 255.0;
vec3 skyDay        = vec3(BASESKY_DR,   BASESKY_DG,   BASESKY_DB)   * BASESKY_DI / 255.0;
vec3 skyEvening    = vec3(BASESKY_ER,   BASESKY_EG,   BASESKY_EB)   * BASESKY_EI / 255.0;
vec3 skyNight      = vec3(BASESKY_NR,   BASESKY_NG,   BASESKY_NB)   * BASESKY_NI * 0.3 / 255.0;
#if SKY_COLOR_MODE == 1
vec3 getBiomeskyColor(){
	vec3 skyDesert   = vec3(BIOMECOLOR_DR, BIOMECOLOR_DG, BIOMECOLOR_DB) / 128.0 * BIOMECOLOR_DI;
	vec3 skySwamp    = vec3(BIOMECOLOR_SR, BIOMECOLOR_SG, BIOMECOLOR_SB) / 128.0 * BIOMECOLOR_SI;
	vec3 skyMushroom = vec3(BIOMECOLOR_MR, BIOMECOLOR_MG, BIOMECOLOR_MB) / 128.0 * BIOMECOLOR_MI;
	vec3 skySavanna  = vec3(BIOMECOLOR_VR, BIOMECOLOR_VG, BIOMECOLOR_VB) / 128.0 * BIOMECOLOR_VI;
	vec3 skyForest   = vec3(BIOMECOLOR_FR, BIOMECOLOR_FG, BIOMECOLOR_FB) / 128.0 * BIOMECOLOR_FI;
	vec3 skyTaiga    = vec3(BIOMECOLOR_TR, BIOMECOLOR_TG, BIOMECOLOR_TB) / 128.0 * BIOMECOLOR_TI;
	vec3 skyJungle   = vec3(BIOMECOLOR_JR, BIOMECOLOR_JG, BIOMECOLOR_JB) / 128.0 * BIOMECOLOR_JI;

	float skyWeight = isDesert + isMesa + isSwamp + isMushroom + isSavanna + isForest + isJungle + isTaiga;

	vec3 biomeskyCol = mix(
		skyDay,
		(
			skyDesert * isDesert  +  skySavanna * isMesa    +
			skySwamp * isSwamp  +  skyMushroom * isMushroom  +  skySavanna * isSavanna +
			skyForest * isForest  +  skyJungle * isJungle  +  skyTaiga * isTaiga
		) / max(skyWeight, 0.0001),
		skyWeight
	);
	return biomeskyCol.rgb;
}
vec3 skyColSqrt = CalcLightColor(CalcSunColor(skyMorning, getBiomeskyColor(), skyEvening), skyNight, vec3(1.0));
#else
vec3 skyColSqrt = CalcLightColor(CalcSunColor(skyMorning, skyDay, skyEvening), skyNight, vec3(1.0));
#endif
vec3 skyCol = skyColSqrt * skyColSqrt;
vec3 fogCol = skyColSqrt * skyColSqrt;
#endif