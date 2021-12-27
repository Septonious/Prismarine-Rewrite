/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

#if defined SSGI && !defined ADVANCED_MATERIALS
//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
#ifdef DENOISE
uniform float aspectRatio;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform float far, near, centerDepth;
#endif

uniform sampler2D colortex0, colortex11;

#ifdef DENOISE
uniform float viewHeight, viewWidth;

//Common Functions//
float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/prismarine/normalAwareBlur.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;
    vec3 gi = texture2D(colortex11, texCoord).rgb;

    #ifdef DENOISE
    gi = NormalAwareBlur(colortex11, colortex6, 0.01 * DENOISE_STRENGTH, texCoord, vec2(0, 1));
    #endif

    /* DRAWBUFFERS:0 */
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
#endif



#ifndef SSGI
//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Program//
void main() {
	discard;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Program//
void main() {
	gl_Position = ftransform();
}

#endif
#endif