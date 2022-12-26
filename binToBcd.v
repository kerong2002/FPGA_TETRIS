`define bcd_uint0 bcd[3:0]
`define bcd_uint1 bcd[7:4]
`define bcd_uint2 bcd[11:8]
`define bcd_uint3 bcd[15:12]

module binToBcd4 (
    input [15:0] bin,
    output reg [15:0] bcd
);
    //parameter strLen = 2'd4;

    reg [15:0] reg_bin;
    integer i;
    always @(*) begin:hi
        bcd = 16'd0;
        reg_bin = bin;

        for ( i = 0; i < 16; i = i + 1) begin:hi2
            if (`bcd_uint0 >= 5) `bcd_uint0  = `bcd_uint0 + 3;
            if (`bcd_uint1 >= 5) `bcd_uint1  = `bcd_uint1 + 3;
            if (`bcd_uint2 >= 5) `bcd_uint2  = `bcd_uint2 + 3;
            if (`bcd_uint3 >= 5) `bcd_uint3  = `bcd_uint3 + 3;
            bcd = {bcd[14:0], reg_bin[15]};
            reg_bin = reg_bin << 1;
        end
    end
endmodule
