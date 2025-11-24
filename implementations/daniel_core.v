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

  wire [row*bw-1:0] l0_input;
  wire [psum*bw-1:0] ofifo_output;

  corelet #(.bw(bw), .psum_bw(psum_bw), .row(row), .col(col)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst_q(inst_q),
    .ofifo_valid(ofifo_valid),
    .l0_input(l0_input),
    .ofifo_output(ofifo_output)
  );


  sram #(.SIZE(36), .WIDTH(bw*row), .ADD_WIDTH(9)) activation_sram (
    .CLK(clk),
    .WEN(inst_q[18]),
    .CEN(inst_q[19]),
    .D(D_xmem),
    .A(inst_q[17:7]),
    .Q(l0_input)
  );

  sram #(.SIZE(8*8*9), .WIDTH(4), .ADD_WIDTH(10)) weight_sram (
    .CLK(clk),
    .WEN(...),
    .CEN(...),
    .D(...),
    .A(...),
    .Q(...)
  );

  sram #(.SIZE(36*9), .WIDTH(psum_bw*col), .ADD_WIDTH(12)) psum_sram (
    .CLK(clk),
    .WEN(inst_q[31]),
    .CEN(inst_q[32]),
    .D(ofifo_output),
    .A(inst_q[30:20]),
    .Q(...)
  );


endmodule
