module clk_gate(input clk, input en, output clk_out);

reg clk_latch;

always @ (negedge clk) begin
   	 clk_latch <= en;
end

assign clk_out = clk && clk_latch;
endmodule
