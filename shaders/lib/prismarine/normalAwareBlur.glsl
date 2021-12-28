#include "/lib/prismarine/macros.glsl"
#include "/lib/util/encode.glsl"

//huge thanks to niemand for helping me with depth aware blur

float[] KernelOffsets = float[](
    0.06859499456330513,
    0.06758866276489915,
    0.0646582434672158,
    0.060053666382841785,
    0.05415271962490796,
    0.0474096695217294,
    0.040297683205704475,
    0.033255219213172406,
    0.0266443947480172,
    0.02072610900858287,
    0.015652912895289143,
    0.011477248433445731,
    0.008170442697260053,
    0.0056470130318222785,
    0.0037892897088649766,
    0.0024686712595739543,
    0.0015614781087428572,
    0.0009589072215278897,
    0.0005717237762381398,
    0.0003309526350349594,
    0.0001860014387826795,
    0.0001014935746937502
);

#ifndef NETHER
float linearizeDepth(in float depth, in mat4 projectionInverse) {
    return 1.0 / ((depth * 2.0 - 1.0) * projectionInverse[2].w + projectionInverse[3].w);
}
#endif

vec3 NormalAwareBlur(sampler2D colortex, sampler2D normaltex, float strength, vec2 coord, vec2 direction) {
	vec3 blur = vec3(0.0);
	vec3 normal = normalize(DecodeNormal(texture2D(normaltex, coord).xy));
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	float weight = 0.0f;
	float GBufferWeight = 1.0f;

	float centerDepth0 = texture2D(depthtex0, coord.xy).x;
    
    #ifndef NETHER
	float centerDepth1 = linearizeDepth(texture2D(depthtex1, coord.xy).x, gbufferProjectionInverse);
    #endif

    for(int i = -21; i <= 21; i++){
        float kernelWeight = KernelOffsets[abs(i)];
		vec2 offset = direction * pixelSize * float(i) * DENOISE_STRENGTH * float(centerDepth0 > 0.56);

        vec3 currentNormal = normalize(DecodeNormal(texture2D(normaltex, coord + offset).xy));
		float normalWeight = pow8(clamp(dot(normal, currentNormal), 0.0001f, 1.0f));
        GBufferWeight = normalWeight * kernelWeight;

        #ifndef NETHER
		float currentDepth = linearizeDepth(texture2D(depthtex1, coord + offset).x, gbufferProjectionInverse);
		float depthWeight = clamp(1.0 - abs(currentDepth - centerDepth1), 0.0001f, 1.0f); 
        GBufferWeight *= depthWeight;
        #endif

        blur += texture2D(colortex, coord + offset).rgb * GBufferWeight;
        weight += GBufferWeight;
    }

	return blur / weight;
}