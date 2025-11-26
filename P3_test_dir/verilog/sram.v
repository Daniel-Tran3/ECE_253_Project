// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram (CLK, D, Q, CEN, WEN, A);

  parameter SIZE=2048;
  parameter WIDTH=128;
  parameter ADD_WIDTH=11;

  input  CLK;
  input  WEN;
  input  CEN;
  input  [WIDTH-1:0] D;
  input  [ADD_WIDTH-1:0] A;
  output [WIDTH-1:0] Q;

  reg [WIDTH-1:0] memory [SIZE-1:0];
  reg [ADD_WIDTH-1:0] add_q;
  wire [WIDTH-1:0] mem_1024;
  assign Q = memory[add_q];
  assign mem_1024 = memory[1024];

  always @ (posedge CLK) begin

   if (!CEN && WEN) // read 
      add_q <= A;
   if (!CEN && !WEN) // write
      memory[A] <= D; 

  end

endmodule
