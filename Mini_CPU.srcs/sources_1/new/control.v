`timescale 1ns/1ps

//====================================================
// control.v — Hardwired Control Unit (single-cycle)
// - Decodes 6-bit opcode
// - Consumes CCR flags {Z,N,C,V} for branches
// - Drives ALU op, reg write, mem R/W, CCR write, WB mux,
//   PC next-source, and CALL/RET helpers.
//====================================================
module control (
    input  [5:0] opcode,     // IR[31:26]
    input  [3:0] flags,      // {Z,N,C,V} from CCR
    output reg        reg_we,
    output reg        mem_we,
    output reg        mem_re,
    output reg        ccr_we,
    output reg        use_imm,  // select opB = imm32 when 1, else rs2
    output reg [3:0]  alu_op,   // to ALU
    output reg [1:0]  wb_sel,   // 0=ALU, 1=DMEM, 2=pass rs1 (MOV), 3=LUI
    output reg [2:0]  pc_src,   // 0=PC+1, 1=branch, 2=jump, 3=call, 4=ret
    output reg        is_call,  // top will push (PC+1) at SP-1 and SP:=SP-1
    output reg        is_ret    // top will PC:=DMEM[SP]; SP:=SP+1
);

  // ---- PC src encodings (keep aligned with cpu_top) ----
  localparam PC_NEXT_PLUS1   = 3'd0;
  localparam PC_NEXT_BRANCH  = 3'd1;
  localparam PC_NEXT_JUMP    = 3'd2;
  localparam PC_NEXT_CALL    = 3'd3;
  localparam PC_NEXT_RET     = 3'd4;

  // ---- Opcode map (adjust to your ISA table) ----
  localparam OP_ADD  = 6'h00, OP_SUB  = 6'h01, OP_MUL  = 6'h02,
             OP_AND  = 6'h03, OP_OR   = 6'h04, OP_XOR  = 6'h05, OP_NOT  = 6'h06,
             OP_ADDI = 6'h08, OP_ANDI = 6'h09, OP_ORI  = 6'h0A, OP_XORI = 6'h0B,
             OP_SLL  = 6'h0C, OP_SRL  = 6'h0D, OP_SRA  = 6'h0E,
             OP_CMP  = 6'h0F, OP_CMPI = 6'h10, OP_TST  = 6'h11,
             OP_LD   = 6'h12, OP_ST   = 6'h13,
             OP_BEQ  = 6'h14, OP_BNE  = 6'h15, OP_BLT  = 6'h16, OP_BLE  = 6'h17,
             OP_BGT  = 6'h18, OP_BGE  = 6'h19,
             OP_JMP  = 6'h1A, OP_CALL = 6'h1B, OP_RET  = 6'h1C,
             OP_MOV  = 6'h1D, OP_LUI  = 6'h1E,
             OP_INC  = 6'h1F, OP_DEC  = 6'h20;

  // ---- ALU sub-ops (must match your alu32) ----
  localparam ALU_ADD=4'h0, ALU_SUB=4'h1, ALU_AND=4'h2, ALU_OR =4'h3,
             ALU_XOR=4'h4, ALU_SLL=4'h5, ALU_SRL=4'h6, ALU_SRA=4'h7,
             ALU_CMP=4'h8, ALU_NOT=4'h9,
             ALU_INC=4'hA, ALU_DEC=4'hB,
             ALU_TST=4'hC;

  // ---- Flags unpack ----
  wire Z = flags[3];
  wire N = flags[2];
  wire C = flags[1];
  wire V = flags[0];

  // Signed compare helpers from A-B
  wire LT = (N ^ V);
  wire LE = LT | Z;
  wire GT = (~(N ^ V)) & (~Z);
  wire GE = (~(N ^ V)) |  (Z);

  // ---- Defaults, then per-opcode overrides ----
  always @* begin
    // safe defaults
    reg_we   = 1'b0;
    mem_we   = 1'b0;
    mem_re   = 1'b0;
    ccr_we   = 1'b0;
    use_imm  = 1'b0;
    alu_op   = ALU_ADD;
    wb_sel   = 2'd0;
    pc_src   = PC_NEXT_PLUS1;
    is_call  = 1'b0;
    is_ret   = 1'b0;

    case (opcode)
      // ---------- ALU (reg-reg) ----------
      OP_ADD:  begin alu_op=ALU_ADD; reg_we=1; ccr_we=1; end
      OP_SUB:  begin alu_op=ALU_SUB; reg_we=1; ccr_we=1; end
      OP_MUL:  begin /* if you add MUL op in ALU, set code here */ reg_we=1; ccr_we=1; end
      OP_AND:  begin alu_op=ALU_AND; reg_we=1; ccr_we=1; end
      OP_OR:   begin alu_op=ALU_OR;  reg_we=1; ccr_we=1; end
      OP_XOR:  begin alu_op=ALU_XOR; reg_we=1; ccr_we=1; end
      OP_NOT:  begin alu_op=ALU_NOT; reg_we=1; ccr_we=1; end
      OP_INC:  begin alu_op=ALU_INC; reg_we=1; ccr_we=1; end
      OP_DEC:  begin alu_op=ALU_DEC; reg_we=1; ccr_we=1; end

      // ---------- ALU (reg-imm) ----------
      OP_ADDI: begin use_imm=1; alu_op=ALU_ADD; reg_we=1; ccr_we=1; end
      OP_ANDI: begin use_imm=1; alu_op=ALU_AND; reg_we=1; ccr_we=1; end
      OP_ORI:  begin use_imm=1; alu_op=ALU_OR;  reg_we=1; ccr_we=1; end
      OP_XORI: begin use_imm=1; alu_op=ALU_XOR; reg_we=1; ccr_we=1; end

      // ---------- Shifts (use imm[4:0] as shamt) ----------
      OP_SLL:  begin alu_op=ALU_SLL; reg_we=1; ccr_we=1; end
      OP_SRL:  begin alu_op=ALU_SRL; reg_we=1; ccr_we=1; end
      OP_SRA:  begin alu_op=ALU_SRA; reg_we=1; ccr_we=1; end

      // ---------- Compare / Test (flags only) ----------
      OP_CMP:  begin alu_op=ALU_CMP; reg_we=0; ccr_we=1; end
      OP_CMPI: begin use_imm=1; alu_op=ALU_CMP; reg_we=0; ccr_we=1; end
      OP_TST:  begin alu_op=ALU_TST; reg_we=0; ccr_we=1; end

      // ---------- Memory ----------
      OP_LD:   begin use_imm=1; mem_re=1; reg_we=1; ccr_we=0; wb_sel=2'd1; end
      OP_ST:   begin use_imm=1; mem_we=1; reg_we=0; ccr_we=0; end

      // ---------- Branches (signed) ----------
      OP_BEQ:  begin pc_src = Z  ? PC_NEXT_BRANCH : PC_NEXT_PLUS1; end
      OP_BNE:  begin pc_src = ~Z ? PC_NEXT_BRANCH : PC_NEXT_PLUS1; end
      OP_BLT:  begin pc_src = LT ? PC_NEXT_BRANCH : PC_NEXT_PLUS1; end
      OP_BLE:  begin pc_src = LE ? PC_NEXT_BRANCH : PC_NEXT_PLUS1; end
      OP_BGT:  begin pc_src = GT ? PC_NEXT_BRANCH : PC_NEXT_PLUS1; end
      OP_BGE:  begin pc_src = GE ? PC_NEXT_BRANCH : PC_NEXT_PLUS1; end

      // ---------- Unconditional flow ----------
      OP_JMP:  begin pc_src = PC_NEXT_JUMP; end
      OP_CALL: begin pc_src = PC_NEXT_CALL; is_call = 1'b1; end
      OP_RET:  begin pc_src = PC_NEXT_RET;  is_ret  = 1'b1; end

      // ---------- Moves / LUI ----------
      OP_MOV:  begin wb_sel=2'd2; reg_we=1; ccr_we=0; end
      OP_LUI:  begin wb_sel=2'd3; reg_we=1; ccr_we=0; end

      default: begin /* NOP by default */ end
    endcase
  end

endmodule
