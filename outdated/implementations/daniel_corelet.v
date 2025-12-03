module corelet.v (clk, reset, inst_q, l0_input, ofifo_valid, ofifo_output);

parameter bw = 4;
parameter psum_bw = 16;
parameter row = 8;
parameter col = 8;

input clk, reset;
input [33:0] inst_q;
input [row*bw-1:0] l0_input;

// L1 interface (external)
input  [col*psum_bw-1:0] l1_read_data;      // data read from external L1
output [col*psum_bw-1:0] l1_write_data;     // data to write back into L1
output [col-1:0] l1_write_enable;   // one bit per column to control L1 write

// OFIFO outputs
output [col*psum_bw-1:0] ofifo_output;
output ofifo_valid;

// Internal wires
wire [col-1:0] mac_valid;                   // per-column valid from MAC array
wire [col*psum_bw-1:0] mac_output;          // staggered psums from MAC array (write into OFIFO)
wire [col*psum_bw-1:0] ofifo_input;         // connected to MAC outputs
wire [col-1:0] ofifo_wr;                   // per-column write enables into OFIFO

wire ofifo_ready;
wire ofifo_full;

wire l0_ready;
wire l0_full;

assign ofifo_input = mac_output;
assign ofifo_wr    = mac_valid;

// MAC array
  mac_array #(.bw(bw), .psum_bw(psum_bw)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(mac_output),    // staggered psums from last row (to OFIFO)
    .in_w(l0_output), // I'm not sure if this is safe, or needs to be guarded by a control bit to make sure that l0_output is currently in weight loading mode.
    .in_n({psum_bw*col{1'b0}}), // no feedback psum into MAC (L1 handled externally)
    .inst_w({inst_q[1], inst_q[0]}),  // instruction for MAC (kernel loading / execute)
    .valid(mac_valid)      // per-column valid signals (for OFIFO writes)
  );

// L0 scratchpad (input activations)
  l0 #(.bw(bw), .row(row)) l0_instance (
    .clk(clk),
    .in(l0_input),
    .out(l0_output),
    .rd(inst_q[3]),   // L0 read enable
    .wr(inst_q[2]),   // L0 write enable
    .o_full(l0_full),
    .reset(reset),
    .o_ready(l0_ready)
  );

// SFU: accumulate + relu
  wire [col*psum_bw-1:0] sfp_accum_out;
  wire [col-1:0] sfp_write_enable;

  sfp #(.col(col), .psum_bw(psum_bw)) sfp_instance (
    .clk(clk),
    .reset(reset),
    .psum_in(mac_output),        // MAC outputs
    .l1_read_data(l1_read_data), // previous partial sums from L1
    .ofifo_valid(mac_valid),     // valid signals from MAC (per-column)
    .relu_enable(inst_q[6]),     // control signal for final pass
    .accum_out(sfp_accum_out),   // output after accumulation + ReLU
    .write_enable(sfp_write_enable) // write enable per column
  );

// OFIFO
  ofifo #(.col(col), .bw(psum_bw)) ofifo_instance (
    .clk(clk),
    .in(sfp_accum_out),     // take SFP output
    .out(ofifo_output),     // aligned row out
    .rd(inst_q[6]),         // read enable
    .wr(sfp_write_enable),  // use SFP write enable
    .o_full(ofifo_full),
    .reset(reset),
    .o_ready(ofifo_ready),
    .o_valid(ofifo_valid)
);

// L1 write
  assign l1_write_data   = sfp_accum_out;
  assign l1_write_enable = sfp_write_enable;

endmodule
