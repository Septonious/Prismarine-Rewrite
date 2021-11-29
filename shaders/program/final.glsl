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
uniform sampler2D colortex1;
uniform int isEyeInWater;
uniform float viewWidth, viewHeight;

#ifdef TEST04
uniform float playerMood;
#endif

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main scene
const int colortex1Format = RGB8; //raw translucent, bloom, final scene
const int colortex2Format = RGBA16; //temporal data
const int colortex3Format = RGB8; //specular data
const int gaux1Format = R8; //cloud alpha, ao
const int gaux2Format = RGB10_A2; //reflection image
const int gaux3Format = RGB16; //normals
const int gaux4Format = RGB16; //fresnel
*/
const bool colortex1MipmapEnabled = true;
const bool shadowHardwareFiltering = true;
const float shadowDistanceRenderMul = 1.0;
const float aberrationStrength = float(CHROMATIC_ABERRATION_STRENGTH) / 512;
const int noiseTextureResolution = 512;

const float drynessHalflife = 50.0;
const float wetnessHalflife = 300.0;

//Common Functions//

//CA from DrDesten [modified]
#ifdef CHROMATIC_ABERRATION
vec2 scaleCoord(vec2 coord, float scale) {
    coord = (coord * scale) - (0.5 * (scale - 1));
    return clamp(coord, 0, 0.999999);
}

vec3 getChromaticAbberation(vec2 coord, float amount) {
    vec3 col = vec3(0.0);

    amount = distance(coord, vec2(0.5)) * amount;
    #if CA_COLOR == 0
    col.r     = texture2D(colortex1, scaleCoord(coord, 1.0 - amount)).r;
    col.g     = texture2D(colortex1, coord).g;
    col.b     = texture2D(colortex1, scaleCoord(coord, 1.0 + amount)).b;
    #elif CA_COLOR == 1
    col.r     = texture2D(colortex1, coord).r;
    col.g     = texture2D(colortex1, scaleCoord(coord, 1.0 - amount)).g;
    col.b     = texture2D(colortex1, scaleCoord(coord, 1.0 + amount)).b;
    #elif CA_COLOR == 2
    col.r     = texture2D(colortex1, scaleCoord(coord, 1.0 - amount)).r;
    col.g     = texture2D(colortex1, scaleCoord(coord, 1.0 + amount)).g;
    col.b     = texture2D(colortex1, coord).b;
    #elif CA_COLOR == 3
    col.r     = texture2D(colortex1, scaleCoord(coord, 1.0 - amount)).r;
    col.g     = texture2D(colortex1, scaleCoord(coord, 1.0 + amount)).g;
    col.b     = texture2D(colortex1, scaleCoord(coord, 1.0 + amount)).b;
    #endif

    return col;
}
#endif

#ifdef TAA
vec2 sharpenOffsets[4] = vec2[4](
	vec2( 1.0,  0.0),
	vec2( 0.0,  1.0),
	vec2(-1.0,  0.0),
	vec2( 0.0, -1.0)
);


void SharpenFilter(inout vec3 color, vec2 coord) {
	float mult = MC_RENDER_QUALITY * 0.125;
	vec2 view = 1.0 / vec2(viewWidth, viewHeight);

	color *= MC_RENDER_QUALITY * 0.5 + 1.0;

	for(int i = 0; i < 4; i++) {
		vec2 offset = sharpenOffsets[i] * view;
		color -= texture2D(colortex1, coord + offset).rgb * mult;
	}
}
#endif

//GLOBAL ILLUMINATION STUFF//
float sphereSDF(vec2 p, float size) {
	return length(p) - size;
}

void AddObj(inout float dist0, float dist1, inout vec3 outColor, vec3 lightColor) {
    if (dist0 > dist1) {
        dist0 = dist1;
        outColor = lightColor;
    }
}

void scene(in vec2 pos, out vec3 color, out float dist0) {
    dist0 = 1e9;
    color = vec3(0.0, 0.0, 0.0);
    AddObj(dist0, sphereSDF(pos - vec2(3.0, 1.0), 1.0), color, vec3(0.0, 0.0, 1.0));
    AddObj(dist0, sphereSDF(pos - vec2(-3.0, 1.0), 1.0), color, vec3(1.0, 0.0, 0.0));
}

void trace(vec2 p, vec2 dir, out vec3 color) {
    for (;;) {
        float dist1 = 0.0;
        scene(p, color, dist1);
        if (dist1 < 1e-3) return;
        if (dist1 > 1e1) break;
        p += dir * dist1;
    }
    color = vec3(0.0, 0.0, 0.0);
}

float random (in vec2 pos) {
    return fract(sin(dot(pos.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

#define SAMPLES 32
////////////////////////

//Program//
void main() {
    vec2 newTexCoord = texCoord;

	#ifdef CHROMATIC_ABERRATION
	vec3 color = getChromaticAbberation(texCoord, aberrationStrength);
	#else
	vec3 color = texture2D(colortex1, texCoord).rgb;
	#endif
	
    vec2 uv = (gl_FragCoord.xy - vec2(viewWidth, viewHeight) * 0.5) / viewWidth * 10.0;
    vec3 col = vec3(0.0, 0.0, 0.0);
    for (int i = 0; i < SAMPLES; i++) {
        float t = (i + random(uv + i)) / SAMPLES * 6.283;
        vec3 gi = vec3(0.0);
        trace(uv, vec2(cos(t), sin(t)), gi);
        col += gi;
    }
    col /= SAMPLES;

    color = col * 2.0;

	#ifdef TAA
	SharpenFilter(color, newTexCoord);
	#endif

	#if Sharpen > 0 && !defined DOF && !defined TAA
	vec2 view = 1.0 / vec2(viewWidth, viewHeight);
	color *= Sharpen * 0.1 + 0.9;
	color -= texture2D(colortex1, texCoord.xy + vec2(1.0,0.0)*view).rgb * Sharpen * 0.025;
	color -= texture2D(colortex1, texCoord.xy + vec2(0.0,1.0)*view).rgb * Sharpen * 0.025;
	color -= texture2D(colortex1, texCoord.xy + vec2(-1.0,0.0)*view).rgb * Sharpen * 0.025;
	color -= texture2D(colortex1, texCoord.xy + vec2(0.0,-1.0)*view).rgb * Sharpen * 0.025;
	#endif

	#ifdef TEST04	
	color *= 1.0 + playerMood;
	#endif

	gl_FragColor = vec4(color, 1.0);
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