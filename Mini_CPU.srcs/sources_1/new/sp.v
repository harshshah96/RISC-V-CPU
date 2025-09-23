//==============================================
// sp.v : Stack Pointer
// - Can be incremented/decremented or loaded
// - Used for CALL/RET and stack operations
//(clk,rst,sp_next,we,sp_out
//==============================================

module sp (
    input         clk,
    input         rst,          // active-high reset
    input  [31:0] sp_next,      // next SP value
    input         we,           // write enable (update SP)
    output [31:0] sp_out        // current SP value
);

    reg [31:0] sp_reg;

    always @(posedge clk) begin
        if (rst)
            sp_reg <= 32'h0000_FFFC; // initialize stack near top of memory
        else if (we)
            sp_reg <= sp_next;
    end

    assign sp_out = sp_reg;

endmodule
