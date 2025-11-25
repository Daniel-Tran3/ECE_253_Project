// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps

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

reg clk = 0;
reg reset = 1;
reg sfp_reset = 1;

wire [33:0] inst_q; 

reg xw_mode = 0; // x if 0, w if 1
reg pmem_mode = 0; // write from OFIFO if 0, write from SFP if 1
reg [1:0]  inst_w_q = 0; 
reg [bw*row-1:0] D_xmem_q = 0;
reg CEN_xmem = 1;
reg WEN_xmem = 1;
reg [10:0] A_xmem = 0;
reg CEN_xmem_q = 1;
reg WEN_xmem_q = 1;
reg [10:0] A_xmem_q = 0;
reg CEN_pmem = 1;
reg WEN_pmem = 1;
reg [10:0] A_pmem = 0;
reg CEN_pmem_q = 1;
reg WEN_pmem_q = 1;
reg [10:0] A_pmem_q = 0;
reg ofifo_rd_q = 0;
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;
reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc_q = 0;
reg acc = 0;
reg relu_en = 0;
reg relu_en_q = 0;

reg [10:0] A_pmem_sfp = 0;
reg [1:0]  inst_w; 
reg [bw*row-1:0] D_xmem;
reg [psum_bw*col-1:0] answer;

integer nij = 0;
reg post_ex = 0;


reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
reg l0_rd;
reg l0_wr;
reg execute;
reg load;
reg [8*30:1] stringvar;
reg [8*30:1] w_file_name;
reg [8*30:1] psum_file_name;
wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer psum_file, psum_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij;
integer error;

assign inst_q[33] = acc_q;
assign inst_q[32] = CEN_pmem_q;
assign inst_q[31] = WEN_pmem_q;
assign inst_q[30:20] = A_pmem_q;
assign inst_q[19]   = CEN_xmem_q;
assign inst_q[18]   = WEN_xmem_q;
assign inst_q[17:7] = A_xmem_q;
assign inst_q[6]   = ofifo_rd_q;
assign inst_q[5]   = ififo_wr_q;
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q;
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; 
assign inst_q[0]   = load_q; 


core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
        .D_xmem(D_xmem_q), 
        .sfp_out(sfp_out), 
	.xw_mode(xw_mode),
	.reset(reset),
	.sfp_reset(sfp_reset),
	.relu_en(relu_en_q),
	.pmem_mode(pmem_mode)); 


initial begin 

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  pmem_mode = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  //x_file = $fopen("activation_tile0.txt", "r");
  x_file = $fopen("activation.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1; sfp_reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0; xw_mode = 0; sfp_reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
  /////////////////////////

  /////// Activation data writing to memory ///////
  //for (t=0; t<len_nij; t=t+1) begin  
  for (t=0; t<len_nij; t=t+1) begin  
    #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
    //$display("%d", core_instance.activation_sram.A);
    //$display("%b", core_instance.activation_sram.D);
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;

    //$display("%d", core_instance.activation_sram.A);
    //$display("%b", core_instance.activation_sram.D);
  #0.5 clk = 1'b1; 

  $fclose(x_file);
  /////////////////////////////////////////////////


  for (kij=0; kij<9; kij=kij+1) begin  // kij loop
  //for (kij=0; kij<2; kij=kij+1) begin  // kij loop
    $display("Kij %d\n", kij);
    case(kij)
     //0: w_file_name = "weight_itile0_otile0_kij0.txt";
     //1: w_file_name = "weight_itile0_otile0_kij1.txt";
     //2: w_file_name = "weight_itile0_otile0_kij2.txt";
     //3: w_file_name = "weight_itile0_otile0_kij3.txt";
     //4: w_file_name = "weight_itile0_otile0_kij4.txt";
     //5: w_file_name = "weight_itile0_otile0_kij5.txt";
     //6: w_file_name = "weight_itile0_otile0_kij6.txt";
     //7: w_file_name = "weight_itile0_otile0_kij7.txt";
     //8: w_file_name = "weight_itile0_otile0_kij8.txt";
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
    case(kij)
     //0: w_file_name = "weight_itile0_otile0_kij0.txt";
     //1: w_file_name = "weight_itile0_otile0_kij1.txt";
     //2: w_file_name = "weight_itile0_otile0_kij2.txt";
     //3: w_file_name = "weight_itile0_otile0_kij3.txt";
     //4: w_file_name = "weight_itile0_otile0_kij4.txt";
     //5: w_file_name = "weight_itile0_otile0_kij5.txt";
     //6: w_file_name = "weight_itile0_otile0_kij6.txt";
     //7: w_file_name = "weight_itile0_otile0_kij7.txt";
     //8: w_file_name = "weight_itile0_otile0_kij8.txt";
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

    A_pmem[9:6] = kij;
    A_pmem[5:0] = 0;


    w_file = $fopen(w_file_name, "r");
    // Following three lines are to remove the first three comment lines of the file
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);
    w_scan_file = $fscanf(w_file,"%s", captured_data);

    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0; 
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   





    /////// Kernel data writing to memory ///////

    A_xmem = 11'b10000000000; xw_mode = 1;

    for (t=0; t<col; t=t+1) begin  
      #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
      //$display("%b", D_xmem); 
      //$display("%b", core_instance.weight_sram.D);
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; 
    /////////////////////////////////////



    /////// Kernel data writing to L0 ///////
    A_xmem = 11'b10000000000;  xw_mode = 1;
    for (t=0; t<col; t=t+1) begin
	    #0.5 clk = 1'b0; CEN_xmem = 0;
	    if (t > 0)  begin
		    A_xmem = A_xmem + 1; 
		    l0_wr = 1; 
	    end
      #0.5 clk = 1'b1;
      //if (t > 1) $display("%b", core_instance.weight_sram.Q);
    end

    #0.5 clk = 1'b0; CEN_xmem = 1; A_xmem = 0;     
    #0.5 clk = 1'b1; //$display("%b", core_instance.weight_sram.Q);

    #0.5 clk = 1'b0; l0_wr = 0;
    #0.5 clk = 1'b1; //$display("%b", core_instance.weight_sram.Q);
    

    /////////////////////////////////////


    /////// Kernel loading to PEs ///////
    for (t=0; t<col; t=t+1) begin
      #0.5 clk = 1'b0; l0_rd = 1; load = 1;
      #0.5 clk = 1'b1;
      if (t > 0) begin
              load = 1;
              //$display("%b", core_instance.corelet_instance.l0_instance.rd_en);
              //$display("%b", core_instance.corelet_instance.l0_instance.out);

              end
    end
    /////////////////////////////////////
  


    ////// provide some intermission to clear up the kernel loading ///
    #0.5 clk = 1'b0;  l0_rd = 0; load = 0;
    #0.5 clk = 1'b1;  //$display("%b", core_instance.corelet_instance.l0_instance.out);
  
    #0.5 clk = 1'b0;  //load = 0;
    #0.5 clk = 1'b1;  //$display("%b", core_instance.corelet_instance.l0_instance.out);

    for (i=0; i<16 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end
    /////////////////////////////////////

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

      


    /////// Activation data writing to L0 ///////
    A_xmem = 11'b00000000000;  xw_mode = 0;
    for (t=0; t<len_nij; t=t+1) begin
	    #0.5 clk = 1'b0; CEN_xmem = 0;
	    if (t > 0) begin
		    A_xmem = A_xmem + 1;
		    l0_wr = 1;
	    end
      #0.5 clk = 1'b1;
      //$display("%d", core_instance.activation_sram.A);
      //if (t > 1) $display("%b", core_instance.activation_sram.Q);

    end

    #0.5 clk = 1'b0; CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; //$display("%b", core_instance.activation_sram.Q);
    
    #0.5 clk = 1'b0; l0_wr = 0;
    #0.5 clk = 1'b1; //$display("%b", core_instance.activation_sram.Q);
    /////////////////////////////////////


    //#0.5 clk = 1'b0; l0_rd = 0; load = 1;
    //#0.5 clk = 1'b1; //$display("%b", core_instance.activation_sram.Q);

    //#0.5 clk = 1'b0; l0_rd = 0; load = 0;
    //#0.5 clk = 1'b1; //$display("%b", core_instance.activation_sram.Q);

    /////// Execution ///////
    $display("Execution begins.\n");
    for (t = 0; t < len_nij; t=t+1) begin
      #0.5 clk = 1'b0; l0_rd = 1; execute = 1;
      #0.5 clk = 1'b1;
      if (t > 1) begin
	      execute = 1;
	      //$display("%b", core_instance.corelet_instance.l0_instance.out);
      end
end

    #0.5 clk = 1'b0; l0_rd = 0; execute = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;

    // Wait for last element to load
    for (t = 0; t < col; t=t+1) begin
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
    for (t = 0; t < len_nij*2; t=t+1) begin
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
    for (t = 0; t < len_nij; t=t+1) begin
            #0.5 clk = 1'b0; 
            if (ofifo_valid) begin
                    ofifo_rd = 1;
            end            

            CEN_pmem = 0; WEN_pmem = 0;
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
    #0.5 clk = 1'b0; ofifo_rd = 0; CEN_pmem = 1; WEN_pmem = 1;

    //$display("%d", core_instance.activation_sram.A);
    //$display("%b", core_instance.activation_sram.D);
  end  // end of kij loop


  ////////// Accumulation /////////
  out_file = $fopen("out.txt", "r");  

  // Following three lines are to remove the first three comment lines of the file
  out_scan_file = $fscanf(out_file,"%s", answer); 
  out_scan_file = $fscanf(out_file,"%s", answer); 
  out_scan_file = $fscanf(out_file,"%s", answer); 

  error = 0; A_pmem = 0; pmem_mode = 1; A_pmem_sfp[10] = 1;

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

  for (i=0; i<len_onij+1; i=i+1) begin 

    #0.5 clk = 1'b0;
    CEN_pmem = 1; WEN_pmem = 1; 
	    //$display("Writing to PMEM.");
            //$display("Address: %d", A_pmem);
            //$display("Address: %d", core_instance.psum_sram.A);
            //$display("Data in: %128b", core_instance.psum_sram.D);
 
    #0.5 clk = 1'b1; 

    if (i>0) begin
     out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer
     
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
   
 
    #0.5 clk = 1'b0; reset = 1; sfp_reset = 1; CEN_pmem = 1; WEN_pmem = 1; A_pmem[10] = 0;
    #0.5 clk = 1'b1;  
    #0.5 clk = 1'b0; reset = 0; sfp_reset = 0;     #0.5 clk = 1'b1;  

    for (j=0; j<len_kij+1; j=j+1) begin 

      #0.5 clk = 1'b0;   relu_en = 0;
        if (j<len_kij) begin 
		CEN_pmem = 0; WEN_pmem = 1; 
        //acc_scan_file = $fscanf(acc_file,"%11b", A_pmem);
        A_pmem[5:0] = $floor(i / o_ni_dim) * a_pad_ni_dim + i % o_ni_dim + $floor(j / ki_dim) * a_pad_ni_dim + j % ki_dim;
        A_pmem[9:6] = j;
        end
                       else  begin CEN_pmem = 1; WEN_pmem = 1; end

                       //$display("Address: %d", core_instance.psum_sram.A);
                       if (j>0)  begin acc = 1; 
                       //$display("Input: %b", core_instance.corelet_instance.sfp_instance.in_psum);
                       //$display("Output: %b", core_instance.corelet_instance.sfp_instance.out_accum);
               end
               if (j == len_kij) begin
                       relu_en = 1;
               end
               
      #0.5 clk = 1'b1;   
    end

    #0.5 clk = 1'b0; acc = 0; relu_en = 0;
    #0.5 clk = 1'b1;
    #0.5 clk = 1'b0;
    if (i > 0) begin 
	     A_pmem_sfp = A_pmem_sfp + 1; 
     end
     A_pmem = A_pmem_sfp;
     //$display("Input: %b", core_instance.corelet_instance.sfp_instance.in_psum);
    //$display("Output: %b", core_instance.corelet_instance.sfp_instance.out_accum);
     if (i < len_onij)  begin
	    CEN_pmem = 0; WEN_pmem = 0;
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
  out_scan_file = $fscanf(out_file,"%s", answer); 
  out_scan_file = $fscanf(out_file,"%s", answer); 
  out_scan_file = $fscanf(out_file,"%s", answer); 

  #0.5 clk = 1'b0;
  A_pmem_sfp[9:0] = 0;
  A_pmem = A_pmem_sfp;
  #0.5 clk = 1'b1;

  for (t=0; t<len_onij; t=t+1) begin
	#0.5 clk = 1'b0; CEN_pmem = 0; WEN_pmem = 1;
	if (t > 0) begin
	  A_pmem_sfp = A_pmem_sfp + 1;
	  A_pmem = A_pmem_sfp;
	end
	if (t > 1) begin
	  A_pmem = A_pmem_sfp;
          out_scan_file = $fscanf(out_file,"%128b", answer); // reading from out file to answer
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

  #0.5 clk = 1'b0; CEN_pmem = 1; WEN_pmem = 1; A_pmem = 0; pmem_mode = 0;
  #0.5 clk = 1'b1;


  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

  #10 $finish;

end

always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   A_xmem_q   <= A_xmem;
   ofifo_rd_q <= ofifo_rd;
   acc_q      <= acc;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;

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




