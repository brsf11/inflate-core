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
  start = 1'b0;
  exit = 1'b0;
  data_in = 8'b0;
  data_in_vld = 1'b0;
  data_out_rdy = 1'b0;
  #300;
  start = 1'b1;
  @(posedge clk);
  start = 1'b0;
  repeat(10) @(posedge clk);
  send_data(8'hDA);
  send_data(8'h91);
  send_data(8'h81);
  send_data(8'h40);
  send_data(8'hF8);
  send_data(8'hF6);
  send_data(8'h46);
  send_data(8'h96);
  send_data(8'h65);
  send_data(8'h67);
  send_data(8'hB1);
  send_data(8'h10);
  send_data(8'h2A);
  send_data(8'hD0);
  send_data(8'h24);
  send_data(8'hCD);
  send_data(8'hF6);
  send_data(8'hDF);
  send_data(8'h77);
  send_data(8'hD8);
  send_data(8'h1F);
  send_data(8'hE3);
  send_data(8'h89);
  send_data(8'hF1);
  send_data(8'h60);
  send_data(8'h3C);
  send_data(8'h18);
  send_data(8'h4F);
  send_data(8'h8C);
  send_data(8'h67);
  send_data(8'h00);

  @(posedge reg_finish);
  repeat(10) @(posedge clk);
  start = 1'b1;
  @(posedge clk);
  start = 1'b0;

  send_data(8'hDA);
  send_data(8'h91);
  send_data(8'h81);
  send_data(8'h40);
  send_data(8'hF8);
  send_data(8'hF6);
  send_data(8'h46);
  send_data(8'h96);
  send_data(8'h65);
  send_data(8'h67);
  send_data(8'hB1);
  send_data(8'h10);
  send_data(8'h2A);
  send_data(8'hD0);
  send_data(8'h24);
  send_data(8'hCD);
  send_data(8'hF6);
  send_data(8'hDF);
  send_data(8'h77);
  send_data(8'hD8);
  send_data(8'h1F);
  send_data(8'hE3);
  send_data(8'h89);
  send_data(8'hF1);
  send_data(8'h60);
  send_data(8'h3C);
  send_data(8'h18);
  send_data(8'h4F);
  send_data(8'h8C);
  send_data(8'h67);
  send_data(8'h00);

  

end



// -------------------------------------------------------------------
// Main Code
// -------------------------------------------------------------------
task send_data(input[7:0] data);
  data_in[7:0] = data;
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
