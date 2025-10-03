//==============================================
// register.v
// 16x32 Register File
// - 2 read ports, 1 write port
// - synchronous write, asynchronous read
//==============================================
`timescale 1ns/1ps

module register (
    input              clk,
    input              rst,        // active-high reset
    input      [3:0]   ra1,        // read address 1
    input      [3:0]   ra2,        // read address 2
    input      [3:0]   wa,         // write address
    input              we,         // write enable
    input      [31:0]  wd,         // write data
    output     [31:0]  rd1,        // read data 1
    output     [31:0]  rd2         // read data 2
);

    // 16 registers, each 32-bit
    reg [31:0] R [0:15];

    integer i;

    // Reset logic (optional: clear registers to 0)
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                R[i] <= 32'd0;
            end
        end
        else if (we) begin
            R[wa] <= wd;
        end
    end

    // Asynchronous read
    assign rd1 = R[ra1];
    assign rd2 = R[ra2];

endmodule
