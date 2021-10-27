void Outline(vec3 color, bool secondPass, out vec4 outerOutline, out vec4 innerOutline) {
	float ph = ceil(viewHeight / 720.0) * 0.5 / viewHeight;
	float pw = ph / aspectRatio;

	float oOutlineMask = 1.0, iOutlineMask = 1.0, iBevel = 1.0;
	vec3  oOutlineColor = vec3(0.0), iOutlineColor = color;

    float z = texture2D(depthtex0, texCoord).r;
	float linZ = GetLinearDepth(z);
	float minZ = z, maxZ = z;

	for (int i = 0; i < 12; i++) {
		vec2 offset = vec2(pw, ph) * outlineOffsets[i];
        float linSampleZSum = 0.0, linSampleZDiff = 0.0;

        for (int j = 0; j < 2; j++) {        
            float sampleZ = texture2D(depthtex0, texCoord + offset).r;
            float linSampleZ = GetLinearDepth(sampleZ);

            #ifdef OUTLINE_OUTER_COLOR
            if((GetLinearDepth(minZ) - 0.125 / far) > linSampleZ) {
                oOutlineColor = texture2D(colortex0, texCoord + offset).rgb;
            }
            #endif

            linSampleZSum += linSampleZ;
            if(j == 0) linSampleZDiff = linSampleZ;
            else linSampleZDiff -= linSampleZ;
            
            minZ = min(minZ, sampleZ);
            maxZ = max(maxZ, sampleZ);
            offset = -offset;
        }

        #ifdef OUTLINE_OUTER
        oOutlineMask *= clamp(1.0 - (linZ * 2.0 - linSampleZSum) * far * 0.25, 0.0, 1.0);
        #endif
        
        #ifdef OUTLINE_INNER
        linSampleZSum -= abs(linSampleZDiff) * 0.5;
        iOutlineMask *= clamp(1.125 + (linZ * 2.0 - linSampleZSum) * 32.0 * far, 0.0, 1.0);
        #endif
	}
    oOutlineColor = sqrt(oOutlineColor) * 0.35;
    oOutlineColor *= oOutlineColor;
    oOutlineMask = 1.0 - oOutlineMask;

    iOutlineColor = sqrt(iOutlineColor) * 1.2;
    iOutlineColor *= iOutlineColor;
    iOutlineMask = 1.0 - iOutlineMask;

	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord.x, texCoord.y, minZ, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	if (oOutlineMask > 0.001) {
		Fog(oOutlineColor, viewPos.xyz);
		if (isEyeInWater == 1.0 && secondPass) {
            vec4 waterFog = GetWaterFog(viewPos.xyz);
            oOutlineColor = mix(oOutlineColor, waterFog.rgb, waterFog.a);
        }
	}

	outerOutline = vec4(oOutlineColor, oOutlineMask);
    innerOutline = vec4(iOutlineColor, iOutlineMask);
}