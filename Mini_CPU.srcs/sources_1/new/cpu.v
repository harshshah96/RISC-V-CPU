//====================================================
// cpu_top.v — Single-cycle mini-CPU (word-addressed PC)
//====================================================
module cpu_top (
    input  wire clk,
    input  wire rst
);
  // -----------------------------
  // Programmer-visible state
  // -----------------------------
  wire [31:0] PC_val;
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
  // Instruction Fetch
  // -----------------------------
  wire [31:0] IR;

  // -----------------------------
  // Field decode
  // -----------------------------
  wire [5:0]  opcode = IR[31:26];
  wire [3:0]  rd     = IR[25:22];
  wire [3:0]  rs1    = IR[21:18];
  wire [3:0]  rs2    = IR[17:14];
  wire [17:0] imm18  = IR[17:0];
  

  // Sign-extend immediate
  wire [31:0] imm32  = {{14{imm18[17]}}, imm18};

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
  wire use_imm;
  wire [31:0] opA = rs1_data;
  wire [31:0] opB = (use_imm ? imm32 : rs2_data);

  // -----------------------------
  // ALU
  // -----------------------------
  wire [3:0]  alu_op;
  wire [31:0] alu_Y;
  wire [3:0]  alu_flags;
  wire [4:0]  shamt = imm32[4:0];

  alu32 U_ALU(
    .A(opA),
    .B(opB),
    .shamt(shamt),
    .alu_op(alu_op),
    .Y(alu_Y),
    .Flag(alu_flags)
  );

  // connect ALU flags to CCR input
  assign ccr_in = alu_flags;

  // -----------------------------
  // Effective address (rs1 + imm)
  // -----------------------------
  wire [31:0] eff_addr;
  addN #(32) U_EADDR(
    .A(rs1_data),
    .B(imm32),
    .cin(1'b0),
    .S(eff_addr),
    .cout(), .carry_into_msb()
  );

  // -----------------------------
  // Memory (Instruction + Data + Stack)
  // -----------------------------
  wire        mem_we;
  wire        mem_re;
  wire [31:0] dmem_rdata;
  wire        is_call, is_ret;
  wire [31:0] ret_target;
  wire [31:0] pc_plus1;

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
    .mem_rdata(dmem_rdata),
    // Stack side
    .is_call(is_call),
    .is_ret(is_ret),
    .sp_addr(SP_val),
    .ret_addr(pc_plus1),
    .ret_target(ret_target)
  );

  // -----------------------------
  // Stack pointer updates
  // -----------------------------
  wire [31:0] sp_dec, sp_inc;
  addN #(32) U_SP_DEC(.A(SP_val), .B(~32'd0), .cin(1'b1), .S(sp_dec), .cout(), .carry_into_msb()); // SP - 1
  addN #(32) U_SP_INC(.A(SP_val), .B(32'd1),  .cin(1'b0), .S(sp_inc), .cout(), .carry_into_msb()); // SP + 1

  // temp wire for PC+1
  
  addN #(32) U_PC_INC(.A(PC_val), .B(32'd1), .cin(1'b0), .S(pc_plus1), .cout(), .carry_into_msb());

  // SP update logic
  reg [31:0] sp_next_r;
  reg        sp_we_r;
  always @* begin
    sp_we_r   = 1'b0;
    sp_next_r = SP_val;
    if (is_call) begin
      sp_we_r   = 1'b1;
      sp_next_r = sp_dec;
    end else if (is_ret) begin
      sp_we_r   = 1'b1;
      sp_next_r = sp_inc;
    end
  end
  assign sp_we   = sp_we_r;
  assign sp_next = sp_next_r;

  // -----------------------------
  // Next PC selection
  // -----------------------------
  wire [31:0] pc1_plus_off;
  addN #(32) U_BR_TGT(.A(pc_plus1), .B(imm32), .cin(1'b0), .S(pc1_plus_off), .cout(), .carry_into_msb());

  wire [31:0] jmp_target  = rs1_data;
  wire [31:0] call_target = rs1_data;

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
  wire [1:0] wb_sel;
  wire [31:0] lui_val = {imm18, 14'b0};

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
  // Control Unit
  // -----------------------------
  control CU (
    .opcode(opcode),
    .flags(ccr_out),
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

endmodule
