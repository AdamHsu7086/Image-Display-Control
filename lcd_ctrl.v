module LCD_CTRL(clk, reset, IROM_Q, cmd, cmd_valid, IROM_EN, IROM_A, IRB_RW, IRB_D, IRB_A, busy, done);
input clk;
input reset;
input [7:0] IROM_Q;
input [3:0] cmd;
input cmd_valid;

output reg IROM_EN;
output reg[5:0] IROM_A;
output reg IRB_RW;
output reg [7:0] IRB_D;
output reg[5:0] IRB_A;
output reg busy;
output reg done;

reg [5:0] IROM_A_dly;
reg [5:0] IRB_A_dly ;
reg [2:0] cs,ns; //current state//next state
reg [8:0] data [0:63];//data[0] to data[63] //let 8:0 because + 64 may exceed 255
reg [2:0] x; //x-coordinate 0 to 7
reg [2:0] y; //y-coordinate 0 to 7
wire [8:0] data_avg;//store average
wire [9:0] data_reg1;
wire [9:0] data_reg2;
wire [9:0] data_reg3;
wire [9:0] data_reg4;

parameter idle = 3'b000;//no action
parameter read = 3'b001;//read 64 data from IROM
parameter decode = 3'b010;//get new cmd
parameter process = 3'b011;//do what cmd ask for
parameter write = 3'b100;//write in data which have been processed to IRB  
parameter done_write = 3'b101;//end 

always@(posedge clk or posedge reset)begin //cs//if reset => read data from IROM//if no => current state to next state
	if(reset)
		cs <= idle;
	else
		cs <= ns;
end

always@(*)begin //ns
	ns = idle;
	case(cs)
	idle:begin
		if(reset == 0)//after reset => read 64 data from IROM_Q to data[IROM_A_reg]
			ns = read; 
		else
			ns = idle;
	end
	read:begin
		if(IROM_A_dly == 63)//after read => get cmd 
			ns = decode;
		else
			ns = read;
	end
	decode:begin
		if(cmd == 4'b0000)//if cmd = 0 => write data to IRB_D 
			ns = write;
		else
			ns = process;
	end
	process:begin
			ns = decode;//if no write => return to decode and get new cmd
	end
	write:begin
		if(IRB_A == 63)//after write => end
			ns = done_write;
		else
			ns = write;
	end
	endcase
end
		

always@(posedge clk or posedge reset)begin //if read => IROM_EN = 0
	if(reset)
		IROM_EN <= 1;
	else if(ns == read)
		IROM_EN <= 0;
	else
	  IROM_EN <= 1; 	  
end

always@(posedge clk or posedge reset)begin //when write => IRB_RW = 0
  if(reset)
    IRB_RW <= 1;
	if(cs == write)
		IRB_RW <= 0;
end

always@(posedge clk or posedge reset)begin //busy = 0 when get cmd //bust = 1 when proccessing
	if(reset)
		busy <= 1;
	else if(ns == decode)
  		busy <= 0;
	else if(ns == process)
	  busy <= 1;
	else if(ns == write)
	  busy <= 1; 
  else
    busy <= 1;
end		
			
always@(posedge clk or posedge reset)begin //IROM_A
	if(reset)
		IROM_A <= 0;
	else if(cs == read)	
		IROM_A <= IROM_A + 1;
	else
		IROM_A <= 0;
end

always@(posedge clk)begin //IROM_A_dly
  IROM_A_dly <= IROM_A;
end


always@(posedge clk or posedge reset)begin //IRB_A_dly
	if(reset)
		IRB_A_dly <= 0;
	else if(IRB_RW == 0)
		IRB_A_dly <= IRB_A_dly + 1;
	else
		IRB_A_dly <= 0;
end

always@(posedge clk)begin //IRB_A_dly
  IRB_A <= IRB_A_dly;
end

assign data_reg1 = data[{y,x} - 9]; //store 1
assign data_reg2 = data[{y,x} - 8]; //store 2
assign data_reg3 = data[{y,x} - 1]; //store 3
assign data_reg4 = data[{y,x}]; //store 4
assign data_avg = (data_reg1 + data_reg2 + data_reg3 + data_reg4) >> 2;//store average data

always@(posedge clk or posedge reset)begin //process//data[0] to data[63] from IROM
	if(cs == read)
		data[IROM_A_dly] <= IROM_Q;
	else if(cs == process && busy == 1)begin
		case(cmd)
		4'b0101:begin//5 //average
			data[{y,x} - 9] <= data_avg;
 			data[{y,x} - 8] <= data_avg;
			data[{y,x} - 1] <= data_avg;
			data[{y,x}] <= data_avg;
		end
		4'b0110:begin//6//mirrow x
			data[{y,x} - 9] <= data_reg3; //1 <- 3 
			data[{y,x} - 8] <= data_reg4;//2 <- 4
			data[{y,x} - 1] <= data_reg1;//3 <- 1
			data[{y,x} - 0] <= data_reg2;//4 <- 2
		end
		4'b0111:begin//7//mirrow y
		  data[{y,x} - 9] <= data_reg2;//1 <- 2
      data[{y,x} - 8] <= data_reg1;//2 <- 1
      data[{y,x} - 1] <= data_reg4;//3 <- 4
      data[{y,x} - 0] <= data_reg3;//4 <- 3
		end
		4'b1001:begin//9
			data[{y,x} - 9] <= (data[{y,x} - 9] + 64 >= 255) ? 255 : data[{y,x} - 9] + 64;
			data[{y,x} - 8] <= (data[{y,x} - 8] + 64 >= 255) ? 255 : data[{y,x} - 8] + 64;
			data[{y,x} - 1] <= (data[{y,x} - 1] + 64 >= 255) ? 255 : data[{y,x} - 1] + 64;
			data[{y,x}] <= (data[{y,x}] + 64 >= 255) ? 255 : data[{y,x}] + 64;		
		end
		4'b1010:begin//A
			data[{y,x} - 9] <= (data[{y,x} - 9] - 64 >= 255) ? 0 : data[{y,x} - 9] - 64;
			data[{y,x} - 8] <= (data[{y,x} - 8] - 64 >= 255) ? 0 : data[{y,x} - 8] - 64;
			data[{y,x} - 1] <= (data[{y,x} - 1] - 64 >= 255) ? 0 : data[{y,x} - 1] - 64;
			data[{y,x}] <= (data[{y,x}] - 64 >= 255) ? 0 : data[{y,x}] - 64;		
		end
		4'b1011:begin//B
			if(data[{y,x} - 9] > 128)
				data[{y,x} - 9] <= 255;
			else
				data[{y,x} - 9] <= 0; 
			if(data[{y,x} - 8] > 128)
				data[{y,x} - 8] <= 255;
			else
				data[{y,x} - 8] <= 0;
			if(data[{y,x} - 1] > 128)
				data[{y,x} - 1] <= 255;
			else
				data[{y,x} - 1] <= 0;
			if(data[{y,x}] > 128)
				data[{y,x}] <= 255;
			else
				data[{y,x}] <= 0;
		end
		4'b1100:begin//C
			if(data[{y,x} - 9] < 128)
				data[{y,x} - 9] <= 255;
			else
				data[{y,x} - 9] <= 0; 
			if(data[{y,x} - 8] < 128)
				data[{y,x} - 8] <= 255;
			else
				data[{y,x} - 8] <= 0;
			if(data[{y,x} - 1] < 128)
				data[{y,x} - 1] <= 255;
			else
				data[{y,x} - 1] <= 0;
			if(data[{y,x}] < 128)
				data[{y,x}] <= 255;
			else
				data[{y,x}] <= 0;
		end
		endcase
	end
end


always@(posedge clk or posedge reset)begin //process//operation point at(4,4)//do process
	if(reset)begin
		x <= 4;
		y <= 4;
	end
	else if(cs == process)begin
		case(cmd)
		4'b0001:begin//1
			if(y > 1)
				y <= y - 1;
			else if(y == 1)
				y <= 1;
			end
		4'b0010:begin//2
			if(y < 7)
				y <= y + 1;
			else if(y == 7)
				y <= 7;
		end
		4'b0011:begin//3
			if(x > 1)
				x <= x - 1;
			else if(x == 1)
				x <= 1;
		end
		4'b0100:begin//4
			if(x < 7)
				x <= x + 1;
			else if(x == 7)
				x <= 7;
		end
		4'b1000:begin//8
			x <= 4;
			y <= 4;
		end
		endcase
	end
end

always@(posedge clk or posedge reset)begin //write
  if(reset)
    IRB_D <= 0;
	else if(IRB_RW == 0)
		IRB_D <= data[IRB_A_dly];
end

always@(posedge clk)begin //done
	if(cs == done_write)
		done <= 1;
	else
		done <= 0;
end
		
endmodule


