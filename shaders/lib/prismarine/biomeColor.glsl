#ifdef OVERWORLD
#if FOG_COLOR_MODE == 2 || defined PERBIOME_LIGHTSHAFTS || defined PERBIOME_CLOUDS_COLOR
vec3 getBiomeColor(vec3 mainCol){
	vec4 fogDesert   = vec4(vec3(BIOMECOLOR_DR, BIOMECOLOR_DG, BIOMECOLOR_DB) / 255.0, 1.0) * BIOMECOLOR_DI;
	vec4 fogSwamp    = vec4(vec3(BIOMECOLOR_SR, BIOMECOLOR_SG, BIOMECOLOR_SB) / 255.0, 1.0) * BIOMECOLOR_SI;
	vec4 fogMushroom = vec4(vec3(BIOMECOLOR_MR, BIOMECOLOR_MG, BIOMECOLOR_MB) / 255.0, 1.0) * BIOMECOLOR_MI;
	vec4 fogSavanna  = vec4(vec3(BIOMECOLOR_VR, BIOMECOLOR_VG, BIOMECOLOR_VB) / 255.0, 1.0) * BIOMECOLOR_VI;
	vec4 fogForest   = vec4(vec3(BIOMECOLOR_FR, BIOMECOLOR_FG, BIOMECOLOR_FB) / 255.0, 1.0) * BIOMECOLOR_FI;
	vec4 fogTaiga    = vec4(vec3(BIOMECOLOR_TR, BIOMECOLOR_TG, BIOMECOLOR_TB) / 255.0, 1.0) * BIOMECOLOR_TI;
	vec4 fogJungle   = vec4(vec3(BIOMECOLOR_JR, BIOMECOLOR_JG, BIOMECOLOR_JB) / 255.0, 1.0) * BIOMECOLOR_JI;

	float fogWeight = isDesert + isMesa + isSwamp + isMushroom + isSavanna + isForest + isJungle + isTaiga;

	vec4 biomeFogCol = mix(
		vec4(mainCol, 1.0),
		(
			fogDesert * isDesert + fogSavanna * isMesa    +
			fogSwamp * isSwamp + fogMushroom * isMushroom + fogSavanna  * isSavanna +
			fogForest * isForest + fogJungle * isJungle + fogTaiga * isTaiga
		) / max(fogWeight, 0.0001),
		fogWeight
	);

	return biomeFogCol.rgb;
}

#endif
#endif