module corelet.v (clk, reset, inst_q, ofifo_valid);

parameter bw = 4;
parameter psum_bw = 16;
parameter row = 8;
parameter col = 8;

input clk, reset;
input [33:0] inst_q;

output ofifo_valid;

wire [col-1:0] ofifo_wr;


  mac_array #(.bw(bw), .psum_bw(psum_bw)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(...),
    .in_w(...),
    .in_n(...),
    .inst_w({inst_q[1], inst_q[0]}),
    .valid(ofifo_wr)
  );

  l0 #(.bw(bw), .row(row)) l0_instance (
    .clk(clk),
    .in(...),
    .out(...),
    .rd(inst_q[3]),
    .wr(inst_q[2]),
    .o_full(...),
    .reset(reset),
    .o_ready(...)
  );

  ofifo #(.col(col), .bw(bw)) ofifo_instance (
    .clk(clk),
    .in(...),
    .out(...),
    .rd(inst_q[6]),
    .wr(ofifo_wr),
    .o_full(...),
    .reset(reset),
    .o_ready(...),
    .o_valid(ofifo_valid)
  );

endmodule
