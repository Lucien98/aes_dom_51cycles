// This changes the representation of sharings, from a block-based representation to
// a bit-based representation, seed shblk2shbit.v for details on these
// representations.
module shblk2shbit
#
(
    parameter d = 2,
    parameter width = 8
)
(
    shblk,
    shbit
);

// IOs
input [d*width-1:0] shblk;
output [d*width-1:0] shbit;

genvar i,j;
generate
for(i=0;i<width;i=i+1) begin
    for(j=0;j<d;j=j+1) begin
        assign shbit[d*i + j] = shblk[width*j + i];
    end
end
endgenerate


endmodule
