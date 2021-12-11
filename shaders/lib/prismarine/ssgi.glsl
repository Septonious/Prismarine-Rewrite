//huge thanks to lvutner, belmu and niemand for help!

//Constants
#define TAU    6.28318530
#define INV_PI 0.31830988

//Noise
const uint k = 1103515245U;

vec3 hash(uvec3 x){
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    x = ((x >> 8U) ^ x.yzx) * k;
    
    return vec3(x) * (1.0 / float(0xffffffffU));
}

float getRandomNoise(vec2 pos){
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}
//

//Space conversions
vec3 viewToScreen(in vec3 view) {
    vec4 temp =  gbufferProjection * vec4(view, 1.0);
    temp.xyz /= temp.w;
    return temp.xyz * 0.5 + 0.5;
}

vec3 screenToView(vec3 view) {
    vec4 clip = vec4(view, 1.0) * 2.0 - 1.0;
    clip = gbufferProjectionInverse * clip;
    clip.xyz /= clip.w;
    return clip.xyz;
}
//

//Raytracer from Zombye's spectrum shader
float AscribeDepth(float depth, float ascribeAmount) {
	depth = 1.0 - 2.0 * depth;
	depth = (depth + gbufferProjection[2].z * ascribeAmount) / (1.0 + ascribeAmount);
	return 0.5 - 0.5 * depth;
}

float MaxOf(vec2 x) { return max(x.x, x.y); }
float MinOf(vec3 x) { return min(min(x.x, x.y), x.z); }

vec2 viewResolution = vec2(viewWidth, viewHeight);
vec2 viewPixelSize = 1.0 / viewResolution;

bool IntersectSSRay(
	inout vec3 position, // Starting position in screen-space. This gets set to the hit position, also in screen-space.
	vec3 startVS, // Starting position in view-space
	vec3 rayDirection, // Ray direction in view-space
    float dither,
	const uint stride // Stride, in pixels. Should be >= 1.
) {
	vec3 rayStep  = startVS + abs(startVS.z) * rayDirection;
	     rayStep  = viewToScreen(rayStep) - position;
	     rayStep *= MinOf((step(0.0, rayStep) - position) / rayStep);

	position.xy *= viewResolution;
	rayStep.xy *= viewResolution;

	rayStep /= MaxOf(abs(rayStep.xy));

	float ditherp = floor(stride * dither + 1.0);

	vec3 stepsToEnd = (step(0.0, rayStep) * vec3(viewResolution - 1.0, 1.0) - position) / rayStep;
	stepsToEnd.z += float(stride);
	float tMax = min(MinOf(stepsToEnd), MaxOf(viewResolution));

	vec3 rayOrigin = position;

	float ascribeAmount = GI_DEPTH_LENIENCY * float(stride) * viewPixelSize.y * gbufferProjectionInverse[1].y;

	bool hit = false;
	float t = ditherp;
	while (t < tMax && !hit) {
		float stepStride = t == ditherp ? ditherp : float(stride);

		position = rayOrigin + t * rayStep;
		float maxZ = position.z;
		float minZ = position.z - stepStride * abs(rayStep.z);

		float depth = texelFetch(depthtex1, ivec2(position.xy), 0).x;
		float ascribedDepth = AscribeDepth(depth, ascribeAmount);

		hit = maxZ >= depth && minZ <= ascribedDepth;

		hit = hit && depth < 1.0;

		if (!hit) t += float(stride);
	}

	if (hit) {

		bool refhit = true;
		float refstride = stride;
		for (int i = 0; i < (2 ^ stride); ++i) {
			t += (refhit && t > 0.0 ? -1.0 : 1.0) * (refstride *= 0.5);
			position = rayOrigin + t * rayStep;

			float maxZ = position.z;
			float minZ = position.z - stride * abs(rayStep.z);

			float depth = texelFetch(depthtex1, ivec2(position.xy), 0).x;
			float ascribedDepth = AscribeDepth(depth, ascribeAmount);

			refhit = maxZ >= depth && minZ <= ascribedDepth;

			hit = hit && depth < 1.0;
		}
	}

	position.xy *= viewPixelSize;

	return hit;
}
//

vec3 rotate(vec3 N, vec3 H){
    vec3 T = normalize(cross(N, vec3(0.0, 1.0, 1.0)));
    vec3 B = cross(T, N);
    return T * H.x + B * H.y + N * H.z;
}

vec3 generateUnitVector(vec2 hash) {
    hash.x *= TAU;
    hash.y = hash.y * 2.0 - 1.0;
    return vec3(vec2(sin(hash.x), cos(hash.x)) * sqrt(1.0 - hash.y * hash.y), hash.y);
}

vec3 generateCosineVector(vec3 vector, vec2 xy) {
    vec3 dir = generateUnitVector(xy);

    return normalize(vector + dir);
}

vec3 computeGI(vec3 screenPos, vec3 normal, float hand) {
    float dither = getRandomNoise(gl_FragCoord.xy);

    vec3 currentPosition = screenPos;
    vec3 hitNormal = normal;

    vec3 illumination = vec3(0.0);
    vec3 weight = vec3(ILLUMINATION_STRENGTH);

    for(int i = 0; i < BOUNCES; i++) {
        vec2 noise = hash(uvec3(gl_FragCoord.xy, frameCounter % 8)).xy;

        hitNormal = normalize(DecodeNormal(texture2D(colortex6, currentPosition.xy).xy));
        currentPosition = screenToView(currentPosition) + hitNormal * 0.001;

        vec3 sampleDir = generateCosineVector(hitNormal, noise);

        vec3 hitPos = viewToScreen(currentPosition);
        bool hit = IntersectSSRay(hitPos, currentPosition, sampleDir, dither, STRIDE);
        currentPosition = hitPos;

        if (hit && hand < 0.5) {
            vec3 albedo = texture2D(colortex0, currentPosition.xy).rgb * INV_PI;
            float isEmissive = texture2D(colortex9, currentPosition.xy).w == 0.0 ? 0.0 : 1.0;

            weight *= albedo;
            illumination += weight * (isEmissive + isEmissive + isEmissive + isEmissive);
        }
    }
    return illumination * normalize(illumination);
}