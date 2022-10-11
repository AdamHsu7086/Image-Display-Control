`timescale 1ns / 1ps
module counter(out, clk, rst, in);
  output reg [3:0] out;
  input clk;
  input rst; 
  input [1:0] in;
  
reg signed [5:0] out_tmp;
reg mode;	//1'b0 inc
			//1'b1 dec
			
always@(*)begin	
	case(mode)
		1'b0:	out_tmp = out + in;
		1'b1:	out_tmp = out - in;
		default: out_tmp = 0;
	endcase
end

always@(posedge clk or posedge rst)begin
	if(rst)
		out <= 4'd0;
	else if(out_tmp < 15 && mode == 1'b0)
		out <= out_tmp[3:0];
	else if(out_tmp >= 15 && mode == 1'b0)
		out <= 4'd15;
	else if(out_tmp > 0 && mode == 1'b1)
		out <= out_tmp[3:0];
	else if(out_tmp <= 0 && mode == 1'b1)
		out <= 4'd0;
end		
	
always@(posedge clk or posedge rst)begin
	if(rst)
		mode <= 0;
	else if(out_tmp > 15 || out_tmp < 0)
		mode <= ~mode;
end
	
	
endmodule
