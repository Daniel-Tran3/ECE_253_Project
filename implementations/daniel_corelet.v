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


  mac_array #(.bw(bw), .psum_bw(psum_bw)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(...),
    .in_w(l0_output), // I'm not sure if this is safe, or needs to be guarded by a control bit to make sure that l0_output is currently in weight loading mode.
    .in_n({psum_bw*col{1'b0}}),
    .inst_w({inst_q[1], inst_q[0]}),
    .valid(ofifo_wr)
  );

  l0 #(.bw(bw), .row(row)) l0_instance (
    .clk(clk),
    .in(l0_input),
    .out(l0_output),
    .rd(inst_q[3]),
    .wr(inst_q[2]),
    .o_full(l0_full),
    .reset(reset),
    .o_ready(l0_ready)
  );

  ofifo #(.col(col), .bw(psum_bw)) ofifo_instance (
    .clk(clk),
    .in(ofifo_input),
    .out(ofifo_output),
    .rd(inst_q[6]),
    .wr(ofifo_wr),
    .o_full(ofifo_full),
    .reset(reset),
    .o_ready(ofifo_ready),
    .o_valid(ofifo_valid)
  );

endmodule
