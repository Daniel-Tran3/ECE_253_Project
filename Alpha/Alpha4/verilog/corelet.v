module corelet (clk, reset, inst, l0_input, ofifo_valid, ofifo_output, xw_mode, sfp_out, sfp_reset, sfp_input, relu_en);

parameter bw = 4;
parameter psum_bw = 16;
parameter row = 8;
parameter col = 8;

input clk, reset;
input [7:0] inst;
input [row*bw-1:0] l0_input;

input [col*psum_bw-1:0] sfp_input;
input xw_mode;
input sfp_reset;
input relu_en;

output [col*psum_bw-1:0] ofifo_output;
output ofifo_valid;
output [col*psum_bw-1:0] sfp_out;

wire [col-1:0] ofifo_wr;
wire [row*bw-1:0] l0_output;

wire ofifo_ready;
wire ofifo_full;

wire l0_ready;
wire l0_full;

wire [col*psum_bw-1:0] mac_output;
wire [col*psum_bw-1:0] sfp_output;
wire [col-1:0] mac_array_valid_o;
wire [col-1:0] sfp_valid_o;
reg [3*col-1:0] shift_mac_array_valid_o_q;

assign sfp_out = sfp_output;


// MAC array
  mac_array #(.bw(bw), .psum_bw(psum_bw), .row(row), .col(col)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(mac_output),    // output connected to SFU
    .in_w(l0_output), // I'm not sure if this is safe, or needs to be guarded by a control bit to make sure that l0_output is currently in weight loading mode.
    .in_n({psum_bw*col{1'b0}}),
    .inst_w({inst[1], inst[0]}),  // instruction for MAC (kernel loading / execute)
    .valid(mac_array_valid_o)    // output valid for each column
  );

// L0 scratchpad (input activations)
  l0 #(.bw(bw), .row(row)) l0_instance (
    .clk(clk),
    .in(l0_input),
    .out(l0_output),
    .rd(inst[3]),   // L0 read enable
    .wr(inst[2]),   // L0 write enable
    .o_full(l0_full),
    .reset(reset),
    .o_ready(l0_ready),
    .xw_mode(xw_mode)
  );

// SFU: accumulate + relu
  sfp #(.col(col), .psum_bw(psum_bw)) sfp_instance (
      .clk(clk),
      .reset(sfp_reset),
      .in_psum(sfp_input),    // MAC outputs connected to SFU input
      .valid_in({col{inst[7]}}),      // MAC output valid
      .out_accum(sfp_output),   // SFP output (accum + relu) connected to OFIFO input
      .wr_ofifo(ofifo_wr),     // write enable for OFIFO
      .o_valid(sfp_valid),
      .relu_en(relu_en)
    );

  ofifo #(.col(col), .bw(psum_bw)) ofifo_instance (
    .clk(clk),
    .in(mac_output),   // SFU output
    .out(ofifo_output),
    .rd(inst[6]),       // read enable
    //.wr(mac_array_valid_o),        // write enable from SFU
    .wr(shift_mac_array_valid_o_q[1*col-1:0*col]),
    .o_full(ofifo_full),
    .reset(reset),
    .o_ready(ofifo_ready),
    .o_valid(ofifo_valid)
  );

  always @(posedge clk) begin
	shift_mac_array_valid_o_q[col-1:0] <= mac_array_valid_o;
	shift_mac_array_valid_o_q[2*col-1:col] <= shift_mac_array_valid_o_q[col-1:0];
	shift_mac_array_valid_o_q[3*col-1:2*col] <= shift_mac_array_valid_o_q[2*col-1:col];
end
endmodule
