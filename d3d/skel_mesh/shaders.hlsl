cbuffer constants : register(b0) {
	matrix mvp;
};

struct vs_in {
	float3 position : POS;
	float3 normal 	: NORM;
	float2 uv	  	: UV;
	uint4  bones	: BONES;
	float4 weight	: WEIGHT;
};

struct vs_out {
	float4 position : SV_POSITION;
};

vs_out vs_main(vs_in input) {
	vs_out output;
	output.position = mul(mvp,float4(input.position,1.0f));
	return output;
}

float4 ps_main(vs_out input) : SV_TARGET {
	return float4(1.0,1.0,1.0,1.0);
}

