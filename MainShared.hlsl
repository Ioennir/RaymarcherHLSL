cbuffer ConstantBuffer : register(b0)
{
	float4x4 worldMatrix;
	float4x4 viewProjectionMatrix;
	float4x4 worldViewProjectionMatrix;
	float3 cameraPosition;
	float time; // in seconds
	float2 resolution; // width, height
}

// Output struct from the Vertex shader
// Input struct for the Pixel shader
struct OutputVS
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD;
};
