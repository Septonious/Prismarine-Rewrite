/*
void PromoOutline(inout vec3 color, sampler2D depth) {
	float ph = 1.0 / viewHeight;
	float pw = ph / aspectRatio;

	float outlinea = 0.0, outlineb = 0.0, outlinec = 0.0, outlined = 0.0;
	float z = GetLinearDepth(texture2D(depth, texCoord).r) * far;
	float totalz = 0.0;
	float maxz = z;
	float sampleza = 0.0;
	float samplezb = 0.0;

	for(int i = 0; i < 12; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
		sampleza = GetLinearDepth(texture2D(depth, texCoord + offset).r) * far;
		samplezb = GetLinearDepth(texture2D(depth, texCoord - offset).r) * far;
		maxz = max(maxz, max(sampleza, samplezb));

		float sample = (z * 2.0 - (sampleza + samplezb)) / length(outlineOffsets[i]);

		outlinea += clamp(1.0 + sample * 4.0 / z, 0.0, 1.0);
		if(i >= 8) outlineb += 1.0 - (1.0 - clamp(1.0 - sample * 512.0 / z, 0.0, 1.0)) * clamp(1.0 - sample * 16.0 / z, 0.0, 1.0);
		outlinec += clamp(1.0 + sample * 128.0 / z, 0.0, 1.0);

		totalz += sampleza + samplezb;
	}
	outlinea = clamp(outlinea - 10.0, 0.0, 1.0);
	outlineb = clamp(outlineb - 2.0, 0.0, 1.0);
	outlinec = 1.0 - clamp(outlinec - 11.0, 0.0, 1.0);
	outlined = clamp(1.0 + 64.0 * (z - maxz) / z, 0.0, 1.0);
	
	float outline = (0.2 * outlinea * outlineb + 0.8) + 0.2 * outlinec * outlined;

	color = sqrt(sqrt(color));
	color *= outline;
	color *= color; color *= color;
}
*/