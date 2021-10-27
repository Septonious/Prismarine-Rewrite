#define TONEMAP_TS 0.5 //0-1
#define TONEMAP_TL 0.5 //0-1
#define TONEMAP_SS 2.0 //0-inf
#define TONEMAP_SL 1.0 //0-1
#define TONEMAP_SA 1.0 //0-1
#define GAMMA 1.0

struct Segment {
    vec2 offset;
    vec2 scale;
    vec2 gradient; //lnA, B
};

struct Curve {
    Segment segments[3];
    float x0;
    float x1;
    float invW;
};

float Eval(float x, Segment segment) {
	float x0 = (x - segment.offset.x) * segment.scale.x;
	float y0 = x0 > 0.0 ? exp(segment.gradient.x + segment.gradient.y * log(x0)) : 0.0;

	return y0 * segment.scale.y + segment.offset.y;
}

float EvalCurve(float x, Curve curve) {
    float normX = x * curve.invW;
    int index = (normX < curve.x0) ? 0 : ((normX < curve.x1) ? 1 : 2);
    return Eval(normX, curve.segments[index]);
}

vec2 SolveAB(float x0, float y0, float m){
    float B = (m * x0) / y0;
    return vec2(log(y0) - B * log(x0), B);
}

// convert to y=mx+b
void AsSlopeIntercept(out float m, out float b, float x0, float x1, float y0, float y1)
{
	float dy = y1 - y0;
	float dx = x1 - x0;
	m = (dx == 0) ? 1.0 : dy / dx;

	b = y0 - x0 * m;
}

float EvalDerivativeLinearGamma(float m, float b, float g, float x) {
	return g * m * pow(m * x + b, g - 1.0);
}

Curve CreateCurve(){
    float toeLength = pow(TONEMAP_TL, 2.2);
    float toeStrength = TONEMAP_TS;
    float shoulderStrength = TONEMAP_SS;
    float shoulderLength = max(TONEMAP_SL, 1e-5);
    float shoulderAngle = TONEMAP_SA;
	float gamma = GAMMA;

    float x0 = toeLength * 0.5;
    float y0 = (1.0 - toeStrength) * x0;

    float remainingY = 1.0 - y0;

    float initialW = x0 + remainingY;

    float y1_offset = (1.0 - shoulderLength) * remainingY;
    float x1 = x0 + y1_offset;
    float y1 = y0 + y1_offset;

    float extraW = exp2(shoulderStrength) - 1.0;

    float W = initialW + extraW;

	float overshootX = W * 2.0 * shoulderAngle * shoulderStrength;
	float overshootY = 0.5 * shoulderAngle * shoulderStrength;

    x0 /= W; x1 /= W;
    overshootX /= W;

    float m, b;
    AsSlopeIntercept(m, b, x0, x1, y0, y1);

    Segment midSegment;
    midSegment.offset = vec2(-b / m, 0.0);
    midSegment.scale = vec2(1.0);
    midSegment.gradient = vec2(log(m), 1.0) * gamma;

    float toeM = EvalDerivativeLinearGamma(m, b, gamma, x0);
    float shoulderM = EvalDerivativeLinearGamma(m, b, gamma, x1);

    y0 = max(1e-5, pow(y0, gamma));
    y1 = max(1e-5, pow(y1, gamma));

    overshootY = pow(1.0 + overshootY, gamma) - 1.0;

    Segment toeSegment;
    toeSegment.offset = vec2(0.0);
    toeSegment.scale = vec2(1.0);
    toeSegment.gradient = SolveAB(x0, y0, toeM);

    Segment shoulderSegment;
    float xs = 1.0 + overshootX - x1;
    float ys = 1.0 + overshootY - y1;
    shoulderSegment.gradient = SolveAB(xs, ys, shoulderM);
    shoulderSegment.offset = vec2(1.0 + overshootX, 1.0 + overshootY);
    shoulderSegment.scale = vec2(-1.0);

    float invScale = 1.0 / Eval(1.0, shoulderSegment);
    toeSegment.offset.y *= invScale;
    toeSegment.scale.y *= invScale;
    midSegment.offset.y *= invScale;
    midSegment.scale.y *= invScale;
    shoulderSegment.offset.y *= invScale;
    shoulderSegment.scale.y *= invScale;

    Curve curve;
    curve.segments[0] = toeSegment;
    curve.segments[1] = midSegment;
    curve.segments[2] = shoulderSegment;
    curve.x0 = x0;
    curve.x1 = x1;
    curve.invW = 1.0 / W;

    return curve;
}

vec3 PiecewiseFilmicTonemap(vec3 color) {
    Curve curve = CreateCurve();

    color.r = EvalCurve(color.r, curve);
    color.g = EvalCurve(color.g, curve);
    color.b = EvalCurve(color.b, curve);
    return color;
}