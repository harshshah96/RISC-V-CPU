module flagsN #(parameter N=32)(
  input  [N-1:0] S,
  input          carry_into_msb, 
  input          carry_out, // expose from adder
  output         Z, 
  output         Neg, 
  output         C,
  output         V
);
  // Z = ~(|S) built without reduction operator:
  // make a tree OR (here using reduction is fine as it's gate-level,
  // if you want pure gates, OR them manually in a small loop in synthesis)
  wire any1 = |S;         // allowed (bitwise reduce -> gate network)
  assign Z = ~any1;

  assign Neg = S[N-1];
  assign C = carry_out;
  assign V = carry_into_msb ^ carry_out;
endmodule
