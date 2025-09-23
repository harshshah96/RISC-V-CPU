//=======================================================
// barrel32.v
// Unified 32-bit Barrel Shifter (No <<, >>, >>> operators)
// mode = 2'b00 -> SLL (Shift Left Logical)
// mode = 2'b01 -> SRL (Shift Right Logical)
// mode = 2'b10 -> SRA (Shift Right Arithmetic)
//=======================================================
module barrel32 (
    input  [31:0] in,
    input  [4:0]  shamt,
    input  [1:0]  mode,      // 00=SLL, 01=SRL, 10=SRA
    output [31:0] out, 
    output [3:0] flag   
);

    wire [31:0] s1, s2, s4, s8, s16;
    reg  [31:0] result;
    reg  C, V;  // Carry, Overflow
    wire Z, N;

    genvar i;

    //-------------------------
    // Stage 1: shift by 1
    //-------------------------
    generate
      for (i=0;i<32;i=i+1) begin: STAGE1
        wire left_src  = (i==0)  ? 1'b0    : in[i-1];        // SLL
        wire right_src = (i==31) ? 1'b0    : in[i+1];        // SRL
        wire arith_src = (i==31) ? in[31]  : in[i+1];        // SRA
        mux3 m (.a(in[i]), .b(left_src), .c(right_src), .d(arith_src),
                .sel_mode(mode), .sel(shamt[0]), .y(s1[i]));
      end
    endgenerate

    //-------------------------
    // Stage 2: shift by 2
    //-------------------------
    generate
      for (i=0;i<32;i=i+1) begin: STAGE2
        wire left_src  = (i<2)  ? 1'b0   : s1[i-2];
        wire right_src = (i>=30)? 1'b0   : s1[i+2];
        wire arith_src = (i>=30)? in[31] : s1[i+2];
        mux3 p (.a(s1[i]), .b(left_src), .c(right_src), .d(arith_src),
                .sel_mode(mode), .sel(shamt[1]), .y(s2[i]));
      end
    endgenerate

    //-------------------------
    // Stage 3: shift by 4
    //-------------------------
    generate
      for (i=0;i<32;i=i+1) begin: STAGE3
        wire left_src  = (i<4)  ? 1'b0   : s2[i-4];
        wire right_src = (i>=28)? 1'b0   : s2[i+4];
        wire arith_src = (i>=28)? in[31] : s2[i+4];
        mux3 q (.a(s2[i]), .b(left_src), .c(right_src), .d(arith_src),
                .sel_mode(mode), .sel(shamt[2]), .y(s4[i]));
      end
    endgenerate

    //-------------------------
    // Stage 4: shift by 8
    //-------------------------
    generate
      for (i=0;i<32;i=i+1) begin: STAGE4
        wire left_src  = (i<8)  ? 1'b0   : s4[i-8];
        wire right_src = (i>=24)? 1'b0   : s4[i+8];
        wire arith_src = (i>=24)? in[31] : s4[i+8];
        mux3 r (.a(s4[i]), .b(left_src), .c(right_src), .d(arith_src),
                .sel_mode(mode), .sel(shamt[3]), .y(s8[i]));
      end
    endgenerate

    //-------------------------
    // Stage 5: shift by 16
    //-------------------------
    generate
      for (i=0;i<32;i=i+1) begin: STAGE5
        wire left_src  = (i<16) ? 1'b0   : s8[i-16];
        wire right_src = (i>=16)? 1'b0   : s8[i+16];
        wire arith_src = (i>=16)? in[31] : s8[i+16];
        mux3 t (.a(s8[i]), .b(left_src), .c(right_src), .d(arith_src),
                .sel_mode(mode), .sel(shamt[4]), .y(s16[i]));
      end
    endgenerate

    //-------------------------
    // Final result
    //-------------------------
    assign out = s16;

    //-------------------------
    // Flags
    //-------------------------
    assign Z = ~(|s16);
    assign N = s16[31];

    // Carry = last shifted-out bit
    always @(*) begin
        case (mode)
          2'b00: C = (shamt==0) ? 1'b0 : in[32-shamt];  // SLL
          2'b01: C = (shamt==0) ? 1'b0 : in[shamt-1];   // SRL
          2'b10: C = (shamt==0) ? 1'b0 : in[shamt-1];   // SRA
          default: C = 1'b0;
        endcase
    end

    // Overflow logic
    always @(*) begin
        case (mode)
          2'b00: V = (shamt==0) ? 1'b0 : (s16[31] ^ in[31]); // sign change for SLL
          2'b01: V = 1'b0;  // SRL: overflow not defined
          2'b10: V = 1'b0;  // SRA: sign preserved
          default: V = 1'b0;
        endcase
    end

    assign flag = {Z, N, C, V};

endmodule

//-------------------------------------------------------
// 3-way mux for shift modes
// sel=0 -> pass input a
// sel=1 -> pick from b/c/d depending on mode
//-------------------------------------------------------
module mux3 (
    input  a, b, c, d,
    input  [1:0] sel_mode,
    input  sel,
    output y
);
    assign y = (sel==0) ? a :
               (sel_mode==2'b00) ? b :   // SLL
               (sel_mode==2'b01) ? c :   // SRL
               d;                         // SRA
endmodule
