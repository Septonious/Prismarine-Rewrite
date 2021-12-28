#if (WATER_MODE == 1 || WATER_MODE == 3) && !defined SKY_VANILLA && (!defined NETHER || !defined NETHER_VANILLA)
uniform vec3 fogColor;
#endif

vec4 GetWaterFog(vec3 viewPos) {
    float clampEyeBrightness = clamp(eBS, 0.1, 1.0);
    float clampTimeBrightness = pow(clamp(timeBrightness, 0.1, 1.0), 2.0);
    float fog = length(viewPos) / waterFogRange;
    fog = 1.0 - exp(-3.0 * fog);
    
    #if WATER_MODE == 0 || WATER_MODE == 2
    vec3 waterFogColor = waterColor.rgb * waterColor.rgb * (1.00 - rainStrength * 0.75) * (1.0 + timeBrightness);
    #elif  WATER_MODE == 1 || WATER_MODE == 3
    vec3 waterFogColor = fogColor * fogColor * 0.5;
    #endif

    waterFogColor *= clampEyeBrightness;

    float VoL = dot(normalize(viewPos.xyz), lightVec);
    float scattering = pow(VoL * shadowFade * 0.5 + 0.5, 6.0) * clampEyeBrightness;
    waterFogColor *= (1.0 + scattering + scattering + scattering + scattering + scattering + scattering);
    waterFogColor *= 1.0 - blindFactor;

    #ifdef OVERWORLD
    vec3 waterFogTint = lightCol * shadowFade * (clampTimeBrightness + clampTimeBrightness);
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