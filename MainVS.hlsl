#include "MainShared.hlsl"
#include "Utils.hlsl"

struct InputVS
{
	float4 position : POSITION; //clip space
	float2 uv : TEXCOORD0;		//worldPos
};

OutputVS main(in InputVS input)
{	
	OutputVS output;
    output.position = float4(input.position.xyz, 1.0f); //mul(worldViewProjectionMatrix, input.position); //float4(input.position.xyz,1.0f);//
	output.uv = input.uv;
	return output;
}
