module sfp (clk, reset, psum_in, l1_read_data, valid_in, relu_enable, accum_out, write_enable);
    parameter col = 8;
    parameter psum_bw = 16;

    input  clk;
    input  reset;
    input  [psum_bw*col-1:0]  psum_in;  // psums from OFIFO aligned
    input  [psum_bw*col-1:0]  l1_read_data;  // old partial sums from L1
    input  [col-1:0] valid_in;          // valid flags from OFIFO
    input  relu_enable;         // only high on FINAL pass
    output wire [psum_bw*col-1:0]  accum_out;    // updated sum
    output reg [col-1:0] write_enable;  // writeback enable for L1

    genvar k;
    generate
        for (k = 0; k < col; k = k + 1) begin : COLUMN
            wire signed [psum_bw-1:0] psum_new = psum_in[(k+1)*psum_bw-1 : k*psum_bw];
            wire signed [psum_bw-1:0] psum_old = l1_read_data[(k+1)*psum_bw-1 : k*psum_bw];

            // pure combinational accumulation
            wire signed [psum_bw-1:0] accum_val = psum_old + psum_new;

            // ReLU (on last pass only)
            wire signed [psum_bw-1:0] relu_val = (relu_enable && accum_val < 0) ? 0 : accum_val;

            assign accum_out[(k+1)*psum_bw-1 : k*psum_bw] = relu_val;
        end
    endgenerate

    always @(posedge clk or posedge reset) begin
        if (reset)
            write_enable <= 0;
        else
            write_enable <= valid_in;
    end

endmodule
