module sfp (clk, reset, in_psum, valid_in, out_accum, wr_ofifo, o_valid, relu_en, lrelu_en, shift);
    parameter col = 8;
    parameter psum_bw = 16;

    input  clk;
    input  reset;
    input  relu_en;
    input  lrelu_en;
    input  [1:0] shift;
    input  [psum_bw*col-1:0] in_psum;   // input from last row MAC array
    input  [col-1:0] valid_in;          // one bit per column indicating valid in_psum
    output wire [psum_bw*col-1:0] out_accum;    // concatenated of accum & relu outputs for all columns
    output wire [col-1:0] wr_ofifo;     // write enable per column of output FIFO
    output wire o_valid;                // high when any column has valid data

    reg signed [psum_bw-1:0] acc_reg [0:col-1];     // signed reg to hold accumulated psum values
    reg        [col-1:0]     wr_reg;                // register to hold write enable for each column

    assign wr_ofifo = wr_reg;
    assign o_valid  = |wr_reg;

    genvar k;
    generate
        for (k = 0; k < col; k = k + 1) begin : COLUMN
            reg signed [psum_bw-1:0] next_val;              // compute next accumulator value includin RELU
            //wire signed [psum_bw-1:0] in_val = in_psum[(k+1)*psum_bw-1 : k*psum_bw];    // extract column k psum

            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    acc_reg[k] <= 0;        // reset accumulator to 0 on reset
                end else begin
                    //next_val = acc_reg[k];      // initialize next_val to current accumulator value

                    // Accumulation
                    //if (valid_in[k])
                    //    next_val = acc_reg[k] + in_val;

                    //acc_reg[k] <= next_val;
		    if (valid_in[k]) begin
			    //acc_reg[k] <= (relu_en && (acc_reg[k] + in_psum[(k+1)*psum_bw-1:k*psum_bw] < 0)) ? 0 : acc_reg[k] + in_psum[(k+1)*psum_bw-1:k*psum_bw];
			    acc_reg[k] <= acc_reg[k] + in_psum[(k+1)*psum_bw-1:k*psum_bw];
		    end else begin 
		    	acc_reg[k] <=  acc_reg[k];
			end
                end
            end

            // output mapping & ReLU
	    assign out_accum[(k+1)*psum_bw-1 : k*psum_bw] = (acc_reg[k] < 0) ? ({psum_bw{lrelu_en}} & 
		    (({psum_bw{1'b1}} ^ ({psum_bw{1'b1}} >> shift)) | acc_reg[k] >>> shift)) : acc_reg[k];


        end
    endgenerate

    // wr_ofifo and o_valid registers
    always @(posedge clk or posedge reset) begin
        if (reset)
            wr_reg <= 0;
        else
            wr_reg <= valid_in;
    end

endmodule
