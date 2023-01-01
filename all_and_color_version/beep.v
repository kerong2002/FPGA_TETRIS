
`define L_C 262
`define L_D 294
`define L_E 330
`define L_F 349
`define L_G 392

`define L_Gs 415

`define L_A 440
`define L_B 494

`define P 0

`define M_C 523
`define M_D 587
`define M_E 659
`define M_F 698
`define M_G 784

`define M_Gs 831

`define M_A 880
`define M_B 988



module beep(clk, rst, level, beep);
	input clk;
	input rst;
	input [2:0] level;
	output reg beep;
	//500ms 跳轉一次
	localparam state_top = 24'd6250_0000-1;
	reg [23:0] state_cnt;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			state_cnt <= 24'd0;
		end
		else if(state_cnt <= state_top)begin
			state_cnt <= state_cnt + 24'd1;
		end
		else begin
			state_cnt <= 24'd0;
		end		
	end
	
	wire state_cnt_done = (state_cnt == state_top) ? 1'b1 : 1'b0;
	
	reg [6:0] state;
	reg [20:0] cnt_top;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			state <= 7'd0;
		end
		else if(state_cnt_done)begin
			state <= state + 7'd1;	
		end
	end
	
	always @(*)begin
		case(state)
			7'd0  : cnt_top = `M_E;
			7'd1  : cnt_top = `M_E;
			7'd2  : cnt_top = `L_B;
			7'd3  : cnt_top = `M_C;
			7'd4  : cnt_top = `M_D;
			7'd5  : cnt_top = `M_D;
			7'd6  : cnt_top = `M_C;
			7'd7  : cnt_top = `L_B;
			
			7'd8  : cnt_top = `L_A;
			7'd9  : cnt_top = `L_A;
			7'd10 : cnt_top = `L_A;
			7'd11 : cnt_top = `M_C;
			7'd12 : cnt_top = `M_E;
			7'd13 : cnt_top = `M_E;
			7'd14 : cnt_top = `M_D;
			7'd15 : cnt_top = `M_C;
			
			7'd16 : cnt_top = `L_B;
			7'd17 : cnt_top = `L_B;
			7'd18 : cnt_top = `L_B;
			7'd19 : cnt_top = `M_C;
			7'd20 : cnt_top = `M_D;
			7'd21 : cnt_top = `M_D;
			7'd22 : cnt_top = `M_E;
			7'd23 : cnt_top = `M_E;
			
			7'd24 : cnt_top = `M_C;
			7'd25 : cnt_top = `M_C;
			7'd26 : cnt_top = `L_A;
			7'd27 : cnt_top = `L_A;
			7'd28 : cnt_top = `L_A;
			7'd29 : cnt_top = `L_A;
			7'd30 : cnt_top = `L_B;
			7'd31 : cnt_top = `M_C;
			
			7'd32 : cnt_top = `M_D;
			7'd33 : cnt_top = `M_D;
			7'd34 : cnt_top = `M_D;
			7'd35 : cnt_top = `M_F;
			7'd36 : cnt_top = `M_A;
			7'd37 : cnt_top = `M_A;
			7'd38 : cnt_top = `M_G;
			7'd39 : cnt_top = `M_F;
			
			7'd40 : cnt_top = `M_E;
			7'd41 : cnt_top = `M_E;
			7'd42 : cnt_top = `M_E;
			7'd43 : cnt_top = `M_C;
			7'd44 : cnt_top = `M_E;
			7'd45 : cnt_top = `M_E;
			7'd46 : cnt_top = `M_D;
			7'd47 : cnt_top = `M_C;
			
			7'd48 : cnt_top = `L_B;
			7'd49 : cnt_top = `L_B;
			7'd50 : cnt_top = `L_B;
			7'd51 : cnt_top = `M_C;
			7'd52 : cnt_top = `M_D;
			7'd53 : cnt_top = `M_D;
			7'd54 : cnt_top = `M_E;
			7'd55 : cnt_top = `M_E;
			
			7'd56 : cnt_top = `M_C;
			7'd57 : cnt_top = `M_C;
			7'd58 : cnt_top = `L_A;
			7'd59 : cnt_top = `L_A;
			7'd60 : cnt_top = `L_A;
			7'd61 : cnt_top = `L_A;
			7'd62 : cnt_top = `P;
			7'd63 : cnt_top = `P;
			
			7'd64 : cnt_top = `M_E;
			7'd65 : cnt_top = `M_E;
			7'd66 : cnt_top = `M_E;
			7'd67 : cnt_top = `M_E;
			7'd68 : cnt_top = `M_C;
			7'd69 : cnt_top = `M_C;
			7'd70 : cnt_top = `M_C;
			7'd71 : cnt_top = `M_C;
			
			7'd72 : cnt_top = `M_D;
			7'd73 : cnt_top = `M_D;
			7'd74 : cnt_top = `M_D;
			7'd75 : cnt_top = `M_D;
			7'd76 : cnt_top = `L_B;
			7'd77 : cnt_top = `L_B;
			7'd78 : cnt_top = `L_B;
			7'd79 : cnt_top = `L_B;
			
			7'd80 : cnt_top = `M_C;
			7'd81 : cnt_top = `M_C;
			7'd82 : cnt_top = `M_C;
			7'd83 : cnt_top = `M_C;
			7'd84 : cnt_top = `L_A;
			7'd85 : cnt_top = `L_A;
			7'd86 : cnt_top = `L_A;
			7'd87 : cnt_top = `L_A;
			
			7'd88 : cnt_top = `L_Gs;
			7'd89 : cnt_top = `L_Gs;
			7'd90 : cnt_top = `L_Gs;
			7'd91 : cnt_top = `L_Gs;
			7'd92 : cnt_top = `L_B;
			7'd93 : cnt_top = `L_B;
			7'd94 : cnt_top = `P;
			7'd95 : cnt_top = `P;
			
			7'd96 : cnt_top = `M_E;
			7'd97 : cnt_top = `M_E;
			7'd98 : cnt_top = `M_E;
			7'd99 : cnt_top = `M_E;
			7'd100: cnt_top = `M_C;
			7'd101: cnt_top = `M_C;
			7'd102: cnt_top = `M_C;
			7'd103: cnt_top = `M_C;
			
			7'd104: cnt_top = `M_D;
			7'd105: cnt_top = `M_D;
			7'd106: cnt_top = `M_D;
			7'd107: cnt_top = `M_D;
			7'd108: cnt_top = `L_B;
			7'd109: cnt_top = `L_B;
			7'd110: cnt_top = `L_B;
			7'd111: cnt_top = `L_B;
			
			7'd112: cnt_top = `M_C;
			7'd113: cnt_top = `M_C;
			7'd114: cnt_top = `M_E;
			7'd115: cnt_top = `M_E;
			7'd116: cnt_top = `M_A;
			7'd117: cnt_top = `M_A;
			7'd118: cnt_top = `M_A;
			7'd119: cnt_top = `M_A;
			
			7'd120: cnt_top = `M_Gs;
			7'd121: cnt_top = `M_Gs;
			7'd122: cnt_top = `M_Gs;
			7'd123: cnt_top = `M_Gs;
			7'd124: cnt_top = `P;
			7'd125: cnt_top = `P;
			7'd126: cnt_top = `P;
			7'd127: cnt_top = `P;
			
			default : begin
				cnt_top = `M_C;
			end
		endcase
	end
	
	reg [26:0] cnt;
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			cnt <= 27'd0;
		end
		else if(cnt < 50_000_000/cnt_top-1)begin
			cnt <= cnt + 27'd1;
		end
		else begin
			cnt <= 27'd0;
		end
	end
	
	
	always @(posedge clk, negedge rst)begin
		if(!rst)begin
			beep <= 1'b0;
		end
		else begin
			beep <= (cnt< (cnt_top*level)) ? 1'b1 : 1'b0;
		end
	end	
	
endmodule 

