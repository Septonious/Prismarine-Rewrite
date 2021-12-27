/* 
BSL Shaders v8 Series by Capt Tatsu 
https://bitslablab.com 
*/ 

//Settings//
#include "/lib/settings.glsl"

#if defined SSGI && defined TAA && !defined ADVANCED_MATERIALS
//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform sampler2D colortex11;
uniform sampler2D colortex13;

//Optifine Constants//
const bool colortex13Clear = false;

//Program//
void main() {
    vec3 gi = texture2D(colortex11, texCoord).rgb;
    vec3 temporalColor = texture2D(colortex13, texCoord).gba;

    /* RENDERTARGETS:11,13 */
    gl_FragData[0] = vec4(gi, 1.0);
    gl_FragData[1] = vec4(0.0, temporalColor);
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