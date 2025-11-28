module corelet (clk, reset, inst, l0_input, ofifo_valid, ofifo_output, xw_mode, sfp_out, sfp_reset, sfp_input, relu_en, psum_ready);

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

input psum_ready;   // pulse from core when PSUM tile has been fully written to SRAM

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


wire [col*psum_bw-1:0] ififo_out;   // to MAC array in_n
wire [col-1:0] ififo_wr;  // write enable per column
wire ififo_rd;            // read enable (MAC array consumes)
wire ififo_full;
wire ififo_ready;
wire ififo_valid;

assign sfp_out = sfp_output;

// MAC array
  mac_array #(.bw(bw), .psum_bw(psum_bw)) mac_array_instance (
    .clk(clk),
    .reset(reset),
    .out_s(mac_output),    // output connected to SFU
    .in_w(l0_output), // I'm not sure if this is safe, or needs to be guarded by a control bit to make sure that l0_output is currently in weight loading mode.
    .in_n(ififo_out),
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

  // PSUM SRAM to IFIFO to MAC_ARRAY
  ififo #(.col(col), .bw(psum_bw)) ififo_instance (
    .clk(clk),
    .in(sfp_input),      // from psum SRAM
    .out(ififo_out),         // Data output from IFIFO to MAC array (in_n of MAC)
    .rd(ififo_rd),          // MAC read enable (psums read), only asserted if MAC is ready and FIFO has valid data
    .wr(ififo_wr),         // write enable from SRAM valid, set when SRAM has valid data and IFIFO not full
    .i_full(ififo_full),          // FIFO full flag
    .reset(reset),
    .i_ready(ififo_ready),         // FIFO can accept more writes
    .i_valid(ififo_valid)          // FIFO has valid data for MAC array
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

  reg load_active;          // indicates the controller is in the phase of loading a psum tile into IFIFO
  reg [2:0] load_count;     // count how many vectors have been loaded into the IFIFO so far during the current load_active session
  wire mac_exec = inst[33];     // inst[33] (MAC execute) and by IFIFO having valid data.
  assign ififo_rd = mac_exec & ififo_valid; // MAC pulls when executing and IFIFO has data

  always @(posedge clk) begin   // Start loading when psum_ready pulse is seen
    if (reset) begin
        load_active <= 1'b0;
        load_count <= 0;
    end else begin
        if (psum_ready && !load_active) begin   // start load when tile_done pulse arrives
            load_active <= 1'b1;
            load_count <= 0;
        end else if (load_active) begin   // only increment count when IFIFO actually accepts a word 
            if (ififo_ready) begin      // only increment count when IFIFO actually accepts a word
                // When ififo_ready is true we assert wr for that cycle
                if (load_count == row - 1) begin
                    load_active <= 1'b0;  // finished loading the tile
                    load_count <= 0;
                end else begin
                    load_count <= load_count + 1;   // continue loading
                end
            end
        end
    end
  end

  assign ififo_wr = {col{ (load_active & ififo_ready) }};


endmodule
