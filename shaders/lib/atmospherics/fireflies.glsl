float getFireflyNoise(vec3 pos, float height){
	float noise = 0.0;
	float ymult = pow(abs(height - pos.y) / 32, 32);
	
	if (ymult < 2.0){
		noise+= rand(pos) * 10.05;
	}
    
	noise = clamp(noise - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec3 GetFireflies(float pixeldepth0, vec3 color, float dither) {
	vec3 ff = vec3(0.0);
	dither *= 2;
	float visibility = (1 - sunVisibility) * (1 - rainStrength) * (0 + eBS);

	if (visibility > 0.0) {
		float depth0 = GetLinearDepth2(pixeldepth0);
		vec4 worldposition = vec4(0.0);

		for(int i = 0; i < 8; i++) {
			float minDist = (i + dither) * 8; 

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

			if (length(worldposition.xz) < 128 && depth0 > minDist){
				vec3 col = vec3(1);

				if (depth0 < minDist) col *= color;
				
				float noise = getFireflyNoise(worldposition.xyz + cameraPosition.xyz, 50);

				col *= noise;

				ff += col;
			}
		}
		ff = sqrt(ff * visibility);
	} else discard;
	
	return ff;
}