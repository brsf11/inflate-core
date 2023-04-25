// =============================================================================
// (c) Copyright 2022-2032 fastchip, Inc. All rights reserved.
// Module Name  : cm_fifo.v
// Design Name  : shilin.tao@fastchip.tech
// Project Name : FIFO
// Create Date  : 2023-01-09
// Description  :
//
// =============================================================================

`ifndef CM_FIFO__V
`define CM_FIFO__V

module CM_FIFO
   #(
    parameter FIFO_DEPTH               = 16,
    parameter DATA_WIDTH               = 32,
    parameter REG_OUT                  = 1,
    parameter NO_RST                   = 0,
    parameter ADDR_WIDTH               = (FIFO_DEPTH > 1) ? ceilLog2(FIFO_DEPTH) : 1'b1, // auto obtained
    parameter CNT_WIDTH                = ceilLog2(FIFO_DEPTH + 1'b1)                     // auto obtained
    )
    (
    input                                        clk,
    input                                        rst_n,
    input                                        flush,
    input                                        src_vld,
    input  [DATA_WIDTH-1:0]                      src_data,
    input  [CNT_WIDTH-1:0]                       afull_th,
    input                                        dst_rdy,
    input  [CNT_WIDTH-1:0]                       aempty_th,
    output reg                                   src_rdy,
    output reg                                   afull,
    output                                       ovfl,
    output reg                                   dst_vld,
    output reg [DATA_WIDTH-1:0]                  dst_data,
    output reg                                   aempty,
    output                                       udfl,
    output reg [CNT_WIDTH-1:0]                   cnt
    );

// -----------------------------------------------------------------------------
// Constant Parameter
// -----------------------------------------------------------------------------
localparam  [ADDR_WIDTH-1:0]   FIFO_DEPTH_MINUS_ONE = FIFO_DEPTH[ADDR_WIDTH-1:0] - 1'b1;

// ceilLog2 function
function integer ceilLog2 (input integer n);
  begin:CEILOG2
    integer m;
    m                     = n - 1;
    for (ceilLog2 = 0; m > 0; ceilLog2 = ceilLog2 + 1)
      m                   = m >> 1;
  end
endfunction

// -----------------------------------------------------------------------------
// Internal Signals Declarations
// -----------------------------------------------------------------------------
wire                                             src_rdy_nxt;
wire                                             dst_vld_nxt;
wire                                             afull_nxt;
wire                                             aempty_nxt;
wire                                             valid_write;
wire                                             valid_read;
wire [DATA_WIDTH-1:0]                            dst_data_nxt;
reg  [CNT_WIDTH-1:0]                             cnt_nxt;
reg  [ADDR_WIDTH-1:0]                            wptr;
reg  [ADDR_WIDTH-1:0]                            wptr_nxt;
reg  [ADDR_WIDTH-1:0]                            rptr;
reg  [ADDR_WIDTH-1:0]                            rptr_nxt;
reg  [DATA_WIDTH-1:0]                            fifo_mem [FIFO_DEPTH-1:0]  ;
reg  [DATA_WIDTH-1:0]                            fifo_mem_nxt [FIFO_DEPTH-1:0]  ;

// -----------------------------------------------------------------------------
// Main Code
// -----------------------------------------------------------------------------
assign valid_write      = src_rdy & src_vld;
assign valid_read       = dst_rdy & dst_vld;

// write pointer control logic
always @(*)
begin:WPTR_NXT_PROC
  wptr_nxt              = wptr;
  if(valid_write == 1'b1)
  begin

    if (wptr == FIFO_DEPTH_MINUS_ONE)
      wptr_nxt          = {ADDR_WIDTH{1'b0}};
    else
      wptr_nxt          = wptr + 1'b1;
  end
end

// read pointer control logic
always @(*)
begin:RPTR_NXT_PROC
  rptr_nxt              = rptr;
  if (valid_read == 1'b1)
  begin
    if (rptr == FIFO_DEPTH_MINUS_ONE)
      rptr_nxt          = {ADDR_WIDTH{1'b0}};
    else
      rptr_nxt          = rptr + 1'b1;
  end
end

// count control logic
always @(*)
begin:CNT_NXT_PROC
  case({valid_write,valid_read})
    2'b10: cnt_nxt      = cnt + 1'b1;
    2'b01: cnt_nxt      = cnt - 1'b1;
    default: cnt_nxt    = cnt;
  endcase
end

// flag output
assign src_rdy_nxt      = (cnt_nxt != FIFO_DEPTH[CNT_WIDTH-1:0]);
assign dst_vld_nxt      = (cnt_nxt != {CNT_WIDTH{1'b0}});
assign afull_nxt        = (cnt_nxt >= afull_th);
assign aempty_nxt       = (cnt_nxt <= aempty_th);
assign ovfl             = src_vld & (~src_rdy);
assign udfl             = (~dst_vld) & dst_rdy;

// DFF for some Signals
always @(posedge clk or negedge rst_n)
begin:DFF_PROC
  if (rst_n == 1'b0)
  begin
    wptr                <= {ADDR_WIDTH{1'b0}};
    rptr                <= {ADDR_WIDTH{1'b0}};
    cnt                 <= {CNT_WIDTH{1'b0}};
    src_rdy             <= 1'b1;
    dst_vld             <= 1'b0;
    afull               <= 1'b0;
    aempty              <= 1'b1;
  end
  else if (flush == 1'b1)
  begin
    wptr                <= {ADDR_WIDTH{1'b0}};
    rptr                <= {ADDR_WIDTH{1'b0}};
    cnt                 <= {CNT_WIDTH{1'b0}};
    src_rdy             <= 1'b1;
    dst_vld             <= 1'b0;
    afull               <= 1'b0;
    aempty              <= 1'b1;
  end
  else
  begin
    wptr                <= wptr_nxt;
    rptr                <= rptr_nxt;
    src_rdy             <= src_rdy_nxt;
    dst_vld             <= dst_vld_nxt;
    cnt                 <= cnt_nxt;
    afull               <= afull_nxt;
    aempty              <= aempty_nxt;
  end
end

// FIFO_MEM
genvar addr;
generate
  for(addr = 0; addr < FIFO_DEPTH; addr = addr + 1)
  begin:FIFO_MEM_NXT_LOOP
    always @(*)
    begin:FIFO_MEM_NXT_PRO
      fifo_mem_nxt[addr] = fifo_mem[addr];
      if ((valid_write == 1'b1)&&(addr[ADDR_WIDTH-1:0] == wptr))
        fifo_mem_nxt[addr] = src_data;
    end
  end
endgenerate

// select whether to reset fifo_mem
generate
  if (NO_RST == 1'b0)
  begin:MEM_RESET_BRANCH
    for (addr = 0; addr < FIFO_DEPTH; addr = addr + 1)
    begin:MEM_RESET_LOOP
      always @(posedge clk or negedge rst_n)
      begin:MEM_RESET_PRO
        if (rst_n == 1'b0)
          fifo_mem[addr] <= {DATA_WIDTH{1'b0}};
        else if (flush == 1'b1)
          fifo_mem[addr] <= {DATA_WIDTH{1'b0}};
        else
          fifo_mem[addr] <= fifo_mem_nxt[addr];
      end
    end
  end
  else
  begin:MEM_NO_RESET_BRANCH
    for (addr = 0; addr < FIFO_DEPTH; addr = addr + 1)
    begin:MEM_NO_RESET_LOOP
      always @(posedge clk)
      begin:MEM_NO_RESET_PRO
        fifo_mem[addr] <= fifo_mem_nxt[addr];
      end
    end
  end
endgenerate

// select whether to register output
generate
  if (REG_OUT == 1'b1)
  begin:REG_OUT_BRANCH
    assign dst_data_nxt     = fifo_mem_nxt[rptr_nxt];
    always @(posedge clk or negedge rst_n)
    begin:REG_OUT_PRO
      if (rst_n == 1'b0)
        dst_data        <= {DATA_WIDTH{1'b0}};
      else if (flush == 1'b1)
        dst_data        <= {DATA_WIDTH{1'b0}};
      else
        dst_data        <= dst_data_nxt;
    end
  end
  else
  begin:NO_REG_OUT_BRANCH
    always @(*)
    begin:NO_REG_OUT_PRO
      dst_data = fifo_mem[rptr];
    end
  end
endgenerate

// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
endmodule
`endif

//-----------------------------------------------------------------------//
// Modified Log
// 2023/01/10 initial version
// 2023/03/3 add input port flush
//-----------------------------------------------------------------------//
