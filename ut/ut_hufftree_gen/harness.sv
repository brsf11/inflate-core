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

logic                                            inc;
logic [8:0]                                      tree_num;
logic [4:0]                                      buff_data;
logic [8:0]                                      buff_addr_bias;
logic [8:0]                                      buff_addr;
logic [7:0]                                      huff_code;
logic [7:0]                                      huff_addr;
logic [3:0]                                      huff_len;
logic                                            winc;
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

hufftree_gen #(
    .HUFF_CODE_LEN                     (8                                      )
    ) DUT
    (
    .clk                               (clk                                    ),
    .rst_n                             (rst_n                                  ),
    .inc                               (inc                                    ),
    .tree_num                          (tree_num                               ),
    .buff_data                         (buff_data                              ),
    .buff_addr_bias                    (buff_addr_bias                         ),
    .buff_addr                         (buff_addr                              ),
    .huff_code                         (huff_code                              ),
    .huff_addr                         (huff_addr                              ),
    .huff_len                          (huff_len                               ),
    .winc                              (winc                                   )
    );

reg [4:0] buff_mem[15:0];

initial begin
  buff_mem[0] = 5'd3;
  buff_mem[1] = 5'd3;
  buff_mem[2] = 5'd3;
  buff_mem[3] = 5'd4;
  buff_mem[4] = 5'd3;
  buff_mem[5] = 5'd2;
  buff_mem[6] = 5'd0;
  buff_mem[7] = 5'd4;
  buff_mem[8] = 5'd0;
  buff_mem[9] = 5'd3;
end

reg [8:0] reg_buff_addr;
always @(posedge clk or negedge rst_n) begin
  if(rst_n == 1'b0)begin
    reg_buff_addr <= 9'b0;
  end
  else begin
    reg_buff_addr <= buff_addr;
  end
end

assign buff_data = buff_mem[reg_buff_addr];
// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
endmodule
