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
  parameter in_chan_num = 8;

  parameter xmem_words = 2048;
  parameter pmem_words = 2048;
  parameter test_ws = 1;  // set to 1 if you want to test weight stationary
  // before output stationary

  reg clk = 0;
  reg reset = 1;
  reg sfp_reset = 1;

  wire [44:0] inst_q;

  // CTRL BITS ------------------------------------------------------------------------
  reg [1:0] pmem_mode = 0;  // write from OFIFO if 0, write from SFP if 1,
  // write from D_pmem if 2
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
  reg [10:0] WA_pmem = 0;
  reg [10:0] RA_pmem = 0;
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
  reg [10:0] WA_pmem_q = 0;
  reg [10:0] RA_pmem_q = 0;
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

  reg [8*30:1] stringvar;
  reg [8*30:1] w_file_name;
  reg execute_warmup = 1;
  wire ofifo_valid;
  wire [col*psum_bw-1:0] sfp_out;

  // reference data for verification
  reg [bw*row-1:0] amem_sim[xmem_words-1:0];
  reg [bw*row-1:0] wmem_sim[xmem_words-1:0];
  reg [psum_bw*col-1:0] pmem_sim[pmem_words-1:0];
  // TODO: add an extra dimension to pe_weights_sim for output tiles
  reg [bw-1:0] pe_weights_sim[row-1:0][col-1:0];

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

  assign inst_q[44:34] = RA_pmem_q;
  assign inst_q[33] = acc_q;
  assign inst_q[32] = CEN_pmem_q;
  assign inst_q[31] = WEN_pmem_q;
  assign inst_q[30:20] = WA_pmem_q;
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

  /////////////////// PROBES ///////////////////////
  genvar gr, gc;

  // pe probes
  wire [bw-1:0] pe_a_q_probe[row-1:0][col-1:0];
  wire [bw-1:0] pe_bq_probe[row-1:0][col-1:0];
  wire [psum_bw-1:0] pe_in_n_probe[row-1:0][col-1:0];
  wire [psum_bw-1:0] pe_in_w_probe[row-1:0][col-1:0];
  wire [psum_bw-1:0] pe_out_s_probe[row-1:0][col-1:0];
  wire [inst_width-1:0] pe_inst_probe[row-1:0][col-1:0];
  wire [psum_bw-1:0] pe_c_q_probe[row-1:0][col-1:0];

  // ofifo probes
  // currently unused, but could be useful. Maybe make a task to print it.
  wire [psum_bw-1:0] ofifo_out_probe[col-1:0];

  // register for splitting answer into separate tokens
  wire [psum_bw-1:0] answer_split[col-1:0];

  for (gr = 0; gr < row; gr = gr + 1) begin : gen_pe_probes_row
    for (gc = 0; gc < col; gc = gc + 1) begin : gen_pe_probes_col
      assign pe_bq_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.b_q;
      assign pe_a_q_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.a_q;
      assign pe_c_q_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.c_q;
      assign pe_in_n_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.in_n;
      assign pe_in_w_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.in_w;
      assign pe_out_s_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.out_s;
      assign pe_inst_probe[gr][gc] = core_instance.corelet_instance.mac_array_instance.row_num[gr+1].mac_row_instance.col_num[gc+1].mac_tile_instance.inst_q;
    end
  end

  for (gc = 0; gc < col; gc = gc + 1) begin : gen_ofifo_out_probe
    assign ofifo_out_probe[gc] = core_instance.corelet_instance.ofifo_output[psum_bw*(gc+1)-1:psum_bw*gc];
  end

  for (gr = 0; gr < row; gr = gr + 1) begin : gen_D_xmem_fragments
    assign D_xmem_fragments[gr] = D_xmem[bw*(gr+1)-1:bw*gr];
  end

  for (gc = 0; gc < col; gc = gc + 1) begin : gen_answer_split
    assign answer_split[gc] = answer[psum_bw*(gc+1)-1:psum_bw*gc];
  end


  task automatic print_pe_status;
    integer a;
    integer b;
    begin
      $display("b_q\t\t\t\ta_q\t\t\t\t\tc_q\t\t\t\t\t\t\tin_n\t\t\t\t\t\tout_s\t\t\t\t\t\tinst_q");
      for (a = 0; a < row; a = a + 1) begin
        for (b = 0; b < col; b = b + 1) begin
          $write("%2d ", $signed(pe_bq_probe[a][b]));
        end
        $write("\t");
        for (b = 0; b < col; b = b + 1) begin
          $write("%2d ", pe_a_q_probe[a][b]);
        end
        $write("\t");
        for (b = 0; b < col; b = b + 1) begin
          $write("%5d ", $signed(pe_c_q_probe[a][b]));
        end
        $write("\t");
        for (b = 0; b < col; b = b + 1) begin
          $write("%5d ", $signed(pe_in_n_probe[a][b]));
        end
        // $write("\t");
        // for (b = 0; b < col; b = b + 1) begin
        //   $write("%2d ", pe_in_w_probe[a][b]);
        // end
        $write("\t");
        for (b = 0; b < col; b = b + 1) begin
          $write("%5d ", $signed(pe_out_s_probe[a][b]));
        end
        $write("\t");
        for (b = 0; b < col; b = b + 1) begin
          $write("%h ", pe_inst_probe[a][b]);
        end
        $display("");
      end
    end
  endtask

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


  // useful tasks
  task automatic compare_psum_out;
    begin
      out_file = $fopen("../OSWS_Files/out.txt", "r");  // only testing

      // Following three lines are to remove the first three comment lines of the file
      out_scan_file = $fscanf(out_file, "%s", answer);
      out_scan_file = $fscanf(out_file, "%s", answer);
      out_scan_file = $fscanf(out_file, "%s", answer);

      RA_pmem = 0;
      CEN_pmem = 0;
      for (t = 0; t < len_onij + 1; t = t + 1) begin
        if (t > 0) begin
          RA_pmem = RA_pmem + 1;
          // $display("Setting RA_pmem to %d as the next pmem request", RA_pmem);
        end

        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        // verify answer after pulse
        if (t > 0) begin
          out_scan_file = $fscanf(out_file, "%128b", answer);
          if (core_instance.psum_sram.Q == answer) begin
            $display("%2d-th output featuremap Data matched! :D", t - 1);
          end else begin
            $display("%2d-th output featuremap Data ERROR!!", t - 1);
            // $display("psum_sram: %128b", core_instance.psum_sram.Q);
            // $display("answer: %128b", answer);
            $display("psum_sram: %32h", core_instance.psum_sram.Q);
            $display("answer: %32h", answer);
            $display("answer as vector:");
            for (j = 0; j < col; j = j + 1) begin
              $write("%d ", $signed(answer_split[j]));
            end
            $display("\n");
            error = 1;
          end
        end
      end
      CEN_pmem = 1;
    end
  endtask

  task automatic clear_psum_ram;
    begin
      // for each output tile (currently assume there is only 1), (row chunk in sram)
      // for each nij value (row in sram),
      // write 0s to that row
      #0.5 clk = 1'b0;
      WA_pmem = 0;
      RA_pmem = 0;
      WEN_pmem = 0;
      CEN_pmem = 0;
      D_pmem = 0;
      pmem_mode = 2;
      // implicitly, we are operating on tile 0.
      // TODO: wrap in for loop to operate on multiple output tiles
      for (t = 0; t < len_nij; t = t + 1) begin
        if (t > 0) WA_pmem = WA_pmem + 1;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        pmem_sim[WA_pmem] = D_pmem;
      end
      // restore values modified for this operation
      WEN_pmem = 1;
      CEN_pmem = 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;

      //verify that 0s are written to all necessary rows in psum sram
      for (t = 0; t < len_nij; t = t + 1) begin
        if (pmem_sim[t] !== core_instance.psum_sram.memory[t]) begin
          $display("Unexpected value in psum SRAM!\n At address %d, expected %h but got %h", t,
                   pmem_sim[t], core_instance.psum_sram.memory[t]);
          $finish;
        end
      end
    end

  endtask

  task automatic write_relu;
    begin
      RA_pmem   = 0;
      WA_pmem   = 0;
      pmem_mode = 1;  // write from SFP back to psums
      relu_en   = 1;
      // Pass psums thru SFP to perform ReLU
      for (i = 0; i < len_onij; i = i + 1) begin
        CEN_pmem = 0;
        if (i > 0) begin
          RA_pmem = RA_pmem + 1;
          WA_pmem = WA_pmem + 1;
        end
        // t = 0+i: reset SFP. Make sure to turn off write request (in case of loop). perform a read request to PSUM memory
        sfp_reset = 1;
        WEN_pmem  = 1;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        // t = 1+h: SFP accumulator is zero'd. Data is available to SFU and is about to be computed
        sfp_reset = 0;
        acc = 1;  // this is just an SFU enable bit
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        // t = 2+h: SFP has the correct value, but needs to wait a cycle due
        // to sfp_out_q being registered.
        sfp_reset = 0;
        acc = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        // t = 3+h: value is available at write port of psum. Write it.
        WEN_pmem = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        $display("sfp_out: %h", sfp_out);
      end

      WEN_pmem = 1;
      CEN_pmem = 1;
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;
    end
  endtask

  task automatic reset_core;
    begin
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
    end
  endtask

  initial begin

    pmem_mode      = 0;
    inst_w         = 0;

    D_xmem         = 0;
    CEN_xmem       = 1;
    WEN_xmem       = 1;

    D_pmem         = 0;
    A_xmem         = 0;
    ofifo_rd       = 0;
    ififo_wr       = 0;
    ififo_rd       = 0;
    l0_rd          = 0;
    l0_wr          = 0;
    execute        = 0;
    load           = 0;
    execution_mode = 0;

    $dumpfile("core_tb.vcd");
    $dumpvars(0, core_tb);

    if (test_ws) begin
      //x_file = $fopen("activation_tile0.txt", "r");
      x_file = $fopen("../OSWS_Files/activation.txt", "r");
      // Following three lines are to remove the first three comment lines of the file
      x_scan_file = $fscanf(x_file, "%s", captured_data);
      x_scan_file = $fscanf(x_file, "%s", captured_data);
      x_scan_file = $fscanf(x_file, "%s", captured_data);

      //////// Reset /////////
      reset_core;
      /////////////////////////

      /////// Activation data writing to memory ///////
      for (t = 0; t < len_nij; t = t + 1) begin
        #0.5 clk = 1'b0;
        // xw_mode=0 is the default, but we want to be explicit that we are
        // writing to activations
        xw_mode = 0;
        x_scan_file = $fscanf(x_file, "%32b", D_xmem);
        WEN_xmem = 0;
        CEN_xmem = 0;
        if (t > 0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;

        // fill in the expected value in xmem_sim
        amem_sim[A_xmem] = D_xmem;
      end

      #0.5 clk = 1'b0;
      WEN_xmem = 1;
      CEN_xmem = 1;
      A_xmem   = 0;

      // verify activations are written to SRAM
      for (t = 0; t < len_nij; t = t + 1) begin
        if (amem_sim[t] != core_instance.activation_sram.memory[t]) begin
          $display("Unexpected value in activation SRAM!\n At address %d, expected %h but got %h",
                   t, amem_sim[t], core_instance.activation_sram.memory[t]);
          $finish;
        end
      end

      #0.5 clk = 1'b1;

      $fclose(x_file);
      /////////////////////////////////////////////////

      // ZERO OUT PSUMS IN MEMORY ----------------------------------------------
      clear_psum_ram;

      // PARTIAL SUMS OVER INPUT CHANNELS AND KIJ ---------------------------------------
      // TODO: wrap in for loop to operate on multiple output tiles
      for (kij = 0; kij < 9; kij = kij + 1) begin  // kij loop
        $display("Kij %d\n", kij);
        case (kij)
          0: w_file_name = "../OSWS_Files/weight_0.txt";
          1: w_file_name = "../OSWS_Files/weight_1.txt";
          2: w_file_name = "../OSWS_Files/weight_2.txt";
          3: w_file_name = "../OSWS_Files/weight_3.txt";
          4: w_file_name = "../OSWS_Files/weight_4.txt";
          5: w_file_name = "../OSWS_Files/weight_5.txt";
          6: w_file_name = "../OSWS_Files/weight_6.txt";
          7: w_file_name = "../OSWS_Files/weight_7.txt";
          8: w_file_name = "../OSWS_Files/weight_8.txt";
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
          // weights file is expected to look like the following:
          // #col7row0[msb-lsb],col6row0[msb-lst],....,col0row0[msb-lst]#
          // #col7row1[msb-lsb],col6row1[msb-lst],....,col0row1[msb-lst]#
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
            pe_weights_sim[t][j] = D_xmem_fragments[j];
          end
        end

        // restore core input registers to default values
        // simultaneously complete the last SRAM write
        WEN_xmem = 1;
        CEN_xmem = 1;
        A_xmem   = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        // verify that kernel data has been written
        // $display("Verifying that wmem has been written to correctly");
        for (t = 0; t < row; t = t + 1) begin
          // $display("%d %d", wmem_sim[t], core_instance.weight_sram.memory[t]);
          if (wmem_sim[t] !== core_instance.weight_sram.memory[t]) begin
            $display("Unexpected value in weight SRAM!\n At address %d, expected %d but got %d", t,
                     wmem_sim[t], core_instance.weight_sram.memory[t]);
            $finish;
          end
        end
        /////////////////////////////////////


        /////// Kernel data writing to IFIFO ///////
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
        execute = 0;
        acc = 0;
        relu_en = 0;
        execution_mode = 0;
        for (t = 0; t < 2 * row + 2 * col; t = t + 1) begin
          // issue enough load instructions to perform a load without bugs
          if (0 <= t && t < 2 * col) load = 1;
          else load = 0;

          // provide data to load from
          // ififo actually has the same delay as instructions
          // due to rd_en being a register, meaning rd->rd_en[0] costs a cycle
          if (1 <= t && t < row + 1) ififo_rd = 1;
          else ififo_rd = 0;

          #0.5 clk = 1'b1;
          #0.5 clk = 1'b0;

          // $display("ififo read: %b", ififo_rd_q);
          // $display("ififo out: %b", core_instance.corelet_instance.ififo_output);
          // print_pe_status;
          //
          // j = 0;
        end
        ififo_rd = 0;
        load = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        // print_pe_status;

        // verify that weights loaded into the kernel are as expected
        for (t = 0; t < row; t = t + 1) begin
          for (j = 0; j < col; j = j + 1) begin
            if (pe_weights_sim[t][j] !== pe_bq_probe[t][j]) begin
              $display(
                  "Unexpected value in PE weight!\n At PE(%d,%d), expected b_q to be %d but got %d",
                  t, j, pe_weights_sim[t][j], pe_bq_probe[t][j]);
              $finish;
            end
          end
        end
        /////////////////////////////////////

        /////////// Execution pipeline ////////////
        RA_pmem = 0;
        WA_pmem = -1;
        A_xmem = 0;  // used, but determined by i and j, not this base value.
        // useful counters to figure out A_xmem
        i = 0;  // rows
        j = 0;  // cols
        pmem_mode = 0;  // update using OFIFO
        xw_mode = 0;  // read in activations
        // it's easier to just enable pmem and xmem for this period of time.
        CEN_pmem = 0;
        CEN_xmem = 0;
        // but keep them in read mode until we really have to write
        WEN_xmem = 1;
        WEN_pmem = 1;
        ififo_mode = 1;  // load psums into IFIFO

        // iterate at least until first vector comes out, then until ofifo stops
        // spitting out nij values for the output tile
        execute_warmup = 1;
        for (t = 0; execute_warmup || ofifo_valid; t = t + 1) begin
          // t=0: issue read requests to psum and activation SRAMs.
          // ensure that the addresses of activations correspond to the
          // nij' indices availble to this kij for convolution.
          // Issue execute instruction to core. It will be in
          // mac_array.inst_w_temp in t=1, and should reach
          // mac_tile.inst_q in t=2.
          if (0 <= t && t < len_onij + 1) begin
            // we must issue one extra execute instruction to ensure that the
            // tail end of the execute chain gets its MAC value read out.
            execute = 1;
          end else begin
            execute = 0;
          end


          if (1 <= t && t < len_onij) begin
            RA_pmem = RA_pmem + 1;

            j = j + 1;
            if (j == o_ni_dim) begin
              j = 0;
              i = i + 1;
            end
          end
          A_xmem = a_pad_ni_dim * (i + kij / ki_dim) + j + kij % ki_dim;

          // t=1-t=16: issue write requests to IFIFO and L0 for each nij. Simultaneously
          // issue a read request!!! because the write signal doesn't have
          // a register between itself and the low-level FIFOs
          if (1 <= t && t < len_onij + 1) begin
            ififo_wr = 1;
            ififo_rd = 1;
            l0_wr = 1;
            l0_rd = 1;
          end else begin
            ififo_wr = 0;
            ififo_rd = 0;
            l0_wr = 0;
            l0_rd = 0;
          end

          // t=2: data is available for PE(0,0), and must be consumed else it
          // will be popped unused in t=3. Fortunately, we issued the execute
          // instruction in t=0, which should be in PE(0,0)'s inst_q by t=2.

          // whenever the output FIFO is ready, issue a read signal to it
          // Wait one cycle for the signal to reach ofifo.rd_en
          // then issue a write signal to the psum FIFO at an address incrementing from 0.
          if (ofifo_valid) begin
            ofifo_rd = 1;

            // the first time ofifo becomes valid, don't increment WA_pmem
            if (!execute_warmup) begin
              WEN_pmem = 0;
              WA_pmem  = WA_pmem + 1;
            end
          end

          // Once OFIFO becomes valid for the first time, we can wait until
          // OFIFO becomes invalid to know when we're done.
          if (execute_warmup && ofifo_valid) execute_warmup = 0;

          // the cycle ofifo_valid goes low, ofifo_rd_q will still be high from the
          // previous cycle. This is ok because ofifo simply will not update.
          // However, WEN_pmem will be high for an extra cycle. Fortunately
          // WA_pmem will increment and not mangle any old work. So, this should
          // be fine, although a bit uncomfortable... WA_pmem cannot be allowed
          // to wrap around.

          #0.5 clk = 1'b1;
          #0.5 clk = 1'b0;

          // verify some things
          // print_pe_status;
          // print valid bits coming out of the last column
        end


        execute = 0;
        CEN_pmem = 1;
        CEN_xmem = 1;
        execute = 0;
        ofifo_rd = 0;
        WEN_pmem = 1;
        ififo_wr = 0;
        ififo_rd = 0;
        l0_wr = 0;
        l0_rd = 0;
        // $display("psum memory contents:");
        // for (t = 0; t < len_onij; t = t + 1) begin
        //   $display("%d: %32h", t, core_instance.psum_sram.memory[t]);
        // end
        // if (kij == 0) $finish;
      end

      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;

      // Pass psums thru SFP to perform ReLU
      write_relu;


      ////////// SRAM verification /////////
      // expecting in out.txt:
      // row 0: nij=0, output channels 0-7
      // row 1: nij=1, output channels 0-7
      // row 2: nij=2, output channels 0-7
      // ...
      // $display("psum memory contents:");
      // for (t = 0; t < len_onij; t = t + 1) begin
      //   $display("%d: %32h", t, core_instance.psum_sram.memory[t]);
      // end
      CEN_pmem = 0;
      WEN_pmem = 1;
      RA_pmem  = 0;

      // now that psum sram has varied values, test if psum sram is being read properly
      for (t = 0; t < len_onij + 1; t = t + 1) begin

        if (t > 0) begin
          RA_pmem = RA_pmem + 1;
        end

        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        // verify after pulse
        if (t > 0) begin
          if (core_instance.psum_sram.Q !== core_instance.psum_sram.memory[RA_pmem-1]) begin
            $display("psum memory read test failed at address %d", RA_pmem - 1);
            $display("%h != %h", core_instance.psum_sram.Q,
                     core_instance.psum_sram.memory[RA_pmem-1]);
            $display("some useful information about psum mem:");
            $display("add_q: %h", core_instance.psum_sram.add_q);
            $display("RA: %h", core_instance.psum_sram.RA);
            $finish;
          end
        end
      end

      compare_psum_out;

      #0.5 clk = 1'b0;
      CEN_pmem  = 1;
      WEN_pmem  = 1;
      WA_pmem   = 0;
      pmem_mode = 0;
      #0.5 clk = 1'b1;


      for (t = 0; t < 10; t = t + 1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end

    end

    // Now for Output-Stationary Execution!

    // again zero out psums in memory, mainly so that we don't accidentally
    // think our machine works because we didn't clear out the old, correct
    // values from PSUM SRAM.
    clear_psum_ram;

    // we expect everything to fail.
    $display("\nZeroed out psum\n");
    // compare_psum_out;

    // reset the machine
    // required each time we compute an output tile in order to set c_ij of
    // all elements to 0.
    reset_core;

    // load weights into weight SRAM
    A_xmem   = 11'b11111111111;
    WEN_xmem = 0;
    CEN_xmem = 0;
    for (kij = 0; kij < 9; kij = kij + 1) begin  // kij loop
      $display("Loading weights for Kij %d\n", kij);
      case (kij)
        0: w_file_name = "../OSWS_Files/weight_0.txt";
        1: w_file_name = "../OSWS_Files/weight_1.txt";
        2: w_file_name = "../OSWS_Files/weight_2.txt";
        3: w_file_name = "../OSWS_Files/weight_3.txt";
        4: w_file_name = "../OSWS_Files/weight_4.txt";
        5: w_file_name = "../OSWS_Files/weight_5.txt";
        6: w_file_name = "../OSWS_Files/weight_6.txt";
        7: w_file_name = "../OSWS_Files/weight_7.txt";
        8: w_file_name = "../OSWS_Files/weight_8.txt";
      endcase

      w_file = $fopen(w_file_name, "r");
      // Following three lines are to remove the first three comment lines of the file
      w_scan_file = $fscanf(w_file, "%s", captured_data);
      w_scan_file = $fscanf(w_file, "%s", captured_data);
      w_scan_file = $fscanf(w_file, "%s", captured_data);

      /////// Kernel data writing to memory ///////
      for (t = 0; t < row; t = t + 1) begin
        w_scan_file = $fscanf(w_file, "%32b", D_xmem);
        A_xmem = A_xmem + 1;
        xw_mode = 1;  // write to weight memory
        // pump wire data into registered inputs
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;

        // update simulation values
        wmem_sim[A_xmem] = D_xmem;
      end
    end
    // restore core input registers to default values
    // simultaneously complete the last SRAM write
    WEN_xmem = 1;
    CEN_xmem = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;

    // verify that kernel data has been written
    // $display("Verifying that wmem has been written to correctly");
    for (t = 0; t < len_kij * row; t = t + 1) begin
      // $display("%d: %b %b", t, wmem_sim[t], core_instance.weight_sram.memory[t]);
      if (wmem_sim[t] !== core_instance.weight_sram.memory[t]) begin
        $display("Unexpected value in weight SRAM!\n At address %d, expected %d but got %d", t,
                 wmem_sim[t], core_instance.weight_sram.memory[t]);
        $finish;
      end
    end


    // load activations into activation SRAM
    x_file = $fopen("../OSWS_Files/activation_os.txt", "r");
    // Following three lines are to remove the first three comment lines of the file
    x_scan_file = $fscanf(x_file, "%s", captured_data);
    x_scan_file = $fscanf(x_file, "%s", captured_data);
    x_scan_file = $fscanf(x_file, "%s", captured_data);
    /////// Activation data writing to memory ///////
    A_xmem = 0;
    for (t = 0; t < col * len_kij; t = t + 1) begin
      // xw_mode=0 is the default, but we want to be explicit that we are
      // writing to activations
      xw_mode = 0;
      x_scan_file = $fscanf(x_file, "%32b", D_xmem);
      WEN_xmem = 0;
      CEN_xmem = 0;
      if (t > 0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;

      // fill in the expected value in xmem_sim
      amem_sim[A_xmem] = D_xmem;
    end

    $fclose(x_file);

    // return inputs to default
    WEN_xmem = 1;
    CEN_xmem = 1;
    A_xmem   = 0;
    xw_mode  = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;

    // verify activations are written to SRAM
    // there should be 8 blocks of activations; each block has 9 activations,
    // corresponding to the number of elements in kij.
    for (t = 0; t < in_chan_num * len_kij; t = t + 1) begin
      if (amem_sim[t] != core_instance.activation_sram.memory[t]) begin
        $display("Unexpected value in activation SRAM!\n At address %d, expected %h but got %h", t,
                 amem_sim[t], core_instance.activation_sram.memory[t]);
        $finish;
      end
    end

    // hack for writing 0s into c_q without a huge reset signal. /////////

    // TODO: see if you don't need to set all c_qs to 0 beforehand
    // point pmem to a 0 vector
    // WEN_pmem = 1;  // read only
    // CEN_pmem = 0;  // activate pmem
    // RA_pmem = 0;  // address 0 should have a 0 right now
    // execution_mode = 1;  // might as well switch to OS mode now.
    // #0.5 clk = 1'b1;
    // #0.5 clk = 1'b0;
    //
    // for (t = 0; t < 2 * row + 2; t = t + 1) begin
    //   // t = 0: write ONE zero vector to IFIFO (from PSUMs, which have been
    //   // zerod out)
    //   // DONT issue a read instruction so that the vector aliases
    //   // issue a flush instruction to PEs
    //   // we need to issue two flush instructions; the second one ensures that
    //   // the row below any given row still sees c_q
    //   if (t == 0) begin
    //     ififo_wr = 1;
    //     ififo_mode = 1;  // read into ififo from psum
    //     load = 1;
    //   end else begin
    //     ififo_wr = 0;  // do not add more than one zero vector
    //     ififo_mode = 0;  // reset to defaults
    //     load = 0;
    //   end
    //
    //   #0.5 clk = 1'b1;
    //   #0.5 clk = 1'b0;
    // end
    //
    // ififo_rd = 1;
    // #0.5 clk = 1'b1;
    // #0.5 clk = 1'b0;
    // ififo_rd = 0;
    // #0.5 clk = 1'b1;
    // #0.5 clk = 1'b0;

    // OS EXECUTE
    pmem_mode = 0;
    CEN_xmem = 0;
    A_xmem = 0;
    ififo_mode = 0;
    execution_mode = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    // execution is much simpler in output-stationary
    for (t = 0; t < in_chan_num * len_kij + col + row + 10; t = t + 1) begin
      // write to IFIFOs
      // issue read to IFIFO, grabbing from weights
      // issue read to L0, grabbing from activations
      // issue os execute instrution to PEs
      if (0 <= t && t < in_chan_num * len_kij + 1) begin
        if (t > 0) A_xmem = A_xmem + 1;
        l0_rd = 1;
        l0_wr = 1;
        ififo_wr = 1;
        ififo_rd = 1;
      end else begin
        l0_rd = 0;
        l0_wr = 0;
        ififo_wr = 0;
        ififo_rd = 0;
      end

      if (0 <= t && t < in_chan_num * len_kij) begin
      end else begin
      end

      // issue one execute to perfomr a_q/b_q load
      // then in_chan*len_kij executes to actually perform MAC
      if (0 <= t && t < in_chan_num * len_kij + 1) begin
        execute = 1;
      end else begin
        execute = 0;
      end
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
      // $display("t = %d", t);
      // print_pe_status;
      // $display;
    end

    // OS FLUSH
    load = 1;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    load = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    while (!ofifo_valid) begin
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
    end

    // write out to pmem
    WA_pmem = 8;
    for (t = 0; t < row + 1; t = t + 1) begin
      pmem_mode = 0;
      ofifo_rd  = 1;
      if (1 <= t && t < row + 1) begin
        WEN_pmem = 0;
        CEN_pmem = 0;
        WA_pmem  = WA_pmem - 1;
      end
      #0.5 clk = 1'b1;
      #0.5 clk = 1'b0;
    end
    WEN_pmem = 1;
    CEN_pmem = 1;
    ofifo_rd = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;

    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;

    // Pass psums thru SFP to perform ReLU
    write_relu;


    compare_psum_out;  // only the first 8 need to match

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
    WA_pmem_q <= WA_pmem;
    CEN_pmem_q <= CEN_pmem;
    WEN_pmem_q <= WEN_pmem;
    D_pmem_q <= D_pmem;
    RA_pmem_q <= RA_pmem;

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
  end


endmodule




