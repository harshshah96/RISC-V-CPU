//==============================================
// ccr.v : Condition Code Register (flags)
// - Stores ALU status flags (Z, N, C, V)
//==============================================

module cc (
    input        clk,
    input        rst,       // active-high reset
    input        we,        // write enable
    input  [3:0] flags_in,  // {Z, N, C, V}
    output [3:0] flags_out
);

    reg [3:0] ccr_reg;

    always @(posedge clk) begin
        if (rst)
            ccr_reg <= 4'b0000;
        else if (we)
            ccr_reg <= flags_in;
    end

    assign flags_out = ccr_reg;

endmodule
