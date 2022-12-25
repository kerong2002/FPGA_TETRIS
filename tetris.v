//`include "./IR.v"
`include "./LCD.v"
`include "./PS2_KEYBOARD2.v"
module tetris(	clk,
					rst,
					IRDA_RXD,
					SW,
					LCD_EN,
					LCD_RW,
					LCD_RS,
					LCD_DATA,
					VGA_HS, 
					VGA_VS,
					VGA_R,
					VGA_G,
					VGA_B,
					VGA_BLANK_N,
					VGA_CLOCK,
					KEY_1,
					PS2_CLK,
					PS2_DAT,
					LEDR);
	
	input clk;						//clk 50MHz
	input rst;						//重製訊號
	input KEY_1;					//按鈕,開始
	
	//==========<PS2>=================
	input	PS2_CLK;						//PS2鍵盤訊號輸入
	inout	PS2_DAT;						//PS2鍵盤資料輸入
	wire [7:0] scandata;				//掃描的資料
	wire key1_on;						//按鍵1
	wire key2_on;						//按鍵2
	wire [7:0] key1_code;			//按鍵1資料
	wire [7:0] key2_code;			//按鍵2資料
	output [17:0] LEDR;				//檢測鍵盤
	assign LEDR[1] = key1_on;		//存載上下左右
	assign LEDR[2] = key2_on;     //存載選轉
	//wire get_keyboard1_on;			//檢測keyboad是否有被按下至少一個鍵
	//assign 
	//wire reset_1; 
	//assign reset_1 = (scandata == 8'hf0) ? 1'b0 : 1'b1;
	
	PS2_KEYBOARD2 ps2_test(	.clk(clk),
									.rst(rst),
									.rst1(1'b1),
									.PS2_DAT(PS2_DAT),
									.PS2_CLK(PS2_CLK),
									.scandata(scandata),
									.key1_on(key1_on),
									.key2_on(key2_on),
									.key1_code(key1_code),
									.key2_code(key2_code)
									);
	
	//==========<IR>=================
	input IRDA_RXD;				//接收到紅外線
	wire [31:0] oDATA;			//接收IR的資料
	wire oDATA_READY;				//IR確實收到資料
	//==============================
	
	input [17:0] SW;				//switch開關
	
	//==========<LCD>=================
	output LCD_EN;					//LCD控制線	
	output LCD_RW;					//LCD控制線
	output LCD_RS;					//LCD控制線
	inout [7:0] LCD_DATA;		//LCD資料
	//================================
	
	//==========<VGA>=================
	output VGA_HS, VGA_VS;
	output reg [7:0] VGA_R,VGA_G,VGA_B;
	output VGA_BLANK_N,VGA_CLOCK;
	//================================
	
	reg VGA_HS, VGA_VS;
	reg[10:0] counterHS;
	reg[9:0] counterVS;
	reg [2:0] valid;
	reg clk25M;
	
	//============<狀態機>===================
	reg [2:0] state, nextstate;
	parameter START 		= 3'd0;		//開始遊戲
	parameter NEW_SHAPE  = 3'd1;		//產生第一個圖形
	parameter DECLINE    = 3'd2;     //方塊降落
	parameter SHIFT_ON   = 3'd3;     //觸發選轉
	parameter REMOVE     = 3'd4;     //落下後檢測是否有需要消除的
	parameter DIED       = 3'd5;     //死亡
	
	//IR ir2(clk, rst, IRDA_RXD, oDATA_READY, oDATA);
	
	parameter H_FRONT = 16;
	parameter H_SYNC  = 96;
	parameter H_BACK  = 48;
	parameter H_ACT   = 640;//
	parameter H_BLANK = H_FRONT + H_SYNC + H_BACK;
	parameter H_TOTAL = H_FRONT + H_SYNC + H_BACK + H_ACT;
	reg [6:0] time_cnt;
	reg [6:0] score;
	//reg [12:0] objY,objX;			//物體的座標
	reg [12:0] X,Y;
	wire clk0_1s;							//除頻訊號
	wire clk1s;							//除頻訊號
	counterDivider #(26, 500_0000) cnt1(clk25M, rst, clk0_1s);  //除頻500萬，相當於0.1s
	counterDivider #(26, 5000_0000) cnt2(clk, rst, clk1s);		//除頻5000萬，相當於1s
	
	
	parameter V_FRONT = 11;
	parameter V_SYNC  = 2;
	parameter V_BACK  = 32;
	parameter V_ACT   = 480;//
	parameter V_BLANK = V_FRONT + V_SYNC + V_BACK;
	parameter V_TOTAL = V_FRONT + V_SYNC + V_BACK + V_ACT;
	assign VGA_SYNC_N = 1'b0;
	assign VGA_BLANK_N = ~((counterHS<H_BLANK)||(counterVS<V_BLANK));
	assign VGA_CLOCK = ~clk25M;
	
	wire [6:0] wire_time;
	wire [6:0] wire_score;
	assign wire_score = score;
	assign wire_time = time_cnt;
	//=====================<tetris data>============================
	reg [9:0] board [23:0];       //20寬度*10高度 4個高度保留值
	reg [5:0] pos_x;			//0~15 X座標
	reg signed [5:0] pos_y;			//0~31 Y座標
	reg [2:0] shape;					//七種圖形
	reg [1:0] rotation_choose;    //選擇的選轉
	parameter initial_shape_pos_x = 6'd4;
	parameter initial_shape_pos_y = -6'd3;
	/* 
		0 -> O
		1 -> I
		2 -> S
		3 -> Z
		4 -> L
		5 -> J
		6 -> T
	*/
	wire [15:0] graph [27:0];
	//O
	assign graph[0] = {{4'b0000},{4'b0000},{4'b0011},{4'b0011}};
	assign graph[1] = {{4'b0000},{4'b0000},{4'b0011},{4'b0011}};
	assign graph[2] = {{4'b0000},{4'b0000},{4'b0011},{4'b0011}};
	assign graph[3] = {{4'b0000},{4'b0000},{4'b0011},{4'b0011}};
	//I
	assign graph[4] = {{4'b0000},{4'b0000},{4'b0000},{4'b1111}};
	assign graph[5] = {{4'b0001},{4'b0001},{4'b0001},{4'b0001}};
	assign graph[6] = {{4'b0000},{4'b0000},{4'b0000},{4'b1111}};
	assign graph[7] = {{4'b0001},{4'b0001},{4'b0001},{4'b0001}};
	//S
	assign graph[8] = {{4'b0000},{4'b0000},{4'b0011},{4'b0110}};
	assign graph[9] = {{4'b0000},{4'b0010},{4'b0011},{4'b0001}};
	assign graph[10] = {{4'b0000},{4'b0000},{4'b0011},{4'b0110}};
	assign graph[11] = {{4'b0000},{4'b0010},{4'b0011},{4'b0001}};
	//Z
	assign graph[12] = {{4'b0000},{4'b0000},{4'b0110},{4'b0011}};
	assign graph[13] = {{4'b0000},{4'b0001},{4'b0011},{4'b0010}};
	assign graph[14] = {{4'b0000},{4'b0000},{4'b0110},{4'b0011}};
	assign graph[15] = {{4'b0000},{4'b0001},{4'b0011},{4'b0010}};
	//L
	assign graph[16] = {{4'b0000},{4'b0000},{4'b0111},{4'b0100}};
	assign graph[17] = {{4'b0000},{4'b0010},{4'b0010},{4'b0011}};
	assign graph[18] = {{4'b0000},{4'b0000},{4'b0001},{4'b0111}};
	assign graph[19] = {{4'b0000},{4'b0011},{4'b0001},{4'b0001}};
	//J
	assign graph[20] = {{4'b0000},{4'b0000},{4'b0111},{4'b0001}};
	assign graph[21] = {{4'b0000},{4'b0011},{4'b0010},{4'b0010}};
	assign graph[22] = {{4'b0000},{4'b0000},{4'b0100},{4'b0111}};
	assign graph[23] = {{4'b0000},{4'b0001},{4'b0001},{4'b0011}};
	//T
	assign graph[24] = {
	{4'b0000},
	{4'b0000},
	{4'b0010},
	{4'b0111}};
	assign graph[25] = {
	{4'b0000},
	{4'b0010},
	{4'b0011},
	{4'b0010}};
	assign graph[26] = {
	{4'b0000},
	{4'b0000},
	{4'b0111},
	{4'b0000}};
	assign graph[27] = {
	{4'b0000},
	{4'b0001},
	{4'b0011},
	{4'b0001}};
	/*
	reg [1:0] gameState;
   always@(*)begin
      case(state)
			START : gameState = 0;
			UP    ,
			DOWN  ,
			LEFT  ,
			RIGHT : gameState = 1;
			END   : gameState = 2;
	  endcase
	end
	LCD lcd1(clk, rst, state, wire_time, wire_score,  , LCD_DATA, LCD_EN, LCD_RW, LCD_RS, DATA_IN);
	*/
	
	always@(posedge clk)
		clk25M = ~clk25M;
	
	//===========<狀態選擇>===================
	always @(posedge clk0_1s,negedge rst)begin
		if(!rst)begin
			state <= START;
		end
		else begin
			state <= nextstate;
		end
	end
	
	
	//============<狀態轉移>===================
	always @(*)begin
		case(state)
			START:begin
				if(!KEY_1)begin
					nextstate = NEW_SHAPE;
				end
				else begin
					nextstate = START;
				end
			end
			NEW_SHAPE:begin
				nextstate = DECLINE;
			end
			DECLINE:begin
				if(key1_code == 8'h12 || key2_code == 8'h12)begin
					nextstate = SHIFT_ON;
				end
				else begin
					nextstate = DECLINE;
				end
			end
			SHIFT_ON:begin
				nextstate = DECLINE;
			end
			default:begin
				nextstate = START;
			end
		endcase
	end
	
	
	always@(posedge clk25M)
	begin
		if(!rst) 
			counterHS <= 0;
		else begin
		
			if(counterHS == H_TOTAL) 
				counterHS <= 0;
			else 
				counterHS <= counterHS + 1'b1;
			
			if(counterHS == H_FRONT-1)
				VGA_HS <= 1'b0;
			if(counterHS == H_FRONT + H_SYNC -1)
				VGA_HS <= 1'b1;
				
			if(counterHS >= H_BLANK)
				X <= counterHS-H_BLANK;
			else
				X <= 0;	
		end
	end

	always@(posedge clk25M)
	begin
		if(!rst) 
			counterVS <= 0;
		else begin
			if(counterVS == V_TOTAL) 
				counterVS <= 0;
			else if(counterHS == H_TOTAL) 
				counterVS <= counterVS + 1'b1;
				
			if(counterVS == V_FRONT-1)
				VGA_VS <= 1'b0;
			if(counterVS == V_FRONT + V_SYNC -1)
				VGA_VS <= 1'b1;
			if(counterVS >= V_BLANK)
				Y <= counterVS-V_BLANK;
			else
				Y <= 0;
		end
	end

	reg [23:0]color[5:0];	//顏色區塊
	//========<設定遊戲布局大小和邊框>===========
	parameter Board_min_X   = 13'd245;
	parameter Board_max_X   = 13'd395;
	parameter Board_min_Y	= 13'd40;
	parameter Board_max_Y   = 13'd440;
	parameter Board_frame   = 13'd5;
	
	integer i,j;
	//因為螢幕比是4:3，所以在寬度跟高度分配上，有差異高/20，寬/15
	//===========<螢幕上色>=================
	always@(posedge clk25M,negedge rst)begin
		if (!rst) begin
			{VGA_R,VGA_G,VGA_B}<=24'h0000ff;//blue
		end
		else begin
			//主要方塊繪製部分
			if(X>=Board_min_X && X<Board_max_X && Y>=Board_min_Y && Y<Board_max_Y)begin
if(graph[(SW[2:0]*4) + rotation_choose][0]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0 )begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][1]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][2]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][3]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][4]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][5]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][6]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][7]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][8]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][9]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][10]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][11]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][12]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][13]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][14]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
else if(graph[(SW[2:0]*4) + rotation_choose][15]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
    {VGA_R,VGA_G,VGA_B}<=color[2];
end
				else if(board[(Y-Board_min_Y)/20+4][(X-Board_min_X)/15]==1'b1 && Y>=Board_min_Y && X>=Board_min_X && (Y-Board_min_Y)%20!=0 && (X-Board_min_X)%15!=0)begin
					{VGA_R,VGA_G,VGA_B}<=color[3];
				end
				else begin
					{VGA_R,VGA_G,VGA_B}<=color[4];
				end
			end
			else if(X>Board_min_X-Board_frame && X<=Board_max_X+Board_frame && Y>Board_min_Y-Board_frame  && Y<=Board_max_Y+Board_frame)begin
				{VGA_R,VGA_G,VGA_B}<=color[5];//邊界
			end
			else begin
				{VGA_R,VGA_G,VGA_B}<=24'b0;//其餘部分
			end
			//{VGA_R,VGA_G,VGA_B}<=color[2];

		end
	end
	/*
	always @(posedge clk1s,negedge rst)begin
		if(!rst)begin
			time_cnt <= 7'd0;
		end
		else begin
			case(state)
				START:begin
					case(SW[1:0])
						2'b00:time_cnt <= 7'd10;
						2'b01:time_cnt <= 7'd30;
						2'b10:time_cnt <= 7'd60;
						2'b11:time_cnt <= 7'd90;
					endcase
				end
				UP    : time_cnt <= time_cnt - 7'd1;
				DOWN  : time_cnt <= time_cnt - 7'd1;
				LEFT  : time_cnt <= time_cnt - 7'd1;
				RIGHT : time_cnt <= time_cnt - 7'd1;
				END   : time_cnt <= 7'd0;
				default:time_cnt <= 7'd0;
			endcase
		end
	end*/
	
	integer y;
	//==============<控制board>==============
	always@(posedge clk25M, negedge rst)begin
		if(!rst)begin
			for(y=0;y<23;y=y+1)begin
				board[y] <= 10'b0;
			end
		end
		else begin
		
		end
	end
	
	//==============<控制左右和旋轉>===========
	always@(posedge clk0_1s, negedge rst)begin
		if(!rst)begin
			pos_x <= initial_shape_pos_x;
			rotation_choose <= 2'd0;
		end
		else begin
			case(state)
				NEW_SHAPE:begin
					pos_x <= initial_shape_pos_x;
					rotation_choose <= 2'd0;
				end
				DECLINE:begin
					case(key1_code)
						8'h6B: pos_x <= pos_x - 1'b1;//左
						8'h74: pos_x <= pos_x + 1'b1;//右
					endcase
				end
				SHIFT_ON:begin
					rotation_choose <= rotation_choose + 1'b1;
				end
			endcase
		end
	end 

	//================<控制向下>===========
	always @(posedge clk1s, negedge rst)begin
		if(!rst)begin
			shape <= 3'd3;
			pos_y <= initial_shape_pos_y;
		end
		else begin
			case(state)
				NEW_SHAPE:begin
					//===========<LFSR>=============
					shape <= {shape[1:0],shape[1]^shape[0]};
					pos_y <= initial_shape_pos_y;
				end
				DECLINE:begin
					pos_y <= pos_y + 1'b1;//下
				end
			endcase
		end	
	end
	

	
	always@(posedge clk,negedge rst)begin
		if(!rst)begin
			color[0]<=24'h0000ff;//blue
			color[1]<=24'h00ff00;//green
			color[2]<=24'hff0000;//red
			color[3]<=24'h003fff;//Dark blue
			color[4]<=24'hffffff;//white
			color[5]<=24'h606166;//gray
		end else begin
			color[0]<=24'h0000ff;//blue
			color[1]<=24'h00ff00;//green
			color[2]<=24'hff0000;//red
			color[3]<=24'h003fff;//Dark blue
			color[4]<=24'hffffff;//white
			color[5]<=24'h606166;//gray
		end
	end

endmodule

//===============<除頻器>=====================
module counterDivider(CLK, RST, CLK_Out); 

    // 除頻設定 1kHz 1ms
	parameter size = 16;
	parameter countDivider = 16'd1_000;
	localparam countDivider_D2  = countDivider / 2;

	input CLK, RST;
	output reg CLK_Out;

	reg [size-1:0] Cnt = 0;

	always @(posedge CLK or negedge RST) begin
		if(!RST) begin
			Cnt <= 0;
			CLK_Out <= 0;
		end 
		else if(Cnt == countDivider_D2) begin
			Cnt <= 0;
			CLK_Out <= ~CLK_Out;
		end 
		else begin
			Cnt <= Cnt + 1'b1;
		end
	end
	
endmodule


