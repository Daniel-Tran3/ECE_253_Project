module core (clk, inst, ofifo1_valid, ofifo2_valid, D1_xmem, D2_xmem, sfp1_out, sfp2_out, xw_mode, reset, sfp_reset, act_mode, relu_en, pmem_mode);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;
  parameter pmem_idx = 11;
  parameter pmem_depth = 1 << pmem_idx;

  input clk, reset, sfp_reset;
  input [33:0] inst;
  input [row*bw-1:0] D1_xmem;
  input [row*bw-1:0] D2_xmem;
  input xw_mode; // x if 0, w if 1
  input pmem_mode; // write from OFIFO if 0, write from SFP if 1
  input act_mode; // 4 bits if 0, 2 bits if 1
  input relu_en;

  output [psum_bw*col-1:0] sfp1_out;
  output [psum_bw*col-1:0] sfp2_out;
  output ofifo1_valid;
  output ofifo2_valid;

  wire [row*bw-1:0] l01_input;
  wire [row*bw-1:0] l02_input;
  wire [row*bw-1:0] act_sram_output;
  wire [row*bw-1:0] w1_sram_output;
  wire [row*bw-1:0] w2_sram_output;
  wire [col*psum_bw-1:0] psum1_sram_output;
  wire [col*psum_bw-1:0] psum2_sram_output;
  wire [col*psum_bw-1:0] ofifo1_output;
  wire [col*psum_bw-1:0] ofifo2_output;
  wire [col*psum_bw-1:0] pmem1_input;
  wire [col*psum_bw-1:0] pmem2_input;

  reg  [col*psum_bw-1:0] sfp1_out_q;
  reg  [col*psum_bw-1:0] sfp2_out_q;

  assign l01_input = ({row*bw{!xw_mode}} & act_sram_output) |  ({row*bw{xw_mode}} & w1_sram_output);
  assign l02_input = ({row*bw{!xw_mode}} & act_sram_output) |  ({row*bw{xw_mode}} & w2_sram_output);

  assign pmem1_input = ({col*psum_bw{!pmem_mode}} & ofifo1_output) | ({col*psum_bw{pmem_mode}} & sfp1_out_q);
  assign pmem2_input = ({col*psum_bw{!pmem_mode}} & ofifo2_output) | ({col*psum_bw{pmem_mode}} & sfp2_out_q);

  corelet #(.bw(bw), .psum_bw(psum_bw), .row(row), .col(col)) corelet1_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst[7:0]),
    .ofifo_valid(ofifo1_valid),
    .l0_input(l01_input),
    .ofifo_output(ofifo1_output),
    .sfp_input(psum1_sram_output),
    .sfp_out(sfp1_out),
    .xw_mode(xw_mode),
    .sfp_reset(sfp_reset),
    .relu_en(relu_en),
    .act_mode(act_mode)
  );

  corelet #(.bw(bw), .psum_bw(psum_bw), .row(row), .col(col)) corelet2_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst[7:0]),
    .ofifo_valid(ofifo2_valid),
    .l0_input(l02_input),
    .ofifo_output(ofifo2_output),
    .sfp_input(psum2_sram_output),
    .sfp_out(sfp2_out),
    .xw_mode(xw_mode),
    .sfp_reset(sfp_reset),
    .relu_en(relu_en),
    .act_mode(act_mode)
  );


  sram #(.SIZE(2048), .WIDTH(bw*row), .ADD_WIDTH(11)) activation_sram (
    .CLK(clk),
    .WEN(inst[8] | xw_mode),
    .CEN(inst[9] | xw_mode),
    .D(D1_xmem),
    .A(inst[22:12]),
    .Q(act_sram_output)
  );

  sram #(.SIZE(2048), .WIDTH(bw*row), .ADD_WIDTH(11)) weight1_sram (
    .CLK(clk),
    .WEN(inst[8] | !xw_mode),
    .CEN(inst[9] | !xw_mode),
    .D(D1_xmem),
    .A(inst[22:12]),
    .Q(w1_sram_output)
  );

  sram #(.SIZE(2048), .WIDTH(bw*row), .ADD_WIDTH(11)) weight2_sram (
    .CLK(clk),
    .WEN(inst[8] | !xw_mode),
    .CEN(inst[9] | !xw_mode),
    .D(D2_xmem),
    .A(inst[22:12]),
    .Q(w2_sram_output)
  );

  sram #(.SIZE(pmem_depth), .WIDTH(psum_bw*col), .ADD_WIDTH(pmem_idx)) psum1_sram (
    .CLK(clk),
    .WEN(inst[10]),
    .CEN(inst[11]),
    .D(pmem1_input),
    .A(inst[23+pmem_idx-1:23]),
    .Q(psum1_sram_output)
  );

  sram #(.SIZE(pmem_depth), .WIDTH(psum_bw*col), .ADD_WIDTH(pmem_idx)) psum2_sram (
    .CLK(clk),
    .WEN(inst[10]),
    .CEN(inst[11]),
    .D(pmem2_input),
    .A(inst[23+pmem_idx-1:23]),
    .Q(psum2_sram_output)
  );


  always @(posedge clk) begin
	  sfp1_out_q <= sfp1_out;
	  sfp2_out_q <= sfp2_out;
  end


endmodule
