// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module rw_sram (
    CLK,
    D,
    Q,
    CEN,
    WEN,
    WA,
    RA
);

  parameter SIZE = 2048;
  parameter WIDTH = 128;
  parameter ADD_WIDTH = 11;

  input CLK;
  input WEN;
  input CEN;
  input [WIDTH-1:0] D;
  input [ADD_WIDTH-1:0] WA;
  input [ADD_WIDTH-1:0] RA;
  output [WIDTH-1:0] Q;

  reg [WIDTH-1:0] memory[SIZE-1:0];
  reg [ADD_WIDTH-1:0] add_q;
  assign Q = memory[add_q];

  always @(posedge CLK) begin

    if (!CEN)  // read
      add_q <= RA;
    if (!CEN && !WEN)  // write
      memory[WA] <= D;

  end

endmodule
