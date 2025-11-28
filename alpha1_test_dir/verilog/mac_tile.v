// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e;
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
reg    [1:0]    inst_q;
reg  signed  [bw-1:0] a_q;
reg  signed  [bw-1:0] b_q;
reg  signed  [psum_bw-1:0] c_q;
reg             load_ready_q;


wire is_zero;
assign is_zero = (a_q == 0);
reg signed [bw-1:0] a_gated; //holds the logic stable if input is zero. Informs multiplier ahead not to perform any action.

always @(*) begin
if (reset)
a_gated = 0;
else if (!is_zero)
a_gated = a_q;
end

wire signed [bw:0] a_pad;
//assign a_pad = {a_gated[bw-1],a_gated};
assign a_pad = {1'b0,a_gated};
reg signed [2*bw:0]product;

//assign product = is_zero ? $signed({(2*bw+1){1'b0}}) : (a_pad*b_q);

always @(*)begin
if(is_zero) begin
product = 0;
end else begin
product = a_pad*b_q;
end
end
assign out_s = c_q + product;

assign out_e = a_q;
assign inst_e = inst_q;

always @(posedge clk) begin
if (reset) begin
    inst_q <= 2'b00;
load_ready_q <= 1;
end else begin
inst_q[1] <= inst_w[1];
if (inst_w[0] || inst_w[1]) begin
a_q <= in_w;
end
if (inst_w[0] && load_ready_q) begin
b_q <= in_w;
load_ready_q <= 0;
end
if (load_ready_q == 0) begin
inst_q[0] <= inst_w[0];
 end
c_q <= in_n;
end
end
endmodule
