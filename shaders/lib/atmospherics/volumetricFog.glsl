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

#ifdef END_SMOKE
#endif

vec4 getVolumetricFog(float pixeldepth0, float pixeldepth1, vec4 color, float dither, vec3 viewPos, float visibility) {
    dither = InterleavedGradientNoiseVL();

	float maxDist = LIGHTSHAFT_MAX_DISTANCE;
	float depth0 = GetLinearDepth2(pixeldepth0);
	float depth1 = GetLinearDepth2(pixeldepth1);
	visibility = clamp(visibility - isEyeInWater, 0.0, 1.0);

    #if defined NETHER && defined NETHER_SMOKE
    visibility = 1.0;
    #endif

    #if defined END && defined END_SMOKE
    visibility = 1.0;
    #endif

	vec4 vf = vec4(0.0);
    vec4 wpos = vec4(0.0);

    if (visibility > 0){
        #ifdef END
        vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
        vec3 nViewPos = normalize(viewPos.xyz);
        float VoL = dot(nViewPos, lightVec);
        float scatter = pow(VoL * 0.5 * (2.0 * sunVisibility - 1.0) + 0.5, 8.0) * 2.0;
        #endif

        for(int i = 0; i < LIGHTSHAFT_SAMPLES; i++) {
			float minDist = (i + dither) * LIGHTSHAFT_MIN_DISTANCE;

            #ifdef DO_NOT_CLICK
            minDist = 0.0;
            #endif

			wpos = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

            if (length(wpos.xz) < maxDist && depth1 > minDist){

                float vh = getCloudWave((wpos.xz + cameraPosition.xz) * 0.025);

                #ifdef WORLD_CURVATURE
                if (length(wpos.xz) < WORLD_CURVATURE_SIZE) wpos.y += length(wpos.xz) * length(wpos.xyz) / WORLD_CURVATURE_SIZE;
                else break;
                #endif

                #ifdef NETHER
                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.75, vh * 48, 0.0);
                #else
                wpos.xyz += cameraPosition.xyz + vec3(frametime * 0.25, vh * 24, 0.0);
                #endif

                #if defined NETHER
                float noise = getFogSample(wpos.xyz, 80.0, 64.0, 1.25, 1.10);
                #elif defined OVERWORLD
                float noise = getFogSample(wpos.xyz, LIGHTSHAFT_HEIGHT, LIGHTSHAFT_VERTICAL_THICKNESS, 0.75, LIGHTSHAFT_HORIZONTAL_THICKNESS);
                #elif defined END
                float noise = getFogSample(wpos.xyz, 75.0, 64.0, 1.25, 1.25);
                #endif

                #if defined NETHER
                vec4 fogColor = vec4(netherCol.rgb * netherCol.rgb * 0.025, noise);
                #elif defined OVERWORLD
                vec4 fogColor = vec4(mix(fogColorC0 * 0.1, fogColorC0 * 0.2, noise), noise);
                #elif defined END
                vec4 fogColor = vec4(vec3(endCol.r, endCol.g * 0.8, endCol.b) * 0.01 * (1.0 + scatter), noise);
                #endif

                fogColor.rgb *= fogColor.a;
                vf += fogColor * (1.0 - vf.a);
            }
		}
		vf = sqrt(vf * visibility);
    }
	
	return vf;
}

