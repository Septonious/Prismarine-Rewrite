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
uniform int frameCounter;
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
const int noisetexture2DResolution = 512;

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

#ifdef CAS
void ContrastAdaptiveSharpening(out vec3 outColor){
    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
  
    vec3 originalColor = texture2D(colortex1, uv).rgb;

    float maxGreen = originalColor.g;
    float minGreen = originalColor.g;

    vec4 uvoff = vec4(1.0, 0.0, 1.0, -1.0) / vec4(vec2(viewWidth, viewWidth), vec2(viewHeight, viewHeight));
    vec3 modifiedColor = vec3(0.0);
    vec3 newColor = texture2D(colortex1, uv + uvoff.yw).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
    modifiedColor = newColor;
    	 newColor = texture2D(colortex1, uv + uvoff.xy).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
    modifiedColor += newColor;
    	 newColor = texture2D(colortex1, uv + uvoff.yz).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
    modifiedColor += newColor;
    	 newColor = texture2D(colortex1, uv - uvoff.xy).rgb;
    maxGreen = max(maxGreen, newColor.g);
    minGreen = min(minGreen, newColor.g);
    modifiedColor += newColor;
    float adaptiveSharpening = 0.0;
    maxGreen = max(0.0, maxGreen);

    adaptiveSharpening = minGreen / maxGreen;

    adaptiveSharpening = sqrt(max(0.0, adaptiveSharpening));
    adaptiveSharpening *= mix(-0.125, -0.2, 0.25 * MC_RENDER_QUALITY);
    outColor = (originalColor + modifiedColor * adaptiveSharpening) / (1.0 + 4.0 * adaptiveSharpening);
}
#endif


//Program//
void main() {
	vec2 halfView = vec2(viewWidth, viewHeight) / 2.0;
	vec2 halfCoord = (floor(texCoord * halfView + 1.0)) / halfView;
    vec2 newTexCoord = halfCoord;

	#ifdef CHROMATIC_ABERRATION
	vec4 color = vec4(getChromaticAbberation(texCoord, aberrationStrength), 1.0);
	#else
	vec4 color = texture2D(colortex1, texCoord);
	#endif

    #ifdef CAS
    ContrastAdaptiveSharpening(color.rgb);
    #endif

	#ifdef TEST04	
	color.rgb *= 1.0 + playerMood;
	#endif

    #ifdef DO_NOT_CLICK
    color *= 0.0;
    #endif

	gl_FragColor = color;
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