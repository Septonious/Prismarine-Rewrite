//technically there's nothing bayer-related, i was just lazy to go to all the files just to replace BayerX with this new thing
/*
//HASH12
float dither(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * vec3(443.8975, 397.2973, 491.1871));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z + frameCounter / 8.0);
}
*/

//IGN
float dither(vec2 p){
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract( magic.z * fract(dot(p,magic.xy)) + frameCounter / 6.0);
}

#define Bayer64(a) dither(a)