vec4 waterColorSqrt = vec4(vec3(WATER_R, WATER_G, WATER_B) / 255.0, WATER_A) * WATER_I;
vec4 waterColor = waterColorSqrt * waterColorSqrt;

const float waterAlpha = WATER_A;
float waterFogDensity = WATER_FOG_DENSITY * clamp(10 - cameraPosition.y * 0.1, 0.1, 2.0);
float waterFogRange = 64.0 / waterFogDensity;