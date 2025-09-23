module subN #(parameter N=32)(
  input  [N-1:0] A, B,
  output [N-1:0] D,
  output         cout,
  output carry_into_msb
);

  wire [N-1:0] Bn = ~B;           // bitwise NOT is a gate op
  addN #(N) add (.A(A), .B(Bn), .cin(1'b1), .S(D), .cout(cout), .carry_into_msb(carry_into_msb) );
endmodule
