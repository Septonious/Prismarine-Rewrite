/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

#ifdef SSGI
//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
#ifdef DENOISE
uniform float viewHeight, viewWidth;

uniform sampler2D colortex6;
uniform sampler2D depthtex0, depthtex1;

uniform mat4 gbufferProjectionInverse;
#endif

uniform sampler2D colortex0, colortex9, colortex11;

#ifdef DENOISE
//Includes//
#include "/lib/prismarine/normalAwareBlur.glsl"
#endif

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;
    vec3 gi = texture2D(colortex11, texCoord).rgb;

    float skyLightmap = clamp(texture2D(colortex9, texCoord).b, 0.0, 1.0);

    #ifdef DENOISE
    gi = NormalAwareBlur(texCoord);
    #endif

    gi *= 300.0 * (1.05 - skyLightmap);
    color.rgb *= 1.0 + gi + gi + gi + gi;

    /* DRAWBUFFERS:0 */
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