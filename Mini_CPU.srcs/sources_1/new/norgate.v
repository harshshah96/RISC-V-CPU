module norG (
    input  a,
    input  b,
    output y
);
    wire temp;
    or u1 (temp, a, b);   // temp = a & b
    not u2 (y,temp);
    
endmodule

module norGate #(parameter N=32)(
  input  [N-1:0] a,
  input  [N-1:0] b,
  output  [N-1:0] y
);

    wire [N-1 : 0] temp;
    orGate u1 (.a(a), .b(b), .y(temp));
    notGate u2(.a(temp), .y(y));
endmodule