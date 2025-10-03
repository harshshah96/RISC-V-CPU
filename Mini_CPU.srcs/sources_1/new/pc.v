//==============================================
// pc.v : Program Counter
// - Holds the current instruction address
// - Updates on each clock cycle or reset
// (clk, rst, pc_next, pc_out)
//==============================================
`timescale 1ns/1ps

module pc (
    input         clk,
    input         rst,         // active-high reset
    input  [31:0] pc_next,     // next PC value
    output [31:0] pc_out       // current PC value
);

    reg [31:0] pc_reg;

    always @(posedge clk) begin
        if (rst)
            pc_reg <= 32'd0;     // reset to 0 (start address)
        else
            pc_reg <= pc_next;   // update to next PC
    end

    assign pc_out = pc_reg;

endmodule
