module SEG_7(in_4,out_LED_7);
	input [3:0] in_4;
	output reg [6:0] out_LED_7;
	always @(*)begin
		case(in_4)
			4'h0 : out_LED_7 = 7'b0000001;
			4'h1 : out_LED_7 = 7'b1001111;
			4'h2 : out_LED_7 = 7'b0010010;
			4'h3 : out_LED_7 = 7'b0000110;
			4'h4 : out_LED_7 = 7'b1001100;
			4'h5 : out_LED_7 = 7'b0100100;
			4'h6 : out_LED_7 = 7'b1100000;
			4'h7 : out_LED_7 = 7'b0001111;
			4'h8 : out_LED_7 = 7'b0000000;
			4'h9 : out_LED_7 = 7'b0001100;
			4'ha : out_LED_7 = 7'b0001000;
			4'hb : out_LED_7 = 7'b1100000;
			4'hc : out_LED_7 = 7'b0110001;
			4'hd : out_LED_7 = 7'b1000010;
			4'he : out_LED_7 = 7'b0110000;
			4'hf : out_LED_7 = 7'b0111000;
		endcase
	end
	
endmodule 