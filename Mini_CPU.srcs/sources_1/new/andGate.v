`timescale 1ns/1ps

module andG (
    input  a,
    input  b,
    output y
);
//    wire temp;
    assign y = a&b;   // temp = a & b
    
endmodule

module andGate #(parameter N=32)(
  input  [N-1:0] a,
  input  [N-1:0] b,
  output  [N-1:0] Y
  );

    
    wire any1;

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin: G
            andG u_and (.a(a[i]), .b(b[i]), .y(Y[i]));
        end
    endgenerate
     
endmodule