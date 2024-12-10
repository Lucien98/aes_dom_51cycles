
module MSKaes_128bits_SB
#
(
    parameter d = 2
)
(
    // Global
    clk,
    nrst,
    // Values
    sh_state_in,
    sh_state_out,
    // Randomness
    rnd_bus0w,
    rnd_bus1w,
    rnd_bus2w
`ifdef CANRIGHT_SBOX
    ,rnd_bus3w
`endif
);

`include "design.vh"

// IOs
input clk;
input nrst;

input [128*d-1:0] sh_state_in;
output [128*d-1:0] sh_state_out;

input [16*rnd_bus0-1:0] rnd_bus0w;
input [16*rnd_bus1-1:0] rnd_bus1w;
input [16*rnd_bus2-1:0] rnd_bus2w;
`ifdef CANRIGHT_SBOX
input [16*rnd_bus3-1:0] rnd_bus3w;
`endif

// Byte matrix representation
wire [8*d-1:0] sh_byte_in [15:0];
wire [8*d-1:0] sh_byte_out [15:0];


genvar i;
generate
for(i=0;i<16;i=i+1) begin: byte_in
    assign sh_byte_in[i] = sh_state_in[8*d*i +: 8*d];
end
endgenerate

// Create the SBOX
generate
for(i=0;i<16;i=i+1) begin: sbox_isnt
    aes_sbox_dom #(.d(d))
    sbox_unit(
        .clk(clk),
        .sboxIn(sh_byte_in[i]),
        .rnd_bus0w(rnd_bus0w[i*rnd_bus0 +: rnd_bus0]),
        .rnd_bus1w(rnd_bus1w[i*rnd_bus1 +: rnd_bus1]),
        .rnd_bus2w(rnd_bus2w[i*rnd_bus2 +: rnd_bus2]),
        .rnd_bus3w(rnd_bus3w[i*rnd_bus3 +: rnd_bus3]),
        .sboxOut(sh_byte_out[i])
    );
end
endgenerate
// Assign output

generate
for(i=0;i<16;i=i+1) begin: byte_out
    assign sh_state_out[8*d*i +: 8*d] = sh_byte_out[i];
end
endgenerate



endmodule
