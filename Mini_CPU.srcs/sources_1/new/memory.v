//====================================================
// memory.v — Unified memory with stack support
// - Word-addressed (32-bit words)
// - Dual-port: instruction fetch + data access
// - Stack push/pop for CALL/RET
//====================================================
module memory #(
    parameter IMEM_SIZE = 256,
    parameter DMEM_SIZE = 256
)(
    input  wire        clk,
    input  wire        rst,

    // ---- Instruction memory interface ----
    input  wire [31:0] pc_addr,       // word address
    output wire [31:0] instr_out,

    // ---- Data memory interface ----
    input  wire        mem_we,        // write enable
    input  wire        mem_re,        // read enable
    input  wire [31:0] mem_addr,      // word address
    input  wire [31:0] mem_wdata,     // write data
    output wire [31:0] mem_rdata,     // read data

    // ---- Stack interface (for CALL/RET) ----
    input  wire        is_call,
    input  wire        is_ret,
    input  wire [31:0] sp_addr,       // current SP
    input  wire [31:0] ret_addr,      // PC+1 (to push)
    output wire [31:0] ret_target     // value popped on RET
);

    // ---------------------------------------
    // Instruction Memory (IMEM)
    // ---------------------------------------
    reg [31:0] IMEM [0:IMEM_SIZE-1];

    initial begin
        // preload IMEM if needed
        // $readmemh("program.hex", IMEM);
    end

    assign instr_out = IMEM[pc_addr[31:0]];

    // ---------------------------------------
    // Data Memory (DMEM + stack space)
    // ---------------------------------------
    reg [31:0] DMEM [0:DMEM_SIZE-1];
    reg [31:0] rdata_reg;

    // Normal data reads
    always @(*) begin
        if (mem_re)
            rdata_reg = DMEM[mem_addr[31:0]];
        else
            rdata_reg = 32'd0;
    end
    assign mem_rdata = rdata_reg;

    // Return target for RET (pop from stack)
    assign ret_target = DMEM[sp_addr[31:0]];

    // Writes (normal + CALL push) synchronous
    always @(posedge clk) begin
        if (rst) begin
            // Optionally clear DMEM
        end else begin
            // Normal store
            if (mem_we)
                DMEM[mem_addr[31:0]] <= mem_wdata;

            // CALL push: write return address at new SP
            if (is_call)
                DMEM[sp_addr[31:0]] <= ret_addr;
        end
    end

endmodule
