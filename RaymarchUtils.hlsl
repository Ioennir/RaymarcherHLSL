struct IntersectionResult
{
    float minDistance;
    int materialIndex;
};

// returns a random float between 0,1
float rand01f(float2 co)
{
    return frac(sin(dot(co.xy, float2(12.9898, 78233.0))) * 43758.5453);
}

// http://iquilezles.org/www/articles/checkerfiltering/checkerfiltering.htm
float checkersGradBox(float2 p)
{
    float2 w = fwidth(p) + 0.001;
    float2 i = 2.0 * (abs(frac((p - 0.5 * w) * 0.5) - 0.5) - abs(frac((p + 0.5 * w) * 0.5) - 0.5)) / w;
    return 0.5 - 0.5 * i.x * i.y;
}

// polynomial smooth min (k = 0.1);
float sminCubic(float a, float b, float k)
{
    float h = max(k - abs(a - b), 0.0);
    return min(a, b) - h * h * h / (6.0 * k * k);
}

// using a k coeficien blend using the polynomial smooth
// by lerping the distances using the result of the polynomial smooth
float2 BlendOp(float2 d1, float2 d2)
{
    float k = 2.0f;
    float d = sminCubic(d1.x, d2.x, k);
    float m = lerp(d1.y, d2.y, clamp(d1.x - d, 0.0f, 1.0f));
    return float2(d, m);
}

//perform an inverse intersection 
float subsOp(float d1, float d2)
{
    return max(-d2, d1);
}

// returns the minimum distance (the surface that is nearest to the cam eye)
float2 unionOp(float2 d1, float2 d2)
{
    return (d1.x < d2.x) ? d1 : d2;

}

// sphere SDF, p point in 3d space, c center, r radius
float sdSphere(in float3 p, in float3 c, in float r)
{
	return length(p - c) - r;
}

// p: point in 3d space, n.xyz: plane equation, n.w: distance from origin.
float sdPlane(float3 p, float4 n)
{
    return dot(p, n.xyz) + n.w;
}

// p: point in 3d space, size: size of the box in x,y,z axis.
float sdBox(float3 p, float3 size)
{
    float3 d = abs(p) - size;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}