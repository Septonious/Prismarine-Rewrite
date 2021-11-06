#ifdef OVERWORLD
vec3 skylightMorning    = vec3(SKYLIGHT_MR,   SKYLIGHT_MG,   SKYLIGHT_MB)   * SKYLIGHT_MI / 255.0;
vec3 skylightDay        = vec3(SKYLIGHT_DR,   SKYLIGHT_DG,   SKYLIGHT_DB)   * SKYLIGHT_DI / 255.0;
vec3 skylightEvening    = vec3(SKYLIGHT_ER,   SKYLIGHT_EG,   SKYLIGHT_EB)   * SKYLIGHT_EI / 255.0;
vec3 skylightNight      = vec3(SKYLIGHT_NR,   SKYLIGHT_NG,   SKYLIGHT_NB)   * SKYLIGHT_NI * 0.3 / 255.0;
vec3 skylightSun       = CalcSunColor(skylightMorning, skylightDay * skylightDay, skylightEvening);

vec3 GetSkyColor(vec3 viewPos, bool isReflection) {
    vec3 nViewPos = normalize(viewPos);

    float VoU = clamp(dot(nViewPos,  upVec), -1.0, 1.0);
    float VoL = clamp(dot(nViewPos, sunVec), -1.0, 1.0);

    float groundDensity = 0.08 * (4.0 - 3.0 * sunVisibility) *
                          (10.0 * rainStrength * rainStrength + 1.0);
    
    float exposure = exp2(CalcDayAmount(SKY_EXPOSURE_M, SKY_EXPOSURE_D, SKY_EXPOSURE_E));
    float nightExposure = exp2(-3.5 + SKY_EXPOSURE_N);
    float weatherExposure = exp2(SKY_EXPOSURE_W);

    float gradientCurve = mix(SKY_HORIZON_F, SKY_HORIZON_N, VoL);

    #ifdef TF
    gradientCurve = mix(SKY_HORIZON_F, SKY_HORIZON_N, VoU);
    #endif

    float baseGradient = exp(-(1.0 - pow(1.0 - max(VoU, 0.0), gradientCurve)) /
                             (CalcDayAmount(SKY_DENSITY_M, SKY_DENSITY_D, SKY_DENSITY_E) + 0.025));

    #ifdef TF
    baseGradient = exp(-(1.0 - pow(1.0 - max(VoU, 0.0), gradientCurve)) / 0.75);
    #endif

    #if SKY_GROUND > 0
    float groundVoU = clamp(-VoU * 1.015 - 0.015, 0.0, 1.0);
    float ground = 1.0 - exp(-groundDensity * SKY_GROUND_I / groundVoU);
    #if SKY_GROUND == 1
    if (!isReflection) ground = 1.0;
    #endif
    #else
    float ground = 1.0;
    #endif

    vec3 weatherSky = weatherCol.rgb * weatherCol.rgb * weatherExposure;

    vec3 sky = skyCol * 2.0 * skyCol * baseGradient;

    #ifdef TF
    sky = mix(tfSkyUp * 0.75, tfSkyUp * tfSkyUp, 0.75) * baseGradient;
    #endif

    #ifndef TF
    #ifdef SKY_VANILLA
    sky = mix(sky, fogCol * baseGradient, pow(1.0 - max(VoU, 0.0), 4.0));
    #endif
    #endif

    sky = sky / sqrt(sky * sky + 1.0) * exposure * sunVisibility * (0.25 + timeBrightness * 0.75);

    float sunMix = (VoL * 0.5 + 0.5) * pow(clamp(1.0 - VoU, 0.0, 1.0), 2.0 - sunVisibility) *
                   pow(1.0 - timeBrightness * 0.75, 3.0);
    
    #ifdef TF
    sunMix = (VoU * 0.5 + 0.5) * pow(clamp(1.0 - VoU, 0.0, 1.0), 2.0 - sunVisibility) *
                   pow(1.0 - timeBrightness * 0.6, 3.0);   
    #endif

    float horizonMix = pow(1.0 - abs(VoU), 1.0) * HORIZON_EXPONENT * (1.0 - timeBrightness * 0.5);
    float lightMix = (1.0 - (1.0 - sunMix) * (1.0 - horizonMix));

    vec3 lightSky = pow(skylightSun, vec3(4.0 - sunVisibility)) * baseGradient;

    #ifdef TF
    lightSky = pow(tfSkyDown, vec3(4.0 - sunVisibility)) * baseGradient;
    #endif

    lightSky = lightSky / (1.0 + lightSky * rainStrength);

    sky = mix(
        sqrt(sky * (1.0 - lightMix)), 
        sqrt(lightSky) * (HORIZON_VERTICAL_EXPONENT - VoU), 
        lightMix
    );

    sky *= sky;

    #ifndef TF
    float nightGradient = exp(-max(VoU, 0.0) / SKY_DENSITY_N);
    vec3 nightSky = skylightNight * skylightNight * nightGradient * nightExposure;
    sky = mix(nightSky, sky, sunVisibility * sunVisibility);

    float rainGradient = exp(-max(VoU, 0.0) / SKY_DENSITY_W);
    weatherSky *= GetLuminance(ambientCol / (weatherSky)) * (0.2 * sunVisibility + 0.2);
    sky = mix(sky, weatherSky * rainGradient, rainStrength);
    #endif

    sky *= ground;

    return sky;
}

#endif