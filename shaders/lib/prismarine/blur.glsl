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

vec3 BoxBlur(sampler2D colortex, float strength, vec2 coord) {
	vec3 blur = vec3(0.0);

	for(int j = 0; j <= 16; j++){
		vec2 offset = BlurOffsets[j] * strength * vec2(1.0 / aspectRatio, 1.0);
		blur += texture2DLod(colortex, texCoord + offset, 1.0).rgb;
	}

	return blur / 16.0;
}