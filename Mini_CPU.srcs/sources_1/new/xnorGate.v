module xnorG (
    input  a,
    input  b,
    output y
);
//    wire temp;
    xnor u1 (y, a, b);   // temp = a & b
    
endmodule

module xnorGate #(parameter N=32)(
  input  [N-1:0] a,
  input  [N-1:0] b,
  output  [N-1:0] y
);

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin: G
            xnorG u_xnor (.a(a[i]), .b(b[i]), .y(y[i]));
        end
    endgenerate
endmodule