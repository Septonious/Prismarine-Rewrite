float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade = 1.0 - timeBrightness;

vec3 CalcSunColor(vec3 morning, vec3 day, vec3 evening) {
	vec3 me = mix(morning, evening, mefade);
	return mix(me, day, 1.0 - dfade * sqrt(dfade));
}

vec3 CalcLightColor(vec3 sun, vec3 night, vec3 weatherCol) {
	vec3 c = mix(night, sun, sunVisibility);
	c = mix(c, dot(c, vec3(0.299, 0.587, 0.114)) * weatherCol, rainStrength);
	return c * c;
}

float CalcDayAmount(float morning, float day, float evening) {
	float me = mix(morning, evening, mefade);
	return mix(me, day, 1.0 - dfade * sqrt(dfade));
}

float CalcTotalAmount(float sun, float night) {
	float c = mix(night, sun, sunVisibility);
	return c * c;
}