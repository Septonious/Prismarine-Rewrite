uniform sampler2DShadow shadowtex0;

#ifdef SHADOW_COLOR
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

/*
uniform sampler2D shadowtex0;

#ifdef SHADOW_COLOR
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
#endif
*/

vec2 shadowOffsets[9] = vec2[9](
    vec2( 0.0, 0.0),
    vec2( 0.0, 1.0),
    vec2( 0.7, 0.7),
    vec2( 1.0, 0.0),
    vec2( 0.7,-0.7),
    vec2( 0.0,-1.0),
    vec2(-0.7,-0.7),
    vec2(-1.0, 0.0),
    vec2(-0.7, 0.7)
);

float biasDistribution[10] = float[10](
    0.0, 0.057, 0.118, 0.184, 0.255, 0.333, 0.423, 0.529, 0.667, 1.0
);

/*
float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    float shadow = texture2D(shadowtex,shadowPos.st).x;
    shadow = clamp((shadow-shadowPos.z)*65536.0,0.0,1.0);
    return shadow;
}
*/

vec3 DistortShadow(vec3 worldPos, float distortFactor) {
	worldPos.xy /= distortFactor;
	worldPos.z *= 0.2;
	return worldPos * 0.5 + 0.5;
}

float GetCurvedBias(int i, float dither) {
    return mix(biasDistribution[i], biasDistribution[i+1], dither);
}

vec3 SampleBasicShadow(vec3 shadowPos) {
    float shadow0 = shadow2D(shadowtex0, vec3(shadowPos.st, shadowPos.z)).x;

    vec3 shadowCol = vec3(0.0);
    #ifdef SHADOW_COLOR
    if (shadow0 < 1.0) {
        shadowCol = texture2D(shadowcolor0, shadowPos.st).rgb *
                    shadow2D(shadowtex1, vec3(shadowPos.st, shadowPos.z)).x;
    }
    #endif

    return clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));
}

vec3 SampleFilteredShadow(vec3 shadowPos, float offset, float biasStep) {
    float shadow0 = 0.0;

    #if SSS_QUALITY == 1
    float sz = shadowPos.z;
    float dither = InterleavedGradientNoise();
    #endif
    
    for (int i = 0; i < 9; i++) {
        vec2 shadowOffset = shadowOffsets[i] * offset;
        shadow0 += shadow2D(shadowtex0, vec3(shadowPos.st + shadowOffset, shadowPos.z)).x;
        #if SSS_QUALITY == 1
        if (biasStep > 0.0) shadowPos.z = sz - biasStep * GetCurvedBias(i, dither);
        #endif
    }
    shadow0 /= 9.0;

    vec3 shadowCol = vec3(0.0);
    #ifdef SHADOW_COLOR
    if (shadow0 < 0.999) {
        for (int i = 0; i < 9; i++) {
            vec2 shadowOffset = shadowOffsets[i] * offset;
            shadowCol += texture2D(shadowcolor0, shadowPos.st + shadowOffset).rgb *
                         shadow2D(shadowtex1, vec3(shadowPos.st + shadowOffset, shadowPos.z)).x;
            #if SSS_QUALITY == 1
            if (biasStep > 0.0) shadowPos.z = sz - biasStep * GetCurvedBias(i, dither);
            #endif
        }
        shadowCol /= 9.0;
    }
    #endif

    return clamp(shadowCol * (1.0 - shadow0) + shadow0, vec3(0.0), vec3(1.0));
}

vec3 GetShadow(vec3 worldPos, float NoL, float subsurface, float skylight) {
    #if SHADOW_PIXEL > 0
    worldPos = (floor((worldPos + cameraPosition) * SHADOW_PIXEL + 0.01) + 0.5) /
               SHADOW_PIXEL - cameraPosition;
    #endif
    
    vec3 shadowPos = ToShadow(worldPos);

    float distb = sqrt(dot(shadowPos.xy, shadowPos.xy));
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
    shadowPos = DistortShadow(shadowPos, distortFactor);

    bool doShadow = shadowPos.x > 0.0 && shadowPos.x < 1.0 &&
                    shadowPos.y > 0.0 && shadowPos.y < 1.0;

    #ifdef OVERWORLD
    doShadow = doShadow && skylight > 0.001;
    #endif

    if (!doShadow) return vec3(skylight);

    float biasFactor = sqrt(1.0 - NoL * NoL) / NoL;
    float distortBias = distortFactor * shadowDistance / 256.0;
    distortBias *= 8.0 * distortBias;
    float distanceBias = sqrt(dot(worldPos.xyz, worldPos.xyz)) * 0.005;
    
    float bias = (distortBias * biasFactor + distanceBias + 0.05) / shadowMapResolution;
    float offset = 1.0 / shadowMapResolution;
    
    if (subsurface > 0.0) {
        bias = 0.0002;
        #if defined SHADOW_FILTER && SSS_QUALITY == 1
        bias *= mix(subsurface, 1.0, NoL);
        #endif
        offset = 0.0007;
    }
    float biasStep = 0.001 * subsurface * (1.0 - NoL);
    
    #if SHADOW_PIXEL > 0
    bias += 0.0025 / SHADOW_PIXEL;
    #endif

    shadowPos.z -= bias;

    #ifdef SHADOW_FILTER
    vec3 shadow = SampleFilteredShadow(shadowPos, offset, biasStep);
    #else
    vec3 shadow = SampleBasicShadow(shadowPos);
    #endif

    return shadow;
}