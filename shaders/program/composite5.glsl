/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform int isEyeInWater;
uniform int worldTime;

#if defined WEATHER_PERBIOME
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna, isForest, isTaiga, isJungle;
#endif

uniform float blindFactor;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;

#ifdef DIRTY_LENS
uniform sampler2D depthtex2;
#endif

#ifdef LENS_FLARE
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
#endif

//Optifine Constants//
const bool colortex2Clear = false;

#ifdef AUTO_EXPOSURE
const bool colortex0MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float pw = 1.0 / viewWidth;
float ph = 1.0 / viewHeight;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

void UnderwaterDistort(inout vec2 texCoord) {
	vec2 originalTexCoord = texCoord;
	float strength = 1;
	#ifdef NETHER
	#ifdef NETHER_HEAT_WAVE
	strength = NETHER_HEAT_WAVE_STRENGTH;
	#endif
	#endif

	texCoord += vec2(
		cos(texCoord.y * 32.0 + frameTimeCounter * 3.0),
		sin(texCoord.x * 32.0 + frameTimeCounter * 1.7)
	) * 0.001 * strength;

	float mask = float(
		texCoord.x > 0.0 && texCoord.x < 1.0 &&
	    texCoord.y > 0.0 && texCoord.y < 1.0
	)
	;
	if (mask < 0.5) texCoord = originalTexCoord;
}

vec3 GetBloomTile(float lod, vec2 coord, vec2 offset) {
	float scale = exp2(lod);
	float resScale = 1.25 * min(360.0, viewHeight) / viewHeight;
	vec2 centerOffset = vec2(0.25 * pw, 0.25 * ph);
	vec3 bloom = texture2D(colortex1, (coord / scale + offset) * resScale + centerOffset).rgb;
	return pow(bloom, vec3(4.0)) * 64.0;
}

void Bloom(inout vec3 color, vec2 coord) {
	float strength = BLOOM_STRENGTH;

	#ifdef BLOOM_BALANCING
	strength *= (1.00 - eBS * 0.75);
	float isEnd = 1;
	#ifdef END
	isEnd = 0.25;
	#endif
	strength *= isEnd;
	#endif

	vec3 blur1 = GetBloomTile(1.0, coord, vec2(0.0      , 0.0   )) * 1.5;
	vec3 blur2 = GetBloomTile(2.0, coord, vec2(0.51     , 0.0   )) * 1.2;
	vec3 blur3 = GetBloomTile(3.0, coord, vec2(0.51     , 0.26  ));
	vec3 blur4 = GetBloomTile(4.0, coord, vec2(0.645    , 0.26  ));
	vec3 blur5 = GetBloomTile(5.0, coord, vec2(0.7175   , 0.26  ));
	vec3 blur6 = GetBloomTile(6.0, coord, vec2(0.645    , 0.3325)) * 0.9;
	vec3 blur7 = GetBloomTile(7.0, coord, vec2(0.670625 , 0.3325)) * 0.7;
	
	#ifdef DIRTY_LENS
	float newAspectRatio = 1.777777777777778 / aspectRatio;
	vec2 scale = vec2(max(newAspectRatio, 1.0), max(1.0 / newAspectRatio, 1.0));
	float dirt = texture2D(depthtex2, (coord - 0.5) / scale + 0.5).r;
	dirt *= length(blur6 / (1.0 + blur6));
	blur3 *= dirt *  1.0 + 1.0;
	blur4 *= dirt *  2.0 + 1.0;
	blur5 *= dirt *  4.0 + 1.0;
	blur6 *= dirt *  8.0 + 1.0;
	blur7 *= dirt * 16.0 + 1.0;
	#endif

	#if BLOOM_RADIUS == 1
	vec3 blur = blur1 * 0.667;
	#elif BLOOM_RADIUS == 2
	vec3 blur = (blur1 + blur2) * 0.37;
	#elif BLOOM_RADIUS == 3
	vec3 blur = (blur1 + blur2 + blur3) * 0.27;
	#elif BLOOM_RADIUS == 4
	vec3 blur = (blur1 + blur2 + blur3 + blur4) * 0.212;
	#elif BLOOM_RADIUS == 5
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5) * 0.175;
	#elif BLOOM_RADIUS == 6
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6) * 0.151;
	#elif BLOOM_RADIUS == 7
	vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7) * 0.137;
	#endif

	#ifdef BLOOM_FLICKERING
    float jitter = 1.0 - sin(frameTimeCounter + cos(frameTimeCounter)) * BLOOM_FLICKERING_STRENGTH;
    strength *= jitter;
	#endif

	#if BLOOM_CONTRAST == 0
	color = mix(color, blur, 0.25 * strength);
	#else
	vec3 bloomContrast = vec3(exp2(BLOOM_CONTRAST * 0.25));
	color = pow(color, bloomContrast);
	blur = pow(blur, bloomContrast);
	vec3 bloomStrength = pow(vec3(0.2 * strength), bloomContrast);
	color = mix(color, blur, bloomStrength);
	color = pow(color, 1.0 / bloomContrast);
	#endif
}

void AutoExposure(inout vec3 color, inout float exposure, float tempExposure) {
	float exposureLod = log2(viewHeight * 0.7);
	
	exposure = length(texture2DLod(colortex0, vec2(0.5), exposureLod).rgb);
	exposure = clamp(exposure, 0.0001, 10.0);
	
	color /= 2.0 * clamp(tempExposure, 0.001, 10.0) + 0.125;
}

void ColorGrading(inout vec3 color) {
	vec3 cgColor = pow(color.r, CG_RC) * pow(vec3(CG_RR, CG_RG, CG_RB) / 255.0, vec3(2.2)) +
				   pow(color.g, CG_GC) * pow(vec3(CG_GR, CG_GG, CG_GB) / 255.0, vec3(2.2)) +
				   pow(color.b, CG_BC) * pow(vec3(CG_BR, CG_BG, CG_BB) / 255.0, vec3(2.2));
	vec3 cgMin = pow(vec3(CG_RM, CG_GM, CG_BM) / 255.0, vec3(2.2));
	color = (cgColor * (1.0 - cgMin) + cgMin) * vec3(CG_RI, CG_GI, CG_BI);
	
	vec3 cgTint = pow(vec3(CG_TR, CG_TG, CG_TB) / 255.0, vec3(2.2)) * GetLuminance(color) * CG_TI;
	color = mix(color, cgTint, CG_TM);
}

void BSLTonemap(inout vec3 color) {
	color = color * exp2(2.0 + EXPOSURE);
	color = color / pow(pow(color, vec3(TONEMAP_WHITE_CURVE)) + 1.0, vec3(1.0 / TONEMAP_WHITE_CURVE));
	color = pow(color, mix(vec3(TONEMAP_LOWER_CURVE), vec3(TONEMAP_UPPER_CURVE), sqrt(color)));
}

void ColorSaturation(inout vec3 color) {
	float grayVibrance = (color.r + color.g + color.b) / 3.0;
	float graySaturation = grayVibrance;
	if (SATURATION < 1.00) graySaturation = dot(color, vec3(0.299, 0.587, 0.114));

	float mn = min(color.r, min(color.g, color.b));
	float mx = max(color.r, max(color.g, color.b));
	float sat = (1.0 - (mx - mn)) * (1.0 - mx) * grayVibrance * 5.0;
	vec3 lightness = vec3((mn + mx) * 0.5);

	color = mix(color, mix(color, lightness, 1.0 - VIBRANCE), sat);
	color = mix(color, lightness, (1.0 - lightness) * (2.0 - VIBRANCE) / 2.0 * abs(VIBRANCE - 1.0));
	color = color * SATURATION - graySaturation * (SATURATION - 1.0);
}

#ifdef LENS_FLARE
vec2 GetLightPos() {
	vec4 tpos = gbufferProjection * vec4(sunPosition, 1.0);
	tpos.xyz /= tpos.w;
	return tpos.xy / tpos.z * 0.5;
}
#endif

//Includes//
#include "/lib/prismarine/timeCalculations.glsl"
#include "/lib/color/lightColor.glsl"

#ifdef LENS_FLARE
#include "/lib/post/lensFlare.glsl"
#endif

//Program//
void main() {
    vec2 newTexCoord = texCoord;
	if (isEyeInWater == 1.0) UnderwaterDistort(newTexCoord);

	#if defined NETHER && defined NETHER_HEAT_WAVE
	UnderwaterDistort(newTexCoord);
	#endif
	
	vec3 color = texture2D(colortex0, newTexCoord).rgb;
	
	#ifdef AUTO_EXPOSURE
	float tempExposure = texture2D(colortex2, vec2(pw, ph)).r;
	#endif

	#ifdef LENS_FLARE
	float tempVisibleSun = texture2D(colortex2, vec2(3.0 * pw, ph)).r;
	#endif

	vec3 temporalColor = vec3(0.0);
	
	#ifdef TAA
	temporalColor = texture2D(colortex2, texCoord).gba;
	#endif
	
	#ifdef BLOOM
	Bloom(color, newTexCoord);
	#endif
	
	#ifdef AUTO_EXPOSURE
	float exposure = 1.0;
	AutoExposure(color, exposure, tempExposure);
	#endif
	
	#ifdef COLOR_GRADING
	ColorGrading(color);
	#endif
	
	BSLTonemap(color);
	
	#ifdef LENS_FLARE
	vec2 lightPos = GetLightPos();
	float truePos = sign(sunVec.z);
	      
    float visibleSun = float(texture2D(depthtex0, lightPos + 0.5).r >= 1.0);
	visibleSun *= max(1.0 - isEyeInWater, eBS) * (1.0 - blindFactor) * (1.0 - rainStrength);
	
	float multiplier = tempVisibleSun * LENS_FLARE_STRENGTH * 0.5;

	if (multiplier > 0.001) LensFlare(color, lightPos, truePos, multiplier);
	#endif
	
	float temporalData = 0.0;
	
	#ifdef AUTO_EXPOSURE
	if (texCoord.x < 2.0 * pw && texCoord.y < 2.0 * ph)
		temporalData = mix(tempExposure, sqrt(exposure), 0.033);
	#endif

	#ifdef LENS_FLARE
	if (texCoord.x > 2.0 * pw && texCoord.x < 4.0 * pw && texCoord.y < 2.0 * ph)
		temporalData = mix(tempVisibleSun, visibleSun, 0.125);
	#endif
	
    #ifdef VIGNETTE
    color *= 1.0 - length(texCoord - 0.5) * (1.0 - GetLuminance(color));
	#endif
	
	color = pow(color, vec3(1.0 / 2.2));
	
	ColorSaturation(color);
	
	float filmGrain = texture2D(noisetex, texCoord * vec2(viewWidth, viewHeight) / 512.0).b;
	color += (filmGrain - 0.25) / 128.0;
	
	/* DRAWBUFFERS:12 */
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(temporalData, temporalColor);
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