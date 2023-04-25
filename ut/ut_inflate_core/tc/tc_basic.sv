// *****************************************************************************
// (c) Copyright 2022-2032 , Inc. All rights reserved.
// Module Name  :
// Design Name  :
// Project Name :
// Create Date  : 2022-12-21
// Description  :
//
// *****************************************************************************

// -------------------------------------------------------------------
// Constant Parameter
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// Internal Signals Declarations
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// initial
// -------------------------------------------------------------------
initial begin
  PSEL                  <= 1'h0;
  PENABLE               <= 1'h0;
  PWRITE                <= 1'h0;
  PADDR                 <= 12'h0;
  PWDATA                <= 32'h0;
end

task apb_w(
  input   [31:0] addr,
  input   [31:0] wdata,
  input    [1:0]            end_idle_cyc = $urandom
);
begin
  #0.1ns;
  PSEL                  <= 1'b1;
  PENABLE               <= 1'b0;
  PWRITE                <= 1'b1;
  PWDATA                <= wdata;
  PADDR                 <= addr;
  @(posedge clk);
  #0.1ns;
  PENABLE               <= 1'b1;
  //wait PREADY assert high
  @(posedge clk);
  while (PREADY === 1'b0) begin
    @(posedge clk);
  end
  //@(posedge clk);
  //#0.1ns;
  repeat (end_idle_cyc) begin
    #0.1ns;
    PSEL                  <= 1'b0;
    PENABLE               <= 1'b0;
    @(posedge clk);
  end
end
endtask


initial begin
  #100000  $finish;
end

initial begin
#300;
apb_w(32'h0000_0000,32'b0);
apb_w(32'h0000_0004,32'b0000_0001);


end



// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------

task recv_data();
  data_out_rdy = 1'b1;
  @(posedge clk);
  while(data_out_vld == 1'b0)begin
    @(posedge clk);
  end
  $display("Decoded data:%H",data_out);
  data_out_rdy = 1'b0;
endtask

initial begin
  #300;
  while(1)begin
    recv_data();
  end
end



// -------------------------------------------------------------------
// Assertion Declarations
// -------------------------------------------------------------------
`ifdef SOC_ASSERT_ON

`endif
