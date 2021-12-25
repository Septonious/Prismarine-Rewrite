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
#ifdef LIGHTSHAFT
const bool colortex1MipmapEnabled = true;
#endif

//Common Functions//
float GetLuminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}

//Includes//
#include "/lib/antialiasing/taa.glsl"

//Program//
void main() {
	vec3 color = texture2D(colortex1, texCoord).rgb;
    vec4 prev = vec4(texture2D(colortex2, texCoord).r, 0.0, 0.0, 0.0);
	
	#if defined TAA && defined OVERWORLD
	prev = TemporalAA(color, prev.r);
	#endif

    /*DRAWBUFFERS:12*/
	gl_FragData[0] = vec4(color, 1.0);
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