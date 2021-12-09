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

#ifdef OUTLINE_OUTER
#include "/lib/util/outlineOffset.glsl"
#include "/lib/util/outlineDepth.glsl"
#endif

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
		  height = clamp(height, 0, 1);
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

#ifdef SSGI
uniform sampler2D colortex6, colortex9, colortex11, noisetex;
const bool colortex11Clear = false;

#include "/lib/util/encode.glsl"

//huge thanks to lvutner and belmu for help!

#define PI         3.14159265
#define TAU        6.28318530
#define INV_PI     0.31830988

vec3 viewToScreen(in vec3 view) {
    vec4 temp =  gbufferProjection * vec4(view, 1.0);
    temp.xyz /= temp.w;
    return temp.xyz * 0.5 + 0.5;
}

float getRandomNoise(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

vec3 binarySearch(in vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < 30; i++) {
        float depthDelta = texture(depthtex1, rayPos.xy).r - rayPos.z;
        rayPos += sign(depthDelta) * rayDir;
        rayDir *= 0.2f;
    }
    return rayPos;
}

/*
vec3 screenToLocal(vec3 posDepth) {
  vec4 result = vec4(posDepth, 1.0) * 2.0 - 1.0;
  result = (gbufferProjectionInverse * result);
  result /= result.w;
  return result.xyz;
}

vec4 evil_raytracer(in vec3 ray_origin, in vec3 ray_direction)
{
    int RT_SAMPLES = 32;
    float RT_TOLERANCE = 0.025;
    
    float ray_step = 1.0 / RT_SAMPLES;

    for (int i = 0; i < RT_SAMPLES; i++)
    {
        vec3 ray_position = ray_origin + ray_direction * ray_step;

        vec4 ray_position_proj = gbufferProjection * vec4(ray_position, 1.0);
        ray_position_proj.xyz /= ray_position_proj.w;
        
        vec2 sample_tc = ray_position_proj.xy * 0.5 + 0.5;
        
        if (sample_tc.x < 0.0 || sample_tc.y < 0.0 || sample_tc.x > 1.0 || sample_tc.y > 1.0)
            break;            
            
        float depth = screenToLocal(vec3(sample_tc, texture2D(depthtex0, sample_tc).x)).z;
        float difference = abs(ray_position.z - depth);
    
        if(difference < RT_TOLERANCE) 
        {
            return vec4(sample_tc, depth, 1.0);
            break;
        }
        
        //Evil shit
        ray_step += difference;
    }
    return vec4(0.0);
}
*/

bool raytrace(vec3 viewPos, vec3 rayDir, int steps, float jitter, inout vec3 hitPos) {
    vec3 screenPos = viewToScreen(viewPos);
    vec3 screenDir = normalize(viewToScreen(viewPos + rayDir) - screenPos) * (1.0 / steps);

    hitPos = screenPos + screenDir * jitter;
    for (int i = 0; i < steps; i++) {
        hitPos += screenDir;
        
        if (clamp(hitPos.xy, 0.0, 1.0) != hitPos.xy) return false;
        float depth = texture(depthtex1, hitPos.xy).r;
        float hand = float(depth < 0.56);

        if(abs(1e-2 - (hitPos.z - depth)) < 1e-2 && hand < 0.5) {
            hitPos = binarySearch(hitPos, screenDir);
            return true;
        }
    }
    return false;
}

vec3 screenToView(vec3 view) {
    vec4 clip = vec4(view, 1.0) * 2.0 - 1.0;
    clip = gbufferProjectionInverse * clip;
    clip.xyz /= clip.w;
    return clip.xyz;
}

vec3 rotate(vec3 N, vec3 H){
    vec3 T = normalize(cross(N, vec3(0.0, 1.0, 1.0)));
    vec3 B = cross(T, N);
    return T * H.x + B * H.y + N * H.z;
}
const uint k = 1103515245U;

vec3 hash(uvec3 x){
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    
    return vec3(x) * (1.0 / float(0xffffffffU));
}

vec3 generateUnitVector(vec2 hash) {
    hash.x *= TAU;
    hash.y = hash.y * 2.0 - 1.0;
    return vec3(vec2(sin(hash.x), cos(hash.x)) * sqrt(1.0 - hash.y * hash.y), hash.y);
}

vec3 generateCosineVector(vec3 vector, vec2 xy) {
    vec3 dir = generateUnitVector(xy);

    return normalize(vector + dir);
}

vec3 computeGI(vec3 screenPos, vec3 normal) {
    float dither = getRandomNoise(gl_FragCoord.xy);

    vec3 hitPos = screenPos;
    vec3 hitNormal = normal;

    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(1.0);

    for(int i = 0; i < 4; i++) {
        vec2 noise = hash(uvec3(gl_FragCoord.xy, frameCounter % 100)).xy;

        hitNormal = normalize(DecodeNormal(texture2D(colortex6, hitPos.xy).xy));
        hitPos = screenToView(hitPos) + hitNormal * 0.001;

        vec3 sampleDir = generateCosineVector(hitNormal, noise);

        bool hit = raytrace(hitPos, sampleDir, 16, dither, hitPos);

        if (hit) {
            vec3 albedo = texture2D(colortex0, hitPos.xy).rgb;
            float isEmissive = texture2D(colortex9, hitPos.xy).w == 0.0 ? 0.0 : 1.0;

            /* LAMBERT DIFFUSE */
            weight *= albedo;
            illumination += weight * isEmissive;
        }
    }
    return illumination;
}
#endif

//Program//
void main() {
	vec3 color = texture2D(colortex0, texCoord).rgb;

    float z0 = texture2D(depthtex0, texCoord.xy).r;
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);

    #if defined DOF || (defined FOG_BLUR && defined OVERWORLD) || defined DISTANT_BLUR
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

    float z1 = texture2D(depthtex1, texCoord.xy).r;

	#ifdef OUTLINE_OUTER
	DepthOutline(z1);
	#endif

	color = DepthOfField(color, z1, viewPos);
	#endif

    #ifdef FOG_BLUR
    #endif

    #ifdef DOF
    #endif

    #ifdef DISTANT_BLUR
    #endif

    #ifdef SSGI
    vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord.xy).xy));
    vec3 gi = computeGI(screenPos.xyz, normal);
    /*RENDERTARGETS:0,11*/
	gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(gi, 1.0);
    #else
    /*DRAWBUFFERS:0*/
    gl_FragData[0] = vec4(color, 1.0);
    #endif
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