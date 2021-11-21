#ifdef OVERWORLD
vec3 fogcolorMorning0    = vec3(FOGCOLOR_MR,   FOGCOLOR_MG,   FOGCOLOR_MB)   * FOGCOLOR_MI / 255.0;
vec3 fogcolorDay0        = vec3(FOGCOLOR_DR,   FOGCOLOR_DG,   FOGCOLOR_DB)   * FOGCOLOR_DI / 255.0;
vec3 fogcolorEvening0    = vec3(FOGCOLOR_ER,   FOGCOLOR_EG,   FOGCOLOR_EB)   * FOGCOLOR_EI / 255.0;
vec3 fogcolorNight0      = vec3(FOGCOLOR_NR,   FOGCOLOR_NG,   FOGCOLOR_NB)   * FOGCOLOR_NI * 0.3 / 255.0;

vec3 fogcolorSun0    = CalcSunColor(fogcolorMorning0, fogcolorDay0, fogcolorEvening0);
vec3 fogColorC0    	= CalcLightColor(fogcolorSun0, fogcolorNight0, weatherCol.rgb);
#endif

#ifdef NETHER_SMOKE
#endif

#ifdef VOLUMETRIC_FOG
#endif

vec4 getVolumetricFog(float pixeldepth0, float pixeldepth1, vec4 color, float dither, vec3 viewPos, float visibility) {
    dither = InterleavedGradientNoiseVL();
	float maxDist = 512;
	float depth0 = GetLinearDepth2(pixeldepth0);
	float depth1 = GetLinearDepth2(pixeldepth1);
	if (isEyeInWater == 1) visibility = 0;

    #ifdef NETHER
    visibility = 1;
    #endif

	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
	vec3 nViewPos = normalize(viewPos.xyz);

	vec4 vf = vec4(0.0);
    vec4 wpos = vec4(0.0);

    if (visibility > 0){
		for(int i = 0; i < LIGHTSHAFT_SAMPLES; i++) {
			float minDist = (i + dither) * LIGHTSHAFT_MIN_DISTANCE; 

			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

            if (length(wpos.xz) < maxDist && depth1 > minDist){

                float vh = getHeightNoise((wpos.xz + cameraPosition.xz) * 0.025);

                #ifdef WORLD_CURVATURE
                if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
                else break;
                #endif

                #ifdef NETHER
                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.75, vh * 48, 0.0);
                #else
                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.25, vh * 24, 0.0);
                #endif

                #ifdef NETHER
                float noise = getFogSample(wpos.xyz, 100, 48, 1.25, 1.10);
                #else
                float noise = getFogSample(wpos.xyz, LIGHTSHAFT_HEIGHT, LIGHTSHAFT_VERTICAL_THICKNESS, 0.4, LIGHTSHAFT_HORIZONTAL_THICKNESS);
                #endif

                #ifdef NETHER
                vec4 fogColor = vec4(mix(netherCol.rgb * 0.01, netherCol.rgb * 0.03, noise), noise);
                #else
                vec4 fogColor = vec4(mix(fogColorC0 * 0.1, fogColorC0 * 0.2, noise), noise);
                #endif

                fogColor.rgb *= fogColor.a;
                vf += fogColor * (1.0 - vf.a);
            }
		}
		vf = sqrt(vf * visibility);
    }
	
	return vf;
}

