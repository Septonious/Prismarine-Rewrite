#if (WATER_MODE == 1 || WATER_MODE == 3) && !defined SKY_VANILLA && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos) {
    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-3 * fog);
    
    #if WATER_MODE == 0 || WATER_MODE == 2    
    vec3 waterFogColor = waterColor.rgb * waterColor.rgb * (1.25 - rainStrength);
    #elif  WATER_MODE == 1 || WATER_MODE == 3
    vec3 waterFogColor = fogColor * fogColor * 0.5;
    #endif

    if (isEyeInWater == 1){
        float VoL = dot(normalize(viewPos), lightVec);
        float scattering = pow(VoL * shadowFade * 0.5 + 0.5, 6.0);
        waterFogColor *= (1 + scattering + scattering + scattering + scattering + scattering + scattering);
    }

    if (isEyeInWater == 0) waterFogColor *= eBS;

    waterFogColor *= 1.0 - blindFactor;

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * lightCol * shadowFade * (1.5 + (timeBrightness * 0.5));
    #endif
    #ifdef NETHER
    vec3 waterFogTint = netherCol.rgb;
    #endif
    #ifdef END
    vec3 waterFogTint = endCol.rgb;
    #endif
    waterFogTint = sqrt(waterFogTint * length(waterFogTint));

    return vec4(waterFogColor * waterFogTint, fog);
}