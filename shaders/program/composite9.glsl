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
uniform float viewWidth, viewHeight, aspectRatio;

uniform sampler2D colortex11, colortex13, depthtex1;

#ifdef TAA
uniform int frameCounter;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferModelViewInverse;
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/antialiasing/fxaa.glsl"
#ifdef TAA
#include "/lib/antialiasing/taa.glsl"
#endif

//Program//
void main() {
    vec3 gi = texture2D(colortex11, texCoord).rgb;
    gi = FXAA311(gi, colortex11, 16.0 * DENOISE_STRENGTH);

    #ifdef TAA
    vec4 prev = vec4(texture2DLod(colortex13, texCoord, 0.0).r, 0.0, 0.0, 0.0);
    prev = TemporalAA(gi, prev.r, colortex11, colortex13);
    /* RENDERTARGETS:11,13 */
    gl_FragData[0] = vec4(gi, 1.0);
    gl_FragData[1] = vec4(prev);
    #else
    /* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color + gi, 1.0);
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
