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
 
logic [4:0]                                      data_in;    
logic                                            data_in_vld;
logic                                            data_in_rdy;
logic [8:0]                                      buff_addr;  
logic [4:0]                                      buff_data; 
logic                                            winc;       
logic                                            finish;     
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

// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------

// -----------------> testcase load
`include "./testcase.sv"

// -----------------> DUT Instance

sq_extractor DUT(
    .clk              (clk               ),
    .rst_n            (rst_n             ),
    .data_in          (data_in           ),
    .data_in_vld      (data_in_vld       ),
    .data_in_rdy      (data_in_rdy       ),
    .buff_addr        (buff_addr         ),
    .buff_data        (buff_data         ),
    .winc             (winc              ),
    .finish           (finish            )
);
// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
endmodule
