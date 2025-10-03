`timescale 1ns/1ps

module notG(
    input a,
    output y

    );
    assign y = ~a; 
endmodule


module notGate #(parameter N=32)(
  input  [N-1:0] a,
  output  [N-1:0] Y
);

    genvar i;
  
    wire any1;
    generate
        for (i = 0; i < N; i = i + 1) begin: G
            notG u_nor (.a(a[i]), .y(Y[i]));
        end
    endgenerate

endmodule