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
        
logic                                            en;             
logic                                            data_in_vld;    
logic                                      [4:0] data_in;        
logic                                      [5:0] ext_bits;       
logic                                            data_in_rdy;    
logic                                            data_out_rdy;   
logic                                      [3:0] data_out;       
logic                                            data_out_vld;   
logic                                      [8:0] buff_read_addr; 
logic                                      [8:0] buff_write_addr;
logic                                      [3:0] buff_data_in;   
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

lz_extractor DUT(
    .clk               (clk            ),
    .rst_n             (rst_n          ),
    .en                (en             ),
    .data_in_vld       (data_in_vld    ),
    .data_in           (data_in        ),
    .ext_bits          (ext_bits       ),
    .data_in_rdy       (data_in_rdy    ),
    .data_out_rdy      (data_out_rdy   ),
    .data_out          (data_out       ),
    .data_out_vld      (data_out_vld   ),
    .buff_read_addr    (buff_read_addr ),
    .buff_write_addr   (buff_write_addr),
    .buff_data_in      (buff_data_in   )
);

reg [4:0] buff_mem[511:0];


reg [8:0] reg_buff_addr;
always @(posedge clk or negedge rst_n) begin
  if(rst_n == 1'b0)begin
    reg_buff_addr <= 9'b0;
  end
  else begin
    reg_buff_addr <= buff_read_addr;
  end
end

always @(posedge clk) begin
  if(data_out_vld & data_out_rdy)begin
    buff_mem[buff_write_addr] = {1'b0,data_out};
  end
end

assign buff_data_in = buff_mem[reg_buff_addr][3:0];

// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
endmodule
