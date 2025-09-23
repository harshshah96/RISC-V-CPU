module nandG (
    input  a,
    input  b,
    output y
);
    wire temp;
    and u1 (temp, a, b);   // temp = a & b
    not u2 (y, temp);      // y = ~temp
endmodule

module nandGate #(parameter N=32)(
  input  [N-1:0] a,
  input  [N-1:0] b,
  output  [N-1:0] y
);

    wire [N-1 : 0] temp;
    andGate u1 (.a(a), .b(b), .y(temp));
    notGate u2(.a(temp), .y(y));
endmodule