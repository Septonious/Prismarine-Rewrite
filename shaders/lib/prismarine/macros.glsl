#define pow2(x) x*x
#define pow6(x) x*x*x*x*x*x
#define pow4(x) pow2(x) * pow2(x)
#define pow8(x) pow2(x) * pow4(x)
#define pow12(x) pow2(x) * pow6(x)
#define pow16(x) pow2(x) * pow8(x)
#define pow24(x) pow2(x) * pow12(x)
#define pow32(x) pow2(x) * pow16(x)
#define pow64(x) pow2(x) * pow32(x)
#define pow128(x) pow2(x) * pow64(x)
#define pow256(x) pow2(x) * pow128(x)
#define pow512(x) pow2(x) * pow256(x)

#define sum3(x) x+x+x
#define sum4(x) x+x+x+x
#define sum6(x) sum3(x) + sum3(x)
#define sum8(x) sum4(x) + sum4(x)
#define sum12(x) sum6(x) + sum6(x)
#define sum16(x) sum8(x) + sum8(x)

/*
void mainImage( out vec4 fragColor, in vec2 fragCoord ){
    vec2 imageSize = iResolution.xy;
    
    fragCoord -= 0.5f;
    
    vec2 uv_fullres = clamp(fragCoord / imageSize, 0.0, 1.0);
    vec2 uv_halfres = floor(fragCoord / 2.0) * 2.0;
    uv_halfres += 1.0f;
    uv_halfres = clamp(uv_halfres / imageSize, 0.0, 1.0);
    
    vec4 test0 = texture(iChannel0, uv_halfres);
    

    fragColor = test0;
}
*/