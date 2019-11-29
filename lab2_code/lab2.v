// top module of ECE1756 lab2  by Zhiyuan Gu (1004920400)
module lab2 ( i_in, o_out, i_valid, o_valid, i_ready, o_ready, clk, reset) /* synthesis multstyle = "dsp" */;
// All * operations in my_module will now use a DSP block if possible */
	// set local parameters
	localparam DSP_num = 7; 		// number of DSP-based mac modules
	localparam input_width = 16;	// input signal width
	localparam coef_width = 16;	// coefficient width
	localparam output_width = 35;	// output width of mac modules
	localparam filter_order = 50;	// order of FIR filter
	// input and output signals
	input signed [input_width-1:0] i_in;
	output signed [input_width-1:0] o_out;
	input i_valid;
	output o_valid;
	input i_ready;
	output o_ready;
	input clk;
	input reset;
	
	integer i;
	
	wire enable;																// enable signal for sequential logic and passing into submodules
	wire signed [output_width-1:0] mac_res [DSP_num-1:0];			// 4-input DSP accumulation of multipliers result
	wire signed [output_width+2:0] adder_tree_res;		   		// adder tree result 
	
	reg signed [coef_width-1:0] coef [filter_order>>1:0];		   // to pass 26 coefficients to DSP inputs
	reg signed [coef_width-1:0] b [filter_order>>1:0];		      // 26 coefficients read from memory initialization file
	reg signed [input_width-1:0] in_sample [filter_order:0];		// samples of input
	wire signed [input_width:0] sample_out [filter_order>>1:0];		// sum of input sample pair which share the same coefficient
	reg signed [input_width:0] sample_out_reg [filter_order>>1:0];		// register the above signal
	reg [filter_order+8:0] valid_reg ;									// register to propagate valid signal
		
	// read coefficients
	initial begin
         $readmemb("coef_out.mif", b);		// read binary coefficients from generated file
   end
	 
	// pass coefficients to DSP inputs
	always@(*) begin
		for(i = 0; i <= filter_order>>1; i = i + 1) begin
			coef[i] = b[i];
		end
	end
	
	assign enable = i_ready & i_valid;							// if data not valid or downstream module not ready, stall pipeline
	assign o_ready = i_ready;										// if downstream not ready, tell upstream not ready
	assign o_valid = i_valid & (&valid_reg) & i_ready;		// output is valid only when all the previous 51 inputs are valid and downstream module is ready
	assign o_out = adder_tree_res[2*(input_width-1):input_width-1];  // assign output signal to be adder tree output and adjust precision
	
	// registers
	always@(posedge clk) begin
		if (reset) begin
			for(i = 0; i < filter_order + 1; i = i + 1) begin
				in_sample[i] <= 0;
			end
			valid_reg <= 0;
		end
		else begin
			if(enable) begin
				valid_reg[filter_order+8:0] <= {valid_reg[filter_order+7:0], i_valid};
				in_sample[0] <= i_in;
				for (i = 0; i < filter_order; i = i + 1) begin
					in_sample[i+1] <= in_sample[i];
				end
				for (i = 0; i <= filter_order>>1; i = i + 1) begin
					sample_out_reg[i] <= sample_out[i];
				end
			end
			else begin	// remain the same state until the downstream module is ready
				for(i = 0; i < filter_order + 1; i = i + 1) begin
					in_sample[i] <= in_sample[i];
				end
				valid_reg <= valid_reg;
				for (i = 0; i <= filter_order>>1; i = i + 1) begin
					sample_out_reg[i] <= sample_out_reg[i];
				end
			end
		end

	end
	
	// generate 25 adder for adding input samples that share the same coefficient
	genvar gi;
	generate
		for(gi = 0; gi < filter_order>>1; gi = gi + 1) begin: adder_l1
			assign sample_out[gi] = in_sample[gi] + in_sample[filter_order - gi];
		end	
	endgenerate
	assign sample_out[filter_order>>1] = in_sample[filter_order>>1];
	
	// generate 7 4-input dsp-based mac ip module, 7*4 = 28 > 26, the last two input pairs are set to (0,0)
	genvar gj;
	generate
		for(gj = 0; gj < DSP_num; gj = gj + 1) begin : mac1
			mult_add_dsp mult_add_dsp1(
			clk,
			sample_out_reg[gj*4+0],
			sample_out_reg[gj*4+1],
			(gj==DSP_num-1) ? 0 : sample_out_reg[gj*4+2],
			(gj==DSP_num-1) ? 0 : sample_out_reg[gj*4+3],
			coef[gj*4+0],
			coef[gj*4+1],
			(gj==DSP_num-1) ? 0 : coef[gj*4+2],
			(gj==DSP_num-1) ? 0 : coef[gj*4+3],
			enable,
			mac_res[gj]		);
		end	
	endgenerate
	
	// instantiate adder tree	
	in7_adder_tree adder_tree1 (mac_res[0], 
										 mac_res[1],
										 mac_res[2],
										 mac_res[3],
										 mac_res[4],
										 mac_res[5],
										 mac_res[6],
										 clk, enable,
										 adder_tree_res);
	

endmodule
