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

uniform sampler2D colortex13, depthtex1;
uniform float viewWidth, viewHeight;
uniform int frameCounter;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;

//Includes//
#include "/lib/antialiasing/taa.glsl"

//Program//
void main() {
    vec3 gi = texture2D(colortex11, texCoord).rgb;
    vec4 prev = vec4(texture2DLod(colortex13, texCoord, 0.0).r, 0.0, 0.0, 0.0);
    prev = TemporalAA(gi.rgb, prev.r, colortex11, colortex13);

    /* RENDERTARGETS:11,13 */
    gl_FragData[0] = vec4(gi, 1.0);
    gl_FragData[1] = vec4(prev);
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


#if !defined SSGI || (!defined TAA && defined SSGI) || defined ADVANCED_MATERIALS
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
