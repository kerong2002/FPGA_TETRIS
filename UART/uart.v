`include "./transmitter.v"

module uart(clk, rst, TxD);
	input clk;		
	input rst;
	output TxD;
	transmitter trans1(clk, rst, 1'd1, 8'd2, TxD);
	
endmodule 