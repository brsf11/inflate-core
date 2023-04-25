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
      
logic                                            PWRITE;
logic                                            PSEL;
logic                                            PENABLE;
logic                                     [31:0] PWDATA;
logic                                     [31:0] PADDR;
logic                                     [31:0] PRDATA;
logic                                            HREADY;
logic                                     [31:0] HRDATA;
logic                                     [31:0] HADDR;
logic                                      [1:0] HTRANS;
logic                                     [15:0] data_out;
logic                                            data_out_vld;
logic                                            data_out_rdy;
logic                                            decode_finish;

logic                                      [9:0] BRAM_RDADDR;
logic                                      [9:0] BRAM_WRADDR;
logic                                     [31:0] BRAM_RDATA;
logic                                     [31:0] BRAM_WDATA;
logic                                      [3:0] BRAM_WRITE;

logic PREADY;
assign PREADY = 1'b1;

logic reg_finish;
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

inflate_core DUT(
    .*
);

AHBlite_Block_RAM #(
    .ADDR_WIDTH (10)
    ) AHB_BRAM_IF
    (
    .HCLK              (clk),    
    .HRESETn           (rst_n), 
    .HSEL              (1'b1),    
    .HADDR             (HADDR),   
    .HTRANS            (HTRANS),  
    .HSIZE             (3'b001),   
    .HPROT             (4'b0),   
    .HWRITE            (1'b0),  
    .HWDATA            (32'b0),   
    .HREADY            (HREADY), 
    .HREADYOUT         (HREADY), 
    .HRDATA            (HRDATA),  
    .HRESP             (),
    .BRAM_RDADDR       (BRAM_RDADDR),
    .BRAM_WRADDR       (BRAM_WRADDR),
    .BRAM_RDATA        (BRAM_RDATA ),
    .BRAM_WDATA        (BRAM_WDATA ),
    .BRAM_WRITE        (BRAM_WRITE )
);

Block_RAM #(
    .ADDR_WIDTH (10)
  ) BRAM  (
    .clka    (clk),
    .addra   (BRAM_WRADDR),
    .addrb   (BRAM_RDADDR),
    .dina    (BRAM_WDATA),
    .wea     (BRAM_WRITE),
    .doutb   (BRAM_RDATA)
);

// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
endmodule
