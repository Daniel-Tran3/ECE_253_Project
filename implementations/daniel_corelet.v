module corelet.v (clk, reset, inst_q, l0_input, ofifo_valid, ofifo_output);

parameter bw = 4;
parameter psum_bw = 16;
parameter row = 8;
parameter col = 8;

input clk, reset;
input [33:0] inst_q;
input [row*bw-1:0] l0_input;

output [col*psum_bw-1:0] ofifo_output;
output ofifo_valid;

wire [col-1:0] ofifo_wr;
wire [col*psum_bw-1:0] ofifo_input;
wire [row*bw-1:0] l0_output;

wire ofifo_ready;
wire ofifo_full;

wire l0_ready;
wire l0_full;

// MAC array
  mac_array #(.bw(bw), .psum_bw(psum_bw)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(ofifo_input),    // output connected to SFU/OFIFO
    .in_w(l0_output), // I'm not sure if this is safe, or needs to be guarded by a control bit to make sure that l0_output is currently in weight loading mode.
    .in_n({psum_bw*col{1'b0}}),
    .inst_w({inst_q[1], inst_q[0]}),  // instruction for MAC (kernel loading / execute)
    .valid(ofifo_wr)    // output valid for each column
  );

// L0 scratchpad (input activations)
  l0 #(.bw(bw), .row(row)) l0_instance (
    .clk(clk),
    .in(l0_input),
    .out(l0_output),
    .rd(inst_q[3]),   // L0 read enable
    .wr(inst_q[2]),   // L0 write enable
    .o_full(l0_full),
    .reset(reset),
    .o_ready(l0_ready)
  );

// SFU: accumulate + relu
  sfp #(.col(col), .psum_bw(psum_bw)) sfp_instance (
      .clk(clk),
      .reset(reset),
      .in_psum(ofifo_input),    // MAC outputs
      .valid_in(ofifo_wr),      // MAC output valid
      .out_accum(ofifo_input),  // reuse ofifo_input as SFU output
      .wr_ofifo(ofifo_wr),     // write enable for OFIFO
      .o_valid(ofifo_valid)
    );

  ofifo #(.col(col), .bw(psum_bw)) ofifo_instance (
    .clk(clk),
    .in(ofifo_input),   // SFU output
    .out(ofifo_output),
    .rd(inst_q[6]),       // read enable
    .wr(ofifo_wr),        // write enable from SFU
    .o_full(ofifo_full),
    .reset(reset),
    .o_ready(ofifo_ready),
    .o_valid(ofifo_valid)
  );

endmodule
