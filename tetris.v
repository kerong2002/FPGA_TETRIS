`include "./IR.v"
`include "./LCD.v"
`include "./PS2_KEYBOARD2.v"
`include "./beep.v"
//a`include "./IMG.v"
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
					PS2_CLK,
					PS2_DAT,
					LEDR,
					LEDG,
					beep
					);
	
	input clk;						//clk 50MHz
	input rst;						//重製訊號
	//=====================<聲音部分>=========================
	output beep;					//聲音
	output reg [8:0] LEDG;
	wire [2:0] level;
	assign LEDR[17] = voice_check;
	assign level = voice_level;
	always @(*)begin
		case(voice_level)
			3'd0 : LEDG[7:0] =  8'b0000_0001; 
			3'd1 : LEDG[7:0] =  8'b0000_0011;
			3'd2 : LEDG[7:0] =  8'b0000_0111;
			3'd3 : LEDG[7:0] =  8'b0000_1111;
			3'd4 : LEDG[7:0] =  8'b0001_1111;
			3'd5 : LEDG[7:0] =  8'b0011_1111;
			3'd6 : LEDG[7:0] =  8'b0111_1111;
			3'd7 : LEDG[7:0] =  8'b1111_1111;
		endcase
	end
	reg [2:0] voice_level;
	reg [2:0] voice_save;
	reg voice_check;
	always @(negedge oDATA_READY, negedge rst)begin
		if(!rst)begin
			voice_level <= 3'd4;
			voice_save  <= 3'd0;
			voice_check <= 1'd0;
		end
		else begin
			case(oDATA[23:16])
				8'h0C:begin
					if(voice_check==1'd0)begin
						voice_save <=voice_level;
						voice_level <= 3'd0;
						voice_check <= 1'd1;
					end
					else begin
						voice_level <=voice_save;
						voice_check <= 1'd0;
					end
				end
				8'h1B:begin
					if(voice_check)begin
						voice_level <= voice_level + voice_save + 3'd1;
						voice_check <= 1'd0;
					end
					else begin
						if(voice_level < 3'd7)begin
							voice_level <= voice_level + 3'd1;
						end
					end
				end
				8'h1F:begin
					if(voice_check)begin
						voice_level <= voice_level + voice_save - 3'd1;
						voice_check <= 1'd0;
					end
					else begin
						if(voice_level > 1)begin
							voice_level <= voice_level - 3'd1;
						end
					end
				end
			endcase
		end
	end
	
	//==========<樂譜>=================
	beep music_1(clk, rst,level, beep);
	
	//input KEY_1;					//按鈕,開始
	//==========<PS2>=================
	input	PS2_CLK;						//PS2鍵盤訊號輸入
	inout	PS2_DAT;						//PS2鍵盤資料輸入
	wire [7:0] scandata;				//掃描的資料
	wire key1_on;						//按鍵1
	wire key2_on;						//按鍵2
	wire key3_on;  					//按鍵3
	wire [7:0] key1_code;			//按鍵1資料
	wire [7:0] key2_code;			//按鍵2資料
	wire [7:0] key3_code;			//按鍵3資料
	output [17:0] LEDR;				//檢測鍵盤
	assign LEDR[1] = key1_on;		//存載上下左右
	assign LEDR[2] = key2_on;     //存載選轉
	assign LEDR[3] = key3_on;     //檢測快速降落
	
	assign LEDR[4] = change_cnt;  //檢測是否hold過了
	assign LEDR[5] = hold_check;	//hold第一次檢測，已經有一次以上亮燈
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
									.key3_on(key3_on),
									.key1_code(key1_code),
									.key2_code(key2_code),
									.key3_code(key3_code)
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
	parameter PLACE      = 3'd6;     //放置
	parameter HOLD       = 3'd7;		//保存
	
	IR ir2(clk, rst, IRDA_RXD, oDATA_READY, oDATA);
	
	parameter H_FRONT = 16;
	parameter H_SYNC  = 96;
	parameter H_BACK  = 48;
	parameter H_ACT   = 640;
	parameter H_BLANK = H_FRONT + H_SYNC + H_BACK;
	parameter H_TOTAL = H_FRONT + H_SYNC + H_BACK + H_ACT;
	reg [9:0] time_cnt;				//時間
	reg [6:0] score;					//分數
	//reg [12:0] objY,objX;			//物體的座標
	reg [12:0] X,Y;
	wire IR_CLK_1S;						//除頻訊號1
	wire IR_CLK_10S;						//除頻訊號10
	reg  reg_IR_CLK_1S;					//暫存1
	reg  reg_IR_CLK_10S;					//暫存10
	reg [1:0] IR_speed;						//IR調整速度
	
	assign IR_CLK_1S = reg_IR_CLK_1S;	//暫存轉移
	assign IR_CLK_10S = reg_IR_CLK_10S; //暫存轉移
	
	always @(*)begin
		case(IR_speed)
			2'd0:begin
				reg_IR_CLK_1S  = first_clk_1;
				reg_IR_CLK_10S = first_clk_10;
			end
			2'd1:begin
				reg_IR_CLK_1S  = second_clk_1;
				reg_IR_CLK_10S = second_clk_10;
			end
			2'd2:begin
				reg_IR_CLK_1S  = third_clk_1;
				reg_IR_CLK_10S = third_clk_10;
			end
			2'd3:begin
				reg_IR_CLK_1S  = forth_clk_1;
				reg_IR_CLK_10S = forth_clk_10;
			end
		endcase
	end
	
	//assign (IR_CLK_1S)  = (IR_speed == 2'd3) ? forth_clk_1  : (IR_speed == 2'd2) ? third_clk_1  : (IR_speed == 2'd1) ? second_clk_1  : first_clk_1;
	//assign (IR_CLK_10S) = (IR_speed == 2'd3) ? forth_clk_10 : (IR_speed == 2'd2) ? third_clk_10 : (IR_speed == 2'd1) ? second_clk_10 : first_clk_10;
	
	//=============<速度調節>=================
	always@(negedge oDATA_READY, negedge rst)begin
		if (!rst)begin
			IR_speed <= 2'd0;
		end 
		else begin
			case(oDATA[23:16])
				8'h1A:begin
					if(IR_speed < 2'd3)begin
						IR_speed <= IR_speed + 2'd1;
					end
				end
				8'h1E:begin
					if(IR_speed > 2'd0)begin
						IR_speed <= IR_speed - 2'd1;
					end
				end
			endcase
		end
	end
	
	reg [25:0] down_speed;// 下降速度
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			down_speed <= 26'd5000_0000;
		end
		else begin
			if( state == DECLINE && key3_code == 8'h29 )begin
				down_speed <= 26'd50;
			end
			else if(key3_code == 8'h72 )begin
				down_speed <= 26'd700_0000;
			end
			else begin
				case(IR_speed)
					2'd0:begin
						down_speed <= 26'd5000_0000;
					end
					2'd1:begin
						down_speed <= 26'd2500_0000;
					end
					2'd2:begin
						down_speed <= 26'd1600_0000;
					end
					2'd3:begin
						down_speed <= 26'd1250_0000;
					end
				endcase
			end
		end
	end
	
	
	wire time_clk;
	counterDivider_TETRIS #(26)  time_cnt_1(clk, rst, time_clk, 26'd5000_0000);  	//除頻5000萬，時間time_clk
	
	wire first_clk_1;
	wire first_clk_10;
	//======================<第一組速度>=====================
	counterDivider_TETRIS #(23)  cnt_first_1(clk25M, rst, first_clk_1, 26'd500_0000);  	//除頻500萬，操作速度相當於0.1as
	counterDivider_TETRIS #(26) cnt_first_10(clk  , rst, first_clk_10, down_speed);		//除頻5000萬
	
	wire second_clk_1;
	wire second_clk_10;
	//======================<第二組速度>=====================
	counterDivider_TETRIS #(23)  cnt_second_1(clk25M, rst, second_clk_1, 26'd400_0000);  	//除頻500萬，操作速度相當於0.2s
	counterDivider_TETRIS #(25) cnt_sceond_10(clk  , rst, second_clk_10, down_speed);	//除頻2500萬
	
	wire third_clk_1;
	wire third_clk_10;
	//======================<第三組速度>=====================
	counterDivider_TETRIS #(23)  cnt_third_1(clk25M, rst, third_clk_1, 26'd360_0000);  	//除頻500萬，操作速度相當於0.2s
	counterDivider_TETRIS #(24) cnt_third_10(clk  , rst, third_clk_10, down_speed);	   //除頻1600萬
	
	wire forth_clk_1;
	wire forth_clk_10;
	//======================<第四組速度>=====================
	counterDivider_TETRIS #(23)  cnt_forth_1(clk25M, rst, forth_clk_1,  26'd360_0000);  	 //除頻500萬，操作速度相當於0.2s
	counterDivider_TETRIS #(24)  cnt_forth_10(clk  , rst, forth_clk_10, down_speed);	 //除頻1250萬
	
	parameter V_FRONT = 11;
	parameter V_SYNC  = 2;
	parameter V_BACK  = 32;
	parameter V_ACT   = 480;//
	parameter V_BLANK = V_FRONT + V_SYNC + V_BACK;
	parameter V_TOTAL = V_FRONT + V_SYNC + V_BACK + V_ACT;
	assign VGA_SYNC_N = 1'b0;
	assign VGA_BLANK_N = ~((counterHS<H_BLANK)||(counterVS<V_BLANK));
	assign VGA_CLOCK = ~clk25M;
	
	//================<LCD顯示資料>===================
	wire [9:0] wire_time;
	wire [6:0] wire_score;
	assign wire_score = score;
	assign wire_time = time_cnt;
	
	
	//=====================<tetris data>============================
	reg [9:0] board [23:0];       //20寬度*10高度 4個高度保留值
	reg [9:0] check_board [23:0]; //檢測消除的board
	reg [5:0] pos_x;			//0~15 X座標
	reg signed [5:0] pos_y;			//0~31 Y座標
	reg [4:0] shape;					//七種圖形
	reg [4:0] n_shape;				//下一個圖形
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
	wire [15:0] graph [31:0];
	//O
	assign graph[0] = {
	{4'b0000},
	{4'b0000},
	{4'b0011},
	{4'b0011}};
	assign graph[1] = {
	{4'b0000},
	{4'b0000},
	{4'b0011},
	{4'b0011}};
	assign graph[2] = {
	{4'b0000},
	{4'b0000},
	{4'b0011},
	{4'b0011}};
	assign graph[3] = {
	{4'b0000},
	{4'b0000},
	{4'b0011},
	{4'b0011}};
	//I
	assign graph[4] = {
	{4'b0000},
	{4'b0000},
	{4'b0000},
	{4'b1111}};
	assign graph[5] = {
	{4'b0001},
	{4'b0001},
	{4'b0001},
	{4'b0001}};
	assign graph[6] = {
	{4'b0000},
	{4'b0000},
	{4'b0000},
	{4'b1111}};
	assign graph[7] = {
	{4'b0001},
	{4'b0001},
	{4'b0001},
	{4'b0001}};
	//S
	assign graph[8] = {
	{4'b0000},
	{4'b0000},
	{4'b0011},
	{4'b0110}};
	assign graph[9] = {
	{4'b0000},
	{4'b0010},
	{4'b0011},
	{4'b0001}};
	assign graph[10] = {
	{4'b0000},
	{4'b0000},
	{4'b0011},
	{4'b0110}};
	assign graph[11] = {
	{4'b0000},
	{4'b0010},
	{4'b0011},
	{4'b0001}};
	//Z
	assign graph[12] = {
	{4'b0000},
	{4'b0000},
	{4'b0110},
	{4'b0011}};
	assign graph[13] = {
	{4'b0000},
	{4'b0001},
	{4'b0011},
	{4'b0010}};
	assign graph[14] = {
	{4'b0000},
	{4'b0000},
	{4'b0110},
	{4'b0011}};
	assign graph[15] = {
	{4'b0000},
	{4'b0001},
	{4'b0011},
	{4'b0010}};
	//L
	assign graph[16] = {
	{4'b0000},
	{4'b0000},
	{4'b0111},
	{4'b0100}};
	assign graph[17] = {
	{4'b0000},
	{4'b0010},
	{4'b0010},
	{4'b0011}};
	assign graph[18] = {
	{4'b0000},
	{4'b0000},
	{4'b0001},
	{4'b0111}};
	assign graph[19] = {
	{4'b0000},
	{4'b0011},
	{4'b0001},
	{4'b0001}};
	//J
	assign graph[20] = {
	{4'b0000},
	{4'b0000},
	{4'b0111},
	{4'b0001}};
	assign graph[21] = {
	{4'b0000},
	{4'b0011},
	{4'b0010},
	{4'b0010}};
	assign graph[22] = {
	{4'b0000},
	{4'b0000},
	{4'b0100},
	{4'b0111}};
	assign graph[23] = {
	{4'b0000},
	{4'b0001},
	{4'b0001},
	{4'b0011}};
	//T
	assign graph[24] = {
	{4'b0000},
	{4'b0000},
	{4'b0010},
	{4'b0111}};
	assign graph[25] = {
	{4'b0000},
	{4'b0001},
	{4'b0011},
	{4'b0001}};
	assign graph[26] = {
	{4'b0000},
	{4'b0000},
	{4'b0111},
	{4'b0010}};
	assign graph[27] = {
	{4'b0000},
	{4'b0010},
	{4'b0011},
	{4'b0010}};
	
	//T overflow
	assign graph[28] = {
	{4'b0000},
	{4'b0000},
	{4'b0010},
	{4'b0111}};
	assign graph[29] = {
	{4'b0000},
	{4'b0001},
	{4'b0011},
	{4'b0001}};
	assign graph[30] = {
	{4'b0000},
	{4'b0000},
	{4'b0111},
	{4'b0010}};
	assign graph[31] = {
	{4'b0000},
	{4'b0010},
	{4'b0011},
	{4'b0010}};


	reg [1:0] gameState;
   always@(*)begin
      case(state)
			START      : gameState = 2'd0;
			NEW_SHAPE  : gameState = 2'd1;
			DECLINE    : gameState = 2'd1;
			SHIFT_ON   : gameState = 2'd1;
			REMOVE     : gameState = 2'd1;
			PLACE      : gameState = 2'd1;
			DIED       : gameState = 2'd2;
	  endcase
	end
	LCD lcd1(clk, rst, gameState, wire_time, wire_score,  , LCD_DATA, LCD_EN, LCD_RW, LCD_RS, DATA_IN);
	
	
	always@(posedge clk)
		clk25M = ~clk25M;
	
	//===========<狀態選擇>===================
	always @(posedge IR_CLK_10S,negedge rst)begin
		if(!rst)begin
			state <= START;
		end
		else begin
			state <= nextstate;
		end
	end
	
	reg change_cnt;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			change_cnt <= 1'd0;
		end
		else begin
			case(state)
				START:begin
					change_cnt <= 1'd0;
				end
				NEW_SHAPE:begin
					change_cnt <= 1'd0;
				end
				PLACE:begin
					change_cnt <= 1'd0;
				end
				HOLD:begin
					change_cnt <= 1'd1;
				end
			endcase
		end
	end
	
	reg hold_check;
	always @(posedge IR_CLK_10S, negedge rst)begin
		if(!rst)begin
			hold_check <= 1'd0;
		end
		else begin
			case(state)
				START:begin
					hold_check <= 1'd0;
				end
				HOLD:begin
					hold_check <= 1'd1;
				end
			endcase
		end
	end
	
	//============<狀態轉移>===================
	always @(*)begin
		case(state)
			START:begin
				if(key1_code == 8'h5A)begin
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
				if(graph[(cur_shape[2:0]*4) + rotation_choose][15]==1'b1 &&( ((pos_y + 3) >= 18) || (board[pos_y+4+5][pos_x+3]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][14]==1'b1 &&( ((pos_y + 3) >= 18) || (board[pos_y+4+5][pos_x+2]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][13]==1'b1 &&( ((pos_y + 3) >= 18) || (board[pos_y+4+5][pos_x+1]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][12]==1'b1 &&( ((pos_y + 3) >= 18) || (board[pos_y+4+5][pos_x+0]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][11]==1'b1 &&( ((pos_y + 2) >= 18) || (board[pos_y+3+5][pos_x+3]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][10]==1'b1 &&( ((pos_y + 2) >= 18) || (board[pos_y+3+5][pos_x+2]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][9]==1'b1 &&( ((pos_y + 2) >= 18) || (board[pos_y+3+5][pos_x+1]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][8]==1'b1 &&( ((pos_y + 2) >= 18) || (board[pos_y+3+5][pos_x+0]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][7]==1'b1 &&( ((pos_y + 1) >= 18) || (board[pos_y+2+5][pos_x+3]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][6]==1'b1 &&( ((pos_y + 1) >= 18) || (board[pos_y+2+5][pos_x+2]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][5]==1'b1 &&( ((pos_y + 1) >= 18) || (board[pos_y+2+5][pos_x+1]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][4]==1'b1 &&( ((pos_y + 1) >= 18) || (board[pos_y+2+5][pos_x+0]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][3]==1'b1 &&( ((pos_y + 0) >= 18) || (board[pos_y+1+5][pos_x+3]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][2]==1'b1 &&( ((pos_y + 0) >= 18) || (board[pos_y+1+5][pos_x+2]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][1]==1'b1 &&( ((pos_y + 0) >= 18) || (board[pos_y+1+5][pos_x+1]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][0]==1'b1 &&( ((pos_y + 0) >= 18) || (board[pos_y+1+5][pos_x+0]==1'b1)))begin
				  nextstate = PLACE;
				end
				else if((key3_code == 8'h21 ||  key3_code == 8'h12)&& change_cnt == 1'd0)begin
					nextstate = HOLD;
				end
				/*else if(key1_code == 8'h12 || key2_code == 8'h12)begin
					nextstate = SHIFT_ON;
				end*/
				else begin
					nextstate = DECLINE;
				end
			end
			/*SHIFT_ON:begin
				nextstate = DECLINE;
			end*/
			PLACE:begin
				if(|board[4])begin
					nextstate = DIED;
				end
				else begin
					nextstate = REMOVE;
				end
			end
			REMOVE:begin
				if(remove_cnt<=3)begin
					nextstate = NEW_SHAPE;
				end
				else begin
					nextstate = REMOVE;
				end
			end
			HOLD:begin
				if(hold_check == 1'b0)begin
					nextstate = NEW_SHAPE;
				end
				else begin
					nextstate = DECLINE;
				end
			end
			DIED:begin
				nextstate = DIED;
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

	reg [23:0]color[12:0];	//顏色區塊
	reg [3:0] current_color;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			current_color <= 4'd0;
		end
		else begin
			case(cur_shape[2:0])
				3'd0:current_color <= 4'd6;
				3'd1:current_color <= 4'd7;
				3'd2:current_color <= 4'd8;
				3'd3:current_color <= 4'd9;
				3'd4:current_color <= 4'd10;
				3'd5:current_color <= 4'd11;
				3'd6:current_color <= 4'd12;
				3'd7:current_color <= 4'd12;
			endcase
		end
	end
	
	reg [3:0] next_color;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			next_color <= 4'd0;
		end
		else begin
			case(n_shape[2:0])
				3'd0:next_color <= 4'd6;
				3'd1:next_color <= 4'd7;
				3'd2:next_color <= 4'd8;
				3'd3:next_color <= 4'd9;
				3'd4:next_color <= 4'd10;
				3'd5:next_color <= 4'd11;
				3'd6:next_color <= 4'd12;
				3'd7:next_color <= 4'd12;
			endcase
		end
	end
	
	reg [3:0] hold_color;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			hold_color <= 4'd0;
		end
		else begin
			case(hold_shape[2:0])
				3'd0:hold_color <= 4'd6;
				3'd1:hold_color <= 4'd7;
				3'd2:hold_color <= 4'd8;
				3'd3:hold_color <= 4'd9;
				3'd4:hold_color <= 4'd10;
				3'd5:hold_color <= 4'd11;
				3'd6:hold_color <= 4'd12;
				3'd7:hold_color <= 4'd12;
			endcase
		end
	end
	//========<設定遊戲布局大小和邊框>===========
	parameter Board_min_X     = 13'd245;
	parameter Board_max_X     = 13'd395;
	parameter Board_min_Y	  = 13'd40;
	parameter Board_max_Y     = 13'd440;
	parameter Board_frame     = 13'd5;
	parameter Board_N_shape_min_X = 13'd450;
	parameter Board_N_shape_max_X	= 13'd510;
	parameter Board_N_shape_min_Y = 13'd70;
	parameter Board_N_shape_max_Y = 13'd150;
	parameter Board_H_shape_min_X = 13'd145;
	parameter Board_H_shape_max_X	= 13'd205;
	//parameter LOGO_min_X = 13'd50;
	//parameter LOGO_max_X = 13'd150;
	//parameter LOGO_min_Y = 13'd240;
	//parameter LOGO_max_Y = 13'd309;
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
				if(graph[(cur_shape[2:0]*4) + rotation_choose][0]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0 )begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][1]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][2]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][3]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+0)*20+40 && Y<(pos_y+0)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][4]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][5]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][6]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][7]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+1)*20+40 && Y<(pos_y+1)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][8]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][9]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][10]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][11]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+2)*20+40 && Y<(pos_y+2)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][12]==1'b1 && X>=(pos_x+0)*15 + 245 && X<(pos_x+0)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][13]==1'b1 && X>=(pos_x+1)*15 + 245 && X<(pos_x+1)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][14]==1'b1 && X>=(pos_x+2)*15 + 245 && X<(pos_x+2)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(graph[(cur_shape[2:0]*4) + rotation_choose][15]==1'b1 && X>=(pos_x+3)*15 + 245 && X<(pos_x+3)*15+260 && Y>=(pos_y+3)*20+40 && Y<(pos_y+3)*20+60 && pos_y>=0)begin
					 {VGA_R,VGA_G,VGA_B}<=color[current_color];
				end
				else if(board[(Y-Board_min_Y)/20+4][(X-Board_min_X)/15]==1'b1 && Y>=Board_min_Y && X>=Board_min_X && (Y-Board_min_Y)%20!=0 && (X-Board_min_X)%15!=0)begin
					{VGA_R,VGA_G,VGA_B}<=color[3];
				end
				else begin
					{VGA_R,VGA_G,VGA_B}<=color[4];
				end
			end
			//next_shape
			else if(X>=Board_N_shape_min_X && X<Board_N_shape_max_X && Y>=Board_N_shape_min_Y && Y<Board_N_shape_max_Y)begin
				if(graph[(n_shape[2:0]*4)][0]==1'b1 && X>=450 && X<465 && Y>=70 && Y<90)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][1]==1'b1 && X>=465 && X<480 && Y>=70 && Y<90)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][2]==1'b1 && X>=480 && X<495 && Y>=70 && Y<90)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][3]==1'b1 && X>=495 && X<510 && Y>=70 && Y<90)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][4]==1'b1 && X>=450 && X<465 && Y>=90 && Y<110)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][5]==1'b1 && X>=465 && X<480 && Y>=90 && Y<110)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][6]==1'b1 && X>=480 && X<495 && Y>=90 && Y<110)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][7]==1'b1 && X>=495 && X<510 && Y>=90 && Y<110)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][8]==1'b1 && X>=450 && X<465 && Y>=110 && Y<130)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][9]==1'b1 && X>=465 && X<480 && Y>=110 && Y<130)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][10]==1'b1 && X>=480 && X<495 && Y>=110 && Y<130)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][11]==1'b1 && X>=495 && X<510 && Y>=110 && Y<130)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][12]==1'b1 && X>=450 && X<465 && Y>=130 && Y<150)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][13]==1'b1 && X>=465 && X<480 && Y>=130 && Y<150)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][14]==1'b1 && X>=480 && X<495 && Y>=130 && Y<150)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else if(graph[(n_shape[2:0]*4)][15]==1'b1 && X>=495 && X<510 && Y>=130 && Y<150)begin
					 {VGA_R,VGA_G,VGA_B}<=color[next_color];
				end
				else begin
					{VGA_R,VGA_G,VGA_B}<=24'b0;//其餘部分
				end
			end
			//hold_shape
			else if(X>=Board_H_shape_min_X && X<Board_H_shape_max_X && Y>=Board_N_shape_min_Y && Y<Board_N_shape_max_Y)begin
				if(hold_check)begin
					if(graph[(hold_shape[2:0]*4)][0]==1'b1 && X>=145 && X<160 && Y>=70 && Y<90)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][1]==1'b1 && X>=160 && X<175 && Y>=70 && Y<90)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][2]==1'b1 && X>=175 && X<190 && Y>=70 && Y<90)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][3]==1'b1 && X>=190 && X<205 && Y>=70 && Y<90)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][4]==1'b1 && X>=145 && X<160 && Y>=90 && Y<110)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][5]==1'b1 && X>=160 && X<175 && Y>=90 && Y<110)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][6]==1'b1 && X>=175 && X<190 && Y>=90 && Y<110)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][7]==1'b1 && X>=190 && X<205 && Y>=90 && Y<110)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][8]==1'b1 && X>=145 && X<160 && Y>=110 && Y<130)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][9]==1'b1 && X>=160 && X<175 && Y>=110 && Y<130)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][10]==1'b1 && X>=175 && X<190 && Y>=110 && Y<130)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][11]==1'b1 && X>=190 && X<205 && Y>=110 && Y<130)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][12]==1'b1 && X>=145 && X<160 && Y>=130 && Y<150)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][13]==1'b1 && X>=160 && X<175 && Y>=130 && Y<150)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][14]==1'b1 && X>=175 && X<190 && Y>=130 && Y<150)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else if(graph[(hold_shape[2:0]*4)][15]==1'b1 && X>=190 && X<205 && Y>=130 && Y<150)begin
						 {VGA_R,VGA_G,VGA_B}<=color[hold_color];
					end
					else begin
						{VGA_R,VGA_G,VGA_B}<=24'b0;//其餘部分
					end
				end
				else begin
					{VGA_R,VGA_G,VGA_B}<=24'b0;//其餘部分
				end
			end
			else if(X>Board_min_X-Board_frame && X<=Board_max_X+Board_frame && Y>Board_min_Y-Board_frame  && Y<=Board_max_Y+Board_frame)begin
				{VGA_R,VGA_G,VGA_B}<=color[5];//邊界
			end
			//else if(X>=LOGO_min_X && X<LOGO_max_X && Y>= LOGO_min_Y && Y<LOGO_max_Y)begin
			//	{VGA_R,VGA_G,VGA_B}<=take_img;
			//end
			else begin
				{VGA_R,VGA_G,VGA_B}<=24'b0;//其餘部分
				//{VGA_R,VGA_G,VGA_B}<=take_img;//其餘部分
			end
			//{VGA_R,VGA_G,VGA_B}<=color[2];

		end
	end
	
	//wire [23:0] take_img;
	//IMG img1(X-LOGO_min_X,Y-LOGO_min_Y,take_img);
	
	always @(posedge time_clk, negedge rst)begin
		if(!rst)begin
			time_cnt <= 10'd0;
		end
		else begin
			case(state)
				START   : time_cnt <= 10'd0;
				DIED    : time_cnt <= time_cnt;
				default : time_cnt <= time_cnt + 10'd1;
			endcase
		end
	end
	integer y,x;
	
	reg [4:0] remove_cnt;			//移除時序
	reg [4:0] remove_pos;			//移除位置
	//=============<檢測board>===============
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			for(y=0;y<=23;y=y+1)begin
				check_board [y] <= 10'b0;
			end
			remove_cnt <= 5'd23;
			remove_pos <= 5'd23;
			score <= 7'd0;
		end
		else begin
			case(state)
				START:begin
					for(y=0;y<=23;y=y+1)begin
						check_board [y] <= 10'b0;
					end
					remove_cnt <= 5'd23;
					remove_pos <= 5'd23;
					score <= 7'd0;
				end
				NEW_SHAPE:begin
					remove_cnt <= 5'd23;
					remove_pos <= 5'd23;
				end
				REMOVE:begin
					if(remove_cnt>3)begin
						if(&board[remove_cnt]!=1)begin
							check_board[remove_pos] <= board[remove_cnt];
							remove_pos <= remove_pos - 5'd1;
						end
						else begin
							score <= score + 7'd1;
						end
						remove_cnt <= remove_cnt - 5'd1;
					end
				end
			endcase
		end
	end
	
	//==============<控制board>==============
	always@(posedge clk, negedge rst)begin
		if(!rst)begin
			for(y=0;y<=23;y=y+1)begin
				board[y] <= 10'b0;
			end
		end
		else begin
			case(state)
				NEW_SHAPE:begin
					for(y=23;y>=0;y=y-1)begin
						board[y] <= check_board[y];
					end
				end
				PLACE:begin
					for(y=3;y>=0;y=y-1)begin
						for(x=3;x>=0;x=x-1)begin
							if(graph[(cur_shape[2:0]*4) + rotation_choose][(y<<2)+x]==1'b1)begin
							  board[pos_y + y + 4][pos_x + x] <= 1'b1;//位置要往下放4個
							end
						end
					end
				
				end
			endcase
		end
	end
	
	reg check_left_point;//檢測向左
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			check_left_point	<= 1'b1;
		end
		else begin
			case(state)
				DECLINE:begin
					if(graph[(cur_shape[2:0]*4) + rotation_choose][0]==1'b1 && board[pos_y+4][pos_x-1])begin
						check_left_point	<= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][4]==1'b1 && board[pos_y+5][pos_x-1])begin
						check_left_point	<= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][8]==1'b1 && board[pos_y+6][pos_x-1])begin
						check_left_point	<= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][12]==1'b1 && board[pos_y+7][pos_x-1])begin
						check_left_point	<= 1'b0;
					end
					else begin
						check_left_point	<= 1'b1;
					end
				end
				NEW_SHAPE:begin
					check_left_point <= 1'b1;
				end
				default:begin
					check_left_point <= 1'b1;
				end
			endcase
		end
	end
	
	reg check_right_point;//檢測向右
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			check_right_point <= 1'b1;
		end
		else begin
			case(state)
				DECLINE:begin
					if(graph[(cur_shape[2:0]*4) + rotation_choose][15]==1'b1 && board[pos_y+7][pos_x+4])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][14]==1'b1 && board[pos_y+7][pos_x+3])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][13]==1'b1 && board[pos_y+7][pos_x+2])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][12]==1'b1 && board[pos_y+7][pos_x+1])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][11]==1'b1 && board[pos_y+6][pos_x+4])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][10]==1'b1 && board[pos_y+6][pos_x+3])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][9]==1'b1 && board[pos_y+6][pos_x+2])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][8]==1'b1 && board[pos_y+6][pos_x+1])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][7]==1'b1 && board[pos_y+5][pos_x+4])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][6]==1'b1 && board[pos_y+5][pos_x+3])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][5]==1'b1 && board[pos_y+5][pos_x+2])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][4]==1'b1 && board[pos_y+5][pos_x+1])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][3]==1'b1 && board[pos_y+4][pos_x+4])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][2]==1'b1 && board[pos_y+4][pos_x+3])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][1]==1'b1 && board[pos_y+4][pos_x+2])begin
					  check_right_point <= 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose][0]==1'b1 && board[pos_y+4][pos_x+1])begin
					  check_right_point <= 1'b0;
					end
					else begin
						check_right_point <= 1'b1;
					end
				end
				NEW_SHAPE:begin
					check_right_point <= 1'b1;
				end
				default:begin
					check_right_point <= 1'b1;
				end
			endcase
		end
	end
	
	reg check_right_rotation;//檢測向右旋轉
	always @(*)begin
		if(!rst)begin
			check_right_rotation = 1'b1;
		end
		else begin
			case(state)
				DECLINE:begin
					if(graph[(cur_shape[2:0]*4) + rotation_choose-1][15]==1'b1 &&  (board[pos_y+7][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][14]==1'b1 &&  (board[pos_y+7][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][13]==1'b1 &&  (board[pos_y+7][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][12]==1'b1 &&  (board[pos_y+7][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][11]==1'b1 &&  (board[pos_y+6][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][10]==1'b1 &&  (board[pos_y+6][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][9]==1'b1 &&  (board[pos_y+6][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][8]==1'b1 &&  (board[pos_y+6][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][7]==1'b1 &&  (board[pos_y+5][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][6]==1'b1 &&  (board[pos_y+5][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][5]==1'b1 &&  (board[pos_y+5][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][4]==1'b1 &&  (board[pos_y+5][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][3]==1'b1 &&  (board[pos_y+4][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][2]==1'b1 &&  (board[pos_y+4][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][1]==1'b1 &&  (board[pos_y+4][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose-1][0]==1'b1 &&  (board[pos_y+4][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_right_rotation = 1'b0;
					end
					else begin
						check_right_rotation = 1'b1;
					end
				end
				NEW_SHAPE:begin
					check_right_rotation = 1'b1;
				end
				default:begin
					check_right_rotation = 1'b1;
				end
			endcase
		end
	end
	
	reg check_left_rotation;//檢測向左旋轉
	always @(*)begin
		if(!rst)begin
			check_left_rotation = 1'b1;
		end
		else begin
			case(state)
				DECLINE:begin
					if(graph[(cur_shape[2:0]*4) + rotation_choose+1][15]==1'b1 && (board[pos_y+7][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][14]==1'b1 && (board[pos_y+7][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][13]==1'b1 && (board[pos_y+7][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][12]==1'b1 && (board[pos_y+7][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][11]==1'b1 && (board[pos_y+6][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][10]==1'b1 && (board[pos_y+6][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][9]==1'b1 && (board[pos_y+6][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][8]==1'b1 && (board[pos_y+6][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][7]==1'b1 && (board[pos_y+5][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][6]==1'b1 && (board[pos_y+5][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][5]==1'b1 && (board[pos_y+5][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][4]==1'b1 && (board[pos_y+5][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][3]==1'b1 && (board[pos_y+4][pos_x+3] || (pos_x + 3)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][2]==1'b1 && (board[pos_y+4][pos_x+2] || (pos_x + 2)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][1]==1'b1 && (board[pos_y+4][pos_x+1] || (pos_x + 1)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else if(graph[(cur_shape[2:0]*4) + rotation_choose+1][0]==1'b1 && (board[pos_y+4][pos_x+0] || (pos_x + 0)>6'd9))begin
					  check_left_rotation = 1'b0;
					end
					else begin
						check_left_rotation = 1'b1;
					end
				end
				NEW_SHAPE:begin
					check_left_rotation = 1'b1;
				end
				default:begin
					check_left_rotation = 1'b1;
				end
			endcase
		end
	end
	

	
	//==============<控制左右和旋轉>===========
	always@(posedge IR_CLK_1S, negedge rst)begin
		if(!rst)begin
			pos_x <= initial_shape_pos_x;
			rotation_choose <= 2'd0;
		end
		else begin
			case(state)
				NEW_SHAPE:begin
					pos_x <= initial_shape_pos_x;
				end
				DECLINE:begin
					if(key2_on)begin
						case(key2_code)
							8'h75:begin
								if(check_left_rotation)begin
									rotation_choose <= rotation_choose + 1'b1;//旋轉
								end
							end
							8'h1A:begin
								if(check_left_rotation)begin
									rotation_choose <= rotation_choose + 1'b1;//左旋轉
								end
							end
							8'h22:begin
								if(check_right_rotation)begin
									rotation_choose <= rotation_choose - 1'b1;//右旋轉
								end
							end
						endcase
					end
					else if(key1_on)begin
						case(key1_code)
							8'h6B:begin
								if(pos_x > 5'd0 && check_left_point)begin					//左邊界限制
									pos_x <= pos_x - 1'b1; //向左
								end
							end
							8'h74:begin									//右邊界限制
								if(cur_shape[2:0] == 3'd0 && pos_x <6'd8 && check_right_point)begin		//O
									pos_x <= pos_x + 1'b1;//向右
								end
								else if(cur_shape[2:0] == 3'd1 && check_right_point)begin					//I
									if(rotation_choose[0]==0)begin
										if(pos_x < 6'd6)begin
											pos_x <= pos_x + 1'b1;//向右
										end
									end
									else begin
										if(pos_x < 6'd9)begin
											pos_x <= pos_x + 1'b1;//向右
										end
									end
								end
								else if(cur_shape[2:0] > 3'd1 && check_right_point) begin					//otherwise
									if(rotation_choose[0]==0)begin
										if(pos_x < 6'd7)begin
											pos_x <= pos_x + 1'b1;//向右
										end
									end
									else begin
										if(pos_x < 6'd8)begin
											pos_x <= pos_x + 1'b1;//向右
										end
									end
								end
							end
							8'h75:begin
								if(check_left_rotation)begin
									rotation_choose <= rotation_choose + 1'b1;//旋轉
								end
							end
							8'h1A:begin
								if(check_left_rotation)begin
									rotation_choose <= rotation_choose + 1'b1;//左旋轉
								end
							end
							8'h22:begin
								if(check_right_rotation)begin
									rotation_choose <= rotation_choose - 1'b1;//右旋轉
								end
							end
						endcase
					end
				end
					
			endcase
		end
	end 
	
	reg [4:0] cur_shape ;
	reg [4:0] hold_shape;
	always @(posedge IR_CLK_10S, negedge rst)begin
		if(!rst)begin
			cur_shape <= n_shape; 
			hold_shape <= 5'd0;
		end
		else begin
			case(state)
				START:begin
					cur_shape <= n_shape; 
				end
				NEW_SHAPE:begin
					cur_shape <= n_shape; 
				end
				HOLD:begin
					if(hold_check == 1'd0)begin
						hold_shape <= cur_shape;
					end
					else begin
						hold_shape <= cur_shape ;
						cur_shape  <= hold_shape; 
					end
				end
			endcase
		end
	end

	//================<控制向下>===========
	always @(posedge IR_CLK_10S, negedge rst)begin
		if(!rst)begin
			shape <= 5'b0_1011;
			pos_y <= initial_shape_pos_y;
			n_shape <= 5'b1_1101;
		end
		else begin
			case(state)
				NEW_SHAPE:begin
					//===========<LFSR>=============
					shape   <= {shape[2]^shape[3], shape[0]^shape[4],  shape[3] ^ shape[4], shape[2], shape[1]};
					n_shape <= {n_shape[2]^n_shape[3], n_shape[0]^n_shape[4],  n_shape[3] ^ n_shape[4], n_shape[2], n_shape[1]};
					//shape   <= {2'd0, shape[1],   shape[2]^shape[0],     shape[1]^shape[0]};
					//n_shape <= {2'd0, n_shape[1]^n_shape[0], n_shape[2]^n_shape[0], n_shape[1]^n_shape[0]};
					pos_y <= initial_shape_pos_y;
				end
				DECLINE:begin
					pos_y <= pos_y + 1'b1;//下
				end
				PLACE:begin
					pos_y <= -6'd4;
				end
				HOLD:begin
					pos_y <= -6'd4;
				end
			endcase
		end	
	end
	

	
	always@(posedge clk,negedge rst)begin
		if(!rst)begin
			color[0]<=24'h0000ff;//blue
			color[1]<=24'h00ff00;//green
			color[2]<=24'hfe0e86;//pink
			color[3]<=24'h0185fc;//sky blue
			color[4]<=24'hffffff;//white
			color[5]<=24'h606166;//gray
			color[6]<=24'hf0e611;//color O
			color[7]<=24'h1cc5fd;//color I
			color[8]<=24'h18c529;//color S
			color[9]<=24'he1031e;//color Z
			color[10]<=24'hff6b24;//color L
			color[11]<=24'h1e07e4;//color J
			color[12]<=24'h7b01d6;//color T
		end else begin
			color[0]<=24'h0000ff;//blue
			color[1]<=24'h00ff00;//green
			color[2]<=24'hfe0e86;//pink
			color[3]<=24'h0185fc;//sky blue
			color[4]<=24'hffffff;//white
			color[5]<=24'h606166;//gray
			color[6]<=24'hf0e611;//color O
			color[7]<=24'h1cc5fd;//color I
			color[8]<=24'h18c529;//color S
			color[9]<=24'he1031e;//color Z
			color[10]<=24'hff6b24;//color L
			color[11]<=24'h1e07e4;//color J
			color[12]<=24'h7b01d6;//color T
		end
	end

endmodule

//===============<除頻器>=====================
module counterDivider_TETRIS(CLK, RST, CLK_Out, countDivider); 
	
    // 除頻設定 1kHz 1ms
	parameter size = 16;
	input [25:0] countDivider;
	wire [25:0] countDivider_D2;
	assign countDivider_D2 = countDivider / 2;
	
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


