// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac (out, a, b1, b2, c, act_mode);

parameter bw = 4;
parameter bw2 = 2;
parameter psum_bw = 16;
parameter psum_bw2 = 8;

output signed [psum_bw-1:0] out;
input signed  [bw-1:0] a;  // activation
input signed  [bw-1:0] b1;  // weight
input signed  [bw-1:0] b2;  // weight
input signed  [psum_bw-1:0] c;
input act_mode;


wire signed [bw*2:0] product2_1;
wire signed [psum_bw2-1:0] psum2_1;
wire signed [bw2:0]   a_pad2_1;
wire signed [bw*2:0] product2_2;
wire signed [psum_bw2-1:0] psum2_2;
wire signed [bw2:0]   a_pad2_2;

assign a_pad2_1 = {1'b0, a[bw2-1:0]}; // force to be unsigned number
assign product2_1 = a_pad2_1 * b1;
assign psum2_1 = product2_1;

assign a_pad2_2 = {1'b0, a[bw-1:bw2]}; // force to be unsigned number
assign product2_2 = (a_pad2_2 * b2) << (2*(1-act_mode));
assign psum2_2 = product2_2;

assign out = (psum2_2 + psum2_1 + c);

endmodule
