module MSKlin_map
#
(
    parameter d = 2,
    parameter count = 16,
    parameter matrix_sel = 1
)
(
	sh_state_in,
	sh_state_out
);
input [8*count*d-1:0] sh_state_in;
output [8*count*d-1:0] sh_state_out;

// wire [8*d-1:0] sh_byte_in [count-1:0];
// wire [8*d-1:0] sh_byte_out [count-1:0];

wire [8*count*d-1:0] shblk_state_in;
wire [8*count*d-1:0] shblk_state_out;


// wire [8*d-1:0] shblk_byte_in [count-1:0];
// wire [8*d-1:0] shblk_byte_out [count-1:0];

genvar i;
genvar j;
// Create the Input Mapping
shbit2shblk #(.d(d),.width(count*8))
switch_encoding_in (
    .shbit(sh_state_in),
    .shblk(shblk_state_in)
);
generate
for(i=0;i<d;i=i+1) begin: lin_map_isnt
	for(j = 0; j < count; j=j+1) begin: count_inst
	    lin_map #(.MATRIX_SEL(matrix_sel))
	    input_mapping (
	        .DataInxDI(shblk_state_in[i*8*count+8*j+:8]),
	        .DataOutxDO(shblk_state_out[i*8*count+8*j+:8])
	    );
	end
end
endgenerate

shblk2shbit #(.d(d),.width(count*8))
switch_encoding_out (
    .shblk(shblk_state_out),
    .shbit(sh_state_out)
);

// generate
// for(i=0;i<count;i=i+1) begin: byte_out
//     assign sh_state_out[8*d*i +: 8*d] = sh_byte_out[i];
// end
// endgenerate

endmodule