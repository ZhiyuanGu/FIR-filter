// 7-input adder tree module of ECE1756 lab2  by Zhiyuan Gu (1004920400)
module in7_adder_tree(A, B, C, D, E, F, G,
								clk, enable, out);
   // set local parameters
	localparam output_width = 35;	
	// input and output signals
	input	[output_width-1:0] A, B, C, D, E, F, G;
	input	clk, enable;
	output [output_width+2:0] out;
	
	reg   [output_width-1:0]    inreg [6:0];
	
	wire	[output_width:0]    sum1 [3:0];
	reg   [output_width:0]    sumreg1 [3:0];
	
	wire	[output_width+1:0]    sum2 [1:0];
	reg   [output_width+1:0]    sumreg2 [1:0];
	
	wire	[output_width+2:0]    sum3;
	reg   [output_width+2:0]    sumreg3;
	
	integer i;
	
	// Registers
	always @ (posedge clk)
		begin
			if(enable) begin
				inreg[0] = A;
				inreg[1] = B;
				inreg[2] = C;
				inreg[3] = D;
				inreg[4] = E;
				inreg[5] = F;
				inreg[6] = G;
				
				for(i = 0; i < 4; i = i + 1) begin
					sumreg1[i] <= sum1[i];
				end
				for(i = 0; i < 2; i = i + 1) begin
					sumreg2[i] <= sum2[i];
				end
				sumreg3 <= sum3;
			end
			else begin
				for(i = 0; i < 4; i = i + 1) begin
					sumreg1[i] <= sumreg1[i];
				end
				for(i = 0; i < 2; i = i + 1) begin
					sumreg2[i] <= sumreg2[i];
				end
				sumreg3 <= sumreg3;
				for(i = 0; i < 7; i = i + 1) begin
					inreg[i] <= inreg[i];
				end
			end
		end

	// 3 level of addition and one output assignments
	assign 			  sum1[0] = inreg[0] + inreg[1];
	assign 			  sum1[1] = inreg[2] + inreg[3];
	assign 			  sum1[2] = inreg[4] + inreg[5];
	assign 			  sum1[3] = inreg[6];
		
	assign 			  sum2[0] = sumreg1[0] + sumreg1[1];
	assign 			  sum2[1] = sumreg1[2] + sumreg1[3];
	
	assign 			  sum3 = sumreg2[0] + sumreg2[1];
	
	assign 			  out = sumreg3;

endmodule