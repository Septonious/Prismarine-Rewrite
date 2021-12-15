#if defined OVERWORLD || defined END
#include "/lib/lighting/shadows.glsl"
#endif

/*
float getSquareSDF(vec2 pos, vec2 size) {
	vec2 r = abs(pos) - size;
    return min(max(r.x, r.y), 0.0) + length(max(r, vec2(0.0)));
}

void addObject(inout float distA, inout vec3 color, float distB, vec3 objectColor) {
    if (distA > distB) {
        distA = distB;
        color = objectColor;
    }
}

void getScene(in vec2 pos, out vec3 color, out float distA) {
	color = vec3(0.0);
    distA = 1e9;
	vec3 objectColor = vec3(1.0, 0.7, 0.3);
    addObject(distA, color, getSquareSDF(pos - vec2(0.0, 0.0), vec2(1.0)), objectColor);

}

void raytrace(vec2 pos, vec2 dir, out vec3 objectColor) {
    for (;;) {
        float distB = 0.0;
        getScene(pos, objectColor, distB);
        if (distB < 1e-3) return;
        if (distB > 1e1) break;
        pos += dir * distB;
    }
    objectColor = vec3(0.0);
}

float getRandomNoise(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

void computeGI(out vec3 color, in float lightmap){
    vec2 coord = (gl_FragCoord.xy - (vec2(viewWidth, viewHeight) * 0.5)) / viewHeight * 6.0;
    vec3 col = vec3(0.0);
    
    for (int i = 0; i < 32; i++) {
        float t = (float(i) + getRandomNoise(coord + float(i))) / 32.0 * 6.283;
        vec3 objectColor = vec3(0.0);
        raytrace(coord, vec2(cos(t), sin(t)), objectColor);
        col += objectColor;
    }

    color = col / 32.0 * 2.0;
}
*/

void GetLighting(inout vec3 albedo, out vec3 shadow, vec3 viewPos, vec3 worldPos,
                 vec2 lightmap, float smoothLighting, float NoL, float vanillaDiffuse,
                 float parallaxShadow, float emission, float subsurface) {

    #if EMISSIVE == 0 || (!defined ADVANCED_MATERIALS && EMISSIVE == 1)
    emission = 0.0;
    #endif

    #if SSS == 0 || (!defined ADVANCED_MATERIALS && SSS == 1)
    subsurface = 0.0;
    #endif

    #ifdef ADVANCED_ILLUMINATION
    lightmap.y = clamp(pow(lightmap.y, 0.25), 0.25, 1.0);
    #endif

    #if defined OVERWORLD || defined END
    if (NoL > 0.0 || subsurface > 0.0) shadow = GetShadow(worldPos, NoL, subsurface, lightmap.y);
    shadow *= parallaxShadow;
    NoL = clamp(NoL * 1.01 - 0.01, 0.0, 1.0);
    
    float scattering = 0.0;
    if (subsurface > 0.0){
        float VoL = clamp(dot(normalize(viewPos.xyz), lightVec) * 0.5 + 0.5, 0.0, 1.0);
        scattering = pow(VoL, 16.0) * (1.0 - rainStrength) * subsurface;
        NoL = mix(NoL, 1.0, sqrt(subsurface) * 0.7);
        NoL = mix(NoL, 1.0, scattering);
    }
    
    vec3 fullShadow = shadow * NoL;

    #ifdef OVERWORLD
    float shadowMult = (1.0 - 0.95 * rainStrength) * shadowFade;
    vec3 sceneLighting = mix(ambientCol, lightCol, fullShadow * shadowMult);
    sceneLighting *= (4.0 - 3.0 * lightmap.y) * lightmap.y * (1.0 + scattering * shadow);
    if (isEyeInWater == 0) sceneLighting *= pow(lightmap.y, 3.0); //light leaking fix
    #endif

    #ifdef END
    vec3 sceneLighting = endCol.rgb * (0.06 * fullShadow + 0.02);
    #endif

    #else
    vec3 sceneLighting = netherColSqrt.rgb * 0.1;
    #endif

    #ifdef LIGHTMAP_DIM_CUTOFF
    lightmap.x = pow(lightmap.x, DIM_CUTOFF_FACTOR);
    #endif

    #ifdef SSGI
    lightmap.x *= 0.0;
    #endif

    float newLightmap = pow(lightmap.x, 8.00) * 2.00 + lightmap.x * 0.75;
    newLightmap = clamp(newLightmap, 0.25, 1.00);

    float lightmapBrightness = lightmap.x * 15.0;
    float lightMapBrightnessFactor = 1.25 - pow(lightmap.x, 6.0);
    blocklightCol *= lightMapBrightnessFactor;
    blocklightCol *= 1.00 - lightmap.y * 0.75;

    #ifdef ADVANCED_ILLUMINATION
    float sunlightmap = pow(lightmap.y, 6.0) * timeBrightness * lightmap.y;
    vec3 sunlight = vec3(ADVANCED_ILLUMINATION_R, ADVANCED_ILLUMINATION_G, ADVANCED_ILLUMINATION_B) / 255.0 * ADVANCED_ILLUMINATION_I;
    sunlight = normalize(sunlight) * sunlightmap;
    #endif

    #ifdef LIGHTMAP_BRIGHTNESS_RECOLOR
    float lightFlatten1 = clamp(1.0 - pow(1.0 - emission, 128.0), 0.0, 1.0);
    if (lightFlatten1 == 0){
        blocklightCol.r *= (pow(newLightmap, 4)) * 3 * LIGHTMAP_R;
        blocklightCol.g *= (3.50 - newLightmap) * newLightmap * 1.25 * LIGHTMAP_G;
        blocklightCol.b *= (3.50 - newLightmap - newLightmap) * 2.50 * LIGHTMAP_B;
    } else {
        float blocklightColr = (pow(newLightmap, 4)) * 3 * LIGHTMAP_R;
        float blocklightColg = (3.50 - newLightmap) * newLightmap * 1.25 * LIGHTMAP_G;
        float blocklightColb = (3.50 - newLightmap - newLightmap) * 2.50 * LIGHTMAP_B;
        blocklightCol = mix(blocklightCol, vec3(blocklightColr, blocklightColg, blocklightColb), 0.5);
    }
    #endif
   
    #ifdef BLOCKLIGHT_ALBEDO_BLENDING
    blocklightCol = mix(blocklightCol, albedo.rgb, 0.25);
    #endif

    #ifdef BLOCKLIGHT_FLICKERING
    float jitter = 1.0 - sin(frameTimeCounter + cos(frameTimeCounter)) * BLOCKLIGHT_FLICKERING_STRENGTH;
    blocklightCol *= jitter;
    #endif

    #ifdef NETHER
    vec3 blocklightColSqrtNether = vec3(BLOCKLIGHT_R_NETHER, BLOCKLIGHT_G_NETHER, BLOCKLIGHT_B_NETHER) * BLOCKLIGHT_I / 300.0;
    vec3 blocklightColNether = blocklightColSqrtNether * blocklightColSqrtNether;
    blocklightCol = blocklightColNether;
    #endif

    #ifdef END
    vec3 blocklightColSqrtEnd = vec3(BLOCKLIGHT_R_END, BLOCKLIGHT_G_END, BLOCKLIGHT_B_END) * BLOCKLIGHT_I / 300.0;
    vec3 blocklightColEnd = blocklightColSqrtEnd * blocklightColSqrtEnd;
    blocklightCol = blocklightColEnd;
    #endif

    //WORLD POSITION BASED - STATIC
    #ifdef RANDOM_COLORED_LIGHTING
    vec2 pos = (cameraPosition.xz + worldPos.xz);
	float CLr = texture2D(noisetex, 0.0002 * pos).r;
	float CLg = texture2D(noisetex, 0.0004 * pos).r;
	float CLb = texture2D(noisetex, 0.0008 * pos).r;
	blocklightCol = vec3(CLr, CLg, CLb) * vec3(CLr, CLg, CLb);
    #endif
    
    vec3 blockLighting = newLightmap * newLightmap * newLightmap * newLightmap * newLightmap * normalize(blocklightCol); //pow is crong

    //#ifdef SSGI
    //blockLighting = vec3(0.0);
    //#endif

    vec3 minLighting = minLightCol * (1.0 - eBS) * (1.25 - isEyeInWater);

    #ifdef TOON_LIGHTMAP
    minLighting *= floor(smoothLighting * 8.0 + 1.001) / 4.0;
    smoothLighting = 1.0;
    #endif
    
    vec3 albedoNormalized = normalize(albedo.rgb + 0.00001);
    vec3 emissiveLighting = mix(albedoNormalized, vec3(1.0), emission * 0.5);
    emissiveLighting *= emission * 4.0;

    float lightFlatten = clamp(1.0 - pow(1.0 - emission, 128.0), 0.0, 1.0);
    blockLighting *= 1.0 - float(lightFlatten > 0.5) * 0.75;
    vanillaDiffuse = mix(vanillaDiffuse, 1.0, lightFlatten);
    smoothLighting = mix(smoothLighting, 1.0, lightFlatten);
        
    float nightVisionLighting = nightVision * 0.25;
    
    #ifdef ALBEDO_BALANCING
    float albedoLength = length(albedo.rgb);
    albedoLength /= sqrt((albedoLength * albedoLength) * 0.25 * (1.0 - lightFlatten) + 1.0);
    albedo.rgb = albedoNormalized * albedoLength;
    #endif

    //albedo = vec3(0.5);
    #ifdef ADVANCED_ILLUMINATION
    albedo *= sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting + sunlight;
    #else
    albedo *= sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting;
    #endif

    albedo *= vanillaDiffuse * smoothLighting * smoothLighting;

    #ifdef DESATURATION
    #ifdef OVERWORLD
    float desatAmount = sqrt(max(sqrt(length(fullShadow / 3.0)) * lightmap.y, lightmap.y)) *
                        sunVisibility * (1.0 - rainStrength * 0.4) + 
                        sqrt(lightmap.x) + lightFlatten;

    vec3 desatNight   = lightNight / LIGHT_NI;
    vec3 desatWeather = weatherCol.rgb / weatherCol.a * 0.5;

    desatNight *= desatNight; desatWeather *= desatWeather;
    
    float desatNWMix  = (1.0 - sunVisibility) * (1.0 - rainStrength);

    vec3 desatColor = mix(desatWeather, desatNight, desatNWMix);
    desatColor = mix(vec3(0.1), desatColor, sqrt(lightmap.y)) * 10.0;
    #endif

    #ifdef NETHER
    float desatAmount = sqrt(lightmap.x) + lightFlatten;

    vec3 desatColor = netherColSqrt.rgb / netherColSqrt.a;
    #endif

    #ifdef END
    float desatAmount = sqrt(lightmap.x) + lightFlatten;

    vec3 desatColor = endCol.rgb * 1.25;
    #endif

    desatAmount = clamp(desatAmount, DESATURATION_FACTOR * 0.4, 1.0);
    desatColor *= 1.0 - desatAmount;

    albedo = mix(GetLuminance(albedo) * desatColor, albedo, desatAmount);
    #endif

}
