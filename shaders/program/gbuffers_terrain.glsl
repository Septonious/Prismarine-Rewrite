/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat, recolor;

#ifdef INTEGRATED_EMISSION
varying float isPlant;
#endif

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#ifdef ADVANCED_MATERIALS
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;
#endif

//Uniforms//
uniform int frameCounter;
uniform int worldTime;
uniform int isEyeInWater;

#if defined WEATHER_PERBIOME || FOG_COLOR_MODE == 2
uniform float isDesert, isMesa, isCold, isSwamp, isMushroom, isSavanna, isForest, isTaiga, isJungle;
#endif

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture, noisetex;

#if defined ADVANCED_MATERIALS || defined NOISY_TEXTURES
uniform ivec2 atlasSize;
#endif

#ifdef ADVANCED_MATERIALS
uniform sampler2D specular;
uniform sampler2D normals;

#ifdef REFLECTION_RAIN
uniform float wetness;

uniform mat4 gbufferModelView;
#endif
#endif

#ifdef DYNAMIC_HANDLIGHT
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
#endif

#if defined ADVANCED_MATERIALS || defined NOISY_TEXTURES
varying vec4 vTexCoord, vTexCoordAM;
float atlasRatio = atlasSize.x / atlasSize.y;
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
#ifdef EMISSIVE_CONCRETE
#endif
//Includes//
#ifdef OVERWORLD
#include "/lib/color/waterColor.glsl"
#endif

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

#if defined ADVANCED_MATERIALS || (defined SSGI && !defined ADVANCED_MATERIALS)
#include "/lib/util/encode.glsl"
#endif

#ifdef ADVANCED_MATERIALS
#include "/lib/reflections/complexFresnel.glsl"
#include "/lib/surface/directionalLightmap.glsl"
#include "/lib/surface/materialGbuffers.glsl"
#include "/lib/surface/parallax.glsl"

#ifdef REFLECTION_RAIN
#include "/lib/reflections/rainPuddles.glsl"
#endif
#endif

/*
tysm emin for allowing me to use your ipbr code!
⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠛⠛⠛⠋⠉⠈⠉⠉⠉⠉⠛⠻⢿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⡿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⢿⣿⣿⣿⣿
⣿⣿⣿⣿⡏⣀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿
⣿⣿⣿⢏⣴⣿⣷⠀⠀⠀⠀⠀⢾⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠈⣿⣿
⣿⣿⣟⣾⣿⡟⠁⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣷⢢⠀⠀⠀⠀⠀⠀⠀⢸⣿
⣿⣿⣿⣿⣟⠀⡴⠄⠀⠀⠀⠀⠀⠀⠙⠻⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⣿
⣿⣿⣿⠟⠻⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠶⢴⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⣿
⣿⣁⡀⠀⠀⢰⢠⣦⠀⠀⠀⠀⠀⠀⠀⠀⢀⣼⣿⣿⣿⣿⣿⡄⠀⣴⣶⣿⡄⣿
⣿⡋⠀⠀⠀⠎⢸⣿⡆⠀⠀⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⠗⢘⣿⣟⠛⠿⣼
⣿⣿⠋⢀⡌⢰⣿⡿⢿⡀⠀⠀⠀⠀⠀⠙⠿⣿⣿⣿⣿⣿⡇⠀⢸⣿⣿⣧⢀⣼
⣿⣿⣷⢻⠄⠘⠛⠋⠛⠃⠀⠀⠀⠀⠀⢿⣧⠈⠉⠙⠛⠋⠀⠀⠀⣿⣿⣿⣿⣿
⣿⣿⣧⠀⠈⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠟⠀⠀⠀⠀⢀⢃⠀⠀⢸⣿⣿⣿⣿
⣿⣿⡿⠀⠴⢗⣠⣤⣴⡶⠶⠖⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⡸⠀⣿⣿⣿⣿
⣿⣿⣿⡀⢠⣾⣿⠏⠀⠠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠛⠉⠀⣿⣿⣿⣿
⣿⣿⣿⣧⠈⢹⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⣿⣿⣿⣿
⣿⣿⣿⣿⡄⠈⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣾⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣦⣄⣀⣀⣀⣀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠙⣿⣿⡟⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⠁⠀⠀⠹⣿⠃⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⣿⣿⣿⣿⡿⠛⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⢐⣿⣿⣿⣿⣿⣿⣿⣿⣿
⣿⣿⣿⣿⠿⠛⠉⠉⠁⠀⢻⣿⡇⠀⠀⠀⠀⠀⠀⢀⠈⣿⣿⡿⠉⠛⠛⠛⠉⠉
⣿⡿⠋⠁⠀⠀⢀⣀⣠⡴⣸⣿⣇⡄⠀⠀⠀⠀⢀⡿⠄⠙⠛⠀⣀⣠⣤⣤⠄⠀
*/

//Program//
void main() {
    vec4 albedo = texture2D(texture, texCoord) * vec4(color.rgb, 1.0);
	
	vec3 newNormal = normal;
	float smoothness = 0.0;

	#ifdef ADVANCED_MATERIALS
	vec2 newCoord = vTexCoord.st * vTexCoordAM.pq + vTexCoordAM.st;
	float surfaceDepth = 1.0;
	float parallaxFade = clamp((dist - PARALLAX_DISTANCE) / 32.0, 0.0, 1.0);
	float skipAdvMat = float(mat > 3.98 && mat < 4.02);
	
	#ifdef PARALLAX
	if(skipAdvMat < 0.5) {
		newCoord = GetParallaxCoord(parallaxFade, surfaceDepth);
		albedo = texture2DGradARB(texture, newCoord, dcdx, dcdy) * vec4(color.rgb, 1.0);
	}
	#endif

	float skyOcclusion = 0.0;
	vec3 fresnel3 = vec3(0.0);
	#endif

	float emissive = 0.0; float lava = 0.0;

	if (albedo.a > 0.001) {
		vec2 lightmap = clamp(lmCoord, vec2(0.0), vec2(1.0));

		#ifdef OVERWORLD
		if (isEyeInWater == 1) lightmap.y = clamp(lightmap.y, 0.15, 1.00);
		#endif
		
		float foliage  = float(mat > 0.98 && mat < 1.02);
		float leaves   = float(mat > 1.98 && mat < 2.02);
			  emissive = float(mat > 2.98 && mat < 3.02);
			  lava     = float(mat > 3.98 && mat < 4.02);
		float candle   = float(mat > 4.98 && mat < 5.02);

		vec3 screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
		#ifdef TAA
		vec3 viewPos = ToNDC(vec3(TAAJitter(screenPos.xy, -0.5), screenPos.z));
		#else
		vec3 viewPos = ToNDC(screenPos);
		#endif
		vec3 worldPos = ToWorld(viewPos);

		#ifdef INTEGRATED_EMISSION
		float iEmissive = 0.0;
        if (mat > 99.9 && mat < 100.1) { // Emissive Ores
            float stoneDif = max(abs(albedo.r - albedo.g), max(abs(albedo.r - albedo.b), abs(albedo.g - albedo.b)));
            float ore = max(max(stoneDif - 0.175, 0.0), 0.0);
            iEmissive = sqrt(ore) * GLOW_STRENGTH;
        } else if (mat > 100.9 && mat < 101.1){ // Crying Obsidian and Respawn Anchor
			iEmissive = (albedo.b - albedo.r) * albedo.r * GLOW_STRENGTH;
            iEmissive *= iEmissive * iEmissive * GLOW_STRENGTH;
		} else if (mat > 101.9 && mat < 102.1){
            vec3 comPos = fract(worldPos.xyz + cameraPosition.xyz);
            comPos = abs(comPos - vec3(0.5));
            float comPosM = min(max(comPos.x, comPos.y), min(max(comPos.x, comPos.z), max(comPos.y, comPos.z)));
            iEmissive = 0.0;
            if (comPosM < 0.1882) { // Command Block Center
                vec3 dif = vec3(albedo.r - albedo.b, albedo.r - albedo.g, albedo.b - albedo.g);
                dif = abs(dif);
                iEmissive = float(max(dif.r, max(dif.g, dif.b)) > 0.1) * 25.0;
                iEmissive *= float(albedo.r > 0.44 || albedo.g > 0.29);
				iEmissive *= 0.5;
            }
		} else if (mat > 102.9 && mat < 103.1){
            float core = float(albedo.r < 0.1);
            float edge = float(albedo.b > 0.35 && albedo.b < 0.401 && core == 0.0);
            iEmissive = (core * 0.195 + 0.035 * edge);
			iEmissive *= 8.0 * GLOW_STRENGTH;
		} else if (mat > 103.9 && mat < 104.1){
            iEmissive = float(albedo.b < 0.16);
            iEmissive = min(pow(length(albedo.rgb) * length(albedo.rgb), 2.0) * iEmissive * GLOW_STRENGTH, 0.3);
			iEmissive *= 8.0 * GLOW_STRENGTH;
		} else if (mat > 104.9 && mat < 105.1){ // Warped Nether Warts
			iEmissive = pow(float(albedo.g - albedo.b), 2) * GLOW_STRENGTH;
		} else if (mat > 105.9 && mat < 106.1){ // Warped Nylium
			if (albedo.g > albedo.b && albedo.g > albedo.r){
				iEmissive = pow(float(albedo.g - albedo.b), 3.0) * GLOW_STRENGTH;
			}
		} else if (mat > 107.9 && mat < 108.1){ // Amethyst
			iEmissive = float(length(albedo.rgb) > 0.975) * 0.25 * GLOW_STRENGTH;
		} else if (mat > 109.9 && mat < 110.1){ // Glow Lichen
			iEmissive = (1.0 - lightmap.y) * float(albedo.r > albedo.g || albedo.r > albedo.b) * 3.0;
		} else if (mat > 110.9 && mat < 111.1){
			iEmissive = float(albedo.r > albedo.g && albedo.r > albedo.b) * 0.2 * GLOW_STRENGTH;
		} else if (mat > 111.9 && mat < 112.1){ // Soul Emissives
			iEmissive = float(albedo.b > albedo.r || albedo.b > albedo.g) * 0.5 * GLOW_STRENGTH;
		} else if (mat > 112.9 && mat < 113.1) { // Brewing Stand
			iEmissive = float(albedo.r > 0.65) * 0.5 * GLOW_STRENGTH;
		} else if (mat > 113.9 && mat < 114.1) { // Glow berries
			iEmissive = float(albedo.r > albedo.g || albedo.r > albedo.b) * GLOW_STRENGTH;
		} else if (mat > 114.9 && mat < 115.1) { // Torches
			iEmissive = 32.0;
		}
		#ifdef OVERWORLD
		if (isPlant > 0.9 && isPlant < 1.1){ // Flowers
			iEmissive = float(albedo.b > albedo.g || albedo.r > albedo.g) * GLOW_STRENGTH * 0.1;
		}
		#endif
		emissive += iEmissive;
		#endif

		#ifdef TEST01
		if (mat > 106.9 && mat < 107.1) albedo.a *= 0.0;
		#endif

		#if (defined SSGI && !defined ADVANCED_MATERIALS) && defined EMISSIVE_CONCRETE
		if (mat > 9998.9) emissive = 16.0;
		#endif

		float metalness      = 0.0;
		float emission       = (emissive + candle + lava) * 0.4;
		float subsurface     = (foliage + candle) * 0.5 + leaves;
		vec3 baseReflectance = vec3(0.04);
		
		emission *= dot(albedo.rgb, albedo.rgb) * 0.333;

		#ifdef ADVANCED_MATERIALS
		float f0 = 0.0, porosity = 0.5, ao = 1.0;
		vec3 normalMap = vec3(0.0, 0.0, 1.0);
		GetMaterials(smoothness, metalness, f0, emission, subsurface, porosity, ao, normalMap,
					 newCoord, dcdx, dcdy);
		
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

		#ifdef TOON_LIGHTMAP
		lightmap = floor(lmCoord * 14.999 * (0.75 + 0.25 * color.a)) / 14.0;
		lightmap = clamp(lightmap, vec2(0.0), vec2(1.0));
		#endif

    	albedo.rgb = pow(albedo.rgb, vec3(2.2));

		float ec = GetLuminance(albedo.rgb) * 1.7;
		#ifdef EMISSIVE_RECOLOR
		if (recolor > 0.5) {
			albedo.rgb = blocklightCol * pow(ec, 1.5) / (BLOCKLIGHT_I * BLOCKLIGHT_I);
			albedo.rgb /= 0.7 * albedo.rgb + 0.7;
		}
		#else
		if (recolor > 0.5) {
			albedo.rgb *= 4.0;
		}
		#endif

		#ifdef WHITE_WORLD
		albedo.rgb = vec3(0.35);
		#endif
		
		vec3 outNormal = newNormal;
		#ifdef NORMAL_PLANTS
		if (foliage > 0.5){
			newNormal = upVec;
			
			#ifdef ADVANCED_MATERIALS
			newNormal = normalize(mix(outNormal, newNormal, normalMap.z * normalMap.z));
			#endif
		}
		#endif
		
		float NoL = clamp(dot(newNormal, lightVec), 0.0, 1.0);

		float NoU = clamp(dot(newNormal, upVec), -1.0, 1.0);
		float NoE = clamp(dot(newNormal, eastVec), -1.0, 1.0);
		float vanillaDiffuse = (0.25 * NoU + 0.75) + (0.667 - abs(NoE)) * (1.0 - abs(NoU)) * 0.15;
			  vanillaDiffuse*= vanillaDiffuse;
		
		#ifndef NORMAL_PLANTS
		if (foliage > 0.5) vanillaDiffuse *= 1.8;
		#endif

		float parallaxShadow = 1.0;
		#ifdef ADVANCED_MATERIALS
		vec3 rawAlbedo = albedo.rgb * 0.999 + 0.001;
		albedo.rgb *= ao * ao;

		#ifdef REFLECTION_SPECULAR
		albedo.rgb *= 1.0 - metalness * smoothness;
		#endif

		float doParallax = 0.0;
		#ifdef SELF_SHADOW
		float pNoL = dot(outNormal, lightVec);
		#ifdef OVERWORLD
		doParallax = float(lightmap.y > 0.0 && pNoL > 0.0);
		#endif
		#ifdef END
		doParallax = float(pNoL > 0.0);
		#endif
		
		if (doParallax > 0.5 && skipAdvMat < 0.5) {
			parallaxShadow = GetParallaxShadow(surfaceDepth, parallaxFade, newCoord, lightVec,
											   tbnMatrix);
		}
		#endif

		#ifdef DIRECTIONAL_LIGHTMAP
		mat3 lightmapTBN = GetLightmapTBN(viewPos);
		lightmap.x = DirectionalLightmap(lightmap.x, lmCoord.x, outNormal, lightmapTBN);
		lightmap.y = DirectionalLightmap(lightmap.y, lmCoord.y, outNormal, lightmapTBN);
		#endif
		#endif
		
		vec3 shadow = vec3(0.0);
		GetLighting(albedo.rgb, shadow, viewPos, worldPos, lightmap, color.a, NoL, vanillaDiffuse,
					parallaxShadow, emission, subsurface);
					
		#ifdef ADVANCED_MATERIALS
		float puddles = 0.0;
		#ifdef REFLECTION_RAIN
		float pNoU = dot(outNormal, upVec);
		if(wetness > 0.001) {
			puddles = GetPuddles(worldPos, newCoord, wetness) * clamp(pNoU, 0.0, 1.0);
		}
		
		#ifdef WEATHER_PERBIOME
		float weatherweight = isCold + isDesert + isMesa + isSavanna;
		puddles *= 1.0 - weatherweight;
		#endif
		
		puddles *= clamp(lightmap.y * 32.0 - 31.0, 0.0, 1.0) * (1.0 - lava);

		float ps = sqrt(1.0 - 0.75 * porosity);
		float pd = (0.5 * porosity + 0.15);	
		
		smoothness = mix(smoothness, 1.0, puddles * ps);
		f0 = max(f0, puddles * 0.02);

		albedo.rgb *= 1.0 - (puddles * pd);

		if (puddles > 0.001 && rainStrength > 0.001) {
			mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);

			vec3 puddleNormal = GetPuddleNormal(worldPos, viewPos, tbnMatrix);
			outNormal = normalize(
				mix(outNormal, puddleNormal, puddles * sqrt(1.0 - porosity) * rainStrength)
			);
		}
		#endif

		skyOcclusion = lightmap.y * lightmap.y * (3.0 - 2.0 * lightmap.y);
		
		baseReflectance = mix(vec3(f0), rawAlbedo, metalness);
		float fresnel = pow(clamp(1.0 + dot(outNormal, normalize(viewPos.xyz)), 0.0, 1.0), 5.0);

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
		newNormal = outNormal;
		if (normalMap.x > -0.999 && normalMap.y > -0.999) {
			normalMap = mix(vec3(0.0, 0.0, 1.0), normalMap, smoothness);
			newNormal = mix(normalMap * tbnMatrix, newNormal, 1.0 - pow(1.0 - puddles, 4.0));
			newNormal = clamp(normalize(newNormal), vec3(-1.0), vec3(1.0));
		}
		#endif

		#ifdef OVERWORLD
		float depth = clamp(length(viewPos.xyz), 0.0, 7.0);
		depth = 8.0 - depth;
		if (isEyeInWater == 1){
			float clampEyeBrightness = clamp(eBS, 0.1, 1.0);
			albedo.rgb *= vec3(waterColor.r * 2.00, waterColor.g * 1.50, waterColor.b * 0.50) * (6.0 - rainStrength - rainStrength) * clampEyeBrightness;
			albedo.rgb *= waterColor.rgb * waterColor.rgb * 512.0 * (0.25 + timeBrightness) + depth;
		}
		#endif

		#ifdef NOISY_TEXTURES
		if ((foliage < 0.1 && leaves < 0.1) || lava > 0.5){
			vec2 noiseCoord = vTexCoord.xy + 0.0025;
			noiseCoord = floor(noiseCoord.xy * 64.0 * vTexCoordAM.pq * 32.0 * vec2(2.0, 2.0 / atlasRatio)) / 5.25;
			/*
			if (lava > 0.5){
				noiseCoord = floor((vTexCoord.xy + 0.0025) * 32.0 * vTexCoordAM.pq * 16.0 * vec2(2.0, 2.0 / atlasRatio)) / 2.625;
				albedo.rgb = mix(albedo.rgb, vec3(1.6, 0.2, 0.0), 0.75);
				noiseCoord += vec2(frametime * 0.01, 0.0);
			}
			*/
			noiseCoord += 0.25 * (floor((worldPos.xz + cameraPosition.xz) + 0.001) + floor((worldPos.y + cameraPosition.y) + 0.001));
			float noise = texture2D(noisetex, noiseCoord).r + 0.6;
			if (lava > 0.5) noise = texture2D(noisetex, noiseCoord).r + 0.2;
			float noiseFactor = NOISE_STRENGTH * (1.0 - 0.5 * metalness) * (1.0 - 0.25 * smoothness) * max(1.0 - emissive, 0.0);
			noise = pow(noise, noiseFactor);
			albedo.rgb *= noise;
		}
		#endif

		#if ALPHA_BLEND == 0
		albedo.rgb = pow(max(albedo.rgb, vec3(0.0)), vec3(1.0 / 2.2));
		#endif
	} else albedo.a = 0.0;

    /* DRAWBUFFERS:0 */
    gl_FragData[0] = albedo;

	#if defined ADVANCED_MATERIALS && defined REFLECTION_SPECULAR
	/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(smoothness, skyOcclusion, 0.0, 1.0);
	gl_FragData[2] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[3] = vec4(fresnel3, 1.0);
	#endif

	#if defined SSGI && !defined ADVANCED_MATERIALS
	/* RENDERTARGETS:0,6,9,12 */
	gl_FragData[1] = vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);
	gl_FragData[2] = vec4(emissive + lava);
	gl_FragData[3] = albedo;
	#endif

}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat, recolor;

#ifdef INTEGRATED_EMISSION
varying float isPlant;
#endif

varying vec2 texCoord, lmCoord;

varying vec3 normal;
varying vec3 sunVec, upVec, eastVec;

varying vec4 color;

#if defined ADVANCED_MATERIALS || defined NOISY_TEXTURES
varying float dist;

varying vec3 binormal, tangent;
varying vec3 viewVector;
#endif

#if defined ADVANCED_MATERIALS || defined NOISY_TEXTURES
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
attribute vec4 mc_midTexCoord;

#if defined ADVANCED_MATERIALS || defined NOISY_TEXTURES
attribute vec4 at_tangent;
#endif

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

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

	#if defined ADVANCED_MATERIALS || defined NOISY_TEXTURES
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
	tangent  = normalize(gl_NormalMatrix * at_tangent.xyz);
	
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
								  
	viewVector = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;
	
	dist = length(gl_ModelViewMatrix * gl_Vertex);

	vec2 midCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texMinMidCoord = texCoord - midCoord;

	vTexCoordAM.pq  = abs(texMinMidCoord) * 2.0;
	vTexCoordAM.st  = min(texCoord, midCoord - texMinMidCoord);
	
	vTexCoord.xy    = sign(texMinMidCoord) * 0.5 + 0.5;
	#endif
    
	color = gl_Color;
	
	mat = 0.0; recolor = 0.0;

	if (mc_Entity.x >= 10100 && mc_Entity.x < 10200)
		mat = 1.0;
	if (mc_Entity.x == 10105 || mc_Entity.x == 10106){
		mat = 2.0;
		color.rgb *= 1.225;
	}
	if (mc_Entity.x >= 10200 && mc_Entity.x < 10300)
		mat = 3.0;
	if (mc_Entity.x == 10203)
		mat = 4.0;
	if (mc_Entity.x == 10208)
		mat = 5.0;

	if (mc_Entity.x == 10201 || mc_Entity.x == 10205 || mc_Entity.x == 10206)
		recolor = 1.0;

	if (mc_Entity.x == 10202)
		lmCoord.x -= 0.0667;

	if (mc_Entity.x == 10203)
		lmCoord.x += 0.0667;

	if (mc_Entity.x == 10400)
		color.a = 1.0;

	if (mc_Entity.x == 20007) mat = 107.0;

	#ifdef INTEGRATED_EMISSION
	isPlant = 0.0;
	if (mc_Entity.x == 20000) mat = 100.0;
	if (mc_Entity.x == 20001) mat = 101.0;
	if (mc_Entity.x == 20002) mat = 102.0;
	if (mc_Entity.x == 20003) mat = 103.0;
	if (mc_Entity.x == 20004) mat = 104.0;
	if (mc_Entity.x == 20005) mat = 105.0;
	if (mc_Entity.x == 20006) mat = 106.0;
	if (mc_Entity.x == 20008) mat = 108.0;
	if (mc_Entity.x == 20010) mat = 110.0;
	if (mc_Entity.x == 20011) mat = 111.0;
	if (mc_Entity.x == 20012) mat = 112.0;
	if (mc_Entity.x == 20013) mat = 113.0;
	if (mc_Entity.x == 20014) mat = 114.0;
	if (mc_Entity.x == 20015) mat = 115.0;
	if (mc_Entity.x == 10101) isPlant = 1.0;
	#endif

	#ifdef SSGI
	if (mc_Entity.x == 29999) mat = 9999.0;
	#endif

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	eastVec = normalize(gbufferModelView[0].xyz);

	vec4 position = gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = WavingBlocks(position.xyz, istopv);

    #ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
    #endif

	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#ifdef TAA
	gl_Position.xy = TAAJitter(gl_Position.xy, gl_Position.w);
	#endif
}

#endif