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
uniform float viewHeight, viewWidth, frameTimeCounter;
uniform int frameCounter;

uniform mat4 gbufferProjection, gbufferProjectionInverse, gbufferModelViewInverse, gbufferModelView;


uniform sampler2D colortex9, colortex6, colortex8, noisetex;


uniform sampler2D colortex0;
uniform sampler2D depthtex1, depthtex0;

#include "/lib/util/encode.glsl"

//colortex8 - blue noise, colortex9 - emissives
//normal is "vec4(EncodeNormal(newNormal), float(gl_FragCoord.z < 1.0), 1.0);"
//normal in vertex: "normal = normalize(gl_NormalMatrix * gl_Normal);"

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

vec3 randomHemisphereDirection(vec2 r) {
    float radius = sqrt(r.y);
    float xOffset = radius * cos(TAU * r.x);
    float yOffset = radius * sin(TAU * r.x);
    float zOffset = sqrt(1.0 - r.y);
    return normalize(vec3(xOffset, yOffset, zOffset));
}

vec3 binarySearch(in vec3 rayPos, vec3 rayDir) {

    for(int i = 0; i < 30; i++) {
        float depthDelta = texture(depthtex1, rayPos.xy).r - rayPos.z;
        rayPos += sign(depthDelta) * rayDir;
        rayDir *= 0.2f;
    }
    return rayPos;
}

bool raytrace(vec3 viewPos, vec3 rayDir, int steps, float jitter, inout vec3 hitPos) {
    vec3 screenPos = viewToScreen(viewPos);
    vec3 screenDir = normalize(viewToScreen(viewPos + rayDir) - screenPos) * (1.0 / steps);

    hitPos = screenPos + screenDir * jitter;
    for(int i = 0; i < steps; i++) {
        hitPos += screenDir;
        
        if(clamp(hitPos.xy, 0.0, 1.0) != hitPos.xy) { return false; }
        float depth = texture(depthtex1, hitPos.xy).r;

        if(abs(1e-2 - (hitPos.z - depth)) < 1e-2) {
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
const uint k = 1103515245U;  // GLIB C
vec3 hash( uvec3 x ){
    x = ((x>>8U)^x.yzx)*k;
    x = ((x>>8U)^x.yzx)*k;
    x = ((x>>8U)^x.yzx)*k;
    
    return vec3(x)*(1.0/float(0xffffffffU));
}
vec3 computeGI(vec3 screenPos, vec3 normal) {
    float dither = getRandomNoise(gl_FragCoord.xy);

    vec3 hitPos = screenPos;
    vec3 hitNormal = normal;

    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(1.0); // How much the current iteration contributes to the final product

    for(int i = 0; i < 1; i++) {
        vec2 noise = hash(uvec3(gl_FragCoord.xy, frameCounter%100)).xy;

        hitNormal = normalize(DecodeNormal(texture2D(colortex6, hitPos.xy).xy)); //Sample 'new normal'
        hitPos = screenToView(hitPos) + hitNormal * 0.001; //Convert hit position into view space position and add small offset

        //Direction - rotate your hemisphere sample by new normal each iteration
        vec3 sampleDir = rotate(hitNormal, randomHemisphereDirection(noise));

        bool hit = raytrace(hitPos, sampleDir, 30, dither, hitPos);

        if(hit) {
            vec3 albedo = texture2D(colortex0, hitPos.xy).rgb;
            float isEmissive = texture2D(colortex9, hitPos.xy).w == 0.0 ? 0.0 : 1.0;

            /* LAMBERT DIFFUSE */
            weight *= albedo;
            illumination += weight * isEmissive;
        }
    }
    return illumination;
}

//Program//
void main() {
	vec3 color = texture2D(colortex0, texCoord).rgb;

    float z0 = texture2D(depthtex0, texCoord.xy).r;

	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

    vec3 normal = normalize(DecodeNormal(texture2D(colortex6, texCoord.xy).xy));
    vec3 gi = computeGI(screenPos.xyz, normal);
    color += gi;

    /*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color + gi, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif