// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission
module mac_row (
    clk,
    out_s,
    in_w,
    in_n,
    valid,
    inst_w,
    reset
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter inst_width = 4;

  input clk, reset;
  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;
  input [bw-1:0] in_w;
  input [inst_width-1:0] inst_w;  // inst[1]:execute, inst[0]: kernel loading
  // inst[3]: os_flush inst[2]: os_execute, inst[1]:ws_execute, inst[0]: kernel loading
  input [psum_bw*col-1:0] in_n;

  wire [(col+1)*bw-1:0] temp_west_inputs;

  // have TWO extra columns to make +2 reads work, used for valid bit
  // computation
  reg [inst_width-1:0] temp_inst_hangover_reg;
  wire [(col+2)*inst_width-1:0] temp_inst_w;

  assign temp_west_inputs[bw-1:0] = in_w;
  assign temp_inst_w[inst_width-1:0] = inst_w;

  assign temp_inst_w[inst_width*(col+2)-1:inst_width*(col+1)] = temp_inst_hangover_reg;

  // changes for part 3:
  // Increased instruction width to accomodate the new instructions

  genvar j;

  genvar i;
  generate
    for (i = 1; i < col + 1; i = i + 1) begin : col_num
      mac_tile #(
          .bw(bw),
          .psum_bw(psum_bw)
      ) mac_tile_instance (
          // clk and reset
          .clk  (clk),
          .reset(reset),

          // inputs
          .in_w  (temp_west_inputs[bw*i-1:bw*(i-1)]),
          .in_n  (in_n[psum_bw*i-1:psum_bw*(i-1)]),
          .inst_w(temp_inst_w[inst_width*i-1:inst_width*(i-1)]),

          // outputs
          .out_s (out_s[psum_bw*i-1:psum_bw*(i-1)]),
          .out_e (temp_west_inputs[bw*(i+1)-1:bw*i]),
          .inst_e(temp_inst_w[inst_width*(i+1)-1:inst_width*i])
      );
    end
  endgenerate

  generate
    for (j = 1; j < col + 1; j = j + 1) begin : valid_loop
      // valid if this column has JUST performed a WS execute,
      // (execute instruction is in inst_q of the PE to this column's right)
      // or IS ABOUT to perform an OS flush. (os_flush instruction is in
      // inst_q of this current column's PE).
      assign valid[j-1] = temp_inst_w[inst_width*(j+1)+1] | temp_inst_w[inst_width*j+3];
    end
  endgenerate

  // the final column does not have a mac tile to register values into it, so
  // we must register the value oureslves.
  always @(posedge clk) begin
    if (reset) temp_inst_hangover_reg <= 0;
    else temp_inst_hangover_reg <= temp_inst_w[inst_width*(col+1)-1:inst_width*(col+0)];
  end

endmodule
