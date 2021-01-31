#include "MainShared.hlsl"
#include "Utils.hlsl"
#include "RaymarchUtils.hlsl"

#define DISPLAY_NORMALS 1
#define DISPLAY_DEPTH 0

#define MAX_STEPS 400
#define MAX_DISTANCE 100.0
#define SURF_DISTANCE 0.001
#define GAMMA 0.4545

// returns the distance and material to use in the render call.
float2 sdfScene(float3 p)
{
    float2 d = float2(sdSphere(p, float3(0.0f, 0.0f, 13.0f), 3.0f), 1);
    d = BlendOp(d, float2(sdSphere(p, float3(3.0f + sin(time * 1.8) + sin(time)* 0.25, 0.0f, 10.0f), 2.0f), 1));
    d = BlendOp(d, float2(sdSphere(p, float3(-3.0f - sin(time * 1.24), 0.0f + sin(time), 11.0f), 2.33f), 1));
    d = BlendOp(d, float2(sdBox(p - float3(0.0f, -2.0f, 11.0f), float3(1.5f, 1.5f, 1.5f)), 1));
    d = unionOp(d, float2(sdPlane(p, float4(0.0f, 1.0f, 0.0f, 5.5f)), 0));
    d = unionOp(d, float2(sdSphere(p, float3(-14.0f, 1.0f, 17.0f), 2.0f), 1));
    
    
    float2 shape0 = float2(sdBox(p - float3(6.5f, -3.0f, 8.0f), float3(1.5f, 1.5f, 1.5f)), 1);
    float2 shape1 = float2(sdSphere(p, float3(6.5f, -3.0f, 8.0f), 1.5f), 3);
    d = unionOp(d, lerp(shape0, shape1, sin(time) * 0.5f + 0.5f));
    
    float2 shapeA = float2(sdBox(p - float3(6, 3.0, 12), float3(1.5, 1.5, 1.5)), 1);
    float2 shapeB = float2(sdSphere(p, float3(6, 3.0, 12), 1.5), 1);
    d = unionOp(d, lerp(shapeA, shapeB, sin(time) * 1.0));
    
    float radius = (sin(time * 1.3) * 0.3 + 0.15) + 1.3;
    d = unionOp(d, float2(subsOp(sdBox(p - float3(-9, 4.5, 12), float3(1, 1, 1)),
                            sdSphere(p, float3(-9, 4.5, 12), radius)), 3));
    
    return d;
}

// lerps from a given color to a fog color using fogAmount,
// fogAmount is a calculation of the density of the fog which deppends
// on the distance of the hit from the camera eye.
// note that the fog amount uses an exp function as the increasing of fog usually works
// that way, it's not linear.
float3 addFog(float3 rgb, float3 fogColor, float dist)
{
    float startDist = 80.0f;
    float fogAmount = 1.0f - exp(-(dist - 8.0f) * (1.0f / startDist));
    return lerp(rgb, fogColor, fogAmount);
}


IntersectionResult castRaymarchRay(in float3 rayOrigin, in float3 rayDirection)
{
    IntersectionResult result;
    result.materialIndex = -1;
    float distance = 0.0f;
    
    for (int i = 0; i < MAX_STEPS; ++i)
    {
        float2 res = sdfScene(rayOrigin + rayDirection * distance);
        // if the distance is less than the minimum distance, in this case 0.001 * the actual distance
        if (res.x < (SURF_DISTANCE * distance))
        {
            result.minDistance = distance;
            return result;
        }
        else if (res.x > MAX_DISTANCE) //this implies it has surpassed the max distance threshold so it wont collide
        {
            result.materialIndex = -1;
            result.minDistance = -1.0f;
            return result;
        }
        // advance/ march forward using the sphere radius we mentioned in the slide.
        distance += res.x;
        result.materialIndex = res.y;
    }
    result.minDistance = distance;
    return result;
}

// calculates the ray from the camera for each pixel
float3 getCameraRayDir(in float2 uv, float3 camPos, float3 camTarget)
{
    // we calculate the components of the camera
    float3 camFwd = normalize(camTarget - camPos);
    float3 camRgt = normalize(cross(float3(0.0f, 1.0f, 0.0f), camFwd));
    float3 camUp = normalize(cross(camFwd, camRgt));
	
    float fovPerspective = 2.0f;
    float3 vDir = normalize(uv.x * camRgt + uv.y * camUp + camFwd * fovPerspective);
	
    return vDir;
}

// to calculate the normals we march four rays
// c being the main ray,
// then we return the normalization of the three slightly moved rays along each axis minus the main ray.
// this has to be done like this if we want to blend different surfaces and
// the center of the blended surfaces isn't clearly defined
float3 calculateNormal(in float3 pos)
{
    float c = sdfScene(pos).x;
    float2 e = float2(0.001f, 0.0f);
    return normalize(float3(sdfScene(pos + e.xyy).x, 
							sdfScene(pos + e.yxy).x, 
							sdfScene(pos + e.yyx).x) - c);
}

float3 render(in float3 rayOrigin, in float3 rayDirection)
{
    float3 col = float3(0.0f, 0.0f, 0.0f);
	
    IntersectionResult result = castRaymarchRay(rayOrigin, rayDirection);
    float distance = result.minDistance;
    int material = result.materialIndex;
    
    if (distance <= -1.0f)
    {
		// background/ skybox color
        col = float3(0.3f, 0.36f, 0.6f) - (rayDirection.y - (rayDirection.y * 1.6f));
    }
	else
    {
        if (material != -1)
        {
            float3 oneHalf = float3(0.5f, 0.5f, 0.5f);
            float3 pos = rayOrigin + rayDirection * distance;
            float3 normal = calculateNormal(pos);
            float3 light = normalize(float3(sin(time) * 1.0f, cos(time * 0.5f) + 0.5f, -0.5f));
            float depth = 1.0f - distance * 0.075f;
		
            float3 objSurfaceColor = float3(0.4f, 0.8f, 0.1f);
            
            
            if (material == 3)
            {
                objSurfaceColor = float3(0.1f, 0.4f, 0.65f);

            }
            
            if (material == 0)
            {
                float grid = checkersGradBox(pos.xz * 0.4f) * 0.03f + 0.1f;
                
                objSurfaceColor = float3(0.8f, 0.2f, 0.3f) * grid;

            }
            else
            {
                //objSurfaceColor = objSurfaceColor * 1.0f / material;
            }
            
            float3 ambientColor = float3(0.02f, 0.021f, 0.02f);
		
            float3 n_normal = normalize(normal);
            float lightImpact = max(dot(n_normal, light), 0.0f);
            float3 dirLight = float3(1.8f, 1.27f, 0.99f) * lightImpact;
            float3 ambLight = float3(0.03f, 0.04f, 0.1f);
            float3 difLight = objSurfaceColor * (dirLight + ambLight);
		
            col = difLight;
		
            
        //shadow
#if 1
            float shadow = 0.0f;
            float3 shadowRayOrigin = pos + n_normal * 0.01f;
            float3 shadowRayDirection = light;
            IntersectionResult shResult = castRaymarchRay(shadowRayOrigin, shadowRayDirection);
            float shadowDistance = shResult.minDistance;
            int shadowMaterial = shResult.materialIndex;
            if (shadowMaterial != -1)
            {
                shadow += 0.67f;
            }
            col = lerp(col, col * 0.67f, shadow);
#endif
        //col = ambientColor * objSurfaceColor * 10.0f;

#if DISPLAY_NORMALS
		col = normal * oneHalf + oneHalf;
#endif
#if DISPLAY_DEPTH
		col = float3(depth, depth, depth);
#endif
        // added based on how far each intersection ocurred
        // from the camera eye
        float3 fogCol = float3(0.30, 0.36, 0.60);
        col = addFog(col, fogCol, pos.z);
        }
        
    }
	
    return col;
}

float2 normalizeScreenCoordinates(float2 screenCoordinates)
{
    float aspectRatio = resolution.x / resolution.y;
    float2 result = 2.0f * (screenCoordinates/resolution.xy - 0.5f);
    result.x *= aspectRatio;
    return result;
}


// main pixel shader
void main(out float4 color : SV_Target, in OutputVS input)
{
    float3 camPos = cameraPosition;
    float3 camTarget = float3(0.0f, 0.0f, 0.0f);
	
    float2 uv = input.uv;
    float2 screenCoord = float2(input.position.x, resolution.y - input.position.y);
    float2 coords = normalizeScreenCoordinates(screenCoord);
	
    float3 rayDirection = getCameraRayDir(coords, camPos, camTarget);
	
    float3 col = render(camPos, rayDirection);
	
	// gamma correction, adjusted to my laptop's screen gamma curve
    // each screen has a different gamma curve so tweaking might be necessary
    col = pow(abs(col), float3(GAMMA, GAMMA, GAMMA));
	
	color = float4(col, 1.0f);
	
	
}
