module lz_extractor(
    input        clk,
    input        rst_n,
    input        en,
    input        data_in_vld,
    input [4:0]  data_in,
    input [5:0]  ext_bits,
    output       data_in_rdy,
    input        data_out_rdy,
    output [3:0] data_out,
    output       data_out_vld,
    output [8:0] buff_addr
);

    reg [4:0] data_in_buffer;
    reg       buffer_vld;
    reg [5:0] ext_bits_buffer;

    wire commit;

    localparam LIT                     = 2'b00;
    localparam LEN                     = 2'b01;
    localparam DIST                    = 2'b10;
    localparam COPY                    = 2'b11;

    reg [1:0]               state,nxt_state;

    


endmodule