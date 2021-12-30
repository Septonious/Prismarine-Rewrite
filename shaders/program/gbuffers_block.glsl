/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int blockEntityId;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

#if defined WEATHER_PERBIOME || FOG_COLOR_MODE == 2 || SKY_COLOR_MODE == 1
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna, isForest, isTaiga, isJungle;
#endif

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D noisetex;

#ifdef ADVANCED_MATERIALS
uniform ivec2 atlasSize;

uniform sampler2D specular;
uniform sampler2D normals;
#endif

#ifdef DYNAMIC_HANDLIGHT
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp((dot( sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#ifdef ADVANCED_MATERIALS
vec2 dcdx = dFdx(texCoord);
vec2 dcdy = dFdy(texCoord);
#endif

vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float InterleavedGradientNoise() {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 8.0);
}

//Includes//
#include "/lib/color/blocklightColor.glsl"
#include "/lib/prismarine/timeCalculations.glsl"
#include "/lib/color/dimensionColor.glsl"
#include "/lib/color/specularColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/lighting/forwardLighting.glsl"
#include "/lib/surface/ggx.glsl"

#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/util/encode.glsl"
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/materialGbuffers.glsl"
#include "/lib/surface/parallax.glsl"
#endif

#ifdef NORMAL_SKIP
#undef PARALLAX
#undef SELF_SHADOW
#endif

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * color;
	vec3 newNormal = normal;
	float smoothness = 0.0;

	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float surfaceDepth = 1.0;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);

	#if MC_VERSION >= 11300
	float skipAdvMat = float(blockEntityId == 10401);
	#else
	float skipAdvMat = float(blockEntityId == 63 || blockEntityId == 68);
	#endif
	
	#ifdef PARALLAX
	if (skipAdvMat < 0.5) {
		newCoord = GetParallaxCoord(parallaxFade, surfaceDepth);
		albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * color;
	}
	#endif

	float skyOcclusion = 0.0;
	vec3 fresnel3 = vec3(0.0);
	#endif

	if(blockEntityId == 10402) albedo.a = 0.0;

	if (albedo.a > 0.001) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));
		
		float metalness      = 0.0;
		float emission       = float(blockEntityId == 10205);
		float subsurface     = float(blockEntityId == 10109) * 0.5;
		vec3 baseReflectance = vec3(0.04);
		
		emission *= dot(albedo.rgb, albedo.rgb) * 0.333;

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#ifdef TAA
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);

		#ifdef ADVANCED_MATERIALS
		float f0 = 0.0, porosity = 0.5, ao = 1.0;
		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		
		GetMaterials(smoothness, metalness, f0, emission, subsurface, porosity, ao, normalMap,
					 newCoord, dcdx, dcdy);

		#ifdef NORMAL_SKIP
		normalMap = vec3(0.0, 0.0, 1.0);
		#endif
		
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

		if (normalMap.x > -0.999 && normalMap.y > -0.999)
			newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		#endif
		
		#ifdef DYNAMIC_HANDLIGHT
		float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
		float handlight = clamp((heldLightValue - 2.0 * length(viewPos)) / 15.0, 0.0, 0.9333);
		lightmap.x = max(lightmap.x, handlight);
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.35);
		#endif
		
		float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);

		float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse;

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
		vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
		albedo.rgb *= ao;

		#ifdef REFLECTION_SPECULAR
		albedo.rgb *= 1.0 - metalness * smoothness;
		#endif

		float doParallax = 0.0;
		#ifdef SELF_SHADOW
		#ifdef OVERWORLD
		doParallax = float(lightmap.y > 0.0 && NoL > 0.0);
		#endif
		#ifdef END
		doParallax = float(NoL > 0.0);
		#endif
		
		if (doParallax > 0.5) {
			parallaxShadow = GetParallaxShadow(surfaceDepth, parallaxFade, newCoord, lightVec,
											   tbnMatrix);
		}
		#endif
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NoL, vanillaDiffuse,
				    parallaxShadow, emission, subsurface);

		#ifdef ADVANCED_MATERIALS
		skyOcclusion = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);

		baseReflectance = mix(vec3(f0), rawAlbedo, metalness);
		float fresnel = pow(clamp(1.0 + dot(newNormal, normalize(viewPos.xyz)), 0.0, 1.0), 5.0);

		fresnel3 = mix(baseReflectance, vec3(1.0), fresnel);
		#if MATERIAL_FORMAT == 1
		if (f0 >= 0.9 && f0 < 1.0) {
			baseReflectance = GetMetalCol(f0);
			fresnel3 = ComplexFresnel(pow(fresnel, 0.2), f0);
			#ifdef ALBEDO_METAL
			fresnel3 *= rawAlbedo;
			#endif
		}
		#endif
		
		float aoSquared = ao * ao;
		shadow *= aoSquared; fresnel3 *= aoSquared;
		albedo.rgb = albedo.rgb * (1.0 - fresnel3 * smoothness * smoothness * (1.0 - metalness));
		#endif

		#if (defined OVERWORLD || defined END) && (defined ADVANCED_MATERIALS || defined SPECULAR_HIGHLIGHT_ROUGH)
		vec3 specularColor = GetSpecularColor(lightmap.y, metalness, baseReflectance);
		
		albedo.rgb += GetSpecularHighlight(newNormal, viewPos, smoothness, baseReflectance,
										   specularColor, shadow * vanillaDiffuse, color.a);
		#endif

		#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR && defined REFLECTION_ROUGH
		normalMap = mix(vec3(0.0, 0.0, 1.0), normalMap, smoothness);
		newNormal = clamp(normalize(normalMap * tbnMatrix), vec3(-1.0), vec3(1.0));
		#endif

		#if ALPHA_BLEND == 0
		albedo.rgb = pow(max(albedo.rgb, vec3(0.0)), vec3(1.0 / 2.2));
		if(blockEntityId == 10205) albedo.a = sqrt(albedo.a);
		#endif
	}

	if(blockEntityId == 10402) {
		vec2 portalCoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
		portalCoord = (portalCoord - 0.5) * vec2(aspectRatio, 1.0);

		vec3 portColSqrt = vec3(END_R, END_G, END_B) / 255.0 * END_I;
		vec3 portCol = portColSqrt * portColSqrt * 0.05;
		vec2 wind = vec2(0.0, frametime * 0.025);

		float portal = texture2D(noisetex, portalCoord * 0.1 + wind * 0.05).r * 0.25 + 0.375;

		#ifdef END
			  portal *= 0.5;
		#endif
			  
			  portal+= texture2D(texture, portalCoord * 0.5 + wind).r * 1.4;
			  portal+= texture2D(texture, portalCoord + wind + 0.15).r;
			  portal+= texture2D(texture, portalCoord * 2.0 + wind + 0.30).r * 0.7;
			  portal+= texture2D(texture, portalCoord * 4.0 + wind + 0.45).r * 0.5;
		
		albedo.rgb = portal * portal * portCol.rgb;
		albedo.a = 1.0;
		
		#if ALPHA_BLEND == 0
		albedo.rgb = pow(max(albedo.rgb, vec3(0.0)), vec3(1.0 / 2.2));
		#endif
	}

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(smoothness, skyOcclusion, 0.0, 1.0);
	gl_FragData[2] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(fresnel3, 1.0);
	#endif
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;

varying vec4 vTexCoord, vTexCoordAM;
#endif

//Uniforms//
uniform int worldTime;

uniform float frameTimeCounter;
uniform float timeAngle;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#ifdef TAA
uniform int frameCounter;

uniform float viewWidth, viewHeight;
#endif

//Attributes//
attribute vec4 mc_Entity;

#ifdef ADVANCED_MATERIALS
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;
#endif

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#ifdef TAA
#include "/lib/util/jitter.glsl"
#endif

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, vec2(0.0), vec2(0.9333, 1.0));

	normal = normalize(gl_NormalMatrix * gl_Normal);

	#ifdef ADVANCED_MATERIALS
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);

	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

    #ifdef WORLD_CURVATURE
	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	position.y -= WorldCurvature(position.xz);
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	#else
	gl_Position = ftransform();
    #endif
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif