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

//Uniforms//
uniform int frameCounter;
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex1;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex2;
uniform sampler2D depthtex1;

//Optifine Constants//
#if defined VOLUMETRIC_LIGHT || defined VOLUMETRIC_FOG || defined FIREFLIES || defined NETHER_SMOKE
const bool colortex1MipmapEnabled = true;
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

//Includes//
#ifdef TAA
#include "/lib/antialiasing/taa.glsl"
#endif

#ifdef FXAA
#include "/lib/antialiasing/fxaa.glsl"
#endif

//Program//
void main() {
	vec3 color = texture2DLod(colortex1, texCoord, 0.0).rgb;
	
    #ifdef FXAA
	color = FXAA311(color);
    #endif

    #ifdef TAA
    vec4 prev = vec4(texture2DLod(colortex2, texCoord, 0.0).r, 0.0, 0.0, 0.0);
    TAA(color, prev);
    #endif

    /*DRAWBUFFERS:1*/
	gl_FragData[0] = vec4(color, 1.0);
	#ifdef TAA
    /*DRAWBUFFERS:12*/
	gl_FragData[1] = vec4(prev);
	#endif
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