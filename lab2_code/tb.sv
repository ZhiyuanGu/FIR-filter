`timescale 1ps/1ps

module tb();

// slow 50MHz clock is used to give DUT signals time to propagate. 
// Quartus assumes all signals launched/latched on positive edge, but for testbench
// this is not the case.
localparam CLK_PERIOD = 20000; // in ps
localparam QSTEP = (CLK_PERIOD/4);	//a quarter of a clock cycle
localparam TIMESTEP = (CLK_PERIOD/10);	//a small-ish timestep

// Set to 1 to build a reference output file (golden/good outputs).
localparam MAKE_GOLDEN = 0;

// Number of valid outputs to check.
localparam OUTPUTS_TO_COMPARE = 200;

// Valid outputs are only generated when we push through 
// (1) enough input data to push through the pipeline and create the first valid output
// + (2) enough input data to empty the pipe (push out all the partial results in the
// pipeline) as we only move partial output data forward when there is new input data.
// Run for an extra 300 input cycles, which will be fine so long as the design latency is < 150 cycles.
localparam INPUTS_TO_SIM = OUTPUTS_TO_COMPARE + 300; 

logic signed [15:0] i_in;
logic signed [15:0] o_out;
logic i_valid;
logic i_ready;
logic o_valid;
logic o_ready;
logic clk;
logic reset;
logic signed [15:0] o_golden_out;   // Golden output you are trying to match.

lab2 dut ( .* );


initial clk = '1;
always #(CLK_PERIOD/2) clk = ~clk;  // Generate clock with the specified period.


logic signed [15:0] inwave[INPUTS_TO_SIM-1:0];
logic signed [15:0] outwave[OUTPUTS_TO_COMPARE-1:0];


// Producer
// Send in data for INPUTS_TO_SIM cycles.
logic signed [15:0] saved_i_in;
logic valid_stall_tested = 0;
initial begin
	integer f;
	
	// Create known good input: a delta function, then a step function
	for (int i = 0; i < INPUTS_TO_SIM; i++) begin
		if (i == 60 || i >= 120)
			/* impulse at i=60, step at i=120+ */
			//inwave[i] = 16'd20000;		// functional simulation inputs
			inwave[i] = $urandom(i);	// feed random inputs to do realistic power estimation
		else
			/* 0 everywhere else */
			inwave[i] = 16'd0;
	end
	
	// Load known good output
	f = $fopen("outdata.txt", "r");
	for (int i = 0; i < OUTPUTS_TO_COMPARE; i++) begin
		integer d;
		d = $fscanf(f, "%d", outwave[i]);
	end
	$fclose(f);

	i_valid = 1'b0;
	i_in = 'd0;
	
	reset = 1'b1;
	#(CLK_PERIOD);
	reset = 1'b0;	
	
	for (int i = 0; i < INPUTS_TO_SIM; i++) begin

		//start on posedge
		//advance quarter cycle
		#(QSTEP);
		//generate an input value
		i_in = inwave[i];
		saved_i_in = i_in;
	
		//advance quarter cycle (now on negedge)
		#(QSTEP);
		//nothing to do here
	
		//advance another quarter cycle
		#(QSTEP);
		//check o_ready and set i_valid
		i_valid = 1'b1;
		while(!o_ready) begin
			//if DUT claims to not be ready, then it shouldn't be an issue if we 
			//give it an erroneous value.
			i_in = -13;
			i_valid = 1'b0;
			
			//wait for a clock period before checking o_ready again
			#(CLK_PERIOD);
			//restore the correct value of i_x if we're going to go out of this while loop
			i_in = saved_i_in;
			i_valid = 1'b1;
		end
	
		//test that DUT stalls properly if we don't give it a valid input
		if (i == 115 && !valid_stall_tested) begin
		   i_valid = 1'b0;
		   i_in = -18000; // Strange input to make sure it's ignored.
		   #(10*CLK_PERIOD);
			
			//make sure the DUT is ready to receive inputs
			while(!o_ready) begin
				#(CLK_PERIOD);
			end
			
			i_in = saved_i_in;
			i_valid = 1'b1;
			valid_stall_tested = 1;
		end
	
		//advance another quarter cycle to next posedge
		#(QSTEP);
	end
	
	// All the inputs applied, no more valid data.
	@(negedge clk);
	i_valid = 1'b0;
	
end

// Consumer
// Will check the first OUTPUTS_TO_COMPARE outputs are the right values.
// These outputs must come out in the right order, but can come out with 
// arbitrary latency, as the output is only compared when o_valid is high.
// When o_valid is low, we just skip over that cycle.
logic ready_stall_tested = 0;
initial begin
	static real rms = 0.0;
	integer f;
	i_ready = 1'b1;
	o_golden_out = 16'b0;
	
	if (MAKE_GOLDEN) begin
		f = $fopen("outdata.txt", "w");
	end
	
	//delay until just before the first posedge
	#(CLK_PERIOD - TIMESTEP);
		
	for (int i = 0; i < OUTPUTS_TO_COMPARE; i=i/*i++*/) begin
		real v1;
		real v2;
		real diff;
		
		if (MAKE_GOLDEN) begin
			$fdisplay(f, "%d", o_out);
		end
		
		//we are now at the point just before the posedge
		//check o_valid and compare results
		if (o_valid) begin
			v1 = real'(o_out);
			o_golden_out = outwave[i];
			v2 = real'(o_golden_out);
			diff = (v1 - v2);
			
			rms += diff*diff;
			$display("diff: %f, rms: %f, o_out: %f, golden: %f, at time: ", diff, rms, v1, v2, $time);
			
			i++;
		end
		
		//advance to posedge
		#(TIMESTEP);

		//then advance another quarter cycle
		#(QSTEP);

		//set i_ready
		i_ready = 1'b1;
		
		//test that DUT stalls properly if receiver isn't ready
		if (i==90 && !ready_stall_tested) begin
			i_ready = 1'b0;
			//wait for 10 clock periods
			#(10*CLK_PERIOD);
			//then restore i_ready
			i_ready = 1'b1;
			ready_stall_tested = 1;
		end
		
		//then advance to just before the next posedge
		#(3*QSTEP - TIMESTEP);
	end
	
	if (MAKE_GOLDEN) begin
		$fclose(f);
		$stop(0);
	end
	
	rms /= OUTPUTS_TO_COMPARE;
	rms = rms ** (0.5);
	
	$display("RMS Error: %f", rms);
	if (rms > 10) begin
		$display("Average RMS Error is above 10 units (on a scale to 32,000) - something is probably wrong");
	end
	else begin
		$display("Error is within 10 units (on a scale to 32,000) - great success!!");
	end
	
	$stop(0);
end

endmodule
