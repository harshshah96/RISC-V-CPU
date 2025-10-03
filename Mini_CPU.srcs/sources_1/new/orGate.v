`timescale 1ns/1ps

module orG (
    input  a,
    input  b,
    output y
);
//    wire temp;
    or u1 (y, a, b);   // temp = a & b
    
endmodule

module orGate #(parameter N=32)(
  input  [N-1:0] a,
  input  [N-1:0] b,
  output  [N-1:0] Y
);


wire any1;
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin: G
            orG u_or (.a(a[i]), .b(b[i]), .y(Y[i]));
        end
    endgenerate  
endmodule