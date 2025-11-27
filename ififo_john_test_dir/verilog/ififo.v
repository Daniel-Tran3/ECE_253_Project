module ififo (clk, in, out, wr, rd, i_full, reset, i_ready, i_valid);

  parameter col  = 8;
  parameter bw = 16;

  input  clk;
  input  [col-1:0] wr;        // write psum into fifo
  input  rd;                   // read psum from fifo for MAC array
  input  reset;
  input  [col*bw-1:0] in;       // psum data to push
  output [col*bw-1:0] out;      // psum data into MAC array
  output i_full;                // cannot push anymore
  output i_ready;               // can accept more psums
  output i_valid;               // has psums ready to feed into MAC array

  wire [col-1:0] empty;
  wire [col-1:0] full;
  reg  rd_en;
  
  genvar i;

  assign i_ready = !(|full) ;
  assign i_full  = &full ;
  assign i_valid = !(|empty) ;

  generate
  for (i=0; i<col ; i=i+1) begin : col_num
      fifo_depth64 #(.bw(bw)) fifo_inst (
	    .rd_clk(clk),
	    .wr_clk(clk),
	    .rd(rd_en),
	    .wr(wr[i]),
      .o_empty(empty[i]),
      .o_full(full[i]),
	    .in(in[(i+1)*bw-1:i*bw]),
	    .out(out[(i+1)*bw-1:i*bw]),
      .reset(reset));
  end
  endgenerate

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 0;
   end
   else
     rd_en <= rd;
   end

endmodule
