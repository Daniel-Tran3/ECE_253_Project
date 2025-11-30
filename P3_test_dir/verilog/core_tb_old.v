// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns / 1ps

module core_tb;

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter len_kij = 9;
  parameter len_onij = 16;
  parameter col = 8;
  parameter row = 8;
  parameter len_nij = 36;
  parameter row_idx = 5;
  parameter col_idx = 1;
  parameter o_ni_dim = 4;
  parameter a_pad_ni_dim = 6;
  parameter ki_dim = 3;
  parameter inst_width = 4;

  parameter xmem_words = 2048;
  parameter pmem_words = 2048;

  reg clk = 0;
  reg reset = 1;
  reg sfp_reset = 1;

  wire [33:0] inst_q;

  // CTRL BITS ------------------------------------------------------------------------
  reg [1:0] pmem_mode = 0;  // write from OFIFO if 0, write from SFP if 1
  reg [inst_width-1:0] inst_w;
  // xmem memory ctrl
  reg xw_mode = 0;  // x if 0, w if 1
  reg [bw*row-1:0] D_xmem;
  reg CEN_xmem = 1;
  reg WEN_xmem = 1;
  reg [10:0] A_xmem = 0;
  // psum memory ctrl
  reg CEN_pmem = 1;
  reg WEN_pmem = 1;
  reg [psum_bw*row-1:0] D_pmem = 0;
  reg [10:0] A_pmem = 0;
  // fifo ctrl
  reg ofifo_rd;
  reg ififo_wr;
  reg ififo_rd;
  reg ififo_mode = 0;  // 0 = load from X mem (weights), 1 = load from psum mem
  reg l0_rd;
  reg l0_wr;
  // pe ctrl
  reg execute;
  reg load;
  reg acc = 0;
  reg relu_en = 0;
  reg execution_mode = 0;  // 0=WS, 1=OS

  // control bit registers/buffers
  reg [1:0] pmem_mode_q = 0;
  reg [inst_width-1:0] inst_w_q = 0;
  reg xw_mode_q = 0;
  reg [bw*row-1:0] D_xmem_q = 0;
  reg CEN_xmem_q = 1;
  reg WEN_xmem_q = 1;
  reg [10:0] A_xmem_q = 0;
  reg CEN_pmem_q = 1;
  reg WEN_pmem_q = 1;
  reg [psum_bw*row-1:0] D_pmem_q = 0;
  reg [10:0] A_pmem_q = 0;
  reg ofifo_rd_q = 0;
  reg ififo_wr_q = 0;
  reg ififo_rd_q = 0;
  reg ififo_mode_q = 0;
  reg l0_rd_q = 0;
  reg l0_wr_q = 0;
  reg execute_q = 0;
  reg load_q = 0;
  reg acc_q = 0;
  reg relu_en_q = 0;
  reg execution_mode_q = 0;

  reg [10:0] A_pmem_sfp = 0;
  reg [psum_bw*col-1:0] answer;

  integer nij = 0;
  reg post_ex = 0;


  reg [8*30:1] stringvar;
  reg [8*30:1] w_file_name;
  reg [8*30:1] psum_file_name;
  wire ofifo_valid;
  wire [col*psum_bw-1:0] sfp_out;

  // reference data for verification
  reg [bw*row-1:0] amem_sim[xmem_words-1:0];
  reg [bw*row-1:0] wmem_sim[xmem_words-1:0];
  reg [psum_bw*col-1:0] pmem_sim[pmem_words-1:0];
  // TODO: add an extra dimension to pe_weights for output tiles
  reg [bw-1:0] pe_weights_sim[row-1:0][col-1:0];
  wire [bw-1:0] pe_weights_probe[row-1:0][col-1:0];
  // divides D_xmem into its constituent activations/weights
  // since we cannot use non-constant part select expressions (D_xmem[j:0])
  // during the initial block, we must generate the division beforehand.
  wire [bw-1:0] D_xmem_fragments[row-1:0];

  integer x_file, x_scan_file;  // file_handler
  integer w_file, w_scan_file;  // file_handler
  integer acc_file, acc_scan_file;  // file_handler
  integer out_file, out_scan_file;  // file_handler
  integer psum_file, psum_scan_file;  // file_handler
  integer captured_data;
  integer t, i, j, k, kij;
  reg [col-1:0] m = 0;
  integer error;

  assign inst_q[33] = acc_q;
  assign inst_q[32] = CEN_pmem_q;
  assign inst_q[31] = WEN_pmem_q;
  assign inst_q[30:20] = A_pmem_q;
  assign inst_q[19] = CEN_xmem_q;
  assign inst_q[18] = WEN_xmem_q;
  assign inst_q[17:7] = A_xmem_q;
  assign inst_q[6] = ofifo_rd_q;
  assign inst_q[5] = ififo_wr_q;
  assign inst_q[4] = ififo_rd_q;
  assign inst_q[3] = l0_rd_q;
  assign inst_q[2] = l0_wr_q;
  assign inst_q[1] = execute_q;
  assign inst_q[0] = load_q;

  genvar gr, gc;

  // testbench probes
  for (gr = 0; gr < row; gr = gr + 1) begin : gen_pe_weights_probe_row
    for (gc = 0; gc < row; gc = gc + 1) begin : gen_pe_weights_probe_col
      assign pe_weights_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.b_q;
    end
  end

  for (gr = 0; gr < row; gr = gr + 1) begin : gen_D_xmem_fragments
    assign D_xmem_fragments[gr] = D_xmem[bw*(gr+1)-1:bw*gr];
  end


  core #(
      .bw (bw),
      .col(col),
      .row(row)
  ) core_instance (
      .clk  (clk),
      .reset(reset),

      // inputs
      .inst(inst_q),
      .D_xmem(D_xmem_q),
      .D_pmem(D_pmem_q),
      .execution_mode(execution_mode_q),
      .ififo_mode(ififo_mode_q),
      .xw_mode(xw_mode_q),
      .pmem_mode(pmem_mode_q),
      .relu_en(relu_en_q),
      .sfp_reset(sfp_reset),

      // outputs
      .ofifo_valid(ofifo_valid),
      .sfp_out(sfp_out)
  );

  initial begin

    pmem_mode = 0;
    inst_w    = 0;

    D_xmem    = 0;
    CEN_xmem  = 1;
    WEN_xmem  = 1;

    D_pmem    = 0;
    A_xmem    = 0;
    ofifo_rd  = 0;
    ififo_wr  = 0;
    ififo_rd  = 0;
    l0_rd     = 0;
    l0_wr     = 0;
    execute   = 0;
    load      = 0;

    $dumpfile("core_tb.vcd");
    $dumpvars(0, core_tb);

    //x_file = $fopen("activation_tile0.txt", "r");
    x_file = $fopen("activation.txt", "r");
    // Following three lines are to remove the first three comment lines of the file
    x_scan_file = $fscanf(x_file, "%s", captured_data);
    x_scan_file = $fscanf(x_file, "%s", captured_data);
    x_scan_file = $fscanf(x_file, "%s", captured_data);

    //////// Reset /////////
    #0.5 clk = 1'b0;
    reset = 1;
    sfp_reset = 1;
    #0.5 clk = 1'b1;

    for (i = 0; i < 10; i = i + 1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0;
    reset = 0;
    xw_mode = 0;
    sfp_reset = 0;
    #0.5 clk = 1'b1;

    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;
    /////////////////////////

    /////// Activation data writing to memory ///////
    //for (t=0; t<len_nij; t=t+1) begin

    for (t = 0; t < len_nij; t = t + 1) begin
      #0.5 clk = 1'b0;
      // xw_mode=0 is the default, but we want to be explicit that we are
      // writing to activations
      xw_mode = 0;
      x_scan_file = $fscanf(x_file, "%32b", D_xmem);
      WEN_xmem = 0;
      CEN_xmem = 0;
      if (t > 0) A_xmem = A_xmem + 1;
      //$display("%d", core_instance.activation_sram.A);
      //$display("%b", core_instance.activation_sram.D);
      #0.5 clk = 1'b1;

      // fill in the expected value in xmem_sim
      if (t == 7) $display("%d\n", D_xmem);
      amem_sim[A_xmem] = D_xmem;
    end

    #0.5 clk = 1'b0;
    WEN_xmem = 1;
    CEN_xmem = 1;
    A_xmem   = 0;

    // verify activations are written to SRAM
    //$display("%d", core_instance.activation_sram.A);
    //$display("%b", core_instance.activation_sram.D);
    for (t = 0; t < len_nij; t = t + 1) begin
      if (amem_sim[t] != core_instance.activation_sram.memory[t]) begin
        $display("Unexpected value in activation SRAM!\n At address %d, expected %h but got %h", t,
                 amem_sim[t], core_instance.activation_sram.memory[t]);
        $finish;
      end
    end

    #0.5 clk = 1'b1;

    $fclose(x_file);
    /////////////////////////////////////////////////

    // ZERO OUT PSUMS IN MEMORY ----------------------------------------------
    // for each output tile (currently assume there is only 1), (row chunk in sram)
    // for each nij value (row in sram),
    // write 0s to that row
    #0.5 clk = 1'b0;
    A_pmem   = 0;
    WEN_pmem = 0;
    CEN_pmem = 0;
    D_pmem   = 0;
    // implicitly, we are operating on tile 0.
    // TODO: wrap in for loop to operate on multiple output tiles
    for (t = 0; t < len_nij; t = t + 1) begin
      if (t > 0) A_pmem = A_pmem + 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
      pmem_sim[A_pmem] = D_pmem;
    end
    // restore values modified for this operation
    WEN_pmem = 1;
    CEN_pmem = 1;

    //verify that 0s are written to all necessary rows in psum sram
    for (t = 0; t < len_nij; t = t + 1) begin
      if (pmem_sim[t] != core_instance.psum_sram.memory[t]) begin
        $display("Unexpected value in psum SRAM!\n At address %d, expected %h but got %h", t,
                 pmem_sim[t], core_instance.psum_sram.memory[t]);
        $finish;
      end
    end

    // PARTIAL SUMS OVER INPUT CHANNELS AND KIJ ---------------------------------------
    for (kij = 0; kij < 9; kij = kij + 1) begin  // kij loop
      $display("Kij %d\n", kij);
      case (kij)
        0: w_file_name = "weight_0.txt";
        1: w_file_name = "weight_1.txt";
        2: w_file_name = "weight_2.txt";
        3: w_file_name = "weight_3.txt";
        4: w_file_name = "weight_4.txt";
        5: w_file_name = "weight_5.txt";
        6: w_file_name = "weight_6.txt";
        7: w_file_name = "weight_7.txt";
        8: w_file_name = "weight_8.txt";
      endcase
      case (kij)
        0: psum_file_name = "psum_0.txt";
        1: psum_file_name = "psum_1.txt";
        2: psum_file_name = "psum_2.txt";
        3: psum_file_name = "psum_3.txt";
        4: psum_file_name = "psum_4.txt";
        5: psum_file_name = "psum_5.txt";
        6: psum_file_name = "psum_6.txt";
        7: psum_file_name = "psum_7.txt";
        8: psum_file_name = "psum_8.txt";
      endcase

      // NOTE: instead of writing all kijs before summing them (sequential
      // style), continuously perform the summation on the same psum elements.
      // A_pmem[9:6] = kij;
      // A_pmem[5:0] = 0;


      w_file = $fopen(w_file_name, "r");
      // Following three lines are to remove the first three comment lines of the file
      w_scan_file = $fscanf(w_file, "%s", captured_data);
      w_scan_file = $fscanf(w_file, "%s", captured_data);
      w_scan_file = $fscanf(w_file, "%s", captured_data);

      #0.5 clk = 1'b0;
      reset = 1;
      #0.5 clk = 1'b1;

      for (i = 0; i < 10; i = i + 1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0;
      reset = 0;
      #0.5 clk = 1'b1;

      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;

      /////// Kernel data writing to memory ///////

      A_xmem  = 11'b00000000000;
      xw_mode = 1;  // write to weight memory


      for (t = 0; t < row; t = t + 1) begin
        // #col7row7[msb-lsb],col6row7[msb-lst],....,col0row7[msb-lst]#
        // #col7row6[msb-lsb],col6row6[msb-lst],....,col0row6[msb-lst]#
        // #................#
        w_scan_file = $fscanf(w_file, "%32b", D_xmem);
        WEN_xmem = 0;
        CEN_xmem = 0;
        if (t > 0) begin
          A_xmem = A_xmem + 1;
        end
        // pump wire data into registered inputs
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        // update simulation values
        wmem_sim[t] = D_xmem;
        for (j = 0; j < col; j = j + 1) begin
          // The first row output by the IFIFO is the bottom row of PE
          // weights; the last row output by the IFIFO is the top row of
          // PE weights.
          pe_weights_sim[row-1-t][j] = D_xmem_fragments[j];
        end

        $display("pe_weights for verification at row %d: %h %h %h %h %h %h %h %h", row - 1 - t,
                 pe_weights_sim[row-1-t][0], pe_weights_sim[row-1-t][1], pe_weights_sim[row-1-t][2],
                 pe_weights_sim[row-1-t][3], pe_weights_sim[row-1-t][4], pe_weights_sim[row-1-t][5],
                 pe_weights_sim[row-1-t][6], pe_weights_sim[row-1-t][7]);
      end

      // restore core input registers to default values
      // simultaneously complete the last SRAM write
      WEN_xmem = 1;
      CEN_xmem = 1;
      A_xmem   = 0;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;

      // verify that kernel data has been written
      $display("Verifying that wmem has been written to correctly");
      for (t = 0; t < row; t = t + 1) begin
        // $display("%d %d", wmem_sim[t], core_instance.weight_sram.memory[t]);
        if (wmem_sim[t] != core_instance.weight_sram.memory[t]) begin
          $display("Unexpected value in weight SRAM!\n At address %d, expected %d but got %d", t,
                   wmem_sim[t], core_instance.weight_sram.memory[t]);
          $finish;
        end
      end
      /////////////////////////////////////


      /////// Kernel data writing to IFIFO ///////
      // TODO: in progress (does not pass test case)
      // a pipelined kernel write has a length of 2.
      // weight sram read must start one cycle before ififo
      // read starts, and must end a cycle before ififo read ends.
      // set ctrl signals
      A_xmem  = 11'b00000000000;
      xw_mode = 1;  // read out from weight sram
      // read from weight memory. Must do this one cycle before reading IFIFO
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;

      ififo_mode = 0;  // IFIFO should copy values from weights
      ififo_wr   = 1;
      // add 1 to iterations for pipeline
      for (t = 0; t < col + 1; t = t + 1) begin
        if (1 <= t && t < col) A_xmem = A_xmem + 1;

        // pipeline weight read
        if (0 <= t && t < col) CEN_xmem = 0;
        else CEN_xmem = 1;

        // pipeline ififo read
        if (1 <= t && t < col + 1) ififo_wr = 1;
        else ififo_wr = 0;

        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        // if (t > 1) begin
        // $display("%b", core_instance.weight_sram.Q);
        // $display("IFIFO writing: %b", core_instance.corelet_instance.ififo.wr);
        // $display("IFIFO input: %h", core_instance.corelet_instance.ififo.in);
        // $display("");
        // end
      end

      // restore defaults
      ififo_wr = 0;
      A_xmem   = 0;
      CEN_xmem = 1;  // already done, this is more explicit.
      xw_mode  = 0;
      #0.5 clk = 1'b1;  //$display("%b", core_instance.weight_sram.Q);
      #0.5 clk = 1'b0;

      /////////////////////////////////////

      /////// Kernel loading to PEs ///////
      // completing kernel loading requires:
      // 1 cycle buffer (across core.inst_w->mac_array.inst_w_temp)
      // `row` cycles to populate all the rows with load instructions
      // `row` cycles to flush out all instructions from instr queue
      // `col` more cycles to complete load out in all columns
      execute=0;
      acc=0;
      relu_en=0;
      execution_mode=0;
      for (t = 0; t < 2*row+col; t = t + 1) begin
        // issue `row` loads
        if (0 <= t && t < row) load = 1;
        else load = 0;

        // provide data to load from
        // ififo actually has the same delay as instructions
        // due to rd_en being a register, meaning rd->rd_en[0] costs a cycle
        if (0 <= t && t < row) ififo_rd = 1;
        else ififo_rd = 0;

        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        j = 0;
      end
      ififo_rd = 0;
      load = 0;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;

      // verify that weights loaded into the kernel are as expected
      for (t = 0; t < row; t = t + 1) begin
        for (j = 0; j < col; j = j + 1) begin
          if (pe_weights_sim[t][j] != pe_weights_probe[t][j]) begin
            $display(
                "Unexpected value in PE weight!\n At PE(%d,%d), expected b_q to be %d but got %d",
                t, j, pe_weights_sim[t][j], pe_weights_probe[t][j]);
            $finish;
          end
        end
      end
      /////////////////////////////////////

      $display("Successfully completed testbench");
      $finish;  // TODO: move down...

      /*
$display("Row 0 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[1].mac_row_instance.in_n);
      $display("Row 0 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[1].mac_row_instance.out_s);
      $display("Row 1 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[2].mac_row_instance.in_n);
      $display("Row 1 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[2].mac_row_instance.out_s);
      $display("Row 2 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[3].mac_row_instance.in_n);
      $display("Row 2 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[3].mac_row_instance.out_s);
      $display("Row 3 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[4].mac_row_instance.in_n);
      $display("Row 3 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[4].mac_row_instance.out_s);
      $display("Row 4 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[5].mac_row_instance.in_n);
      $display("Row 4 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[5].mac_row_instance.out_s);
      $display("Row 5 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[6].mac_row_instance.in_n);
      $display("Row 5 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[6].mac_row_instance.out_s);
      $display("Row 6 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[7].mac_row_instance.in_n);
      $display("Row 6 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[7].mac_row_instance.out_s);
      $display("Row 7 in: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.in_n);
      $display("Row 7 out: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.out_s);
     */
      /*
$display("Row 0, col 1 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[1].mac_tile_instance.b_q);
$display("Row 0, col 2 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[2].mac_tile_instance.b_q);
$display("Row 0, col 3 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[3].mac_tile_instance.b_q);
$display("Row 0, col 4 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[4].mac_tile_instance.b_q);
$display("Row 0, col 5 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[5].mac_tile_instance.b_q);
$display("Row 0, col 6 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[6].mac_tile_instance.b_q);
$display("Row 0, col 7 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[7].mac_tile_instance.b_q);
$display("Row 0, col 8 weight: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[8].mac_tile_instance.b_q);
*/

      // TODO: load partial sums from pmem into IFIFO for accumulation
      // TODO: simultaneously load activations into L0.
      // TODO: the cycle after loading the first element, issue execution
      // instruction to PEs


      /////// Activation data writing to L0 ///////
      // A_xmem  = 11'b00000000000;
      // xw_mode = 0;
      // for (t = 0; t < len_nij; t = t + 1) begin
      //   #0.5 clk = 1'b0;
      //   CEN_xmem = 0;
      //   if (t > 0) begin
      //     A_xmem = A_xmem + 1;
      //     l0_wr  = 1;
      //   end
      //   #0.5 clk = 1'b1;
      //   //$display("%d", core_instance.activation_sram.A);
      //   //if (t > 1) $display("%b", core_instance.activation_sram.Q);
      //
      // end
      //
      // #0.5 clk = 1'b0;
      // CEN_xmem = 1;
      // A_xmem   = 0;
      // #0.5 clk = 1'b1;  //$display("%b", core_instance.activation_sram.Q);
      //
      // #0.5 clk = 1'b0;
      // l0_wr = 0;
      // #0.5 clk = 1'b1;  //$display("%b", core_instance.activation_sram.Q);
      /////////////////////////////////////


      //#0.5 clk = 1'b0; l0_rd = 0; load = 1;
      //#0.5 clk = 1'b1; //$display("%b", core_instance.activation_sram.Q);

      //#0.5 clk = 1'b0; l0_rd = 0; load = 0;
      //#0.5 clk = 1'b1; //$display("%b", core_instance.activation_sram.Q);

      /////// Execution ///////
      $display("Execution begins.\n");
      for (t = 0; t < len_nij; t = t + 1) begin
        #0.5 clk = 1'b0;
        l0_rd   = 1;
        execute = 1;
        #0.5 clk = 1'b1;
        if (t > 1) begin
          execute = 1;
          //$display("%b", core_instance.corelet_instance.l0_instance.out);
        end
      end

      #0.5 clk = 1'b0;
      l0_rd   = 0;
      execute = 0;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;

      // Wait for last element to load
      for (t = 0; t < col; t = t + 1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
        //$display("%b\n", core_instance.corelet_instance.mac_array_instance.temp);
        /*
      $display("Row 0, col 1 inst_w[1]: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[8].mac_tile_instance.inst_w[1]);
$display("Row 0, col 1 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[1].mac_tile_instance.a_q);
$display("Row 0, col 2 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[2].mac_tile_instance.a_q);
$display("Row 0, col 3 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[3].mac_tile_instance.a_q);
$display("Row 0, col 4 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[4].mac_tile_instance.a_q);
$display("Row 0, col 5 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[5].mac_tile_instance.a_q);
$display("Row 0, col 6 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[6].mac_tile_instance.a_q);
$display("Row 0, col 7 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[7].mac_tile_instance.a_q);
$display("Row 0, col 8 act: %b\n", core_instance.corelet_instance.mac_array_instance.row_num[8].mac_row_instance.col_num[8].mac_tile_instance.a_q);
*/
      end



      // Wait for last element to be delivered to bottom
      for (t = 0; t < len_nij * 2; t = t + 1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
        //$display("%d cycles after output should be valid.\n", t);
        //$display("%b\n", core_instance.corelet_instance.mac_array_instance.temp);
        //$display("%b\n", core_instance.corelet_instance.mac_array_instance.out_s);
      end
      /////////////////////////////////////

      /*
    psum_file = $fopen(psum_file_name, "r");
    psum_scan_file = $fscanf(psum_file, "%s", answer);
    psum_scan_file = $fscanf(psum_file, "%s", answer);
    psum_scan_file = $fscanf(psum_file, "%s", answer);
*/

      //////// OFIFO READ ////////
      // Ideally, OFIFO should be read while execution, but we have enough ofifo
      // depth so we can fetch out after execution.
      for (t = 0; t < len_nij; t = t + 1) begin
        #0.5 clk = 1'b0;
        if (ofifo_valid) begin
          ofifo_rd = 1;
        end

        CEN_pmem = 0;
        WEN_pmem = 0;
        if (t > 0) begin
          //psum_scan_file = $fscanf(psum_file, "%128b", answer);

          //if (core_instance.corelet_instance.ofifo_instance.out == answer) begin
          //      $display("%2d-th psum data matched.", t);
          //if (answer == 'd0) begin
          //        $display("Was 0.");
          //end else begin
          //        $display("Nonzero!");
          //end
          //end else begin
          //$display("%2d-th output featuremap Data ERROR!!", t); 
          //$display("ofifoout: %128b", core_instance.corelet_instance.ofifo_instance.out);
          //$display("answer  : %128b", answer);
          // end
          A_pmem = A_pmem + 1;


        end
        //$display("%d", A_pmem);
        //$display("%d", core_instance.psum_sram.A);
        //$display("%b", core_instance.psum_sram.D); 
        #0.5 clk = 1'b1;
        //$display("%b", core_instance.corelet_instance.ofifo_instance.out);

      end
      /////////////////////////////////////
      #0.5 clk = 1'b0;
      ofifo_rd = 0;
      CEN_pmem = 1;
      WEN_pmem = 1;

      //$display("%d", core_instance.activation_sram.A);
      //$display("%b", core_instance.activation_sram.D);
    end  // end of kij loop


    ////////// Accumulation /////////
    out_file = $fopen("out.txt", "r");

    // Following three lines are to remove the first three comment lines of the file
    out_scan_file = $fscanf(out_file, "%s", answer);
    out_scan_file = $fscanf(out_file, "%s", answer);
    out_scan_file = $fscanf(out_file, "%s", answer);

    error = 0;
    A_pmem = 0;
    pmem_mode = 1;
    A_pmem_sfp[10] = 1;

    /*
  A_pmem = 11'b00000000000; 
    for (t=0; t<600; t=t+1) begin
	    #0.5 clk = 1'b0; CEN_pmem = 0;
	    if (t > 0)  begin
		    A_pmem = A_pmem + 1; 
	    end
      if (t > 1) $display("%b", core_instance.psum_sram.Q);
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0; CEN_pmem = 1; A_pmem = 0;     
    $display("%b", core_instance.psum_sram.Q);
    #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;
    $display("%b", core_instance.psum_sram.Q);
    #0.5 clk = 1'b1; 
*/
    $display("############ Verification Start during accumulation #############");

    for (i = 0; i < len_onij + 1; i = i + 1) begin

      #0.5 clk = 1'b0;
      CEN_pmem = 1;
      WEN_pmem = 1;
      //$display("Writing to PMEM.");
      //$display("Address: %d", A_pmem);
      //$display("Address: %d", core_instance.psum_sram.A);
      //$display("Data in: %128b", core_instance.psum_sram.D);

      #0.5 clk = 1'b1;

      if (i > 0) begin
        out_scan_file = $fscanf(out_file, "%128b", answer);  // reading from out file to answer

        if (sfp_out == answer) begin
          $display("%2d-th output featuremap Data matched! :D", i);
          //$display("sfpout: %128b", sfp_out);
          //$display("answer: %128b", answer);
        end else begin
          $display("%2d-th output featuremap Data ERROR!!", i);
          $display("sfpout: %128b", sfp_out);
          $display("answer: %128b", answer);
          error = 1;
        end

      end


      #0.5 clk = 1'b0;
      reset = 1;
      sfp_reset = 1;
      CEN_pmem = 1;
      WEN_pmem = 1;
      A_pmem[10] = 0;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
      reset = 0;
      sfp_reset = 0;
      #0.5 clk = 1'b1;

      for (j = 0; j < len_kij + 1; j = j + 1) begin

        #0.5 clk = 1'b0;
        relu_en = 0;
        if (j < len_kij) begin
          CEN_pmem = 0;
          WEN_pmem = 1;
          //acc_scan_file = $fscanf(acc_file,"%11b", A_pmem);
          A_pmem[5:0] = $floor(i / o_ni_dim) * a_pad_ni_dim + i % o_ni_dim +
              $floor(j / ki_dim) * a_pad_ni_dim + j % ki_dim;
          A_pmem[9:6] = j;
        end else begin
          CEN_pmem = 1;
          WEN_pmem = 1;
        end

        //$display("Address: %d", core_instance.psum_sram.A);
        if (j > 0) begin
          acc = 1;
          //$display("Input: %b", core_instance.corelet_instance.sfp_instance.in_psum);
          //$display("Output: %b", core_instance.corelet_instance.sfp_instance.out_accum);
        end
        if (j == len_kij) begin
          relu_en = 1;
        end

        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0;
      acc = 0;
      relu_en = 0;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
      if (i > 0) begin
        A_pmem_sfp = A_pmem_sfp + 1;
      end
      A_pmem = A_pmem_sfp;
      //$display("Input: %b", core_instance.corelet_instance.sfp_instance.in_psum);
      //$display("Output: %b", core_instance.corelet_instance.sfp_instance.out_accum);
      if (i < len_onij) begin
        CEN_pmem = 0;
        WEN_pmem = 0;
      end
      //$display("%b", core_instance.corelet_instance.sfp_instance.out_accum);
      #0.5 clk = 1'b1;



    end


    if (error == 0) begin
      $display("############ No error detected ##############");
      $display("########### Project Completed !! ############");

    end

    $fclose(out_file);
    //////////////////////////////////


    ////////// SFP output store to SRAM verification /////////
    out_file = $fopen("out.txt", "r");

    // Following three lines are to remove the first three comment lines of the file
    out_scan_file = $fscanf(out_file, "%s", answer);
    out_scan_file = $fscanf(out_file, "%s", answer);
    out_scan_file = $fscanf(out_file, "%s", answer);

    #0.5 clk = 1'b0;
    A_pmem_sfp[9:0] = 0;
    A_pmem = A_pmem_sfp;
    #0.5 clk = 1'b1;

    for (t = 0; t < len_onij; t = t + 1) begin
      #0.5 clk = 1'b0;
      CEN_pmem = 0;
      WEN_pmem = 1;
      if (t > 0) begin
        A_pmem_sfp = A_pmem_sfp + 1;
        A_pmem = A_pmem_sfp;
      end
      if (t > 1) begin
        A_pmem = A_pmem_sfp;
        out_scan_file = $fscanf(out_file, "%128b", answer);  // reading from out file to answer
        if (core_instance.psum_sram.Q == answer) begin
          $display("%2d-th output featuremap Data matched! :D", t);
        end else begin
          $display("%2d-th output featuremap Data ERROR!!", t);
          $display("sfpout: %128b", core_instance.psum_sram.Q);
          $display("answer: %128b", answer);
          error = 1;
        end

      end
      #0.5 clk = 1'b1;
    end

    #0.5 clk = 1'b0;
    CEN_pmem = 1;
    WEN_pmem = 1;
    A_pmem = 0;
    pmem_mode = 0;
    #0.5 clk = 1'b1;


    for (t = 0; t < 10; t = t + 1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end

    #10 $finish;

  end

  always @(posedge clk) begin
    pmem_mode_q <= pmem_mode;
    inst_w_q <= inst_w;

    D_xmem_q <= D_xmem;
    CEN_xmem_q <= CEN_xmem;
    WEN_xmem_q <= WEN_xmem;
    A_xmem_q <= A_xmem;

    xw_mode_q <= xw_mode;
    A_pmem_q <= A_pmem;
    CEN_pmem_q <= CEN_pmem;
    WEN_pmem_q <= WEN_pmem;
    D_pmem_q <= D_pmem;

    ofifo_rd_q <= ofifo_rd;
    ififo_wr_q <= ififo_wr;
    ififo_rd_q <= ififo_rd;
    ififo_mode_q <= ififo_mode;
    l0_rd_q <= l0_rd;
    l0_wr_q <= l0_wr;

    execute_q <= execute;
    load_q <= load;
    acc_q <= acc;
    relu_en_q <= relu_en;
    execution_mode_q <= execution_mode;

    post_ex <= core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.inst_w[1];

    /*
   if (core_instance.corelet_instance.ofifo_instance.wr[0] != 0) begin
	   $display("Ofifo write to 0.");
	   $display("%b", core_instance.corelet_instance.ofifo_instance.wr);
	   $display("%b", core_instance.corelet_instance.ofifo_instance.in);
   end
*/
    /*
  
   if (core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.inst_w[1] != 0) begin

	      $display("%b", core_instance.corelet_instance.l0_instance.out);
	   $display("Nij %d, Captured: A_q %b", nij, core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.in_w);
     end

     if (post_ex && kij > 0) begin
          if (nij == 7) begin
	   $display("Multiplication on row 1, column 1.");
	   $display("A_q: %d", core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.a_q);
	   $display("B_q: %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.b_q));
	   $display("In_n: %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.in_n));
	   $display("Out_s: %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.out_s));
	   $display("Product: %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.mac_instance.product));
	   $display("Product (Expand): %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.mac_instance.product_expand));
	   $display("Padded A: %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.mac_instance.a_pad));
	   $display("C: %d", $signed(core_instance.corelet_instance.mac_array_instance.row_num[row_idx].mac_row_instance.col_num[col_idx].mac_tile_instance.mac_instance.c));
     end

     nij <= nij + 1;
   end
  */
  end


endmodule




