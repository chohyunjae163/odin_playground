struct vs_in {
	float3 position : POS;
};

struct vs_out {
	float4 position : SV_POSITION;
};

vs_out vs_main(vs_in input) {
	vs_out output;
	output.position = float4(input.position,0.0);
	return output;
}

float4 ps_main(vs_out input) : SV_TARGET {
	return float4(0.0,1.0,1.0,1.0);
}

