/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float star;

varying vec3 upVec, sunVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;
uniform int frameCounter;

#if defined WEATHER_PERBIOME || defined PERBIOME_CLOUDS_COLOR || FOG_COLOR_MODE == 2 || SKY_COLOR_MODE == 1
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna, isForest, isTaiga, isJungle;
#endif

uniform float blindFactor;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D noisetex;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

void RoundSunMoon(inout vec3 color, vec3 viewPos, vec3 sunColor, vec3 moonColor) {
	float VoL = dot(normalize(viewPos), sunVec);
	float isMoon = float(VoL < 0.0);
	float sun = pow(abs(VoL), 800.0 * isMoon + 800.0) * (1.0 - sqrt(rainStrength));

	vec3 sunMoonCol = mix(moonColor * moonVisibility, sunColor * sunVisibility, float(VoL > 0.0));
	color += sun * sunMoonCol * ROUND_SUN_MOON_SIZE;
}

void SunGlare(inout vec3 color, vec3 viewPos, vec3 lightCol) {
	float VoL = dot(normalize(viewPos), lightVec);
	float visfactor = 0.05 * (-0.8 * timeBrightness + 1.0) * (3.0 * rainStrength + 1.0);
	float invvisfactor = 1.0 - visfactor;

	float visibility = clamp(VoL * 0.5 + 0.5, 0.0, 1.0);
    visibility = visfactor / (1.0 - invvisfactor * visibility) - visfactor;
	visibility = clamp(visibility * 1.015 / invvisfactor - 0.015, 0.0, 1.0);
	visibility = mix(1.0, visibility, 0.25 + 0.75) * (1.0 - rainStrength * 0.875);
	visibility *= shadowFade * (1.1 - timeBrightness);

	#ifdef SUN_GLARE
	color += lightCol * visibility * (0.1 + 0.25 * isEyeInWater);
	#endif
}

//Includes//
#include "/lib/prismarine/timeCalculations.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/sky.glsl"

#if defined WEATHER_PERBIOME || defined PERBIOME_CLOUDS_COLOR || FOG_COLOR_MODE == 2 || SKY_COLOR_MODE == 1
#include "/lib/prismarine/biomeColor.glsl"
#endif

#if defined PLANAR_CLOUDS || NIGHT_SKY_MODE == 1 || defined AURORA
#include "/lib/atmospherics/clouds.glsl"
#endif

//Program//
void main() {
	#ifdef END_STARS
	#endif

	float dither = Bayer64(gl_FragCoord.xy);
	dither = fract(dither + frameCounter / 8.0);

	vec4 screenPos = vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#ifdef OVERWORLD
	vec3 albedo = GetSkyColor(viewPos.xyz, false);
	
	vec3 nViewPos = normalize(viewPos.xyz);
	float NdotU = dot(nViewPos, upVec);
	
	#ifdef ROUND_SUN_MOON
    vec3 sunColor = vec3(1.0, 0.8, 0.2);
	if (isEyeInWater == 1) sunColor = waterColor.rgb;
    vec3 moonColor = sqrt(lightNight);

	RoundSunMoon(albedo, viewPos.xyz, sunColor, lightCol);
	#endif

	#ifdef STARS
	#ifdef SMALL_STARS
	DrawStars(albedo.rgb, viewPos.xyz);
	#endif
	#ifdef BIG_STARS
	DrawBigStars(albedo.rgb, viewPos.xyz);
	#endif
	#endif

	#if NIGHT_SKY_MODE == 1
	if (moonVisibility > 0.0 && rainStrength != 1.0){
		albedo.rgb += DrawRift(viewPos.xyz, dither, 6, 1);
		albedo.rgb += DrawRift(viewPos.xyz, dither, 6, 0);
	}
	#endif

	#ifdef AURORA
	if (moonVisibility != 0) albedo.rgb += DrawAurora(viewPos.xyz, dither, 10);
	#endif

	#ifdef PLANAR_CLOUDS
	vec4 cloud = DrawCloud(viewPos.xyz, dither, lightCol, ambientCol);
	albedo.rgb = mix(albedo.rgb, cloud.rgb, cloud.a);
	#endif

	SunGlare(albedo, viewPos.xyz, CalcLightColor(skylightSun, skylightNight, weatherCol.rgb));

	albedo.rgb *= 1 * (1.0 + nightVision);

	#if ALPHA_BLEND == 0
	albedo.rgb = pow(max(albedo.rgb, vec3(0.0)), vec3(1.0 / 2.2));
	albedo.rgb = albedo.rgb + dither / vec3(64.0);
	#endif
	#endif
	
    /* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(albedo, 1.0 - star);
    #if defined OVERWORLD && defined PLANAR_CLOUDS
    /* DRAWBUFFERS:04 */
	gl_FragData[1] = vec4(cloud.a, 0.0, 0.0, 0.0);
    #endif
	
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float star;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	
	gl_Position = ftransform();

	star = float(gl_Color.r == gl_Color.g && gl_Color.g == gl_Color.b && gl_Color.r > 0.0);
}

#endif