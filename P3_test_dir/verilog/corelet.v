module corelet (
    clk,
    reset,
    inst,
    ififo_input,
    l0_input,
    ofifo_valid,
    ofifo_output,
    execution_mode,
    sfp_out,
    sfp_reset,
    sfp_input,
    relu_en
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter row = 8;
  parameter col = 8;

  // constants for execution mode
  localparam reg OS = 0;  // output stationary
  localparam reg WS = 1;  // weight-stationary

  input clk, reset;
  input [33:0] inst;
  input [col*bw-1:0] ififo_input;
  input [row*bw-1:0] l0_input;
  input execution_mode;

  input [col*psum_bw-1:0] sfp_input;
  input sfp_reset;
  input relu_en;

  output [col*psum_bw-1:0] ofifo_output;
  output ofifo_valid;
  output [col*psum_bw-1:0] sfp_out;

  wire [col-1:0] ofifo_wr;
  wire [row*bw-1:0] l0_output;

  wire ofifo_ready;
  wire ofifo_full;

  wire l0_ready;
  wire l0_full;

  // ififo
  wire [col*psum_bw-1:0] ififo_output;
  wire ififo_ready;
  wire ififo_full;

  // mac array
  wire [col*bw-1:0] mac_north_input;

  wire [col*psum_bw-1:0] mac_output;
  wire [col*psum_bw-1:0] sfp_output;
  wire [col-1:0] mac_array_valid_o;
  wire [col-1:0] sfp_valid_o;
  reg [3*col-1:0] shift_mac_array_valid_o_q;

  // instruction decode values
  wire acc_q;
  wire CEN_pmem_q;
  wire WEN_pmem_q;
  wire A_pmem_q;
  wire CEN_xmem_q;
  wire WEN_xmem_q;
  wire A_xmem_q;
  wire ofifo_rd_q;
  wire ififo_wr_q;
  wire ififo_rd_q;
  wire l0_rd_q;
  wire l0_wr_q;
  wire execute_q;
  wire load_q;

  localparam reg OS = 0;  // output stationary
  localparam reg WS = 1;  // weight-stationary

  assign sfp_out = sfp_output;

  // changes for part 3:
  // - have ififo draw from weight sram (need an extra input for that, called
  // ififo_in)
  // TODO:
  // - if acc (or "negate shift out") bit is LOW, downward shift accumulated
  // values instead of weights.

  // decode logic (just a simple mapping)
  assign acc_q = inst[33];
  assign CEN_pmem_q = inst[32];
  assign WEN_pmem_q = inst[31];
  assign A_pmem_q = inst[30:20];
  assign CEN_xmem_q = inst[19];
  assign WEN_xmem_q = inst[18];
  assign A_xmem_q = inst[17:7];
  assign ofifo_rd_q = inst[6];
  assign ififo_wr_q = inst[5];
  assign ififo_rd_q = inst[4];
  assign l0_rd_q = inst[3];
  assign l0_wr_q = inst[2];
  assign execute_q = inst[1];
  assign load_q = inst[0];

  // TODO: multiplex between straight 0s (for WS execute) or IFIFO (WS
  // kernel load or OS execute)
  assign mac_north_input =  /* TODO */ 0 ? {psum_bw * col{1'b0}} : ififo_output;


  // MAC array
  mac_array #(
      .bw(bw),
      .psum_bw(psum_bw)
  ) mac_array_instance (
      .clk  (clk),
      .reset(reset),
      .out_s(mac_output),
      .in_w (l0_output),

      .in_n(mac_north_input),

      .inst_w({
        execute_q, load_q
      }),  // instruction for MAC (kernel loading / execute)  // TODO: add extra bits for OS exec/flush
      .valid(mac_array_valid_o)  // output valid for each column
  );

  // L0 scratchpad (input activations)
  l0 #(
      .bw (bw),
      .row(row)
  ) l0_instance (
      .clk  (clk),
      .reset(reset),

      .in (l0_input),
      .out(l0_output),

      .rd(l0_rd_q),  // L0 read enable
      .wr(l0_wr_q),  // L0 write enable

      .o_full (l0_full),
      .o_ready(l0_ready),
  );

  // IFIFO (weights for kernel loading or output-stationary execute)
  l0 #(
      .bw (bw),
      .row(col)
  ) ififo (
      .clk  (clk),
      .reset(reset),

      .in (ififo_input),
      .out(ififo_output),

      .rd(ififo_rd_q),  // ififo read enable
      .wr(ififo_wr_q),  // L0 write enable

      .o_full (  /* TODO */),
      .o_ready(  /* TODO */),
  );

  // SFU: accumulate + relu
  sfp #(
      .col(col),
      .psum_bw(psum_bw)
  ) sfp_instance (
      .clk      (clk),
      .reset    (sfp_reset),
      .in_psum  (sfp_input),        // MAC outputs connected to SFU input
      .valid_in ({col{inst[33]}}),  // MAC output valid
      .out_accum(sfp_output),       // SFP output (accum + relu) connected to OFIFO input
      .wr_ofifo (ofifo_wr),         // write enable for OFIFO
      .o_valid  (sfp_valid),
      .relu_en  (relu_en)
  );

  ofifo #(
      .col(col),
      .bw (psum_bw)
  ) ofifo_instance (
      .clk    (clk),
      .in     (mac_output),                                // SFU output
      .out    (ofifo_output),
      .rd     (ofifo_rd_q),                                // read enable
      .wr     (shift_mac_array_valid_o_q[1*col-1:0*col]),
      .o_full (ofifo_full),
      .reset  (reset),
      .o_ready(ofifo_ready),
      .o_valid(ofifo_valid)
  );

  always @(posedge clk) begin
    shift_mac_array_valid_o_q[col-1:0] <= mac_array_valid_o;
    shift_mac_array_valid_o_q[2*col-1:col] <= shift_mac_array_valid_o_q[col-1:0];
    shift_mac_array_valid_o_q[3*col-1:2*col] <= shift_mac_array_valid_o_q[2*col-1:col];
  end
endmodule
