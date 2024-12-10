module aes_sbox_dom
#
(
    parameter d=2
)
(
    clk,
    sboxIn,
    rnd_bus0w,
    rnd_bus1w,
    rnd_bus2w,
    rnd_bus3w,
    sboxOut
);

`include "design.vh"

    input clk;
    input [8*d-1:0] sboxIn;
    input [rnd_bus0-1:0] rnd_bus0w;
    input [rnd_bus1-1:0] rnd_bus1w;
    input [rnd_bus2-1:0] rnd_bus2w;
    input [rnd_bus3-1:0] rnd_bus3w;
    output [8*d-1:0] sboxOut;

    wire [8*d-1 : 0] _XxDI;
    wire [2*d*(d-1)-1 : 0] _Zmul1xDI; // for y1 * y0
    wire [2*d*(d-1)-1 : 0] _Zmul2xDI; // for 0 * y1
    wire [2*d*(d-1)-1 : 0] _Zmul3xDI; // for 0 * y0
    wire [d*(d-1)-1 : 0] _Zinv1xDI; // for inverter
    wire [d*(d-1)-1 : 0] _Zinv2xDI;
    wire [d*(d-1)-1 : 0] _Zinv3xDI;
    wire [2*blind_n_rnd-1 : 0] _Binv1xDI; // for inverter
    wire [2*blind_n_rnd-1 : 0] _Binv2xDI; // ...
    wire [2*blind_n_rnd-1 : 0] _Binv3xDI; // ...
    wire [8*d-1 : 0] _QxDO;

    genvar j;
    genvar i;
    for (j= 0; j < 8; j=j+1) begin
	    for (i = 0; i < d; i=i+1) begin
            assign _XxDI[i*8+j] = sboxIn[j*d+i];
            assign sboxOut[j*d+i] = _QxDO[i*8+j];
        end
    end
    wire [7:0] out;
    assign out = _QxDO[15:8] ^ _QxDO[7:0];

    wire [7:0] in;
    assign in = _XxDI[15:8] ^ _XxDI[7:0];

    assign _Zmul1xDI = rnd_bus0w[0 +: 2*d*(d-1)];
    assign _Zmul2xDI = rnd_bus3w[0 +: 2*d*(d-1)];
    assign _Zmul3xDI = rnd_bus3w[2*d*(d-1) +: 2*d*(d-1)];

    assign _Zinv1xDI = rnd_bus1w[0 +: d*(d-1)];
    assign _Zinv2xDI = rnd_bus2w[0 +: d*(d-1)];
    assign _Zinv3xDI = rnd_bus2w[d*(d-1) +: d*(d-1)];


    assign _Binv1xDI = rnd_bus1w[d*(d-1) +: 2*blind_n_rnd];
    assign _Binv2xDI = rnd_bus2w[2*d*(d-1) +: blind_n_rnd*2];
    assign _Binv3xDI = rnd_bus2w[2*(d*(d-1) + blind_n_rnd) +: blind_n_rnd*2];

    aes_sbox #(.PIPELINED(1), .EIGHT_STAGED(0), .SHARES(d))
    inst_aes_box (
        .ClkxCI(clk),
        .RstxBI(1'b1),
        ._XxDI(_XxDI),
        ._Zmul1xDI(_Zmul1xDI),
        ._Zmul2xDI(_Zmul2xDI),
        ._Zmul3xDI(_Zmul3xDI),
        ._Zinv1xDI(_Zinv1xDI),
        ._Zinv2xDI(_Zinv2xDI),
        ._Zinv3xDI(_Zinv3xDI),
        // ._Bmul1xDI(_Bmul1xDI),
        ._Binv1xDI(_Binv1xDI),
        ._Binv2xDI(_Binv2xDI),
        ._Binv3xDI(_Binv3xDI),
        ._QxDO(_QxDO)
    );
endmodule
