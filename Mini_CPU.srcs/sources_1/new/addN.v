`timescale 1ns/1ps

module fa1(input a, b, cin, output sum, cout);
  wire axb  = (~a & b) | (a & ~b);       // XOR(a,b)
  assign sum  = (~axb & cin) | (axb & ~cin); // XOR(axb,cin)
  assign cout = (a & b) | (axb & cin);   // carry out
endmodule


module addN #(parameter N=32) (
  input  [N-1:0] A, B,
  input          cin,
  output [N-1:0] S,
  output         cout,
  output         carry_into_msb
);
  wire [N:0] c;
  assign c[0] = cin;
  
  wire Z,Neg,C,V;
//  wire any1;

  genvar i;
  generate
    for (i=0; i<N; i=i+1) begin: G
      fa1 u (.a(A[i]), .b(B[i]), .cin(c[i]), .sum(S[i]), .cout(c[i+1]));
    end
  endgenerate
  assign cout = c[N];       // carry out of MSB
  assign carry_into_msb = c[N-1];  // carry into MSB
  
  wire any1 = |S;
  assign Z = ~any1;
  assign Neg = S[31];
  assign C = cout;// define borrow mapping carefully
  assign V =  cout ^ carry_into_msb ; // TODO: wire using carry_into_msb ^ carry_ot
  assign flag = {Z,Neg,C,V};
endmodule



