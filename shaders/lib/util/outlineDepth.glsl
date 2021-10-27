void DepthOutline(inout float z) {
	float ph = ceil(viewHeight / 720.0) * 0.5 / viewHeight;
	float pw = ph / aspectRatio;
	for (int i = 0; i < 12; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
		for (int j = 0; j < 2; j++) {
			z = min(z, texture2D(depthtex1, texCoord + offset).r);
			offset = -offset;
		}
	}
}