/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

#if defined WEATHER_PERBIOME || FOG_COLOR_MODE == 2 || SKY_COLOR_MODE == 1 || defined PERBIOME_LIGHTSHAFTS
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna, isForest, isTaiga, isJungle;
#endif

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec, lightVec;

//Uniforms//
uniform int frameCounter;
uniform int blockEntityId;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor, nightVision;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1, depthtex2;

uniform sampler2D noisetex;

#if FOG_MODE == 1 || FOG_MODE == 2 || defined FIREFLIES
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

//Optifine Constants//
const bool colortex5Clear = false;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef REFRACTION
float GetWaterHeightMap(vec3 worldPos, vec2 offset) {
    float noise = 0.0;
    
    vec2 wind = vec2(frametime) * 0.5 * WATER_SPEED;

	worldPos.xz -= worldPos.y * 0.2;

	#if WATER_NORMALS == 1
	offset /= 256.0;
	float noiseA = texture2D(noisetex, (worldPos.xz - wind) / 256.0 + offset).g;
	float noiseB = texture2D(noisetex, (worldPos.xz + wind) / 48.0 + offset).g;
	#elif WATER_NORMALS == 2
	offset /= 256.0;
	float noiseA = texture2D(noisetex, (worldPos.xz - wind) / 256.0 + offset).r;
	float noiseB = texture2D(noisetex, (worldPos.xz + wind) / 96.0 + offset).r;
	noiseA *= noiseA; noiseB *= noiseB;
	#endif

	#if WATER_NORMALS > 0
	noise = mix(noiseA, noiseB, WATER_DETAIL);
	#endif

    return noise * WATER_BUMP;
}

vec2 getRefract(vec2 coord, vec3 waterPos, vec4 viewPos, float z0, float z1){
	float depthFactor = clamp(32 - clamp(length(viewPos.xyz), 0, 31.95), 0, 1);
	float normalOffset = WATER_SHARPNESS;
	float h1 = GetWaterHeightMap(waterPos, vec2( normalOffset, 0.0));
	float h2 = GetWaterHeightMap(waterPos, vec2(-normalOffset, 0.0));
	float h3 = GetWaterHeightMap(waterPos, vec2(0.0,  normalOffset));
	float h4 = GetWaterHeightMap(waterPos, vec2(0.0, -normalOffset));

	float xDelta = (h2 - h1) / normalOffset;
	float yDelta = (h4 - h3) / normalOffset;

	vec2 noise = vec2(xDelta, yDelta);

	vec2 waveN = noise * REFRACTION_STRENGTH * 0.025 * depthFactor * (1 - (z1 - z0));

	return coord + waveN;
}
#endif

//Includes//
#include "/lib/prismarine/timeCalculations.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/skyColor.glsl"
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"

#if FOG_MODE == 1 || FOG_MODE == 2 || defined FIREFLIES
vec3 lightshaftMorninga  = vec3(LIGHTSHAFTAMBIENT_MR, LIGHTSHAFTAMBIENT_MG, LIGHTSHAFTAMBIENT_MB) * LIGHTSHAFTAMBIENT_MI / 255.0;
vec3 lightshaftDaya      = vec3(LIGHTSHAFTAMBIENT_DR, LIGHTSHAFTAMBIENT_DG, LIGHTSHAFTAMBIENT_DB) * LIGHTSHAFTAMBIENT_DI / 255.0;
vec3 lightshaftEveninga  = vec3(LIGHTSHAFTAMBIENT_ER, LIGHTSHAFTAMBIENT_EG, LIGHTSHAFTAMBIENT_EB) * LIGHTSHAFTAMBIENT_EI / 255.0;
vec3 lightshaftNighta    = vec3(LIGHTSHAFTAMBIENT_NR, LIGHTSHAFTAMBIENT_NG, LIGHTSHAFTAMBIENT_NB) * LIGHTSHAFTAMBIENT_NI * 0.3 / 255.0;
vec3 lightshaftCola = CalcLightColor(CalcSunColor(lightshaftMorninga, lightshaftDaya, lightshaftEveninga), lightshaftNighta, vec3(1));

#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#ifdef REFRACTION
#include "/lib/util/spaceConversion.glsl"
#endif

#ifdef OUTLINE_ENABLED
#include "/lib/color/blocklightColor.glsl"
#include "/lib/util/outlineOffset.glsl"
#include "/lib/util/outlineMask.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/post/outline.glsl"
#endif

//Program//
void main() {
    vec4 color = texture2D(colortex0, texCoord);
    vec3 translucent = texture2D(colortex1, texCoord).rgb;
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;
	vec3 vl = vec3(0.0);

	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;
	
	#if ALPHA_BLEND == 0
	color.rgb = pow(color.rgb, vec3(2.2));
	#endif

	#ifdef OUTLINE_ENABLED
	vec4 outerOutline = vec4(0.0), innerOutline = vec4(0.0);
	float outlineMask = GetOutlineMask();
	if (outlineMask > 0.5 || isEyeInWater > 0.5)
		Outline(color.rgb, true, outerOutline, innerOutline);

	if(z1 > z0) color.rgb = mix(color.rgb, innerOutline.rgb, innerOutline.a);
	#endif

	if (isEyeInWater == 1.0) {
		vec4 waterFog = GetWaterFog(viewPos.xyz);
		color.rgb = mix(color.rgb, waterFog.rgb, waterFog.a);
	}

	#ifdef OUTLINE_ENABLED
	color.rgb = mix(color.rgb, outerOutline.rgb, outerOutline.a);
	#endif

	#if ((FOG_MODE == 1 || FOG_MODE == 2) && defined OVERWORLD) || (defined END_VOLUMETRIC_FOG && defined END) || (defined OVERWORLD && defined FIREFLIES)
	float dayVis0 = 0;
	float nightVis0 = 0;
	
	#ifdef LIGHTSHAFT_NIGHT
	nightVis0 = 1;
	#endif

	#ifdef LIGHTSHAFT_DAY
	dayVis0 = 1;
	#endif

	float visibility0 = CalcTotalAmount(CalcDayAmount(1, dayVis0, 1), nightVis0);
	if (isEyeInWater == 1) visibility0 = 1;

	#ifdef END
	visibility0 = 1;
	#endif
	
	float dither = Bayer64(gl_FragCoord.xy);
	if (visibility0 > 0) vl = GetLightShafts(z0, z1, translucent, dither);
	#endif

	#if defined FIREFLIES && defined OVERWORLD
	if (visibility0 == 0) {
		float visibility1 = (1 - sunVisibility) * (1 - rainStrength) * (0 + eBS) * (1 - isEyeInWater);
		if (visibility1 > 0) vl = GetFireflies(z0, translucent, dither);
	}
	#endif

	#ifdef REFRACTION
	vec3 worldPos = ToWorld(viewPos.xyz);

	if (z0 < z1 && translucent.r < 0.25){
		vec2 refractionCoord = getRefract(texCoord.xy, worldPos + cameraPosition, viewPos, z0, z0);
		color.rgb = texture2D(colortex0, refractionCoord).rgb;
		if (isEyeInWater == 1){
			color.rgb *= waterColor.rgb * 16 * eBS;
		}
	}
	#endif

	#ifdef OVERWORLD
	if (z0 < z1 && translucent.r < 0.25 && isEyeInWater == 0){
		vec3 newColor = waterColor.rgb * (1.00 - rainStrength * 0.50) * 0.5 * timeBrightness * (1 - (z1 - z0));
		color.rgb += newColor;
	}
	if (isEyeInWater == 1) color.rgb *= waterColor.rgb * 15 * (0.25 + timeBrightness);
	#endif

	vec3 reflectionColor = pow(color.rgb, vec3(0.125)) * 0.5;
	
    /*DRAWBUFFERS:01*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);
	
    #ifdef REFLECTION_PREVIOUS
    /*DRAWBUFFERS:015*/
	gl_FragData[2] = vec4(reflectionColor, float(z0 < 1.0));
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
