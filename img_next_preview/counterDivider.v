module counterDivider( CLK, RST, CLK_Out ); /* 除頻器 Use 50MHz OSC */

    // 除頻設定 1kHz 1ms
    parameter size = 16;
    parameter countDivider = 16'd1_000;
    localparam countDivider_D2  = countDivider / 2;

    input CLK, RST;
    output reg CLK_Out;

    reg [size-1:0] Cnt = 0;

    always @(posedge CLK or posedge RST ) begin
        if( RST ) begin
            Cnt <= 0;
            CLK_Out <= 0;
        end else if( Cnt == countDivider_D2 ) begin
            Cnt <= 0;
            CLK_Out <= ~CLK_Out;
        end else
            Cnt <= Cnt + 1'b1;
    end

endmodule