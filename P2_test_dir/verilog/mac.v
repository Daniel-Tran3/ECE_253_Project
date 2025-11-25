// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac (out, a, b, c);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out;
input  [bw-1:0] a;  // activation
input  [bw-1:0] b;  // weight
input  [psum_bw-1:0] c;


wire [2*bw:0] product;
wire [psum_bw-1:0] psum;
wire [bw:0]   a_pad;
wire [psum_bw-1:0] product_expand;

assign a_pad = {1'b0, a}; // force to be unsigned number
assign product = a_pad * b;
assign product_expand = {{bw{1'b0}}, a} * {{bw{b[bw-1]}}, b}; 

assign psum = {{8{product_expand[2*bw-1]}}, product_expand[2*bw-1:0]} + c;
assign out = psum;

endmodule
