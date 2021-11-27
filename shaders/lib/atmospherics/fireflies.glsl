float getFireflyNoise(vec3 pos, float height){
	float noise = 0.0;
	float ymult = pow(abs(height - pos.y) / 256.0, 2.0);
	
	if (ymult < 2.0){
		noise+= getVolumetricNoise0(pos + vec3(frametime * 0.2, frametime * 0.05, frametime * 0.1)) * 10.075;
	}
    
	noise = clamp(noise - (10.0 + 5.0 * ymult), 0.0, 1.0);
	return noise;
}

vec3 GetFireflies(float pixeldepth0, vec3 color, float dither) {
	vec3 ff = vec3(0.0);
	dither *= 0.5;
	float visibility = (1 - sunVisibility) * (1 - rainStrength) * (0 + eBS);

	if (visibility > 0.0) {
		float depth0 = GetLinearDepth2(pixeldepth0);
		vec4 worldposition = vec4(0.0);

		for(int i = 0; i < 64; i++) {
			float minDist = (i + dither) * 16.0; 

			worldposition = GetWorldSpace(GetLogarithmicDepth(minDist), texCoord.st);

			if (length(worldposition.xz) < 128.0 && depth0 > minDist){
				vec3 col = vec3(1.0);

				if (depth0 < minDist) col *= color;
				
				float noise = getFireflyNoise(worldposition.xyz + cameraPosition.xyz, 80.0);

				col *= noise;

				ff += col;
			}
		}
		ff = sqrt(ff * visibility);
	}
	
	return ff;
}