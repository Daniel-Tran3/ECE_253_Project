// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;

	wire   [(row+1)*2-1:0]       temp_inst_w;
	wire   [row*col-1:0]         temp_valid;
	wire   [row*psum_bw*col-1:0] temp_out_s;
	reg    [(row)*2-1:0]         reg_inst_w;

	assign temp_inst_w[1:0] = inst_w;
	assign temp_inst_w[(col+1)*2-1:2] = reg_inst_w[(col)*2-1:0];

	assign valid = temp_valid[row*col-1:(row-1)*col];
	assign out_s = temp_out_s[row*psum_bw*col-1:(row-1)*psum_bw*col];

	genvar i;
  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw)) mac_row_instance (
      	.clk(clk),
	      .reset(reset),
	      .in_w(in_w[bw*i-1:bw*(i-1)]),
	      .in_n(in_n),
	      .valid(temp_valid[col*i-1:col*(i-1)]),
	      .out_s(temp_out_s[psum_bw*col*i-1:psum_bw*col*(i-1)]),
	      .inst_w(temp_inst_w[2*i-1:2*(i-1)])
      );
  end

  always @ (posedge clk) begin
   // inst_w flows to row0 to row7
   if (reset) begin
     reg_inst_w <= 0;
	 end else begin
		 reg_inst_w[1:0] <= inst_w;
		 reg_inst_w[2*(col)-1:2] <= reg_inst_w[2*(col-1)-1:0];
	 end
  end
endmodule
