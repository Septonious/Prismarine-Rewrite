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

#ifdef SSGI
uniform sampler2D colortex9, colortex10, colortex8;
#endif

uniform sampler2D colortex0;
uniform sampler2D depthtex1, depthtex0;

#ifdef SSGI
#include "/lib/util/encode.glsl"

#define PI 3.14159265
#define PI2 PI * 2.0
#define INV_PI 1.0 / PI

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
    float xOffset = radius * cos(PI2 * r.x);
    float yOffset = radius * sin(PI2 * r.x);
    float zOffset = sqrt(1.0 - r.y);
    return normalize(vec3(xOffset, yOffset, zOffset));
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
float InterleavedGradientNoiseVL() {
	#ifdef BLUE_NOISE_DITHER
	float n = texelFetch2D(colortex8, ivec2(gl_FragCoord.xy) & 255, 0).r;
	#else
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	#endif

	#ifdef TAA
	n = fract(n + frameCounter / 8.0);
	#else
	n = fract(n);
	#endif

	return n;
}

mat3 getTBN(vec3 normal) {
    vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    return mat3(tangent, cross(tangent, normal), normal);
}


vec3 computeGI(vec3 viewPos, vec3 normal) {
    float jitter = InterleavedGradientNoiseVL();

    vec3 hitPos = viewPos + normal;

    mat3 TBN = getTBN(normal);  

    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(2.0); // How much the current iteration contributes to the final product

    for(int i = 0; i < 4; i++) {
        vec2 noise = vec2(jitter);
        noise = fract(frameTimeCounter * 16.0 + noise);

        vec3 sampleDir = TBN * randomHemisphereDirection(noise.xy);
        bool hit = raytrace(viewPos, sampleDir, 20, jitter, hitPos);

        if(hit) {
            vec3 albedo = texture2D(colortex0, hitPos.xy).rgb;
            float isEmissive = texture2D(colortex9, hitPos.xy).w == 0.0 ? 0.0 : 1.0;

            /* LAMBERT DIFFUSE */
            weight *= albedo;
            illumination += weight * (isEmissive + isEmissive);

			normal = normalize(DecodeNormal(texture2D(colortex10, hitPos.xy).xy));
        } else {
            break;
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
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

    #ifdef SSGI
    vec3 normal = normalize(DecodeNormal(texture2D(colortex10, texCoord.xy).xy));
    vec3 gi = computeGI(viewPos.xyz, normal);
    color += gi;
    #endif

    /*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color, 1.0);
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