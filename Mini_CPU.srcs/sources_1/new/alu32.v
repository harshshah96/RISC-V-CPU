module alu32 #(parameter N=32)(
  input  [N-1:0] A, B,
  input  [4:0]  shamt,
  input  [3:0]  alu_op,      // e.g., 0000=ADD,0001=SUB,0010=AND,0011=OR,0100=XOR,0101=SHL,0110=SHR,0111=SAR,1000=CMP ...
  output [N-1:0] Y,
  output [3:0] Flag
);

      
  // build submodules once
  wire [N-1:0] addS, subD, sl, srlY, sraY, andY, orY, xorY, notY;
  wire [N-1:0] incY, decY;
  wire addC, addC_prev, subC, subC_prev, addCinMSB, subCinMSB; // expose carries for V
  wire Z,Neg,C,V;
  wire [1:0]mode ; 
  wire [3:0]flag;
  wire [3:0]flags_in;
  assign mode = (alu_op == 6'hC ) ? {2'b00} : {(alu_op == 6'hD ) ? {2'b01} : {(alu_op == 6'hE )? {2'b10} : {2'b11} }} ;
  
  
  // adder with cin=0
  // To get carry into MSB, either modify addN to expose c[N-1], or compute top stage separately.
  addN #(N) UADD (.A(A), .B(B), .cin(1'b0), .S(addS), .cout(addC), .carry_into_msb(addC_prev));
  subN #(N) USUB (.A(A), .B(B), .D(subD), .cout(subC),.carry_into_msb(subC_prev));
  
  // shifts
  barrel32 U_SLL (.in(A),.mode(mode), .shamt(shamt), .out(sl), .flag(flag));
  
  //Gates
  andGate uAnd (.a(A),.b(B),.Y(andY));
  orGate uOr (.a(A),.b(B),.Y(orY));
  xorGate uXor (.a(A),.b(B),.Y(xorY));
  notGate uNot (.a(A),.Y(notY));
  
//    i. EqualTo (==)                       -> a-b -> ( Z==1 )
//    ii. NotEqualTo( (!=)                  -> a-b -> ( Z==0 )
//    iii. LessThan (<)                     -> a-b -> ( Z==0 && N==1 )
//    iv. LessThanEqualTo (<=)               -> a-b -> ( Z==1 || (Z==0 && N==1 ))
//    v. GreaterThan (>)                     -> a-b -> ( Z==0 && N==0 )
//    vi. GreaterThanEqualTo (>=)            -> a-b -> ( Z==1 || (Z==0 && N==0 )  )
//    vii. The outcome should be stored in a CC register
  

  // logic (bitwise per bit with generate if you want to avoid vector ops)
//  assign andY = A & B;                 // if TA forbids '&' vector, implement bit by bit via generate
//  assign orY  = A | B;
//  assign xorY = (A & ~B) | (~A & B);
//  assign notY = ~A;

  
  // similar SRL and SAR modules…

  // select result
  reg [N-1:0] y_r;
  always @* begin
  case (alu_op)
    // Arithmetic
    4'h0: y_r = addS;         // ADD
    4'h1: y_r = subD;         // SUB
    4'h2: y_r = addS;         // INC  (A + 1)
    4'h3: y_r = subD;         // DEC  (A - 1)
//    4'h4: y_r = mulY;         // MUL  (from sequential multiplier)

    // Logical
    6'h5: y_r = andY;         // AND
    6'h6: y_r = orY;          // OR
    6'h7: y_r = xorY;         // XOR
    6'h8: y_r = notY;         // NOT

    // Shifts
    6'hC: y_r = sl;         // SHL (logical left)
    6'hD: y_r = sl;         // SHR (logical right)
    6'hE: y_r = sl;         // SAR (arithmetic right)

    // Compare / Test (flags only, no writeback)
    6'hF: y_r = subD;        // CMP rs1, rs2 // dont return output // Just for flag logic
    6'h10: y_r = subD;       // CMPI rs1, imm // dont return output // Just for flag logic
    6'h11: y_r = andY;       // TST rs1, rs2 (bitwise AND, flags only) // dont return output // Just for flag logic

    // Default
    default: y_r = 32'b0;
  endcase
end

  assign Y = y_r;
  
  // flags for ADD/SUB/CMP path
  // Expose carry_into_msb from addN/subN if you want exact V; or compute MSB cell separately.
  // Here we show simple versions; refine once you wire c[N-1].
  
  wire any1 = |Y;
  assign Z = ~any1;
  assign Neg = Y[31];
  assign C = (alu_op==6'h0 || alu_op==6'h2) ? addC :
             (alu_op==6'h1 || alu_op==6'hF || alu_op==6'h3 || alu_op==6'h10 ) ? ~subC : 1'b0; // define borrow mapping carefully
  assign V = (alu_op==6'h0 || alu_op==6'h2) ? addC ^ addC_prev  :
             (alu_op==6'h1 || alu_op==6'hF || alu_op==6'h3 || alu_op==6'h10 ) ? subC ^ subC_prev : 1'b0; // TODO: wire using carry_into_msb ^ carry_ot
  assign flags_in = (alu_op == 6'hC  || alu_op == 6'hD || alu_op == 6'hE ) ? flag : {Z,Neg, C ,V};
  
  cc UCC (.clk(clk) , .rst(rst), .we(1), .flags_in(flags_in), .flags_out(Flag));
  
             
  

endmodule
