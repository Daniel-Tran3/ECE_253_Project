// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (
    clk,
    reset,
    out_s,
    in_w,
    in_n,
    inst_w,
    valid
);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;
  parameter inst_width = 4;

  input clk, reset;

  // inst[3]: OS flush, inst[2]: OS execute, inst[1]:WS execute, inst[0]: WS kernel loading
  input [inst_width-1:0] inst_w;
  input [row*bw-1:0] in_w;
  input [psum_bw*col-1:0] in_n;

  output [psum_bw*col-1:0] out_s;
  output [col-1:0] valid;


  reg    [inst_width*row-1:0] inst_w_temp;
  wire   [psum_bw*col*(row+1)-1:0] temp;
  wire   [row*col-1:0] valid_temp;


  genvar i;

  assign out_s = temp[psum_bw*col*9-1:psum_bw*col*8];
  assign temp[psum_bw*col*1-1:psum_bw*col*0] = 0;
  assign valid = valid_temp[row*col-1:row*col-8];

  generate

    for (i = 1; i < row + 1; i = i + 1) begin : row_num
      mac_row #(
          .bw(bw),
          .psum_bw(psum_bw)
      ) mac_row_instance (
          .clk(clk),
          .reset(reset),
          .in_w(in_w[bw*i-1:bw*(i-1)]),
          .inst_w(inst_w_temp[inst_width*i-1:inst_width*(i-1)]),
          .in_n(temp[psum_bw*col*i-1:psum_bw*col*(i-1)]),
          .valid(valid_temp[col*i-1:col*(i-1)]),
          .out_s(temp[psum_bw*col*(i+1)-1:psum_bw*col*(i)])
      );
    end
  endgenerate

  always @(posedge clk) begin

    //valid <= valid_temp[row*col-1:row*col-8];
    // inst_w_temp[1:0]   <= inst_w;
    // inst_w_temp[3:2]   <= inst_w_temp[1:0];
    // inst_w_temp[5:4]   <= inst_w_temp[3:2];
    // inst_w_temp[7:6]   <= inst_w_temp[5:4];
    // inst_w_temp[9:8]   <= inst_w_temp[7:6];
    // inst_w_temp[11:10] <= inst_w_temp[9:8];
    // inst_w_temp[13:12] <= inst_w_temp[11:10];
    // inst_w_temp[15:14] <= inst_w_temp[13:12];
    inst_w_temp[inst_width-1:0] <= inst_w;
    for (integer i = 1; i < row; i = i + 1) begin
      // we only unconditionally shift the low 3 bits of instructions
      inst_w_temp[inst_width*(i+1)-2:inst_width*i] <= inst_w_temp[inst_width*i-2:inst_width*(i-1)];
      // instantly propagate the os-flush bit to all rows' instructions if it
      // is set in inst_w. Rely on the programmer to avoid instruction one-hot
      // encoding contention. Otherwise, shift up as normal
      inst_w_temp[inst_width*(i+1)-1] = inst_w[3] ? 1'b1 : inst_w_temp[inst_width*i-1];
    end
  end



endmodule
