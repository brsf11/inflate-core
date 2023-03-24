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
  en = 1'b0;
  ext_bits = 6'b0;
  data_out_rdy = 1'b0;
  #300;
  en = 1'b1;
  send_data(1,0);
  send_data(2,0);
  send_data(3,0);
  send_data(4,0);
  send_data(5,0);
  send_data(6,0);
  send_data(7,0);
  send_data(8,0);

end



// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------
task send_data(input[4:0] data,input[5:0] bits);
  data_in[4:0] = data;
  ext_bits = bits;
  data_in_vld = 1'b1;
  @(posedge clk);
  while(data_in_rdy == 1'b0)begin
    @(posedge clk);
  end
  data_in_vld = 1'b0;
endtask

task recv_data();
  data_out_rdy = 1'b1;
  @(posedge clk);
  while(data_out_vld == 1'b0)begin
    @(posedge clk);
  end
  data_out_rdy = 1'b0;
  $display("Decoded data:%H",data_out);
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
