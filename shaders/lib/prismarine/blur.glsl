vec2 BlurOffsets[16] = vec2[16](
	vec2( 0.0    ,  0.25  ),
	vec2(-0.2165 ,  0.125 ),
	vec2(-0.2165 , -0.125 ),
	vec2( 0      , -0.25  ),
	vec2( 0.2165 , -0.125 ),
	vec2( 0.2165 ,  0.125 ),
	vec2( 0      ,  0.5   ),
	vec2(-0.25   ,  0.433 ),
	vec2(-0.433  ,  0.25  ),
	vec2(-0.5    ,  0     ),
	vec2(-0.433  , -0.25  ),
	vec2(-0.25   , -0.433 ),
	vec2( 0      , -0.5   ),
	vec2( 0.25   , -0.433 ),
	vec2( 0.433  , -0.2   ),
	vec2( 0.5    ,  0     )
);

#define INV_SQRT_OF_2PI 0.39894228040143267793994605993439
#define INV_PI 0.31830988618379067153776752674503

vec3 smartDeNoise(sampler2D tex, vec2 uv, float sigma, float kSigma, float threshold){
    float radius = round(kSigma * sigma);
    float radQ = radius * radius;
    
    float invSigmaQx2 = 0.5 / (sigma * sigma);
    float invSigmaQx2PI = INV_PI * invSigmaQx2;
    
    float invThresholdSqx2 = 0.5 / (threshold * threshold);
    float invThresholdSqrt2PI = INV_SQRT_OF_2PI / threshold;
    
    vec4 centrPx = texture(tex,uv);
    
    float zBuff = 0.0;
    vec4 aBuff = vec4(0.0);
    vec2 size = vec2(textureSize(tex, 0));
    
    for(float x= -radius; x <= radius; x++) {
        float pt = sqrt(radQ - x * x);
        for(float y= -pt; y <= pt; y++) {
            vec2 d = vec2(x, y);

            float blurFactor = exp(-dot(d , d) * invSigmaQx2) * invSigmaQx2PI; 
            
            vec4 walkPx = texture(tex, uv + d / size);

            vec4 dC = walkPx-centrPx;
            float deltaFactor = exp( -dot(dC, dC) * invThresholdSqx2) * invThresholdSqrt2PI * blurFactor;
                                 
            zBuff += deltaFactor;
            aBuff += deltaFactor * walkPx;
        }
    }
    return (aBuff / zBuff).rgb;
}

vec3 BoxBlur(sampler2D colortex, float strength, vec2 coord) {
	vec3 blur = vec3(0.0);

	for(int j = 0; j <= 16; j++){
		vec2 offset = BlurOffsets[j] * strength * vec2(1.0 / aspectRatio, 1.0);
		blur += texture2D(colortex, coord + offset).rgb;
	}

	return blur / 16.0;
}