/* 
BSL Shaders v7.2.01 by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat;
uniform int worldTime;

varying vec2 texCoord;

varying vec4 position0;

varying vec4 color;

//Uniforms//
uniform int blockEntityId;
uniform int isEyeInWater;

uniform sampler2D tex;

#ifdef PROJECTED_CAUSTICS
uniform sampler2D noisetex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 cameraPosition;

uniform float frameTimeCounter, timeBrightness;

#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

#include "/lib/color/waterColor.glsl"
#include "/lib/util/spaceConversion.glsl"
#include "/lib/prismarine/caustics.glsl"
#endif

//Program//
void main() {
    #if MC_VERSION >= 11300
	if (blockEntityId == 10205) discard;
	#endif

    vec4 albedo = texture2D(tex, texCoord.xy);
	albedo.rgb *= color.rgb;

    float premult = float(mat > 0.98 && mat < 1.02);
	float disable = float(mat > 1.98 && mat < 2.02);
	float water = float (mat > 2.98);
	if (disable > 0.5 || albedo.a < 0.01) discard;

    #ifdef SHADOW_COLOR
	albedo.rgb = mix(vec3(1), albedo.rgb, pow(albedo.a, (1.0 - albedo.a) * 0.5) * COLORED_SHADOW_OPACITY * 2);
	albedo.rgb *= 1.0 - pow(albedo.a, 128.0);
	#else
	if ((premult > 0.5 && albedo.a < 0.98)) albedo.a = 0.0;
	#endif

	#ifdef PROJECTED_CAUSTICS
	if (water > 0.9){
		albedo.rgb = waterColor.rgb;
		albedo.rgb = getCaustics(position0.xyz + cameraPosition.xyz) * albedo.rgb * WATER_CAUSTICS_STRENGTH * (0.25 + timeBrightness);
	}
	#endif

	gl_FragData[0] = albedo * COLORED_SHADOW_BRIGHTNESS;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;

varying vec2 texCoord;
varying vec4 position0;
varying vec4 color;

//Uniforms//
uniform int worldTime;
uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#ifdef WORLD_TIME_ANIMATION
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;

	color = gl_Color;
	
	mat = 0;
	if (mc_Entity.x == 10301 || mc_Entity.x == 10302) mat = 1;
	if (mc_Entity.x == 10300 || mc_Entity.x == 10204) mat = 2;
	if (mc_Entity.x == 10303) mat = 3;
	
	position0 = shadowModelViewInverse * shadowProjectionInverse * ftransform();

	vec4 position = shadowModelViewInverse * shadowProjectionInverse * ftransform();
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz = WavingBlocks(position.xyz, istopv);

	#ifdef WORLD_CURVATURE
	position.y -= WorldCurvature(position.xz);
	#endif
	
	gl_Position = shadowProjection * shadowModelView * position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
	
	gl_Position.xy *= 1.0 / distortFactor;
	gl_Position.z = gl_Position.z * 0.2;
}

#endif