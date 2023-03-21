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
  pending = 1'b1;
  data_in_vld = 1'b0;
  data_in = 8'b0;
  mode = 1'b0;
  data_out_rdy = 1'b1;

  inc = 1'b0;
  tree_num = 6'd10;
  buff_addr_bias = 6'd0;
  #300;
  inc = 1'b1;
  @(posedge clk);
  inc = 1'b0;
  @(negedge finish);
  pending = 1'b0;
  send_data(8'hD9);
  send_data(8'hCF);
  send_data(8'h01);
  send_data(8'h50);
  send_data(8'hD5);
  send_data(8'hCC);
  send_data(8'hCC);
  send_data(8'h54);
  send_data(8'hF1);

end



// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------
task send_data(input[7:0] data);
  data_in[7:0] = {data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]};
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
