const float pi = 3.1415927;
float pi2wt = 6.2831854 * (frametime * 24.0);

float GetNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

float Noise2D(vec2 pos) {
    vec2 flr = floor(pos);
    vec2 frc = fract(pos);
    frc = frc * frc * (3.0 - 2.0 * frc);

    float n00 = GetNoise(flr);
    float n01 = GetNoise(flr + vec2(0.0, 1.0));
    float n10 = GetNoise(flr + vec2(1.0, 0.0));
    float n11 = GetNoise(flr + vec2(1.0, 1.0));

    float n0 = mix(n00, n01, frc.y);
    float n1 = mix(n10, n11, frc.y);

    return mix(n0, n1, frc.x) - 0.5;
}

vec3 CalcMove(vec3 pos, float density, float speed, vec2 mult) {
    pos = pos * density + frametime * speed;
    vec3 wave = vec3(Noise2D(pos.yz), Noise2D(pos.xz + 0.333), Noise2D(pos.xy + 0.667));
    return wave * vec3(mult, mult.x);
}

float CalcLilypadMove(vec3 worldpos) {
    worldpos.z -= 0.125;
    float wave = sin(2 * pi * (frametime * 0.7 + worldpos.x * 0.14 + worldpos.z * 0.07)) +
                 sin(2 * pi * (frametime * 0.5 + worldpos.x * 0.10 + worldpos.z * 0.20));
    return wave * 0.0125;
}

float CalcLavaMove(vec3 worldpos) {
    float fy = fract(worldpos.y + 0.005);
		
    if (fy > 0.01) {
    float wave = sin(pi * (frametime * 0.7 + worldpos.x * 0.14 + worldpos.z * 0.07)) +
                 sin(pi * (frametime * 0.5 + worldpos.x * 0.10 + worldpos.z * 0.20));
    return wave * 0.0125;
    } else return 0.0;
}

vec3 CalcLanternMove(vec3 position) {
    vec3 frc = fract(position);
    frc = vec3(frc.x - 0.5, fract(frc.y - 0.001) - 1.0, frc.z - 0.5);
    vec3 flr = position - frc;
    float offset = flr.x * 2.4 + flr.y * 2.7 + flr.z * 2.2;

    float rmult = pi * 0.016;
    float rx = sin(frametime       + offset) * rmult;
    float ry = sin(frametime * 1.7 + offset) * rmult;
    float rz = sin(frametime * 1.4 + offset) * rmult;
    mat3 rotx = mat3(
               1,        0,        0,
               0,  cos(rx), -sin(rx),
               0,  sin(rx),  cos(rx)
    );
    mat3 roty = mat3(
         cos(ry),        0,  sin(ry),
               0,        1,        0,
        -sin(ry),        0,  cos(ry)
    );
    mat3 rotz = mat3(
         cos(rz), -sin(rz),        0,
         sin(rz),  cos(rz),        0,
               0,        0,        1
    );
    frc = rotx * roty * rotz * frc;
    
    return flr + frc - position;
}

vec3 WavingBlocks(vec3 position, float istopv) {
    vec3 wave = vec3(0.0);
    vec3 worldpos = position + cameraPosition;

    #ifdef WAVING_PLANT
    if (mc_Entity.x == 10100 && istopv > 0.9)
        wave += CalcMove(worldpos, 0.35, 1.0, vec2(0.25, 0.06));
    if (mc_Entity.x == 10101 && (istopv > 0.9|| fract(worldpos.y + 0.005) > 0.01))
        wave += CalcMove(worldpos, 0.7, 1.35, vec2(0.12, 0.06));
    if (mc_Entity.x == 10102 && (istopv > 0.9 || fract(worldpos.y + 0.005) > 0.01) ||
        mc_Entity.x == 10103)
        wave += CalcMove(worldpos, 0.35, 1.15, vec2(0.15, 0.06));
    if (mc_Entity.x == 10104 && (istopv > 0.9 || fract(worldpos.y + 0.0675) > 0.01))
        wave += CalcMove(worldpos, 0.35, 1.0, vec2(0.15, 0.06));
    if (mc_Entity.x == 10106)
        wave += CalcMove(worldpos, 0.35, 1.25, vec2(0.06, 0.06));        
    if (mc_Entity.x == 10107 || mc_Entity.x == 10207)
        wave += CalcMove(worldpos, 0.5, 1.25, vec2(0.06, 0.00));
    if (mc_Entity.x == 10108)
        wave.y += CalcLilypadMove(worldpos);
    #endif
    #ifdef WAVING_LEAF
    if (mc_Entity.x == 10105)
        wave += CalcMove(worldpos, 0.25, 1.0, vec2(0.08, 0.08));
    #endif
    #ifdef WAVING_LIQUID
    if (mc_Entity.x == 10203)
        wave.y += CalcLavaMove(worldpos);
    #endif
    #ifdef WAVING_EXTRA
    if (mc_Entity.x == 10204 && istopv > 0.9)
        wave += CalcMove(worldpos, 1.0, 1.5, vec2(0.0, 0.37));
    if (mc_Entity.x == 10206)
		wave += CalcLanternMove(worldpos);
    #endif

    position += wave;

    return position;
}