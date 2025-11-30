module corelet (clk, reset, inst, l0_input, ofifo_valid, ofifo_output, xw_mode, sfp_out, sfp_reset, sfp_input, relu_en, psum_load_enable);

parameter bw = 4;
parameter psum_bw = 16;
parameter row = 8;
parameter col = 8;

input clk, reset;
input [33:0] inst;
input [row*bw-1:0] l0_input;

input [col*psum_bw-1:0] sfp_input;    // connected to psum_sram_output in core.v
input xw_mode;
input sfp_reset;
input relu_en;

input psum_load_enable;

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


wire [col*psum_bw-1:0] psum_fifo_out; // out of the psum L0 (feeds mac in_n)
wire psum_fifo_wr;   // write single-cycle when core presents a new psum-vector
wire psum_fifo_rd;   // read single-cycle when MAC consumes one vector
wire psum_fifo_ready; // L0 can accept a write
wire psum_fifo_full;
wire psum_fifo_valid; // L0 has data available
assign sfp_out = sfp_output;

// MAC array
  mac_array #(.bw(bw), .psum_bw(psum_bw)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(mac_output),    // output connected to SFU
    .in_w(l0_output), // I'm not sure if this is safe, or needs to be guarded by a control bit to make sure that l0_output is currently in weight loading mode.
    .in_n(psum_fifo_out),
    .inst_w({inst[1], inst[0]}),  // now fed from psum_l0
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
      .valid_in({col{inst[33]}}),      // MAC output valid
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

  // PSUM FIFO (L0)
  l0 #(.bw(psum_bw), .row(col)) psum_l0 (
    .clk(clk),
    .in(sfp_input),          // core will present one psum-vector per cycle during load
    .out(psum_fifo_out),     // drives mac_array in_n
    .rd(psum_fifo_rd),       // asserted when MAC wants PSUMs (mac_exec & psum_fifo_valid)
    .wr(psum_fifo_wr),       // asserted during load when psum_l0 o_ready is true
    .o_full(psum_fifo_full),
    .reset(reset),
    .o_ready(psum_fifo_ready),
    .xw_mode(1'b0)           // not using xw_mode for PSUM storage
);


  always @(posedge clk) begin
    if (reset) begin
        shift_mac_array_valid_o_q <= 0;
    end else begin
	    shift_mac_array_valid_o_q[col-1:0] <= mac_array_valid_o;
	    shift_mac_array_valid_o_q[2*col-1:col] <= shift_mac_array_valid_o_q[col-1:0];
	    shift_mac_array_valid_o_q[3*col-1:2*col] <= shift_mac_array_valid_o_q[2*col-1:col];
    end
  end

  reg load_active;      // indicates we are in the phase of loading a PSUM tile from SRAM into psum_l0
  reg [2:0] load_count;   // counts how many vectors have been accepted into psum_l0 so far

  wire mac_exec = inst[33];                // MAC execute bit
  assign psum_fifo_rd = mac_exec; // MAC reads a PSUM vector when executing

  always @(posedge clk) begin
    if (reset) begin
        load_active <= 1'b0;
        load_count <= 0;
    end else begin
        if (psum_load_enable && !load_active) begin
            // start the load sequence, core must present psum sram outputs at sfp_input
            load_active <= 1'b1;
            load_count <= 0;
        end else if (load_active) begin
            // only count a load when psum_l0 accepted the word (when o_ready true, we assert wr this cycle)
            if (psum_fifo_ready) begin
                if (load_count == row - 1) begin
                    // finished loading all row vectors for this tile
                    load_active <= 1'b0;
                    load_count <= 0;
                end else begin
                    load_count <= load_count + 1;
                end
            end
        end
    end
  end

  assign psum_fifo_wr = (load_active & psum_fifo_ready);    // ensures no overflow (if psum_l0 is temporarily full, pause the load until o_ready becomes true)


endmodule
