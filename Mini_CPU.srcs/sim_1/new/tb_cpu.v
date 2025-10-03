`timescale 1ns/1ps

module tb_cpu;

  reg clk;
  reg rst;

  // Instantiate CPU
  cpu_top UUT (
    .clk(clk),
    .rst(rst)
  );

    initial begin
      #1;
      $display("IMEM[0]=%h, IMEM[1]=%h", UUT.MEM.IMEM[0], UUT.MEM.IMEM[1]);
    end
  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz
  end

  // Stimulus
  initial begin
    rst = 1;
    #20 rst = 0;

    // Preload instructions
//    $readmemh("program.hex", UUT.MEM.IMEM);

    // Run for some time
    #200;

    // Dump DMEM[0] result
    $display("Result stored in DMEM[0] = %d (expected 15)", UUT.MEM.DMEM[0]);

    $finish;
  end

  // Waveform
  initial begin
    $dumpfile("cpu_wave.vcd");
    $dumpvars(0, tb_cpu);
  end

endmodule
