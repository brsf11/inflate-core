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
  #100000  $finish;
end

initial begin
  data_in = 5'b0;
  data_in_vld = 1'b0;
  #300;
  send_data(2);
  send_data(9);
  send_data(7);
  send_data(9);
  send_data(1);
  send_data(2);
  send_data(5);
  send_data(5);
  send_data(5);
  send_data(5);
  send_data(0);
  send_data(4);
  send_data(0);
  send_data(4);
  send_data(2);
  send_data(9);
  send_data(1);
  send_data(5);
  send_data(9);
  send_data(1);
  send_data(5);
  send_data(4);
  send_data(0);
  send_data(2);
  send_data(1);
  send_data(3);
  send_data(9);
  send_data(2);

end



// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------
task send_data(input[4:0] data);
  data_in[4:0] = data;
  data_in_vld = 1'b1;
  @(posedge clk);
  while(data_in_rdy == 1'b0)begin
    @(posedge clk);
  end
  data_in_vld = 1'b0;
endtask

task recv_data();
  @(posedge clk);
  while(winc == 1'b0)begin
    @(posedge clk);
  end
  $display("Decoded data:%H",buff_data);
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
