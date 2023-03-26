// *****************************************************************************
// (c) Copyright 2022-2032 , Inc. All rights reserved.
// Module Name  :
// Design Name  :
// Project Name :
// Create Date  : 2022-12-21
// Description  :
//
// *****************************************************************************

module harness;

// -------------------------------------------------------------------
// Constant Parameter
// -------------------------------------------------------------------
parameter                                        PERIOD_CLK = 10;

// -------------------------------------------------------------------
// Internal Signals Declarations
// -------------------------------------------------------------------
logic                                            clk;
logic                                            rst_n;
      
logic                                            start;
logic                                            exit;
logic                                      [7:0] data_in;      
logic                                            data_in_vld;  
logic                                            data_in_rdy;  
logic                                      [7:0] data_out;     
logic                                            data_out_vld; 
logic                                            data_out_rdy; 
logic                                            decode_finish;
logic                                            reg_finish;
// -------------------------------------------------------------------
// fadb wave
// -------------------------------------------------------------------
initial begin
  $fsdbDumpfile("harness.fsdb");
  $fsdbDumpvars(0,"harness");
  $fsdbDumpMDA();
end

function integer myclog2 (input integer n);
begin
  n                                              = n - 1;
  for (myclog2 = 0; n > 0; myclog2 = myclog2 + 1)
    n                                            = n >> 1;
end
endfunction

// -------------------------------------------------------------------
// clock & reset
// -------------------------------------------------------------------
initial begin
  clk                        = 1'b0;
  rst_n                      = 1'b1;
  # 100 rst_n = 1'b0;
  # 100 rst_n = 1'b1;
end

always #(PERIOD_CLK/2) clk = ~clk;

initial begin
  #300;
  while(1)begin
    @(posedge reg_finish);
    $display("Decode finished!");
  end
end

always @(posedge clk or negedge rst_n) begin
  if(rst_n == 1'b0)begin
    reg_finish <= 1'b0;
  end
  else begin
    reg_finish <= decode_finish;
  end
end

// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------

// -----------------> testcase load
`include "./testcase.sv"

// -----------------> DUT Instance

inflate DUT(
    .clk            (clk          ),
    .rst_n          (rst_n        ),
    .start          (start        ),
    .exit           (exit         ),
    .data_in        (data_in      ),
    .data_in_vld    (data_in_vld  ),
    .data_in_rdy    (data_in_rdy  ),
    .data_out       (data_out     ),
    .data_out_vld   (data_out_vld ),
    .data_out_rdy   (data_out_rdy ),
    .decode_finish  (decode_finish)
);
// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
endmodule
