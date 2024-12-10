// This changes the representation of sharings, from a bit-based share representation
// where all the shares of a bit in a block are adjacent, to a block-based share
// representation where the block is viewed as a unit as a whole and the representation 
// starts with the first share of the block.
// shbit: view every bit in the "block" as a shared unit.
// shblk: see the whole block as a shared unit.
// The bit-based representation is more convenient for computing on sharins as it
// is easy to extract subsets of bits, while the block-based representation is often
// more convenient for interfacing and debugging.
module shbit2shblk
#
(
    parameter d = 2,
    parameter width = 8
)
(
    shbit,
    shblk
);

// IOs
input [d*width-1:0] shbit;
output [d*width-1:0] shblk;

genvar i,j;
generate
for(i=0;i<width;i=i+1) begin: bit_wiring
    for(j=0;j<d;j=j+1) begin: share_wiring
        assign shblk[width*j + i] = shbit[d*i + j];
    end
end
endgenerate


endmodule
