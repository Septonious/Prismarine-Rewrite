//based on sky from physicalsl by rre36

#define INV_PI 0.31830988
#define PI 3.1415926535
#define fade(x, y) (1.0 - exp2(-x * y))

vec3 lightAbsorption  = vec3(0.3, 0.6, 1.0);
vec3 zenithColor = vec3(0.1, 0.2, 1.0);
vec3 ozoneAdditionalColor = vec3(1.0, 1.25, 1.0);

vec3 sunLight    = vec3(sunIllum_r, sunIllum_g, sunIllum_b) * sunIllum_mult;
vec3 moonLight   = vec3(moonIllum_r, moonIllum_g, moonIllum_b) * moonIllum_mult;

float getMie(float mu, float g) {
    float numerator = (1.0 - g * g) * (1.0 + mu * mu);
    float denominator = (2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5);
    return ((3.0 / (8.0 * PI)) * numerator / denominator) * 0.5 + 0.5;
}

float whereTheHellIsOurHorizon(float x) {
    return 0.75 / pow(max(x, 0.35e-3), 0.75);
}

vec3 getSkyAbsorption(vec3 x, float y){
	vec3 absorption = x * -y;
	     absorption = exp(absorption) * 2.0;
    
    return absorption;
}

vec3 getLighting(float lightVec) {
    vec3 ozone = lightAbsorption * mix(lightAbsorption, vec3(1.0), smoothstep(0.0, 0.25, lightVec));
    
    return getSkyAbsorption(ozone, whereTheHellIsOurHorizon(lightVec));
}

vec3 getAtmosphericScattering(float horizon, float sunScatter, float moonScatter, float sunAngle, float moonAngle, vec3 absorption, vec3 sunlight, vec3 moonlight, vec3 ozone){
	float densityFade = fade(0.25, horizon);

    vec3 sunScattering  = (zenithColor * horizon) * (sunlight + length(sunlight));
	vec3 sunScatteringFade = mix(fade(0.5, sunScattering), ozone, densityFade);
         sunScattering  = mix(sunScattering * absorption, sunScatteringFade, sunAngle);
         sunScattering += (1.0 - exp(-horizon * ozone)) * sunScatter * sunlight;

    vec3 moonScattering  = (zenithColor * horizon) * (moonlight + length(moonlight));
	vec3 moonScatteringFade = mix(fade(0.5, moonScattering), ozone, densityFade);
         moonScattering  = mix(moonScattering * absorption, moonScatteringFade, moonAngle);
         moonScattering += fade(horizon, zenithColor) * moonScatter * moonlight;
         moonScattering  = mix(moonScattering, dot(moonScattering, vec3(0.3)) * vec3(0.3, 0.6, 1.0), 0.75);	
	return sunScattering + moonScattering;
}

vec3 GetSkyColor(vec3 viewPos, bool reflection) {
    vec3 viewVec = normalize(mat3(gbufferModelViewInverse) * viewPos.xyz);
    vec3 sunVec = normalize(mat3(gbufferModelViewInverse) * sunVec);
	vec3 moonVec = -sunVec;

    float WdotS = dot(viewVec, sunVec);
    float WdotM = dot(viewVec, moonVec);

	float rayleighSun = 0.5 + WdotS * 0.5;
	float rayleighMoon = 0.5 + WdotM * 0.5;
	float mieSun = getMie(WdotS, sunVisibility);
	float mieMoon = getMie(WdotM, moonVisibility);

    float sunAngle = clamp(length(sunVec.y), 0.0, 1.0);
    float moonAngle = clamp(length(moonVec.y), 0.0, 1.0);

	float lightAngle = smoothstep(0.0, 0.25, max(sunVec.y, moonVec.y));
    vec3 ozone = zenithColor * mix(vec3(1.0), vec3(1.0), lightAngle);

    float horizon = whereTheHellIsOurHorizon(viewVec.y + 0.05);

    vec3 absorption = getSkyAbsorption(ozone, horizon);
    vec3 sunlight = getLighting(sunVec.y) * sunLight;
    vec3 moonlight = getLighting(moonVec.y) * moonLight;

    float sunScatter = rayleighSun + mieSun;
    float moonScatter = rayleighMoon + mieMoon;

	vec3 atmosphericScattering = getAtmosphericScattering(horizon, sunScatter, moonScatter, sunAngle, moonAngle, absorption, sunlight, moonlight, ozone);

    return atmosphericScattering * INV_PI;
}