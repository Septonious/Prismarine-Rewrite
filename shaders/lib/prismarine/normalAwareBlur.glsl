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

#define pow2(x) x*x
#define pow4(x) pow2(x) * pow2(x)
#define pow16(x) pow4(x) * pow4(x)
#define pow32(x) pow2(x) * pow16(x)
#define pow64(x) pow4(x) * pow16(x)
#define pow256(x) pow16(x) * pow16(x)
#define pow512(x) pow256(x) * pow2(x)

vec3 NormalAwareBlur(sampler2D colortex, sampler2D normaltex, float strength, vec2 coord, vec2 direction) {
	vec3 blur = vec3(0.0);
	vec2 view = 1.0 / vec2(viewWidth, viewHeight);
	float weight = 0.0;
	float GBufferWeight = 1.0f;

    vec3 normal = texture2D(normaltex, coord).xyz * 2.0 - 1.0;

    for(int i = -21; i <= 21; i++){
        float KernelWeight = KernelOffsets[abs(i)];
		vec2 offsetCoord = coord + direction * view * float(i) * DENOISE_STRENGTH;
        
        vec3 newNormal = texture2D(normaltex, offsetCoord).xyz * 2.0 - 1.0;
        
		float sampleDepth = GetLinearDepth(texture2D(depthtex0, offsetCoord).r);
		float NormalWeight = pow512(clamp(dot(normal, newNormal), 0.0001f, 1.0f));
		float DepthWeight = clamp(pow512(1.0f / abs(centerDepth - sampleDepth)), 0.0001f, 1.0f);
		GBufferWeight = NormalWeight * DepthWeight * KernelWeight;

        blur += texture2D(colortex, offsetCoord).rgb * GBufferWeight;
        weight += GBufferWeight;
    }

	return blur / weight;
}