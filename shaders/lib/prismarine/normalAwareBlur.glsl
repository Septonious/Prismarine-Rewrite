#include "/lib/prismarine/macros.glsl"
#include "/lib/util/encode.glsl"

//huge thanks to niemand for helping me with depth aware blur

vec2 dofOffsets[60] = vec2[60](
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
	vec2( 0.5    ,  0     ),
	vec2( 0.433  ,  0.25  ),
	vec2( 0.25   ,  0.433 ),
	vec2( 0      ,  0.75  ),
	vec2(-0.2565 ,  0.7048),
	vec2(-0.4821 ,  0.5745),
	vec2(-0.51295,  0.375 ),
	vec2(-0.7386 ,  0.1302),
	vec2(-0.7386 , -0.1302),
	vec2(-0.51295, -0.375 ),
	vec2(-0.4821 , -0.5745),
	vec2(-0.2565 , -0.7048),
	vec2(-0      , -0.75  ),
	vec2( 0.2565 , -0.7048),
	vec2( 0.4821 , -0.5745),
	vec2( 0.51295, -0.375 ),
	vec2( 0.7386 , -0.1302),
	vec2( 0.7386 ,  0.1302),
	vec2( 0.51295,  0.375 ),
	vec2( 0.4821 ,  0.5745),
	vec2( 0.2565 ,  0.7048),
	vec2( 0      ,  1     ),
	vec2(-0.2588 ,  0.9659),
	vec2(-0.5    ,  0.866 ),
	vec2(-0.7071 ,  0.7071),
	vec2(-0.866  ,  0.5   ),
	vec2(-0.9659 ,  0.2588),
	vec2(-1      ,  0     ),
	vec2(-0.9659 , -0.2588),
	vec2(-0.866  , -0.5   ),
	vec2(-0.7071 , -0.7071),
	vec2(-0.5    , -0.866 ),
	vec2(-0.2588 , -0.9659),
	vec2(-0      , -1     ),
	vec2( 0.2588 , -0.9659),
	vec2( 0.5    , -0.866 ),
	vec2( 0.7071 , -0.7071),
	vec2( 0.866  , -0.5   ),
	vec2( 0.9659 , -0.2588),
	vec2( 1      ,  0     ),
	vec2( 0.9659 ,  0.2588),
	vec2( 0.866  ,  0.5   ),
	vec2( 0.7071 ,  0.7071),
	vec2( 0.5    ,  0.8660),
	vec2( 0.2588 ,  0.9659)
);

#ifndef NETHER
uniform float far, near;

float GetLinearDepth2(float depth) {
    return 2.0 * near * far / (far + near - (2.0 * depth - 1.0) * (far - near));
}
#endif

vec3 NormalAwareBlur(float strength, vec2 coord) {
	vec3 blur = vec3(0.0);
	vec3 normal = normalize(DecodeNormal(texture2D(colortex6, coord).xy));
	vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

	float weight = 0.0;
	float GBufferWeight = 1.0;

	float centerDepth0 = texture2D(depthtex0, coord.xy).x;

    #ifndef NETHER
	float centerDepth1 = GetLinearDepth2(texture2D(depthtex1, coord.xy).x);
    #endif
    
    for(int i = 0; i <= DENOISE_QUALITY; i++){
        vec2 offset = dofOffsets[i] * pixelSize * DENOISE_STRENGTH * float(centerDepth0 > 0.56);

        vec3 currentNormal = normalize(DecodeNormal(texture2D(colortex6, coord + offset).xy));
        float normalWeight = pow8(clamp(dot(normal, currentNormal), 0.0001, 1.0));
        GBufferWeight = normalWeight;

        #ifndef NETHER
        float currentDepth = GetLinearDepth2(texture2D(depthtex1, coord + offset).x);
        float depthWeight = (clamp(1.0 - abs(currentDepth - centerDepth1), 0.0001, 1.0)); 
        GBufferWeight *= depthWeight;
        #endif

        blur += texture2D(colortex11, coord + offset).rgb * GBufferWeight;
        weight += GBufferWeight;
    }

	return blur / weight;
}