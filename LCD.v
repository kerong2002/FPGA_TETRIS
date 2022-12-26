`include "./binToBcd.v"

`define displayregLine2 {LCD_L[9],LCD_L[8],LCD_L[7],LCD_L[6],LCD_L[5],LCD_L[4],LCD_L[3],LCD_L[2],LCD_L[1],LCD_L[0],displayreg[16],displayreg[17],displayreg[18],displayreg[19],displayreg[20],displayreg[21],displayreg[22],displayreg[23],displayreg[24],displayreg[25],displayreg[26],displayreg[27],displayreg[28],displayreg[29],displayreg[30],displayreg[31],LCD_R[9],LCD_R[8],LCD_R[7],LCD_R[6],LCD_R[5],LCD_R[4],LCD_R[3],LCD_R[2],LCD_R[1],LCD_R[0],LCD_B[15],LCD_B[14],LCD_B[13],LCD_B[12],LCD_B[11],LCD_B[10],LCD_B[9],LCD_B[8],LCD_B[7],LCD_B[6],LCD_B[5],LCD_B[4],LCD_B[3],LCD_B[2],LCD_B[1],LCD_B[0]}

`define lcdLine1 {displayreg[0],displayreg[1],displayreg[2],displayreg[3],displayreg[4],displayreg[5],displayreg[6],displayreg[7],displayreg[8],displayreg[9],displayreg[10],displayreg[11],displayreg[12],displayreg[13],displayreg[14],displayreg[15]}

`define lcdLine2 {displayreg[16],displayreg[17],displayreg[18],displayreg[19],displayreg[20],displayreg[21],displayreg[22],displayreg[23],displayreg[24],displayreg[25],displayreg[26],displayreg[27],displayreg[28],displayreg[29],displayreg[30],displayreg[31]}

module LCD(Clk, rst, gameState, timeNum, point, SW, LCD_DATA, LCD_EN, LCD_RW, LCD_RS, DATA_IN, LEDR, LEDG);
    input           Clk, rst;
    input   [3:0]   DATA_IN;
    inout   [7:0]   LCD_DATA;
    output          LCD_EN, LCD_RW, LCD_RS;
    input [1:0] SW;
    output reg [17:0] LEDR;
    output wire [8:0] LEDG;
    input [1:0] gameState;
    wire  [127:0] gameStr[2:0];
    input [9:0] timeNum;
    input [6:0] point;

    assign gameStr[0] = { {5{8'h20}}, 40'h53_54_41_52_54,    {6{8'h20}} };
    assign gameStr[1] = { {5{8'h20}}, 48'h47_41_4D_49_4E_47, {5{8'h20}} };
    assign gameStr[2] = { {3{8'h20}}, 32'h47_41_4D_45, 8'h20, 32'h_4F_56_45_52 , {4{8'h20}} };

    wire [3:0] time1000Num;
    wire [3:0] time_100Num;
    wire [3:0] time__10Num;
    wire [3:0] time___1Num;
    binToBcd4 timeBcd(
        {6'b0, timeNum},
        {time1000Num, time_100Num, time__10Num, time___1Num}
    );

    wire [3:0] time1000ascii;
    wire [3:0] time_100ascii;
    wire [3:0] time__10ascii;
    wire [3:0] time___1ascii;
    assign time1000ascii = time1000Num + 8'h30;
    assign time_100ascii = time_100Num + 8'h30;
    assign time__10ascii = time__10Num + 8'h30;
    assign time___1ascii = time___1Num + 8'h30;

    wire [3:0] point1000;
    wire [3:0] point_100;
    wire [3:0] point__10;
    wire [3:0] point___1;
    binToBcd4 pointBcd(
        {9'b0, point},
        {point1000, point_100, point__10, point___1}
    );

    wire [3:0] point1000ascii;
    wire [3:0] point_100ascii;
    wire [3:0] point__10ascii;
    wire [3:0] point___1ascii;
    assign point1000ascii = point1000 + 8'h30;
    assign point_100ascii = point_100 + 8'h30;
    assign point__10ascii = point__10 + 8'h30;
    assign point___1ascii = point___1 + 8'h30;

    reg     [3:0]   state, next_command;
    // Enter new ASCII hex data above for LCD Display
    reg     [7:0]   DATA_BUS_VALUE;
    reg     [7:0]   Next_Char;
    reg     [19:0]  CLK_COUNT_400HZ;
    reg     [4:0]   CHAR_COUNT;
    reg             CLK_400HZ, LCD_RW, LCD_EN, LCD_RS;
    wire    [79:0]   STD_ID[2:0];
    assign STD_ID[0] = {8'h43, 8'h31, 8'h31, 8'h30, 8'h31, 8'h35, 8'h32, 8'h33, 8'h35, 8'h31};
    assign STD_ID[1] = {8'h43, 8'h31, 8'h31, 8'h30, 8'h31, 8'h35, 8'h32, 8'h33, 8'h33, 8'h38};
    assign STD_ID[2] = {8'h43, 8'h31, 8'h31, 8'h30, 8'h31, 8'h35, 8'h32, 8'h33, 8'h35, 8'h33};
    //wire    [239:0]   STD_LCD_ID[2:0];
    //assign STD_LCD_ID = {10{8'h20}};

    reg     [5:0]   font_addr;
    wire    [7:0]   font_data;

    wire clk72;
    counterDivider #(50, 50000000/4) D21(Clk, ~rst, clk72);
    always @(*) begin
        LEDR[15] = clk72;
        LEDR[14] = Clk;
        LEDR[13] = CLK_400HZ;
    end

    parameter
    RESET           = 4'h0,
    DROP_LCD_E      = 4'h1,
    HOLD            = 4'h2,
    DISPLAY_CLEAR   = 4'h3,
    MODE_SET        = 4'h4,
    Print_String    = 4'h5,
    LINE2           = 4'h6,
    RETURN_HOME     = 4'h7,
    CG_RAM_HOME     = 4'h8,
    write_CG        = 4'h9,
    CUSTOM_OP       = 4'hA;


    assign LCD_DATA = LCD_RW ? 8'bZZZZZZZZ : DATA_BUS_VALUE;

    Custom_font_ROM ROM_U(.addr(font_addr), .out_data(font_data));
    //LCD_display_string u1(.index(CHAR_COUNT), .out(Next_Char), .DATA_IN(DATA_IN), .clk(Clk), .rst(rst));


    //=============================除頻===============================
    always @(posedge Clk or negedge rst)begin
        if (!rst)begin
            CLK_COUNT_400HZ <= 20'h00000;
            CLK_400HZ       <= 1'b0;
        end
        else if (CLK_COUNT_400HZ < 20'h0F424)begin
            CLK_COUNT_400HZ <= CLK_COUNT_400HZ + 1'b1;
        end
        else begin
            CLK_COUNT_400HZ <= 20'h00000;
            CLK_400HZ       <= ~CLK_400HZ;
        end
    end
    //============================================================
    always @(posedge CLK_400HZ or negedge rst)begin
        if (!rst)begin
            state <= RESET;
        end
        else begin
            case (state)
                RESET : begin  // Set Function to 8-bit transfer and 2 line display with 5x8 Font size
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b0;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= 8'h38;
                    state           <= DROP_LCD_E;
                    next_command    <= DISPLAY_CLEAR;
                    CHAR_COUNT      <= 5'b00000;
                end

                // Clear Display (also clear DDRAM content)
                DISPLAY_CLEAR : begin
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b0;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= 8'h01;
                    state           <= DROP_LCD_E;
                    next_command    <= MODE_SET;
                end

                // Set write mode to auto increment address and move cursor to the right
                MODE_SET : begin
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b0;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= 8'h06;
                    state           <= DROP_LCD_E;
                    next_command    <= CG_RAM_HOME;
                end

                // Write ASCII hex character in first LCD character location
                Print_String : begin
                    state           <= DROP_LCD_E;
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b1;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= Next_Char;

                    // Loop to send out 32 characters to LCD Display  (16 by 2 lines)
                    if (CHAR_COUNT < 31)
                        CHAR_COUNT <= CHAR_COUNT + 1'b1;
                    else
                        CHAR_COUNT <= 5'b00000;

                    // Jump to second line?
                    if (CHAR_COUNT == 15)
                        next_command <= LINE2;
                        // Return to first line?
                    else if (CHAR_COUNT == 31)
                        next_command <= RETURN_HOME;
                    else
                        next_command <= Print_String;
                end

                // Set write address to line 2 character 1
                LINE2 : begin
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b0;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= 8'hC0; //line 2 character 2 ==> 8'hC1
                    state           <= DROP_LCD_E;
                    next_command    <= Print_String;
                end

                // Return write address to first character postion on line 1
                RETURN_HOME : begin
                    //LEDR[17] <= 1'd0;
                    //LEDR[16] <= 1'd1;
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b0;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= 8'h80; //line 1 character 2 ==> 8'h81
                    state           <= DROP_LCD_E;
                    next_command    <= Print_String;
                end
                CG_RAM_HOME : begin
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b0;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= 8'h40; //CGRAM begin address = 6'h00
                    font_addr       <= 6'd0;//
                    state           <= DROP_LCD_E;
                    next_command    <= write_CG;
                end
                write_CG : begin
                    state           <= DROP_LCD_E;
                    LCD_EN          <= 1'b1;
                    LCD_RS          <= 1'b1;
                    LCD_RW          <= 1'b0;
                    DATA_BUS_VALUE  <= font_data;

                    if(font_addr == 6'b111111)begin
                        next_command    <= RETURN_HOME;
                    end else begin
                        font_addr       <= font_addr + 1;
                        next_command    <= write_CG;
                    end
                end

                DROP_LCD_E : begin
                    LCD_EN  <= 1'b0;
                    state   <= HOLD;
                end

                HOLD : begin
                    state   <= next_command;
                end
            endcase
        end
    end
    // ======================
    //LCD_display_string u1(.index(CHAR_COUNT), .out(Next_Char), .DATA_IN(DATA_IN), .clk(Clk), .rst(rst));
    //module LCD_display_string(index, out, DATA_IN, clk, rst);

    reg [7:0] ASCII;
    reg [7:0] displayreg [31:0];
    reg [3:0] ID_COUNT;
    reg [7:0] LCD_L [9:0];
    reg [7:0] LCD_R [9:0];
    reg [7:0] LCD_B [15:0];
    reg [7:0] _;
    always @(posedge Clk or negedge rst)begin
        if (!rst)begin
            `lcdLine1 <= gameStr[gameState];
            `lcdLine2 <= {
                "TIME:",
                {time_100ascii, time__10ascii, time___1ascii },
                "POINT:",
                {point__10ascii, point___1ascii },
            };

            //TIME:30 POINT:00;
        end else begin
            `lcdLine1 <= gameStr[gameState];
            `lcdLine2 <= {
               "TIME:",
                {time_100ascii, time__10ascii, time___1ascii },
                "POINT:",
                {point__10ascii, point___1ascii },
            };
        end
    end

    always@(*)begin
        Next_Char <= displayreg[CHAR_COUNT];
    end

    always@(*)begin
        case(DATA_IN)/* 0 - 9 */
            4'h0    : ASCII = 8'h30;
            4'h1    : ASCII = 8'h31;
            4'h2    : ASCII = 8'h32;
            4'h3    : ASCII = 8'h33;
            4'h4    : ASCII = 8'h34;
            4'h5    : ASCII = 8'h35;
            4'h6    : ASCII = 8'h36;
            4'h7    : ASCII = 8'h37;
            4'h8    : ASCII = 8'h38;
            4'h9    : ASCII = 8'h39;
            default : ASCII = 8'h20;
        endcase
    end


endmodule

module LCD_display_string(index, out, DATA_IN, clk, rst);
    input             clk, rst;
    input       [4:0] index;
    input       [3:0] DATA_IN;
    output reg  [7:0] out;

    reg [7:0] ASCII;
    reg [7:0] displayreg [31:0];

    always@(posedge clk)begin
        //`lcdLine1 <= gameStr[gameState];
        displayreg[0]   <= 8'h47; //g
        displayreg[1]   <= 8'h53; //r
        displayreg[2]   <= 8'h4F; //o
        displayreg[3]   <= 8'h55; //u
        displayreg[4]   <= 8'h50; //p
        displayreg[5]   <= 8'h20; //
        displayreg[6]   <= 8'h20; //
        displayreg[7]   <= 8'h20; //
        displayreg[8]   <= 8'h30; //0
        displayreg[9]   <= 8'h32; //2
        displayreg[10]  <= 8'h20; //
        displayreg[11]  <= 8'h20; //
        displayreg[12]  <= 8'h20; //
        displayreg[13]  <= 8'h20; //
        displayreg[14]  <= 8'h20; //
        //displayreg[15]  <= 8'h20; //
        displayreg[15]  <= ASCII;
        // Line 2
        displayreg[16]  <= 8'h44; //D
        displayreg[17]  <= 8'h45; //E
        displayreg[18]  <= 8'h32; //2
        displayreg[19]  <= 8'h20; //
        displayreg[20]  <= 8'h31; //1
        displayreg[21]  <= 8'h31; //1
        displayreg[22]  <= 8'h35; //5
        displayreg[23]  <= 8'h20; //
        displayreg[24]  <= 8'h53; //S
        displayreg[25]  <= 8'h57; //W
        displayreg[26]  <= 8'h00; //+-(自定義字形)
        displayreg[27]  <= 8'h4c; //L
        displayreg[28]  <= 8'h43; //C
        displayreg[29]  <= 8'h44; //D
    end
    always@(*)begin
        out <= displayreg[index];
    end

    always@(*)begin
        case(DATA_IN)/* 0 - 9 */
            4'h0    : ASCII = 8'h30;
            4'h1    : ASCII = 8'h31;
            4'h2    : ASCII = 8'h32;
            4'h3    : ASCII = 8'h33;
            4'h4    : ASCII = 8'h34;
            4'h5    : ASCII = 8'h35;
            4'h6    : ASCII = 8'h36;
            4'h7    : ASCII = 8'h37;
            4'h8    : ASCII = 8'h38;
            4'h9    : ASCII = 8'h39;
            default : ASCII = 8'h20;
        endcase
    end
endmodule

module Custom_font_ROM(addr, out_data);//8個自定義字形
    input   [5:0] addr;//8*8
    output  [7:0] out_data;

    wire    [7:0] data[63:0];

    assign out_data = data[addr];
    //0
    assign data[00] = 8'b000_00100;//+-
    assign data[01] = 8'b000_00100;
    assign data[02] = 8'b000_11111;
    assign data[03] = 8'b000_00100;
    assign data[04] = 8'b000_00100;
    assign data[05] = 8'b000_00000;
    assign data[06] = 8'b000_11111;
    assign data[07] = 8'b000_00000;//游標位置
    //1
    assign data[08] = 8'b000_00000;//
    assign data[09] = 8'b000_00000;
    assign data[10] = 8'b000_00000;
    assign data[11] = 8'b000_00000;
    assign data[12] = 8'b000_00000;
    assign data[13] = 8'b000_00000;
    assign data[14] = 8'b000_00000;
    assign data[15] = 8'b000_00000;//游標位置
    //2
    assign data[16] = 8'b000_00000;//
    assign data[17] = 8'b000_00000;
    assign data[18] = 8'b000_00000;
    assign data[19] = 8'b000_00000;
    assign data[20] = 8'b000_00000;
    assign data[21] = 8'b000_00000;
    assign data[22] = 8'b000_00000;
    assign data[23] = 8'b000_00000;//游標位置
    //3
    assign data[24] = 8'b000_00000;//
    assign data[25] = 8'b000_00000;
    assign data[26] = 8'b000_00000;
    assign data[27] = 8'b000_00000;
    assign data[28] = 8'b000_00000;
    assign data[29] = 8'b000_00000;
    assign data[30] = 8'b000_00000;
    assign data[31] = 8'b000_00000;//游標位置
    //4
    assign data[32] = 8'b000_00000;//
    assign data[33] = 8'b000_00000;
    assign data[34] = 8'b000_00000;
    assign data[35] = 8'b000_00000;
    assign data[36] = 8'b000_00000;
    assign data[37] = 8'b000_00000;
    assign data[38] = 8'b000_00000;
    assign data[39] = 8'b000_00000;//游標位置
    //5
    assign data[40] = 8'b000_00000;//
    assign data[41] = 8'b000_00000;
    assign data[42] = 8'b000_00000;
    assign data[43] = 8'b000_00000;
    assign data[44] = 8'b000_00000;
    assign data[45] = 8'b000_00000;
    assign data[46] = 8'b000_00000;
    assign data[47] = 8'b000_00000;//游標位置
    //6
    assign data[48] = 8'b000_00000;//
    assign data[49] = 8'b000_00000;
    assign data[50] = 8'b000_00000;
    assign data[51] = 8'b000_00000;
    assign data[52] = 8'b000_00000;
    assign data[53] = 8'b000_00000;
    assign data[54] = 8'b000_00000;
    assign data[55] = 8'b000_00000;//游標位置
    //7
    assign data[56] = 8'b000_00000;//
    assign data[57] = 8'b000_00000;
    assign data[58] = 8'b000_00000;
    assign data[59] = 8'b000_00000;
    assign data[60] = 8'b000_00000;
    assign data[61] = 8'b000_00000;
    assign data[62] = 8'b000_00000;
    assign data[63] = 8'b000_00000;//游標位置
endmodule
