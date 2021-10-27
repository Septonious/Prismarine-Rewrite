vec3 secondnebulaLowColSqrt = vec3(RIFTSECOND_LR, RIFTSECOND_LG, RIFTSECOND_LB) * RIFTSECOND_LI / 255.0;
vec3 secondnebulaLowCol = secondnebulaLowColSqrt * secondnebulaLowColSqrt;
vec3 secondnebulaHighColSqrt = vec3(RIFTSECOND_HR, RIFTSECOND_HG, RIFTSECOND_HB) * RIFTSECOND_HI / 255.0;
vec3 secondnebulaHighCol = secondnebulaHighColSqrt * secondnebulaHighColSqrt;

vec3 nebulaLowColSqrt = vec3(RIFT_LR, RIFT_LG, RIFT_LB) * RIFT_LI / 255.0;
vec3 nebulaLowCol = nebulaLowColSqrt * nebulaLowColSqrt;
vec3 nebulaHighColSqrt = vec3(RIFT_HR, RIFT_HG, RIFT_HB) * RIFT_HI / 255.0;
vec3 nebulaHighCol = nebulaHighColSqrt * nebulaHighColSqrt;

vec3 auroraLowColSqrt = vec3(AURORA_LR, AURORA_LG, AURORA_LB) * AURORA_LI / 255.0;
vec3 auroraLowCol = auroraLowColSqrt * auroraLowColSqrt;
vec3 auroraHighColSqrt = vec3(AURORA_HR, AURORA_HG, AURORA_HB) * AURORA_HI / 255.0;
vec3 auroraHighCol = auroraHighColSqrt * auroraHighColSqrt;