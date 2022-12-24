module IR(iCLK,iRST_n,iIRDA,oDATA_READY,oDATA);
					
input iCLK;        //input clk,50MHz
input iRST_n;      //rst
input iIRDA;       //Irda RX output decoded data
output oDATA_READY; //data ready
output reg [31:0] oDATA; //output data,32bit 	
				
parameter IDLE = 2'b00;   //State Machine 
parameter GUIDANCE = 2'b01;    
parameter DATAREAD = 2'b10;    


parameter IDLE_DUR = 230000;  // idle_count    230000*0.02us = 4.60ms, threshold for IDLE--------->GUIDANCE
parameter GUIDANCE_DUR = 210000;  // guidance_count   210000*0.02us = 4.20ms, 4.5-4.2 = 0.3ms < BIT_AVAILABLE_DUR = 0.4ms,threshold for GUIDANCE------->DATAREAD
parameter DATAREAD_DUR = 262143;  // data_count    262143*0.02us = 5.24ms, threshold for DATAREAD-----> IDLE

parameter DATA_HIGH_DUR = 41500;	 // data_count    41500 *0.02us = 0.83ms, sample time from the posedge of iIRDA
parameter BIT_AVAILABLE_DUR = 20000;   // data_count    20000 *0.02us = 0.4ms,  the sample bit pointer,can inhibit the interference from iIRDA signal

reg [17:0] idle_count;           
reg idle_count_flag;       
reg [17:0] guidance_count;           
reg guidance_count_flag;      
reg [17:0] data_count;            
reg data_count_flag;    
  
reg [5:0] bitcount; //sample bit pointer
reg [1:0] state;   //state reg
reg [31:0] data;   //data reg
reg [31:0] data_buf; //data buf
reg data_ready; //data ready flag


assign oDATA_READY = data_ready;

//state change between IDLE,GUIDE,DATA_READ according to irda edge or counter
always @(posedge iCLK or negedge iRST_n)
begin 
	  if (!iRST_n)	     
	     state <= IDLE;
	  else 
			 case (state)
 			    IDLE     : if (idle_count > IDLE_DUR)  
			  	              state <= GUIDANCE; 
			    GUIDANCE : if (guidance_count > GUIDANCE_DUR)
			  	              state <= DATAREAD;
			    DATAREAD : if ((data_count >= DATAREAD_DUR) || (bitcount >= 33))
			  					      state <= IDLE;
	        default  : state <= IDLE; 
			 endcase
end
//idle counter switch when iIRDA is low under IDLE state
always @(posedge iCLK or negedge iRST_n)
begin	
	  if (!iRST_n)
		   idle_count_flag <= 1'b0;
	  else if ((state == IDLE) && !iIRDA)
			 idle_count_flag <= 1'b1;
		else                           
			 idle_count_flag <= 1'b0;		     		 	
 end  		  
//idle counter works on iclk under IDLE state only
always @(posedge iCLK or negedge iRST_n)
begin	
	  if (!iRST_n)
		   idle_count <= 0;
	  else if (idle_count_flag)    //the counter works when the flag is 1
			 idle_count <= idle_count + 1'b1;
		else  
			 idle_count <= 0;	         //the counter resets when the flag is 0		      		 	
end
   
//state counter switch when iIRDA is high under GUIDE state
always @(posedge iCLK or negedge iRST_n)	
begin
	  if (!iRST_n)
		   guidance_count_flag <= 1'b0;
	  else if ((state == GUIDANCE) && iIRDA)
			 guidance_count_flag <= 1'b1;
		else  
			 guidance_count_flag <= 1'b0;     		 	
end
//state counter works on iclk under GUIDE state only
always @(posedge iCLK or negedge iRST_n)	
begin
	  if (!iRST_n)
		   guidance_count <= 0;
	  else if (guidance_count_flag)    //the counter works when the flag is 1
			 guidance_count <= guidance_count + 1'b1;
		else  
			 guidance_count <= 0;	        //the counter resets when the flag is 0		      		 	
end
//data counter switch
always @(posedge iCLK or negedge iRST_n)
begin
	  if (!iRST_n) 
		   data_count_flag <= 0;	
	  else if ((state == DATAREAD) && iIRDA)
			 data_count_flag <= 1'b1;  
		else
			 data_count_flag <= 1'b0; 
end
//data read decode counter based on iCLK
always @(posedge iCLK or negedge iRST_n)	
begin
	  if (!iRST_n)
		   data_count <= 1'b0;
	  else if(data_count_flag)      //the counter works when the flag is 1
			 data_count <= data_count + 1'b1;
		else 
			 data_count <= 1'b0;        //the counter resets when the flag is 0
end
///////////////////////////////////////////////////////////////////////////////////////////////

//data reg pointer counter 
always @(posedge iCLK or negedge iRST_n)
begin
    if (!iRST_n)
       bitcount <= 6'b0;
	  else if (state == DATAREAD)
		begin
			if (data_count == BIT_AVAILABLE_DUR)
					bitcount <= bitcount + 1'b1; //add 1 when iIRDA posedge
		end   
	  else
	     bitcount <= 6'b0;
end	  
//data decode base on the value of data_count 	
always @(posedge iCLK or negedge iRST_n)
begin
	  if (!iRST_n)
	     data <= 0;
		else if (state == DATAREAD)
		begin
			 if (data_count >= DATA_HIGH_DUR) //2^15 = 32767*0.02us = 0.64us
			    data[bitcount-1'b1] <= 1'b1;  //>0.52ms  sample the bit 1
		end
		else
			 data <= 0;	
end		 
//set the data_ready flag 
always @(posedge iCLK or negedge iRST_n)
begin 
	  if (!iRST_n)
	     data_ready <= 1'b0;
    else if (bitcount == 32)   
		begin
			 if (data[31:24] == ~data[23:16])
			 begin		
					data_buf <= data;     //fetch the value to the databuf from the data reg
				  data_ready <= 1'b1;   //set the data ready flag
			 end	
			 else
				  data_ready <= 1'b0 ;  //data error
		end
		else
		   data_ready <= 1'b0 ;
end
//read data
always @(posedge iCLK or negedge iRST_n)
begin
	  if (!iRST_n)
		   oDATA <= 32'b0000;
	  else if (data_ready)
	     oDATA <= data_buf;  //output
end	  
endmodule