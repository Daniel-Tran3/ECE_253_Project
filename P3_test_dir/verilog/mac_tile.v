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
    os_write,

    // outputs
    out_s,
    out_e,
    inst_e
);

  parameter bw = 4;
  parameter psum_bw = 16;

  input clk;
  input reset;

  input [bw-1:0] in_w;  // westward input
  input [psum_bw-1:0] in_n;  // northward input
  input [3:0] inst_w;  // instruction input, coming from the west
  // inst[3]: os_flush inst[2]: os_execute, inst[1]:ws_execute, inst[0]: kernel loading

  // southward output
  // may be accumulated value, or a weight
  output [psum_bw-1:0] out_s;
  output [bw-1:0] out_e;  // eastward output
  output [1:0] inst_e;  // instruction eastward passthrough

  // instrucion decode
  wire os_flush;
  wire os_exec;
  wire ws_exec;
  wire ws_kernld;
  assign os_flush  = inst[3];
  assign os_exec   = inst[2];
  assign ws_exec   = inst[1];
  assign ws_kernld = inst[0];

  // write enable control bits
  reg                a_wr;
  reg                b_wr;
  reg                c_wr;

  // data wires for internal registers that aren't so obvious
  reg                c_d;

  reg  [        1:0] inst_q;  // instruction register
  reg  [     bw-1:0] a_q;  // leftward register (activation)
  reg  [     bw-1:0] b_q;  // weight OR northward register
  reg  [psum_bw-1:0] c_q;  // accumulated value
  wire [psum_bw-1:0] mac_out;

  always @(os_flush, os_exec, ws_exec, ws_kernld, b_q, c_q, mac_out, in_n) begin : comb_logic

    // decide what to send southbound (3 way mux ew)
    out_s = b_q;  // emit weight by default, for kernel loading and OS exec
    if (ws_exec) out_s = mac_out;  // emit mac output when executing for WS
    else if (os_flush) out_s = c_q;  // emit c_q when writing for OS

    // control the c (accumulator) register
    c_wr = ws_exec | os_exec | os_write;
    c_d  = os_exec ? mac_out : in_n;

    // control the b (weight) register
    b_wr = ws_kernld | os_exec;

    // while a_q assignment is simple, we still want to gate its write.
    // to maybe conserve power in idle?
    a_wr = ws_exec | os_exec;

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
      inst_q <= 2'b00;
      c_q <= 0; // if OS, c_q must start at 0
    end else begin
      inst_q <= inst_w;
      if (a_wr) a_q <= in_w;
      if (b_wr) b_q <= in_n;
      if (c_wr) c_q <= c_d;  // see comb_logic
    end
  end
endmodule
