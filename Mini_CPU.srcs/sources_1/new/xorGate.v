module xorG (
    input  a,
    input  b,
    output y
);
//    wire temp;
    xnor u1 (y, a, b);   // temp = a & b
    
endmodule

module xorGate #(parameter N=32)(
  input  [N-1:0] a,
  input  [N-1:0] b,
  output  [N-1:0] Y
);

    genvar i;
    wire any1;
    generate
        for (i = 0; i < N; i = i + 1) begin: G
            xorG u_xor (.a(a[i]), .b(b[i]), .y(Y[i]));
        end
    endgenerate
 
endmodule