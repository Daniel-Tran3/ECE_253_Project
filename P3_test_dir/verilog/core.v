module core (
    clk,
    inst,
    ofifo_valid,
    D_xmem,
    D_pmem,
    execution_mode,
    ififo_mode,
    sfp_out,
    xw_mode,
    reset,
    sfp_reset,
    relu_en,
    pmem_mode
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  // constants for execution mode

  input clk, reset, sfp_reset;
  input [44:0] inst;
  input [row*bw-1:0] D_xmem;
  input [col*psum_bw-1:0] D_pmem;
  input xw_mode;  // x if 0, w if 1
  input [1:0] pmem_mode;  // write from OFIFO if 0, write from SFP if 1, write
  // from D_pmem (user) if 2.
  input relu_en;
  input execution_mode;  // 0 = weight-stationary, 1 = output-stationary
  input ififo_mode;  // 0 = load from X mem (weights), 1 = load from psum mem

  output [psum_bw*col-1:0] sfp_out;
  output ofifo_valid;

  wire [col*psum_bw-1:0] weight_sram_expanded;
  wire [col*psum_bw-1:0] ififo_input;
  wire [row*bw-1:0] l0_input;
  wire [row*bw-1:0] act_sram_output;
  wire [row*bw-1:0] w_sram_output;
  wire [col*psum_bw-1:0] psum_sram_output;
  wire [col*psum_bw-1:0] ofifo_output;
  wire [col*psum_bw-1:0] pmem_input;

  reg [col*psum_bw-1:0] sfp_out_q;

  assign l0_input = xw_mode ? w_sram_output : act_sram_output;

  genvar i;
  for (i = 0; i < col; i = i + 1) begin
    assign weight_sram_expanded[i*psum_bw+bw-1:i*psum_bw] = w_sram_output[bw*(i+1)-1:bw*i];
    assign weight_sram_expanded[(i+1)*psum_bw-1:i*psum_bw+bw] = {(psum_bw - bw) {1'b0}};
  end
  assign ififo_input = ififo_mode ? psum_sram_output : weight_sram_expanded;
  assign pmem_input  = pmem_mode[1] ? D_pmem : (pmem_mode[0] ? sfp_out_q : ofifo_output);

  corelet #(
      .bw(bw),
      .psum_bw(psum_bw),
      .row(row),
      .col(col)
  ) corelet_instance (
      // clock/reset
      .clk  (clk),
      .reset(reset),

      // inputs
      .inst(inst[33:0]),  // top 11 bits aren't used by corelet
      .ififo_input(ififo_input),
      .l0_input(l0_input),
      .execution_mode(execution_mode),

      // sfp control
      .sfp_input(psum_sram_output),
      .sfp_reset(sfp_reset),
      .relu_en  (relu_en),

      // outputs
      .ofifo_output(ofifo_output),
      .ofifo_valid(ofifo_valid),
      .sfp_out(sfp_out)
  );


  sram #(
      .SIZE(2048),
      .WIDTH(bw * row),
      .ADD_WIDTH(11)
  ) activation_sram (
      .CLK(clk),
      .WEN(inst[18] | xw_mode),
      // In part 3, removed CEN xw_mode gate because we need to read from both
      // activation and weight srams at the same time (at least, if we want
      // pipelined execution).
      // TODO: add separate clock enables for read and write enable
      .CEN(inst[19]),
      .D  (D_xmem),
      .A  (inst[17:7]),
      .Q  (act_sram_output)
  );

  sram #(
      .SIZE(2048),
      .WIDTH(bw * row),
      .ADD_WIDTH(11)
  ) weight_sram (
      .CLK(clk),
      .WEN(inst[18] | !xw_mode),
      // In part 3, removed CEN xw_mode gate because we need to read from both
      // activation and weight srams at the same time (at least, if we want
      // pipelined execution).
      // TODO: add separate clock enables for read and write enable
      .CEN(inst[19]),
      .D  (D_xmem),
      .A  (inst[17:7]),
      .Q  (w_sram_output)
  );

  rw_sram #(
      .SIZE(2048),
      .WIDTH(psum_bw * col),
      .ADD_WIDTH(11)
  ) psum_sram (
      .CLK(clk),
      .D  (pmem_input),
      .Q  (psum_sram_output),
      .CEN(inst[32]),
      .WEN(inst[31]),
      .WA (inst[30:20]),
      .RA (inst[44:34])
  );

  always @(posedge clk) begin
    sfp_out_q <= sfp_out;
  end

endmodule
