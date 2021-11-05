/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec, lightVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;
uniform int frameCounter;

#if defined WEATHER_PERBIOME || FOG_COLOR_MODE == 2 || defined PERBIOME_LIGHTSHAFTS
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna, isForest, isTaiga, isJungle;
#endif

uniform float blindFactor;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float frameTimeCounter;
uniform float far, near;
uniform float viewHeight, viewWidth;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
uniform sampler2D colortex8;
uniform sampler2D colortex9;
#endif
uniform sampler2D noisetex;

//Optifine Constants//
const bool colortex1MipmapEnabled = true;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime)/20.0*ANIMATION_SPEED;
#else
float frametime = frameTimeCounter*ANIMATION_SPEED;
#endif

float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/prismarine/timeCalculations.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"

#ifdef PERBIOME_LIGHTSHAFTS
#include "/lib/prismarine/biomeColor.glsl"
#endif

#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
#include "/lib/prismarine/volumetricClouds.glsl"
#endif

//Program//
void main() {
	vec4 color = texture2D(colortex0, texCoord.xy);
	float pixeldepth0 = texture2D(depthtex0, texCoord.xy).x;
	
	#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
	float lod0 = 2;

	#ifndef MC_GL_RENDERER_GEFORCE
		if (fract(viewHeight / 2.0) > 0.25 || fract(viewWidth / 2.0) > 0.25) 
			lod0 = 0.0;
	#endif

	vec3 aux1 = texture2DLod(colortex8, texCoord.xy + vec2( 0.0,  1 / viewHeight), lod0).rgb;
	vec3 aux2 = texture2DLod(colortex8, texCoord.xy + vec2( 0.0, -1 / viewHeight), lod0).rgb;
	vec3 aux3 = texture2DLod(colortex8, texCoord.xy + vec2( 1 / viewWidth,   0.0), lod0).rgb;
	vec3 aux4 = texture2DLod(colortex8, texCoord.xy + vec2(-1 / viewWidth,   0.0), lod0).rgb;
	vec3 aux8 = (aux1 + aux2 + aux3 + aux4) * 0.5;

	vec3 auxA = texture2DLod(colortex9, texCoord.xy + vec2( 0.0,  1 / viewHeight), lod0).rgb;
	vec3 auxB = texture2DLod(colortex9, texCoord.xy + vec2( 0.0, -1 / viewHeight), lod0).rgb;
	vec3 auxC = texture2DLod(colortex9, texCoord.xy + vec2( 1 / viewWidth,   0.0), lod0).rgb;
	vec3 auxD = texture2DLod(colortex9, texCoord.xy + vec2(-1 / viewWidth,   0.0), lod0).rgb;
	vec3 aux9 = (auxA + auxB + auxC + auxD) * 0.5;
	#endif

	float lod = 2;

	#ifndef MC_GL_RENDERER_GEFORCE
		if (fract(viewHeight / 2.0) > 0.25 || fract(viewWidth / 2.0) > 0.25) 
			lod = 0.0;
	#endif

	vec3 vl1 = texture2DLod(colortex1, texCoord.xy + vec2( 0.0,  1 / viewHeight), lod).rgb;
	vec3 vl2 = texture2DLod(colortex1, texCoord.xy + vec2( 0.0, -1 / viewHeight), lod).rgb;
	vec3 vl3 = texture2DLod(colortex1, texCoord.xy + vec2( 1 / viewWidth,   0.0), lod).rgb;
	vec3 vl4 = texture2DLod(colortex1, texCoord.xy + vec2(-1 / viewWidth,   0.0), lod).rgb;
	vec3 vlSum = (vl1 + vl2 + vl3 + vl4) * 0.5;
	vec3 vl = vlSum;
	vl *= vl;

	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord.xy, pixeldepth0, 1.0) * 2.0 - 1.0);
		 viewPos /= viewPos.w;

	#ifdef OVERWORLD
	
	#ifdef VOLUMETRIC_LIGHT
	vec3 lightshaftMorning  = vec3(LIGHTSHAFT_MR, LIGHTSHAFT_MG, LIGHTSHAFT_MB) * LIGHTSHAFT_MI / 255.0;
	vec3 lightshaftDay      = vec3(LIGHTSHAFT_DR, LIGHTSHAFT_DG, LIGHTSHAFT_DB) * LIGHTSHAFT_DI / 255.0;
	vec3 lightshaftEvening  = vec3(LIGHTSHAFT_ER, LIGHTSHAFT_EG, LIGHTSHAFT_EB) * LIGHTSHAFT_EI / 255.0;
	vec3 lightshaftNight    = vec3(LIGHTSHAFT_NR, LIGHTSHAFT_NG, LIGHTSHAFT_NB) * LIGHTSHAFT_NI * 0.3 / 255.0;
	vec3 lightshaftSun     = CalcSunColor(lightshaftMorning, lightshaftDay, lightshaftEvening);
	vec3 lightshaftCol  = CalcLightColor(lightshaftSun, lightshaftNight, weatherCol.rgb);

	float visibility0 = CalcTotalAmount(CalcDayAmount(1, 1, 1), 0);
	if (isEyeInWater == 1) visibility0 = 1;

	if (visibility0 > 0){
		vec3 lightshaftWater = vec3(LIGHTSHAFT_WR, LIGHTSHAFT_WG, LIGHTSHAFT_WB) * LIGHTSHAFT_WI / 255.0;
		vl *= lightshaftCol * 0.25;

		#ifdef PERBIOME_LIGHTSHAFTS
		vl *= getBiomeColor(lightshaftCol);
		#endif

		if (isEyeInWater == 1) vl *= waterColor.rgb * lightshaftWater.rgb * lightCol.rgb * LIGHTSHAFT_WI;
	}
	#endif

	#ifdef FIREFLIES
	float visibility1 = (1 - sunVisibility) * (1 - rainStrength) * (0 + eBS) * (1 - isEyeInWater);
	if (visibility1 > 0) vl *= vec3(100, 255, 180) * FIREFLIES_I * 16;	
	#endif

	#endif

    vl *= LIGHT_SHAFT_STRENGTH * (1.0 - rainStrength * 0.875) * shadowFade *
		  (1.0 - blindFactor);

	color.rgb += vl;

	#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
	float dither = Bayer64(gl_FragCoord.xy);
	float pixeldepth1 = texture2D(depthtex1, texCoord.xy).x;
	#endif

	/* DRAWBUFFERS:089 */
	gl_FragData[0] = color;
	#if defined VOLUMETRIC_CLOUDS && defined OVERWORLD
	gl_FragData[1] = getVolumetricCloud(pixeldepth0, pixeldepth1, dither, aux8, aux9, 0);
	gl_FragData[2] = getVolumetricCloud(pixeldepth0, pixeldepth1, dither, aux8, aux9, 1);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif