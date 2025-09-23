module mux2(input a, input b, input sel, output y);
  // y = sel ? b : a  ->  y = (a & ~sel) | (b & sel)
  assign y = (a & ~sel) | (b & sel);
endmodule
