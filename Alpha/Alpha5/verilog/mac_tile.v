// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission

// changes for part 3:
// - additional instruction bits. Now, the instructions are:
//     - NOP (duh)
//     - weight-stationary kernel loading
//     - weight-stationary execute
//     - output-stationary execute
//     - output-stationary flush
// - cleaner (hopefully RTL), including:
//     - combinational logic mostly split into its own block
//     - bits specifically for enabling write to a_q, b_q, and c_q
//     - formatting courtesy of verilator
// - muxing between different values to assign to out_s. These values are
// c_q, b_q, and mac_out
// - configurable local accumulation in c_q.


module mac_tile (
    clk,
    reset,

    // inputs
    in_w,
    in_n,
    inst_w,

    // outputs
    out_s,
    out_e,
    inst_e
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter inst_width = 4;

  input clk;
  input reset;

  input [bw-1:0] in_w;  // westward input
  input [psum_bw-1:0] in_n;  // northward input
  input [inst_width-1:0] inst_w;  // instruction input, coming from the west
  // inst[4]: load_psum, inst[3]: os_flush inst[2]: os_execute, inst[1]:ws_execute, inst[0]: kernel loading

  // southward output
  // may be accumulated value, or a weight
  output reg [psum_bw-1:0] out_s;
  output [bw-1:0] out_e;  // eastward output
  output [inst_width-1:0] inst_e;  // instruction eastward passthrough

  // instrucion decode
  wire                  os_flush;
  wire                  os_exec;
  wire                  ws_exec;
  wire                  ws_kernld;
  // write enable control bits
  reg                   a_wr;
  reg                   b_wr;
  reg                   c_wr;

  // data wires for internal registers that aren't so obvious
  reg  [        bw-1:0] a_d;
  reg  [   psum_bw-1:0] c_d;

  reg  [inst_width-1:0] inst_q;  // instruction register
  reg  [        bw-1:0] a_q;  // leftward register (activation)
  reg  [        bw-1:0] b_q;  // weight OR northward register
  reg  [   psum_bw-1:0] c_q;  // accumulated value
  reg                   kern_ld_ready;
  wire [   psum_bw-1:0] mac_out;

  // decoded instruction
  assign os_flush  = inst_q[3];
  assign os_exec   = inst_q[2];
  assign ws_exec   = inst_q[1];
  assign ws_kernld = inst_q[0];


  always @(*) begin : comb_logic

    // decide what to send southbound
    out_s = c_q;  // emit c_q when writing for OS. This also MUST be the default
    // for quirky implementation reasons (this enables a hack that allows c_q
    // to be reset to 0s without a reset signal, useful for output stationary execution)
    if (os_exec) out_s = {{psum_bw - bw{1'b0}}, b_q};  // emit weight by default, for OS exec
    else if (ws_kernld) out_s = {{psum_bw - bw{1'b0}}, a_q};  // if loading kernel in WS, send a_q.
    else if (ws_exec) out_s = mac_out;  // emit mac output when executing for WS

    // control the c (accumulator) register
    c_wr = ws_exec | os_exec | os_flush;
    c_d  = os_exec ? (kern_ld_ready ? 0 : mac_out) : in_n;

    // control the b (weight) register
    b_wr = (ws_kernld && kern_ld_ready) | os_exec;

    a_wr = ws_kernld | ws_exec | os_exec;
    a_d  = ws_kernld ? in_n[3:0] : in_w;

    // inst_q does not require complex logic
  end

  mac #(
      .bw(bw),
      .psum_bw(psum_bw)
  ) mac_instance (
      .a(a_q),
      .b(b_q),
      .c(c_q),

      .out(mac_out)
  );
  assign out_e  = a_q;
  assign inst_e = inst_q;

  always @(posedge clk) begin : seq_logic
    if (reset) begin
      inst_q <= 4'b0000;
      kern_ld_ready <= 1'b1;
      // c_q load 0s from IFIFO via flush.
    end else begin
      inst_q <= inst_w;
      if (ws_kernld | os_exec) kern_ld_ready <= 0;
      if (a_wr) a_q <= a_d;
      if (b_wr) b_q <= in_n[bw-1:0];
      if (c_wr) c_q <= c_d;  // see comb_logic
    end
  end
endmodule
