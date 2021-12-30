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

//Uniforms//
uniform float viewHeight, viewWidth, centerDepthSmooth, aspectRatio;
uniform int frameCounter;

uniform mat4 gbufferProjection, gbufferProjectionInverse, gbufferModelViewInverse, shadowModelView, shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D depthtex1, depthtex0;

#if defined FOG_BLUR && defined OVERWORLD
varying vec3 sunVec, upVec, cameraPosition;

uniform int isEyeInWater;

uniform float timeBrightness, timeAngle, rainStrength;

float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
#endif

//Optifine Constants//
const bool colortex0MipmapEnabled = true;

//Common Variables//
vec2 dofOffsets[60] = vec2[60](
	vec2( 0.0    ,  0.25  ),
	vec2(-0.2165 ,  0.125 ),
	vec2(-0.2165 , -0.125 ),
	vec2( 0      , -0.25  ),
	vec2( 0.2165 , -0.125 ),
	vec2( 0.2165 ,  0.125 ),
	vec2( 0      ,  0.5   ),
	vec2(-0.25   ,  0.433 ),
	vec2(-0.433  ,  0.25  ),
	vec2(-0.5    ,  0     ),
	vec2(-0.433  , -0.25  ),
	vec2(-0.25   , -0.433 ),
	vec2( 0      , -0.5   ),
	vec2( 0.25   , -0.433 ),
	vec2( 0.433  , -0.2   ),
	vec2( 0.5    ,  0     ),
	vec2( 0.433  ,  0.25  ),
	vec2( 0.25   ,  0.433 ),
	vec2( 0      ,  0.75  ),
	vec2(-0.2565 ,  0.7048),
	vec2(-0.4821 ,  0.5745),
	vec2(-0.51295,  0.375 ),
	vec2(-0.7386 ,  0.1302),
	vec2(-0.7386 , -0.1302),
	vec2(-0.51295, -0.375 ),
	vec2(-0.4821 , -0.5745),
	vec2(-0.2565 , -0.7048),
	vec2(-0      , -0.75  ),
	vec2( 0.2565 , -0.7048),
	vec2( 0.4821 , -0.5745),
	vec2( 0.51295, -0.375 ),
	vec2( 0.7386 , -0.1302),
	vec2( 0.7386 ,  0.1302),
	vec2( 0.51295,  0.375 ),
	vec2( 0.4821 ,  0.5745),
	vec2( 0.2565 ,  0.7048),
	vec2( 0      ,  1     ),
	vec2(-0.2588 ,  0.9659),
	vec2(-0.5    ,  0.866 ),
	vec2(-0.7071 ,  0.7071),
	vec2(-0.866  ,  0.5   ),
	vec2(-0.9659 ,  0.2588),
	vec2(-1      ,  0     ),
	vec2(-0.9659 , -0.2588),
	vec2(-0.866  , -0.5   ),
	vec2(-0.7071 , -0.7071),
	vec2(-0.5    , -0.866 ),
	vec2(-0.2588 , -0.9659),
	vec2(-0      , -1     ),
	vec2( 0.2588 , -0.9659),
	vec2( 0.5    , -0.866 ),
	vec2( 0.7071 , -0.7071),
	vec2( 0.866  , -0.5   ),
	vec2( 0.9659 , -0.2588),
	vec2( 1      ,  0     ),
	vec2( 0.9659 ,  0.2588),
	vec2( 0.866  ,  0.5   ),
	vec2( 0.7071 ,  0.7071),
	vec2( 0.5    ,  0.8660),
	vec2( 0.2588 ,  0.9659)
);

//Includes//
#include "/lib/util/spaceConversion.glsl"

#if defined FOG_BLUR && defined OVERWORLD
#include "/lib/prismarine/timeCalculations.glsl"
#endif

//Common Functions//
vec3 DepthOfField(vec3 color, float z, vec4 viewPos) {
	vec3 dof = vec3(0.0);
	float hand = float(z < 0.56);

	float fovScale = gbufferProjection[1][1] / 1.37;
	float coc = max(abs(z - centerDepthSmooth) * DOF_STRENGTH - 0.01, 0.0);
	coc = coc / sqrt(coc * coc + 0.1);

	#if defined DISTANT_BLUR || (defined FOG_BLUR && defined OVERWORLD)
	vec3 worldPos = ToWorld(viewPos.xyz);
	#endif

	#if defined DISTANT_BLUR || (defined FOG_BLUR && defined OVERWORLD)
	float range = DISTANT_BLUR_RANGE;

	#if defined FOG_BLUR && defined OVERWORLD
	range = 10.0;
	#endif

	coc = min(length(worldPos) * range * 0.00025, DISTANT_BLUR_STRENGTH * 0.025) * DISTANT_BLUR_STRENGTH;
	#endif

	#if defined FOG_BLUR && defined OVERWORLD
	vec3 pos = worldPos.xyz + cameraPosition.xyz + 1000.0;
	float height = (pos.y - FOG_FIRST_LAYER_ALTITUDE) * 0.001;
		  height = pow(height, 16.0);
		  height = clamp(height, 0.0, 1.0);
	float isEyeInCave = clamp(clamp(cameraPosition.y * 0.005, 0.0, 1.0) - isEyeInWater, 0.0, 1.0);
	coc *= FIRST_LAYER_DENSITY * CalcTotalAmount(CalcDayAmount(MORNING_FOG_DENSITY, DAY_FOG_DENSITY, EVENING_FOG_DENSITY), NIGHT_FOG_DENSITY) * (1.00 + rainStrength * 0.50) * (1.0 + isEyeInWater);
	coc *= 1.0 - height;
	#endif

	if (coc > 0.0 && hand < 0.5) {
		for(int i = 0; i < 60; i++) {
			vec2 offset = dofOffsets[i] * coc * 0.015 * fovScale * vec2(1.0 / aspectRatio, 1.0);
			float lod = log2(viewHeight * aspectRatio * coc * fovScale / 320.0);
			dof += texture2DLod(colortex0, texCoord + offset, lod).rgb;
		}
		dof /= 60.0;
	}
	else dof = color;
	return dof;
}

//Program//
void main() {
	vec3 color = texture2D(colortex0, texCoord).rgb;

    #if defined DOF || (defined FOG_BLUR && defined OVERWORLD) || defined DISTANT_BLUR
    float z0 = texture2D(depthtex0, texCoord.xy).r;
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

    float z1 = texture2D(depthtex1, texCoord.xy).r;

	color = DepthOfField(color, z1, viewPos);
	#endif

    #ifdef FOG_BLUR
    #endif

    #ifdef DOF
    #endif

    #ifdef DISTANT_BLUR
    #endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

#ifdef FOG_BLUR
uniform mat4 gbufferModelView;
varying vec3 sunVec, upVec;
uniform float timeAngle;
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;

	gl_Position = ftransform();

	#ifdef FOG_BLUR
	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
	#endif
}

#endif