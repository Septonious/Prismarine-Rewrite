//technically there's nothing bayer-related, i was just lazy to go to all the files just to replace BayerX with this new thing
float InterleavedGradientNoise(vec2 a) {
	float n = 52.9829189 * fract(0.06711056 * gl_FragCoord.x + 0.00583715 * gl_FragCoord.y);
	return fract(n + frameCounter / 6.0);
}

#define Bayer64(a)  InterleavedGradientNoise(a)