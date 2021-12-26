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

uniform sampler2D colortex0, colortex11;

//Includes//
#include "/lib/prismarine/blur.glsl"

//Program//
void main() {
    vec3 color = texture2D(colortex0, texCoord).rgb;
    vec3 gi = texture2D(colortex11, texCoord).rgb;

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
