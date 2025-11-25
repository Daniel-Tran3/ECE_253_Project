// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac (out, a, b, c);

parameter bw = 4;
parameter bw2 = 2;
parameter psum_bw = 16;
parameter psum_bw2 = 8;

output [psum_bw-1:0] out;
input  [bw-1:0] a;  // activation
input  [bw-1:0] b;  // weight
input  [psum_bw-1:0] c;
input act_mode;

wire [2*bw:0] product;
wire [bw+bw2:0] product2_1;
wire [bw+bw2:0] product2_2;
wire [psum_bw-1:0] psum;
wire [psum_bw2-1:0] psum2_1;
wire [psum_bw2-1:0] psum2_2;
wire [bw:0]   a_pad;
wire [bw2:0]   a_pad2_1;
wire [bw2:0]   a_pad2_2;

wire [psum_bw2-1:0] c2_1;
wire [psum_bw2-1:0] c2_2;



wire [psum_bw-1:0] product_expand;
wire [psum_bw2-1:0] product_expand2_1;
wire [psum_bw2-1:0] product_expand2_2;

assign a_pad = {1'b0, a}; // force to be unsigned number
assign product = a_pad * b;
assign product_expand = {{bw{1'b0}}, a} * {{bw{b[bw-1]}}, b}; 

assign a_pad2_1 = {1'b0, a[bw2-1:0]}; // force to be unsigned number
assign product2_1 = a_pad2_1 * b;
assign product_expand2_1 = {{(bw){1'b0}}, a[bw2-1:0]} * {{(bw2){b[bw-1]}}, b}; 

assign psum = {{8{product_expand[2*bw-1]}}, product_expand[2*bw-1:0]} + c;
assign out = psum;

endmodule
