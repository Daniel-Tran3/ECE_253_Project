module core (clk, inst_q, ofifo_valid, D_xmem, sfp_out, reset);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;
  
  input clk, reset;
  input [33:0] inst_q;
  input [row*bw-1:0] D_xmem;

  output [psum_bw*col-1:0] sfp_out;
  output ofifo_valid;

endmodule
