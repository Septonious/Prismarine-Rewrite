void GetMaterials(out float smoothness, out float metalness, out float f0, inout float emission,
                  inout float subsurface, out float porosity, out float ao, out vec3 normalMap,
                  vec2 newCoord, vec2 dcdx, vec2 dcdy) {
    vec4 specularMap = texture2DGradARB(specular, newCoord, dcdx, dcdy);

    #if MATERIAL_FORMAT == 0
    smoothness = specularMap.r;
    
    metalness = specularMap.g;
    f0 = 0.02;

    float emissionMat = specularMap.b * specularMap.b;
    ao = 1.0;

	normalMap = texture2DGradARB(normals, newCoord, dcdx, dcdy).xyz * 2.0 - 1.0;
    if (normalMap.x + normalMap.y < -1.999) normalMap = vec3(0.0, 0.0, 1.0);
    #endif

    #if MATERIAL_FORMAT == 1
    smoothness = specularMap.r;

    f0 = specularMap.g;
    metalness = f0 >= 0.9 ? 1.0 : 0.0;
    porosity = specularMap.b <= 0.251 ? specularMap.b * 3.984 : 0.0;
    float sssMat = specularMap.b > 0.251 ? clamp(specularMap.b * 1.335 - 0.355, 0.0, 1.0) : 0.0;
    #if SSS == 2
    subsurface = mix(sssMat, 1.0, subsurface);
    #else
    subsurface = sssMat;
    #endif

    float emissionMat = specularMap.a < 1.0 ? specularMap.a * specularMap.a : 0.0;
    ao = texture2DGradARB(normals, newCoord, dcdx, dcdy).z;

	normalMap = vec3(texture2DGradARB(normals, newCoord, dcdx, dcdy).xy, 0.0) * 2.0 - 1.0;
    if (normalMap.x + normalMap.y > -1.999) {
        if (length(normalMap.xy) > 1.0) normalMap.xy = normalize(normalMap.xy);
        normalMap.z = sqrt(1.0 - dot(normalMap.xy, normalMap.xy));
        normalMap = normalize(clamp(normalMap, vec3(-1.0), vec3(1.0)));
    }else{
        normalMap = vec3(0.0, 0.0, 1.0);
        ao = 1.0;
    }
    #endif

    #if EMISSIVE == 2
    emission = mix(emissionMat, 1.0, emission);
    #else
    emission = emissionMat;
    #endif

    #ifdef NORMAL_DAMPENING
    vec2 mipx = dcdx * atlasSize;
    vec2 mipy = dcdy * atlasSize;
    float delta = max(dot(mipx, mipx), dot(mipy, mipy));
    float miplevel = max(0.25 * log2(delta), 0.0);
    
    normalMap = normalize(mix(vec3(0.0, 0.0, 1.0), normalMap, 1.0 / exp2(miplevel)));
    #endif
}