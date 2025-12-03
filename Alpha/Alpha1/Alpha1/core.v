module core (clk, inst, ofifo_valid, D_xmem, sfp_out, xw_mode, reset, sfp_reset,, relu_en, pmem_mode);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;
  
  input clk, reset, sfp_reset;
  input [33:0] inst;
  input [row*bw-1:0] D_xmem;
  input xw_mode; // x if 0, w if 1
  input pmem_mode; // write from OFIFO if 0, write from SFP if 1
  input relu_en;

  output [psum_bw*col-1:0] sfp_out;
  output ofifo_valid;

  wire [row*bw-1:0] l0_input;
  wire [row*bw-1:0] act_sram_output;
  wire [row*bw-1:0] w_sram_output;
  wire [col*psum_bw-1:0] psum_sram_output;
  wire [col*psum_bw-1:0] ofifo_output;
  wire [col*psum_bw-1:0] pmem_input;

  reg  [col*psum_bw-1:0] sfp_out_q;

  assign l0_input = ({row*bw{!xw_mode}} & act_sram_output) |  ({row*bw{xw_mode}} & w_sram_output);

  assign pmem_input = ({col*psum_bw{!pmem_mode}} & ofifo_output) | ({col*psum_bw{pmem_mode}} & sfp_out_q);

  corelet #(.bw(bw), .psum_bw(psum_bw), .row(row), .col(col)) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .ofifo_valid(ofifo_valid),
    .l0_input(l0_input),
    .ofifo_output(ofifo_output),
    .sfp_input(psum_sram_output),
    .sfp_out(sfp_out),
    .xw_mode(xw_mode),
    .sfp_reset(sfp_reset),
    .relu_en(relu_en)
  );


  sram #(.SIZE(2048), .WIDTH(bw*row), .ADD_WIDTH(11)) activation_sram (
    .CLK(clk),
    .WEN(inst[18] | xw_mode),
    .CEN(inst[19] | xw_mode),
    .D(D_xmem),
    .A(inst[17:7]),
    .Q(act_sram_output)
  );

  sram #(.SIZE(2048), .WIDTH(bw*row), .ADD_WIDTH(11)) weight_sram (
    .CLK(clk),
    .WEN(inst[18] | !xw_mode),
    .CEN(inst[19] | !xw_mode),
    .D(D_xmem),
    .A(inst[17:7]),
    .Q(w_sram_output)
  );

  sram #(.SIZE(2048), .WIDTH(psum_bw*col), .ADD_WIDTH(11)) psum_sram (
    .CLK(clk),
    .WEN(inst[31]),
    .CEN(inst[32]),
    .D(pmem_input),
    .A(inst[30:20]),
    .Q(psum_sram_output)
  );

  always @(posedge clk) begin
	  sfp_out_q <= sfp_out;
  end


endmodule
