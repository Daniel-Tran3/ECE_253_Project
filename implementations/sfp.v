module sfp (clk, reset, psum_in, l1_read_data, ofifo_valid, relu_enable, accum_out, write_enable);
    parameter col = 8;
    parameter psum_bw = 16;

    input  clk;
    input  reset;
    input  [psum_bw*col-1:0]  psum_in;  // psums from OFIFO aligned
    input  [psum_bw*col-1:0]  l1_read_data;  // old partial sums from L1
    input  [col-1:0] ofifo_valid;          // valid flags from OFIFO indicating new data
    input  relu_enable;         // only high on FINAL pass
    output wire [psum_bw*col-1:0]  accum_out;    // updated sum back to L1
    output reg [col-1:0] write_enable;  // writeback enable for L1

    reg signed [psum_bw-1:0] acc_reg [0:col-1];
    
    genvar k;
    generate
        for (k = 0; k < col; k = k + 1) begin : COLUMN
            wire signed [psum_bw-1:0] psum_new = psum_in[(k+1)*psum_bw-1 : k*psum_bw];
            wire signed [psum_bw-1:0] psum_old = l1_read_data[(k+1)*psum_bw-1 : k*psum_bw];

            // Accumulate only when OFIFO valid
            always @(posedge clk or posedge reset) begin
                if (reset)
                    acc_reg[k] <= 0;
                else if (ofifo_valid[k])
                    acc_reg[k] <= psum_old + psum_new;
            end
        
            // Apply ReLU if needed
            wire signed [psum_bw-1:0] relu_val = (relu_enable && acc_reg[k] < 0) ? 0 : acc_reg[k];

            // Pack into output
            assign accum_out[(k+1)*psum_bw-1 : k*psum_bw] = (relu_enable && acc_reg[k] < 0) ? 0 : acc_reg[k];
        end
    endgenerate

    // write back only when valid
    always @(posedge clk or posedge reset) begin
        if (reset)
            write_enable <= 0;
        else
            write_enable <= ofifo_valid;
    end

endmodule
