#define PI    3.1415926535897932384626433
#define PI_SQ 9.8696044010893586188344910

#define SCALE 0.5 // Scale of image
#define LANCZOS_SIZE 8 // lanczosUpscaling Kernel Size

float lanczosWeight(float x, float size) {
    if (x == 0.0) return 1.0;
    return (size * sin(PI * x) * sin(PI * (x / size))) / (PI_SQ * x*x);
}

float lanczosWeight(vec2 x, float size) {
    return lanczosWeight(x.x, size) * lanczosWeight(x.y, size);
}

vec3 lanczosUpscaling(sampler2D colortex, vec2 coord, int size) {
    vec2 fullResolution = vec2(textureSize(colortex, 0));
    coord += -0.5 / fullResolution;
    vec2 newCoord = floor(coord * fullResolution) / fullResolution;

    vec3 result  = vec3(0.0);
    for (int i = -size; i <= size; i++) {
        for (int j = -size; j <= size; j++) {
            vec2 offset = vec2(i, j);
            
            vec2 scaleCoord = (offset / fullResolution) + newCoord;
            vec2 d = clamp((scaleCoord - coord) * fullResolution, vec2(-size), vec2(size));
            vec3 val = texelFetch(colortex, ivec2(scaleCoord * fullResolution), 0).rgb;
            
            float weight = lanczosWeight(d, float(size));
            
            result += val * weight;
        }
    }

    return result;
}