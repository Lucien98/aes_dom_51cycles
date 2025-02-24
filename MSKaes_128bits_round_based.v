`ifndef DEFAULTSHARES
`define DEFAULTSHARES 2
`endif
`ifndef DEFAULTLATENCY
`define DEFAULTLATENCY 4
`endif

module MSKaes_128bits_round_based
#
(
    parameter d=`DEFAULTSHARES,
    parameter LATENCY = 4//`DEFAULTLATENCY
)
(
    // Global
    nrst,
    clk,
    valid_in,
    ready,
    cipher_valid,
    // Data
    sh_plaintext,
    sh_key,
    sh_ciphertext,
    // Randomness busses (required for the Sboxes)
    rnd_bus0w,
    rnd_bus1w,
    rnd_bus2w
`ifdef CANRIGHT_SBOX
    ,rnd_bus3w
`endif
);

`include "design.vh"

// IOs ports

input nrst;

input clk;

input valid_in;

output ready;

output cipher_valid;


input [128*d-1:0] sh_plaintext;

input [128*d-1:0] sh_key;

output [128*d-1:0] sh_ciphertext;


input [20*rnd_bus0-1:0] rnd_bus0w;

input [20*rnd_bus1-1:0] rnd_bus1w;

input [20*rnd_bus2-1:0] rnd_bus2w;
`ifdef CANRIGHT_SBOX

input [20*rnd_bus3-1:0] rnd_bus3w;
`endif

///// Control pipe for the round
wire [7:0] ctrl_RCON_in, ctrl_RCON_KS, ctrl_RCON_out;
MSKaes_128bits_pipe_ctrl #(.LATENCY(LATENCY))
pipe_control(
    .clk(clk),
    .nrst(nrst),
    .RCON_in(ctrl_RCON_in),
    .RCON_delayed(ctrl_RCON_KS),
    .RCON_out(ctrl_RCON_out)
);
wire feedback_valid = (ctrl_RCON_out != 8'h0);
wire feedback_finish = (ctrl_RCON_out == 8'h6c);

wire [8*d-1:0] round_sh_RCON;
MSKcst #(.d(d),.count(8))
cst_RCON(
    .cst(ctrl_RCON_KS),
    .out(round_sh_RCON)
);

////// Round logic
wire [128*d-1:0] round_sh_state_in, round_sh_key_in;
wire [128*d-1:0] round_sh_state_out, round_sh_key_out;
wire [128*d-1:0] round_sh_state_SR_out, round_sh_state_AK_out;
wire round_cleaning_on;
MSKaes_128bits_round_with_cleaning #(.d(d),.LATENCY(LATENCY))
round_logic(
    .clk(clk),
    .sh_state_in(round_sh_state_in),
    .sh_key_in(round_sh_key_in),
    .sh_RCON(round_sh_RCON),
    .sh_state_out(round_sh_state_out),
    .sh_key_out(round_sh_key_out),
    .sh_state_SR_out(round_sh_state_SR_out),
    // .sh_state_AK_out(round_sh_state_AK_out),
    .rnd_bus0w(rnd_bus0w),
    .rnd_bus1w(rnd_bus1w),
    .rnd_bus2w(rnd_bus2w),
`ifdef CANRIGHT_SBOX
    .rnd_bus3w(rnd_bus3w),
`endif
    .cleaning_on(round_cleaning_on)
);

//// Generation of the input control logic 
assign ready = ~feedback_valid;
    
////// Input stage             
wire [128*d-1:0] to_sh_state, to_sh_key;
wire [8*d-1:0] to_RCON;
reg [7:0] from_RCON;

wire [128*d-1:0] statereg_in;
MSKmux #(.d(d), .count(128))
mux_statereg_in(
    .sel(feedback_finish),
    .in_true(sh_postAK),
    .in_false(sh_postAK_cleaned),
    .out(statereg_in)
);

MSKreg #(.d(d),.count(128))
inreg_state(
    .clk(clk),
    .in(statereg_in/*to_sh_state*/),
    .out(round_sh_state_in)
);

MSKreg #(.d(d),.count(128))
inreg_key(
    .clk(clk),
    .in(/*to_sh_key*/ sh_key_postLM),
    .out(round_sh_key_in)
);

wire [128*d-1:0] sh_key_postLM; 
assign sh_key_postLM[0 +: 12*8*d] = to_sh_key[0 +: 12*8*d];

MSKlin_map #(.d(d), .count(4))
lin_map_key(
    .sh_state_in(to_sh_key[12*8*d +: 4*8*d]),
    .sh_state_out(sh_key_postLM[12*8*d +: 4*8*d])
    );

// AK
wire [128*d-1:0] sh_postAK; 
MSKaes_128bits_AK #(.d(d))
AKmod(
    .sh_state_in(to_sh_state),
    .sh_key_in(to_sh_key),
    .sh_state_out(sh_postAK)
);

wire [128*d-1:0] sh_postLM;
MSKlin_map #(.d(d), .count(16))
lin_map(
    .sh_state_in(sh_postAK),
    .sh_state_out(sh_postLM)
    );

// SB 
wire [128*d-1:0] sh_postAK_cleaned;
MSKmux #(.d(d), .count(128))
mux_clean_sbox(
    .sel(round_cleaning_on),
    .in_true(sh_zero),
    .in_false(sh_postLM),
    .out(sh_postAK_cleaned)
);


always@(posedge clk)
if (~nrst) begin
    from_RCON <= 8'h0; 
end else begin
    from_RCON <= to_RCON;
end

// Constant sharing of 0
wire [128*d-1:0] sh_zero;
MSKcst #(.d(d), .count(128))
sh_zero_mod(
    .cst(128'b0),
    .out(sh_zero)
);

//// Input mux
wire fetch_in = ready & valid_in;

// wire [128*d-1:0] sh_state_tmp;
// MSKmux #(.d(d),.count(128))
// mux_state_in(
//     .sel(fetch_in),
//     .in_true(sh_plaintext),
//     .in_false(sh_zero), // sh_key
//     .out(sh_state_tmp)
// );

// wire [128*d-1:0] sh_key_tmp;
// MSKmux #(.d(d),.count(128))
// mux_key_in(
//     .sel(fetch_in),
//     .in_true(sh_key),
//     .in_false(sh_zero), // sh_plaintext
//     .out(sh_key_tmp)
// );

wire [128*d-1:0] sh_feedback_state_choice;
MSKmux #(.d(d),.count(128))
mux_feedback_choice(
    .sel(feedback_finish),
    .in_true(round_sh_state_SR_out),
    .in_false(round_sh_state_out),
    .out(sh_feedback_state_choice)
);

// MSKmux #(.d(d),.count(128))
// mux_feedback_state(
//     .sel(feedback_valid),
//     .in_true(sh_feedback_state_choice),
//     .in_false(sh_state_tmp),
//     .out(to_sh_state)
// );

assign to_sh_state = feedback_valid ? sh_feedback_state_choice : (fetch_in ? sh_plaintext : sh_feedback_state_choice);//;sh_feedback_state_choice


// MSKmux #(.d(d),.count(128))
// mux_feedback_key(
//     .sel(feedback_valid),
//     .in_true(round_sh_key_out),
//     .in_false(sh_key_tmp /*round_sh_key_out*/),
//     .out(to_sh_key)
// );

assign to_sh_key = feedback_valid ? round_sh_key_out : (fetch_in ? sh_key : round_sh_key_out);//sh_key_tmp;

// Rcon input mux
wire fetch_feedback_RCON = feedback_valid & (~feedback_finish);
wire [7:0] RCON_tmp = fetch_in ? 8'h01 : 8'h0;
assign to_RCON = fetch_feedback_RCON ? ctrl_RCON_out : RCON_tmp; 
assign ctrl_RCON_in = from_RCON;

///// Cipher valid logic
reg reg_cipher_valid;
always@(posedge clk)
if(~nrst) begin
    reg_cipher_valid = 0;
end else begin
    reg_cipher_valid = feedback_finish;
end
assign cipher_valid = reg_cipher_valid;//feedback_finish;

assign round_cleaning_on = reg_cipher_valid;

MSKmux #(.d(d),.count(128))
mux_ciphervalid(
    .sel(cipher_valid),
    .in_true(round_sh_state_in/*round_sh_state_AK_out*/),
    .in_false(sh_zero),//round_sh_state_AK_out
    .out(sh_ciphertext)
);


endmodule
