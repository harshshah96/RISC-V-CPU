//====================================================
// cpu_top.v — Single-cycle mini-CPU (word-addressed PC)
// - 16 GPRs + PC + SP + CCR
// - R/I/J formats (6-bit opcode)
// - ALU ops (reg/reg & reg/imm), shifts, CMP/CMPI/TST
// - LD/ST, BEQ/BNE/BLT/ BLE /BGT/BGE, JMP/CALL/RET
//====================================================
module cpu_top (
    input  wire clk,
    input  wire rst
);
  // -----------------------------
  // Instruction and Data memory (simple reg arrays)
  // -----------------------------
  parameter IMEM_SIZE = 256;
  parameter DMEM_SIZE = 256;

  reg [31:0] IMEM [0:IMEM_SIZE-1];
  reg [31:0] DMEM [0:DMEM_SIZE-1];
  
  // -----------------------------
  // Programmer-visible state
  // -----------------------------
  wire [31:0] PC_val;   // word index
  wire [31:0] SP_val;

  // pc_next computed combinationally
  wire [31:0] pc_next;

  // PC register
  pc U_PC(
    .clk(clk),
    .rst(rst),
    .pc_next(pc_next),
    .pc_out(PC_val)
  );

  // SP register
  wire        sp_we;
  wire [31:0] sp_next;
  sp U_SP(
    .clk(clk),
    .rst(rst),
    .sp_next(sp_next),
    .we(sp_we),
    .sp_out(SP_val)
  );

  // CCR register (Z N C V)
  wire        ccr_we;
  wire [3:0]  ccr_in, ccr_out;
  cc U_CCR(
    .clk(clk),
    .rst(rst),
    .we(ccr_we),
    .flags_in(ccr_in),
    .flags_out(ccr_out)
  );

  // -----------------------------
  // Instruction Fetch (word-addressed)
  // -----------------------------
  wire [31:0] IR;
  assign IR = IMEM[PC_val];

  // -----------------------------
  // Field decode (our formats)
  // -----------------------------
  wire [5:0]  opcode = IR[31:26];
  wire [3:0]  rd     = IR[25:22];
  wire [3:0]  rs1    = IR[21:18];
  wire [3:0]  rs2    = IR[17:14];
  wire [17:0] imm18  = IR[17:0];

  // Sign-extend immediate
  wire [31:0] imm32  = {{14{imm18[17]}}, imm18}; // 18->32

  // -----------------------------
  // Register file
  // -----------------------------
  wire [31:0] rs1_data, rs2_data;
  wire        reg_we;
  wire [31:0] rd_wdata;

  register U_RF(
    .clk(clk),
    .rst(rst),
    .ra1(rs1),
    .ra2(rs2),
    .wa(rd),
    .we(reg_we),
    .wd(rd_wdata),
    .rd1(rs1_data),
    .rd2(rs2_data)
  );

  // -----------------------------
  // ALU operand select
  // -----------------------------
  wire use_imm;            // from control: 1 => opB=imm32
  wire [31:0] opA = rs1_data;
  wire [31:0] opB = (use_imm ? imm32 : rs2_data);

  // -----------------------------
  // ALU
  // -----------------------------
  wire [3:0]  alu_op;      // small code inside ALU
  wire [31:0] alu_Y;
  wire [3:0]  alu_flags;   // {Z,N,C,V}
  wire [4:0]  shamt = imm32[4:0]; // use low 5 bits for shifts

  alu32 U_ALU(
    .A(opA),
    .B(opB),
    .shamt(shamt),
    .alu_op(alu_op),
    .Y(alu_Y),
    .Flag(alu_flags)
  );

  // connect ALU flags to CCR input (latched only if ccr_we)
  assign ccr_in = alu_flags;

  // -----------------------------
  
  wire        mem_we;        // write enable
  wire        mem_re;        // read enable
  wire [31:0] eff_addr;      // effective address = rs1 + imm
  wire [31:0] dmem_rdata;
  // Data memory interface (word addressed)
  memory MEM (
    .clk(clk),
    .rst(rst),
    // Instruction side
    .pc_addr(PC_val),
    .instr_out(IR),
    // Data side
    .mem_we(mem_we),
    .mem_re(mem_re),
    .mem_addr(eff_addr),
    .mem_wdata(rs2_data),
    .mem_rdata(dmem_rdata)
);

  // -----------------------------
  
  
  // Effective address via adder (no '+')
  addN #(32) U_EADDR(
    .A(rs1_data),
    .B(imm32),
    .cin(1'b0),
    .S(eff_addr),
    .cout(), .carry_into_msb()
  );

  // DMEM read (async) and write (sync)
  assign dmem_rdata = DMEM[eff_addr];

  always @(posedge clk) begin
    if (mem_we) DMEM[eff_addr] <= rs2_data;
  end

  // -----------------------------
  // Stack push/pop for CALL/RET (word addressed)
  // -----------------------------
  // compute SP-1 and SP+1 using adders
  wire [31:0] sp_dec, sp_inc;
  addN #(32) U_SP_DEC(.A(SP_val), .B(~32'd0), .cin(1'b1), .S(sp_dec), .cout(), .carry_into_msb()); // SP - 1
  addN #(32) U_SP_INC(.A(SP_val), .B(32'd1),  .cin(1'b0), .S(sp_inc), .cout(), .carry_into_msb()); // SP + 1

  // temp wire to write return address (PC+1) on CALL
  wire [31:0] pc_plus1;
  addN #(32) U_PC_INC(.A(PC_val), .B(32'd1), .cin(1'b0), .S(pc_plus1), .cout(), .carry_into_msb());

  // -----------------------------
  // Next PC selection (pc_src)
  // -----------------------------
  // We’ll assemble possible targets and let control pick.
  // PC+1 already computed (pc_plus1)

  // Branch target: PC+1 + imm32 (offset is in words already)
  wire [31:0] pc1_plus_off;
  addN #(32) U_BR_TGT(.A(pc_plus1), .B(imm32), .cin(1'b0), .S(pc1_plus_off), .cout(), .carry_into_msb());

  // Jump target:
  // Option A (simple): use rs1 as absolute word address (JR/JMP via register)
  wire [31:0] jmp_target = rs1_data;

  // CALL target: also via rs1 (consistent with your J-type-by-register)
  wire [31:0] call_target = rs1_data;

  // RET target will be loaded from stack top (DMEM[SP_val])
  wire [31:0] ret_target = DMEM[SP_val];

  // pc_src encoding
  localparam PC_NEXT_PLUS1   = 3'd0;
  localparam PC_NEXT_BRANCH  = 3'd1;
  localparam PC_NEXT_JUMP    = 3'd2;
  localparam PC_NEXT_CALL    = 3'd3;
  localparam PC_NEXT_RET     = 3'd4;

  wire [2:0] pc_src;

  reg [31:0] pc_next_r;
  always @* begin
    case (pc_src)
      PC_NEXT_PLUS1:  pc_next_r = pc_plus1;
      PC_NEXT_BRANCH: pc_next_r = pc1_plus_off;
      PC_NEXT_JUMP:   pc_next_r = jmp_target;
      PC_NEXT_CALL:   pc_next_r = call_target;
      PC_NEXT_RET:    pc_next_r = ret_target;
      default:        pc_next_r = pc_plus1;
    endcase
  end
  assign pc_next = pc_next_r;

  // -----------------------------
  // Writeback mux
  // -----------------------------
  // 0: ALU result, 1: DMEM read, 2: MOV (pass rs1), 3: LUI (upper imm)
  wire [1:0] wb_sel;
  wire [31:0] lui_val = {imm18, 14'b0}; // example: place imm high (tweak per your spec)

  reg [31:0] rd_wdata_r;
  always @* begin
    case (wb_sel)
      2'd0: rd_wdata_r = alu_Y;
      2'd1: rd_wdata_r = dmem_rdata;
      2'd2: rd_wdata_r = rs1_data;
      2'd3: rd_wdata_r = lui_val;
      default: rd_wdata_r = alu_Y;
    endcase
  end
  assign rd_wdata = rd_wdata_r;

  // -----------------------------
  // Branch condition logic (from CCR)
  // -----------------------------
  wire Z = ccr_out[3];
  wire N = ccr_out[2];
  wire C = ccr_out[1];
  wire V = ccr_out[0];

  wire LT = (N ^ V);
  wire LE = LT | Z;
  wire GT = (~(N ^ V)) & (~Z);
  wire GE = (~(N ^ V)) |  (Z);

  // -----------------------------
  // Opcode map (6-bit) — adjust to your exact table
  // -----------------------------
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

  // ALU sub-op map (to match your alu32)
  localparam ALU_ADD=4'h0, ALU_SUB=4'h1, ALU_AND=4'h2, ALU_OR =4'h3,
             ALU_XOR=4'h4, ALU_SLL=4'h5, ALU_SRL=4'h6, ALU_SRA=4'h7,
             ALU_CMP=4'h8, ALU_NOT=4'h9,
             ALU_INC=4'hA, ALU_DEC=4'hB,
             ALU_TST=4'hC;  // flags from A&B, no writeback

  // -----------------------------
  // Control Unit (combinational decode)
  control CU (
  .opcode(opcode),
  .flags(ccr_out),     // {Z,N,C,V} from CCR
  .reg_we(reg_we),
  .mem_we(mem_we),
  .mem_re(mem_re),
  .ccr_we(ccr_we),
  .use_imm(use_imm),
  .alu_op(alu_op),
  .wb_sel(wb_sel),
  .pc_src(pc_src),
  .is_call(is_call),
  .is_ret(is_ret)
);

  // -----------------------------
  reg        r_reg_we, r_mem_we, r_mem_re, r_ccr_we, r_use_imm, r_sp_we;
  reg [3:0]  r_alu_op;
  reg [2:0]  r_pc_src;
  reg [1:0]  r_wb_sel;

  always @* begin
    // safe defaults
    r_reg_we  = 1'b0;
    r_mem_we  = 1'b0;
    r_mem_re  = 1'b0;
    r_ccr_we  = 1'b0;
    r_sp_we   = 1'b0;
    r_use_imm = 1'b0;
    r_pc_src  = PC_NEXT_PLUS1;
    r_wb_sel  = 2'd0;
    r_alu_op  = ALU_ADD;

    case (opcode)
      // Arithmetic / logic (reg-reg)
      OP_ADD:  begin r_alu_op=ALU_ADD; r_reg_we=1; r_ccr_we=1; end
      OP_SUB:  begin r_alu_op=ALU_SUB; r_reg_we=1; r_ccr_we=1; end
      OP_MUL:  begin r_alu_op=ALU_ADD; r_reg_we=1; r_ccr_we=1; /* use your ALU's MUL path if present */ end
      OP_AND:  begin r_alu_op=ALU_AND; r_reg_we=1; r_ccr_we=1; end
      OP_OR:   begin r_alu_op=ALU_OR;  r_reg_we=1; r_ccr_we=1; end
      OP_XOR:  begin r_alu_op=ALU_XOR; r_reg_we=1; r_ccr_we=1; end
      OP_NOT:  begin r_alu_op=ALU_NOT; r_reg_we=1; r_ccr_we=1; end
      OP_INC:  begin r_alu_op=ALU_INC; r_reg_we=1; r_ccr_we=1; end
      OP_DEC:  begin r_alu_op=ALU_DEC; r_reg_we=1; r_ccr_we=1; end

      // Arithmetic / logic (reg-imm)
      OP_ADDI: begin r_use_imm=1; r_alu_op=ALU_ADD; r_reg_we=1; r_ccr_we=1; end
      OP_ANDI: begin r_use_imm=1; r_alu_op=ALU_AND; r_reg_we=1; r_ccr_we=1; end
      OP_ORI:  begin r_use_imm=1; r_alu_op=ALU_OR;  r_reg_we=1; r_ccr_we=1; end
      OP_XORI: begin r_use_imm=1; r_alu_op=ALU_XOR; r_reg_we=1; r_ccr_we=1; end

      // Shifts (use shamt=imm[4:0])
      OP_SLL:  begin r_alu_op=ALU_SLL; r_reg_we=1; r_ccr_we=1; end
      OP_SRL:  begin r_alu_op=ALU_SRL; r_reg_we=1; r_ccr_we=1; end
      OP_SRA:  begin r_alu_op=ALU_SRA; r_reg_we=1; r_ccr_we=1; end

      // Compare / test (flags only)
      OP_CMP:  begin r_alu_op=ALU_CMP; r_reg_we=0; r_ccr_we=1; end
      OP_CMPI: begin r_use_imm=1; r_alu_op=ALU_CMP; r_reg_we=0; r_ccr_we=1; end
      OP_TST:  begin r_alu_op=ALU_TST; r_reg_we=0; r_ccr_we=1; end

      // Memory
      OP_LD:   begin r_use_imm=1; r_mem_re=1; r_reg_we=1; r_ccr_we=0; r_wb_sel=2'd1; end
      OP_ST:   begin r_use_imm=1; r_mem_we=1; r_reg_we=0; r_ccr_we=0; end

      // Branches (use CCR)
      OP_BEQ:  begin r_pc_src = (Z  ? PC_NEXT_BRANCH : PC_NEXT_PLUS1); end
      OP_BNE:  begin r_pc_src = (~Z ? PC_NEXT_BRANCH : PC_NEXT_PLUS1); end
      OP_BLT:  begin r_pc_src = (LT ? PC_NEXT_BRANCH : PC_NEXT_PLUS1); end
      OP_BLE:  begin r_pc_src = (LE ? PC_NEXT_BRANCH : PC_NEXT_PLUS1); end
      OP_BGT:  begin r_pc_src = (GT ? PC_NEXT_BRANCH : PC_NEXT_PLUS1); end
      OP_BGE:  begin r_pc_src = (GE ? PC_NEXT_BRANCH : PC_NEXT_PLUS1); end

      // Jumps / Calls / Returns
      OP_JMP:  begin r_pc_src=PC_NEXT_JUMP; end

      OP_CALL: begin
        // push return address then jump
        // Push: SP <- SP-1; DMEM[SP-1] <- PC+1
        // We'll commit in seq block below using sp_we & DMEM write
        r_pc_src = PC_NEXT_CALL;
      end

      OP_RET:  begin
        // pc_next <- DMEM[SP]; SP <- SP+1
        r_pc_src = PC_NEXT_RET;
      end

      // Moves / LUI
      OP_MOV:  begin r_reg_we=1; r_ccr_we=0; r_wb_sel=2'd2; end
      OP_LUI:  begin r_reg_we=1; r_ccr_we=0; r_wb_sel=2'd3; end

      default: begin /* NOP */ end
    endcase
  end

  // Drive real outputs from reg signals
  assign reg_we   = r_reg_we;
  assign mem_we   = r_mem_we;
  assign mem_re   = r_mem_re;
  assign ccr_we   = r_ccr_we;
  assign use_imm  = r_use_imm;
  assign pc_src   = r_pc_src;
  assign wb_sel   = r_wb_sel;
  assign alu_op   = r_alu_op;

  // -----------------------------
  // CALL/RET stack side effects (sequential commit)
  // -----------------------------
  // CALL: push (PC+1) at SP-1, then SP := SP-1
  // RET : PC loads from DMEM[SP], then SP := SP+1
  // For simplicity, do the SP updates here.
  always @(posedge clk) begin
    if (rst) begin
      // Optionally init SP near top of DMEM
    end else begin
      // CALL
      if (opcode == OP_CALL) begin
        // write return address at (SP_val - 1)
        DMEM[sp_dec] <= pc_plus1;
      end
    end
  end

  // Select next SP value and write-enable
  reg [31:0] sp_next_r;
  reg        sp_we_r;
  always @* begin
    sp_we_r   = 1'b0;
    sp_next_r = SP_val;

    case (opcode)
      OP_CALL: begin sp_we_r=1; sp_next_r=sp_dec; end
      OP_RET:  begin sp_we_r=1; sp_next_r=sp_inc; end
      default: begin end
    endcase
  end
  assign sp_we   = sp_we_r;
  assign sp_next = sp_next_r;

  // -----------------------------
  // OPTIONAL: preload IMEM from file in simulation
  // -----------------------------
  // initial $readmemh("program.hex", IMEM);

endmodule
