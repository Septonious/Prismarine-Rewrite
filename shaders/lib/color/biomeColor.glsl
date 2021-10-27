#ifdef OVERWORLD
vec3 fogcolorMorning    = vec3(FOGCOLOR_MR,   FOGCOLOR_MG,   FOGCOLOR_MB)   * FOGCOLOR_MI / 255.0;
vec3 fogcolorDay        = vec3(FOGCOLOR_DR,   FOGCOLOR_DG,   FOGCOLOR_DB)   * FOGCOLOR_DI / 255.0;
vec3 fogcolorEvening    = vec3(FOGCOLOR_ER,   FOGCOLOR_EG,   FOGCOLOR_EB)   * FOGCOLOR_EI / 255.0;
vec3 fogcolorNight      = vec3(FOGCOLOR_NR,   FOGCOLOR_NG,   FOGCOLOR_NB)   * FOGCOLOR_NI * 0.3 / 255.0;

vec3 fogcolorSun    = CalcSunColor(fogcolorMorning, fogcolorDay, fogcolorEvening);
vec4 fogColorC    	= vec4(CalcLightColor(fogcolorSun, fogcolorNight, weatherCol.rgb), 1);

#if FOG_COLOR_MODE == 2 || defined PERBIOME_LIGHTSHAFTS
vec3 getBiomeColor(vec3 mainCol){
	vec4 fogCold     = vec4(vec3(BIOMECOLOR_CR, BIOMECOLOR_CG, BIOMECOLOR_CB) / 255.0, 1.0) * BIOMECOLOR_CI;
	vec4 fogDesert   = vec4(vec3(BIOMECOLOR_DR, BIOMECOLOR_DG, BIOMECOLOR_DB) / 255.0, 1.0) * BIOMECOLOR_DI;
	vec4 fogSwamp    = vec4(vec3(BIOMECOLOR_SR, BIOMECOLOR_SG, BIOMECOLOR_SB) / 255.0, 1.0) * BIOMECOLOR_SI;
	vec4 fogMushroom = vec4(vec3(BIOMECOLOR_MR, BIOMECOLOR_MG, BIOMECOLOR_MB) / 255.0, 1.0) * BIOMECOLOR_MI;
	vec4 fogSavanna  = vec4(vec3(BIOMECOLOR_VR, BIOMECOLOR_VG, BIOMECOLOR_VB) / 255.0, 1.0) * BIOMECOLOR_VI;
	vec4 fogForest   = vec4(vec3(BIOMECOLOR_FR, BIOMECOLOR_FG, BIOMECOLOR_FB) / 255.0, 1.0) * BIOMECOLOR_FI;
	vec4 fogTaiga    = vec4(vec3(BIOMECOLOR_TR, BIOMECOLOR_TG, BIOMECOLOR_TB) / 255.0, 1.0) * BIOMECOLOR_TI;
	vec4 fogJungle   = vec4(vec3(BIOMECOLOR_JR, BIOMECOLOR_JG, BIOMECOLOR_JB) / 255.0, 1.0) * BIOMECOLOR_JI;

	float fogWeight = isCold + isDesert + isMesa + isSwamp + isMushroom + isSavanna + isForest + isJungle + isTaiga;

	vec4 biomeFogCol = mix(
		vec4(mainCol, 1.0),
		(
			fogCold  * isCold  + fogDesert * isDesert + fogSavanna * isMesa    +
			fogSwamp * isSwamp + fogMushroom * isMushroom + fogSavanna  * isSavanna +
			fogForest * isForest + fogJungle * isJungle + fogTaiga * isTaiga
		) / max(fogWeight, 0.0001),
		fogWeight
	);

	return biomeFogCol.rgb;
}

#endif

#endif