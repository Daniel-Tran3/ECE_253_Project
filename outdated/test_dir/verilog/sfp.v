module sfp (clk, reset, valid_in, relu_enable, l1_read_data, accum_out, write_enable);
    parameter col = 8;
    parameter psum_bw = 16;

    input  clk;
    input  reset;
    input  valid_in;        // indicates accumulation
    input  relu_enable;         // enables ReLU activation before output
    input  [psum_bw*col-1:0] l1_read_data;      // packed bus contained col values, each psum bits wide
    output reg [psum_bw*col-1:0] accum_out;     // packed accumulated result
    output reg write_enable;        // control signal

    // Internal accumulation storage
    reg signed [psum_bw-1:0] acc_reg [0:col-1];

    // Wires to hold unpacked L1 data
    wire signed [psum_bw-1:0] l1_vec [0:col-1];

    // Unpack L1 data using genvar k  
    genvar k;
    generate
        for (k = 0; k < col; k = k + 1) begin : UNPACK
            assign l1_vec[k] = l1_read_data[(k+1)*psum_bw-1 : k*psum_bw];
        end
    endgenerate

    // Accumulate using integer loop  
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < col; i = i + 1)
                acc_reg[i] <= 0;

            write_enable <= 0;
        end
        else begin
            write_enable <= valid_in;

            if (valid_in) begin
                for (i = 0; i < col; i = i + 1)
                    acc_reg[i] <= acc_reg[i] + l1_vec[i];
            end
        end
    end

    // Pack outputs
    generate
        for (k = 0; k < col; k = k + 1) begin : PACK
            always @(*) begin
                if (relu_enable && acc_reg[k] < 0)
                    accum_out[(k+1)*psum_bw-1 : k*psum_bw] = 0;
                else
                    accum_out[(k+1)*psum_bw-1 : k*psum_bw] = acc_reg[k];
            end
        end
    endgenerate

endmodule
