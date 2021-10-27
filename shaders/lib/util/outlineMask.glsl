float GetOutlineMask() {
	float ph = ceil(viewHeight / 720.0) * 0.5 / viewHeight;
	float pw = ph / aspectRatio;

	float mask = 0.0;
	for (int i = 0; i < 12; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
        for (int j = 0; j < 2; j++){
		    mask += float(texture2D(depthtex0, texCoord + offset).r <
		                  texture2D(depthtex1, texCoord + offset).r);
            offset = -offset;
        }
	}

	return float(mask > 0.5);
}