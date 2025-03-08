
module MSKaes_128bits_KS_round
#
(
    parameter d = 2,
    parameter LATENCY = 4
)
(
    // Global
    clk,
    // Data
    sh_key_in,
    sh_key_out,
    sh_RCON_in, //expected to be valid at the last cycle of the round
    // Randomness
    rnd_bus0w,
    rnd_bus1w,
    rnd_bus2w
    ,rnd_bus3w
);

`include "design.vh"

// IOs
input clk;

input [128*d-1:0] sh_key_in;
output [128*d-1:0] sh_key_out;
input [8*d-1:0] sh_RCON_in;

input [4*rnd_bus0-1:0] rnd_bus0w;
input [4*rnd_bus1-1:0] rnd_bus1w;
input [4*rnd_bus2-1:0] rnd_bus2w;
input [4*rnd_bus3-1:0] rnd_bus3w;

wire [128*d-1:0] sh_key_back;
assign sh_key_back[0 +: 12*8*d] = sh_key_in[0 +: 12*8*d];

MSKlin_map #(.d(d), .count(4), .matrix_sel(3))
lin_map_key(
    .sh_state_in(sh_key_in[12*8*d +: 4*8*d]),
    .sh_state_out(sh_key_back[12*8*d +: 4*8*d])
    );

// Byte matrix representation
genvar i;
wire [8*d-1:0] sh_byte_in [15:0];
wire [8*d-1:0] sh_byte_out [15:0];
generate
for(i=0;i<16;i=i+1) begin: byte_in
    assign sh_byte_in[i] = sh_key_back[8*d*i +: 8*d];
    assign sh_key_out[8*d*i +: 8*d] = sh_byte_out[i];
end
endgenerate

// Sbox for the key scheduling
wire [8*d-1:0] sh_lcol_SB [3:0];
generate
for(i=0;i<4;i=i+1) begin: sbox_isnt
    aes_sbox_dom #(.d(d))
    sbox_unit(
        .clk(clk),
        .sboxIn(sh_key_in[(12+i)*8*d +: 8*d]),
        .rnd_bus0w(rnd_bus0w[i*rnd_bus0 +: rnd_bus0]),
        .rnd_bus1w(rnd_bus1w[i*rnd_bus1 +: rnd_bus1]),
        .rnd_bus2w(rnd_bus2w[i*rnd_bus2 +: rnd_bus2]),
        .rnd_bus3w(rnd_bus3w[i*rnd_bus3 +: rnd_bus3]),
        .sboxOut(sh_lcol_SB[i])
    );
end
endgenerate

// From Sbox rotation and RCON addition
wire [8*d-1:0] sh_lcol_SB_RCON [3:0];
MSKxor #(.d(d), .count(8))
xor_rcon(
    .ina(sh_RCON_in),
    .inb(sh_lcol_SB[1]),
    .out(sh_lcol_SB_RCON[0])
);
assign sh_lcol_SB_RCON[1] = sh_lcol_SB[2];
assign sh_lcol_SB_RCON[2] = sh_lcol_SB[3];
assign sh_lcol_SB_RCON[3] = sh_lcol_SB[0];


// Create the pipeline for the key with the parametrized latency
genvar j;
wire [8*d-1:0] sh_key_byte_delayed [15:0];
generate
for(i=0;i<16;i=i+1) begin: key_byte_pipeline
    for(j=0;j<LATENCY;j=j+1) begin: stage
        wire [8*d-1:0] D,Q;
        MSKreg #(.d(d),.count(8))
        reg_stage(
            .clk(clk),
            .in(D),
            .out(Q)
        );
        if (j==0) begin
            assign D = sh_byte_in[i];
        end else begin
            assign D = stage[j-1].Q;
        end
    end
    assign sh_key_byte_delayed[i] = stage[LATENCY-1].Q;
end
endgenerate

//// Compute the new first column
MSKxor #(.d(d), .count(8))
xor_00(
    .ina(sh_lcol_SB_RCON[0]),
    .inb(sh_key_byte_delayed[0]),
    .out(sh_byte_out[0])
);

MSKxor #(.d(d), .count(8))
xor_10(
    .ina(sh_lcol_SB_RCON[1]),
    .inb(sh_key_byte_delayed[1]),
    .out(sh_byte_out[1])
);

MSKxor #(.d(d), .count(8))
xor_20(
    .ina(sh_lcol_SB_RCON[2]),
    .inb(sh_key_byte_delayed[2]),
    .out(sh_byte_out[2])
);

MSKxor #(.d(d), .count(8))
xor_30(
    .ina(sh_lcol_SB_RCON[3]),
    .inb(sh_key_byte_delayed[3]),
    .out(sh_byte_out[3])
);

//// Compute the other one
generate
for(i=0;i<3;i=i+1) begin: column_add
    for(j=0;j<4;j=j+1) begin: byte_add
        MSKxor #(.d(d), .count(8))
        xor_col(
            .ina(sh_byte_out[4*i+j]),
            .inb(sh_key_byte_delayed[4*(i+1)+j]),
            .out(sh_byte_out[4*(i+1)+j])
        );
    end
end
endgenerate
endmodule
