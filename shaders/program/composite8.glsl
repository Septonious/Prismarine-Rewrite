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
uniform float viewWidth, viewHeight;

uniform sampler2D colortex11, colortex13;

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/antialiasing/fxaa.glsl"

//Optifine Constants//
const bool colortex13Clear = false;

//Program//
void main() {
    vec3 gi = texture2D(colortex11, texCoord).rgb;
    gi = FXAA311(gi, colortex11, 16.0 * DENOISE_STRENGTH);

    #ifdef TAA
    vec3 temporalColor = texture2D(colortex13, texCoord).gba;

    /* RENDERTARGETS:11,13 */
    gl_FragData[0] = vec4(gi, 1.0);
    gl_FragData[1] = vec4(0.0, temporalColor);
    #else
    /* RENDERTARGETS:11 */
    gl_FragData[0] = vec4(gi, 1.0);
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
