`timescale 1ns/1ps

module alu32 #(parameter N=32)(
  input  [N-1:0] A, B,
  input  [4:0]   shamt,
  input  [3:0]   alu_op,   // 4-bit ALU code from CU
  output [N-1:0] Y,
  output [3:0]   Flag      // {Z,N,C,V}
);

  // build submodules once
  wire [N-1:0] addS, subD, sl, andY, orY, xorY, notY;
  wire addC, addCinMSB, subC, subCinMSB;
  wire Z,Nf,C,V;

  // adder and subtractor
  addN #(N) UADD (.A(A), .B(B), .cin(1'b0), .S(addS),
                  .cout(addC), .carry_into_msb(addCinMSB));
  subN #(N) USUB (.A(A), .B(B), .D(subD),
                  .cout(subC), .carry_into_msb(subCinMSB));

  // barrel shifter (mode depends on op)
  wire [1:0] mode = (alu_op==4'h5) ? 2'b00 :  // SLL
                    (alu_op==4'h6) ? 2'b01 :  // SRL
                    (alu_op==4'h7) ? 2'b10 :  // SRA
                                     2'b11;
  barrel32 U_SHIFT (.in(A), .mode(mode), .shamt(shamt), .out(sl), .flag());

  // basic gates
  andGate uAnd (.a(A),.b(B),.Y(andY));
  orGate  uOr  (.a(A),.b(B),.Y(orY));
  xorGate uXor (.a(A),.b(B),.Y(xorY));
  notGate uNot (.a(A),.Y(notY));

  // select result
  reg [N-1:0] y_r;
  always @* begin
    case (alu_op)
      4'h0: y_r = addS;   // ADD
      4'h1: y_r = subD;   // SUB
      4'h2: y_r = andY;   // AND
      4'h3: y_r = orY;    // OR
      4'h4: y_r = xorY;   // XOR
      4'h5: y_r = sl;     // SLL
      4'h6: y_r = sl;     // SRL
      4'h7: y_r = sl;     // SRA
      4'h8: y_r = subD;   // CMP (flags only)
      4'h9: y_r = notY;   // NOT
      4'hA: y_r = addS;   // INC (A+1)
      4'hB: y_r = subD;   // DEC (A-1)
      4'hC: y_r = andY;   // TST (flags only)
      default: y_r = {N{1'b0}};
    endcase
  end
  assign Y = y_r;

  // flag logic
  wire any1 = |Y;
  assign Z = ~any1;
  assign Nf = Y[N-1];
  assign C = (alu_op==4'h0 || alu_op==4'hA) ? addC :
             (alu_op==4'h1 || alu_op==4'h8 || alu_op==4'hB) ? ~subC : 1'b0;
  assign V = (alu_op==4'h0 || alu_op==4'hA) ? (addC ^ addCinMSB) :
             (alu_op==4'h1 || alu_op==4'h8 || alu_op==4'hB) ? (subC ^ subCinMSB) : 1'b0;

  assign Flag = {Z,Nf,C,V};

endmodule
