module PS2_KEYBOARD2(
        inout            PS2_DAT,
        input            PS2_CLK,
        input            clk,
        input            rst,
        input            rst1,
        output reg [7:0] scandata,
        output reg       key1_on,
        output reg       key2_on,
        output reg [7:0] key1_code,
        output reg [7:0] key2_code
    );
	
	parameter KEY_UP     = 8'h75;
	parameter KEY_DWON   = 8'h72;
	parameter KEY_LEFT   = 8'h6B;
	parameter KEY_RIGHT  = 8'h74;
	parameter KEY_ROTATE = 8'h12;
	parameter KEY_BUTTON = 8'h29;

    ////////////Keyboard Initially/////////
    reg [10:0] MCNT;
    always @(negedge rst or posedge clk)begin
        if (!rst)
            MCNT=0;
        else if(MCNT < 500)
            MCNT=MCNT+1;
    end

    ///// sequence generator /////
    reg	[7:0]	revcnt;
    wire rev_tr=(MCNT<12)?1:0;

    always @(posedge rev_tr or posedge PS2_CLK)begin
        if (rev_tr)
            revcnt=0;
        else if (revcnt >=10)
            revcnt=0;
        else
            revcnt=revcnt+1;
    end

    //////KeyBoard serial data in /////
    reg [9:0]keycode_o;
    always @(posedge PS2_CLK)begin
        case (revcnt[3:0])
            1:
                keycode_o[0]=PS2_DAT;
            2:
                keycode_o[1]=PS2_DAT;
            3:
                keycode_o[2]=PS2_DAT;
            4:
                keycode_o[3]=PS2_DAT;
            5:
                keycode_o[4]=PS2_DAT;
            6:
                keycode_o[5]=PS2_DAT;
            7:
                keycode_o[6]=PS2_DAT;
            8:
                keycode_o[7]=PS2_DAT;
        endcase
    end
    wire [7:0]rc=keycode_o[7:0];
    wire HOST_ACK=(revcnt==10)?~(rc[7]^rc[6]^rc[5]^rc[4]^rc[3]^rc[2]^rc[1]^rc[0]) :1;
	 
    ////////PS2 InOut/////////
    assign   PS2_DAT =(HOST_ACK)?1'bz:1'b0;


    ///////KeyBoard Scan-Code trigger//////
    reg keyready;
    always @(posedge rev_tr or negedge PS2_CLK)begin
        if (rev_tr)
            keyready=0;
        else if (revcnt[3:0]==10)
            keyready=1;
        else
            keyready=0;
    end
    /////////////////////////////////////Key1-Key2 Output///////////////////////////
    wire is_key=(
            (keycode_o == KEY_UP)?1:(
            (keycode_o == KEY_DWON)?1:(
            (keycode_o == KEY_LEFT)?1:(
            (keycode_o == KEY_RIGHT)?1:(
            (keycode_o == KEY_ROTATE)?1:(
            (keycode_o == KEY_BUTTON)?1:0
            )))))
         );

    //////////////key1 & key2 Assign///////////
    wire keyboard_off=((MCNT==200) || (!rst1))?0:1;

    always @(posedge keyready) scandata = keycode_o;

    always @(negedge keyboard_off  or posedge keyready)begin
        if (!keyboard_off)begin
            key1_on=0;
            key2_on=0;
            key1_code=8'hf0;
            key2_code=8'hf0;
        end
        else if (scandata==8'hf0)begin
			if (keycode_o==key1_code)begin
				key1_code=8'hf0;
				key1_on=0;
			end
			else if (keycode_o==key2_code)begin
				key2_code=8'hf0;
				key2_on=0;
			end
		end
		else if (is_key)begin
			if ((!key1_on) && (key2_code!=keycode_o))begin
				case(keycode_o)
					KEY_UP:begin
						key1_on=1;
						key1_code=keycode_o;
					end
					KEY_DWON:begin
						key1_on=1;
						key1_code=keycode_o;
					end
					KEY_LEFT:begin
						key1_on=1;
						key1_code=keycode_o;
					end
					KEY_RIGHT:begin
						key1_on=1;
						key1_code=keycode_o;
					end
					KEY_ROTATE:begin
						key2_on=1;
						key2_code=keycode_o;
					end
				endcase
			end
			else if ((!key2_on) && (key1_code!=keycode_o))begin
				case(keycode_o)
					KEY_ROTATE:begin
						key2_on=1;
						key2_code=keycode_o;
					end
				endcase
			end
		end
    end


endmodule
