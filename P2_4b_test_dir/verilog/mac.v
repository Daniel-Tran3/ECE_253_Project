// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac (out, a, b, c, act_mode);

parameter bw = 4;
parameter bw2 = 2;
parameter psum_bw = 24;
parameter psum_bw2 = 12;

output signed [psum_bw-1:0] out;
input signed  [bw-1:0] a;  // activation
input signed  [bw-1:0] b;  // weight
input signed  [psum_bw-1:0] c;
input act_mode;

wire signed [2*bw:0] product;
wire signed [psum_bw-1:0] psum;
wire signed [bw:0]   a_pad;

wire signed [bw+bw2:0] product2_1;
wire signed [psum_bw2-1:0] psum2_1;
wire signed [bw2:0]   a_pad2_1;
wire signed [bw+bw2:0] product2_2;
wire signed [psum_bw2-1:0] psum2_2;
wire signed [bw2:0]   a_pad2_2;

wire signed [psum_bw2-1:0] c2_1;
wire signed [psum_bw2-1:0] c2_2;

assign c2_1 = c[psum_bw2-1:0];
assign c2_2 = c[psum_bw-1:psum_bw2];

assign a_pad = {1'b0, a}; // force to be unsigned number
assign product = a_pad * b;
assign psum = product + c;


assign a_pad2_1 = {1'b0, a[bw2-1:0]}; // force to be unsigned number
assign product2_1 = a_pad2_1 * b;
assign psum2_1 = product2_1 + c2_1;

assign a_pad2_2 = {1'b0, a[bw-1:bw2]}; // force to be unsigned number
assign product2_2 = a_pad2_2 * b;
assign psum2_2 = product2_2 + c2_2;

assign out = act_mode ? {psum2_2, psum2_1} : psum;

endmodule
