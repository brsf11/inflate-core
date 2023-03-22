module huffman_decoder #(
    parameter HUFF_CODE_LEN = 8,
    parameter HUFF_LEN_LEN  = ceilLog2(HUFF_CODE_LEN + 1)
    )
    (
    input                      clk,
    input                      rst_n,
    input                      pending,
    input                      data_in_vld,
    input [7:0]                data_in,
    output                     data_in_rdy,
    output [HUFF_CODE_LEN-1:0] huff_addr,
    input [HUFF_LEN_LEN-1:0]   lit_huff_len,
    input [4:0]                lit_huff_code,
    input [HUFF_LEN_LEN-1:0]   dist_huff_len,
    input [4:0]                dist_huff_code,
    input                      mode,            //mode 0 refers to standard mode, 1 refers to lz sequence decode mode
    output                     data_out_vld,
    output [4:0]               data_out,
    output reg [5:0]           ext_bits,
    input                      data_out_rdy
    );
    // ceilLog2 function
    function integer ceilLog2 (input integer n);
    begin:CEILOG2
        integer m;
        m                     = n - 1;
        for (ceilLog2 = 0; m > 0; ceilLog2 = ceilLog2 + 1)
        m                     = m >> 1;
    end
    endfunction

    reg [15:0] buffer;
    reg        huff_code_vld;
    reg [4:0]  buffer_pointer; // point to last valid buffer data bit
    reg        dist_sel;

    wire [HUFF_LEN_LEN-1:0] mux_huff_len;
    assign mux_huff_len = dist_sel ? dist_huff_len : lit_huff_len;
    
    wire [HUFF_LEN_LEN-1:0] final_len;


    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            huff_code_vld  <= 1'b0;
            buffer_pointer <= 5'd16;
        end
        else begin
            if(pending == 1'b1)begin
                huff_code_vld  <= 1'b0;
                buffer_pointer <= buffer_pointer; 
            end
            else begin
                if((data_out_vld & data_out_rdy) == 1'b1)begin
                    huff_code_vld  <= 1'b0;
                    buffer_pointer <= buffer_pointer + final_len; 
                end
                else if((data_in_rdy & data_in_vld) == 1'b1)begin
                    huff_code_vld  <= 1'b0;
                    buffer_pointer <= buffer_pointer - 8; 
                end
                else begin
                    huff_code_vld  <= 1'b1;
                    buffer_pointer <= buffer_pointer; 
                end
            end
        end
    end

    wire [15:0] buffer_after_read[8:0];

    assign buffer_after_read[0][15:0] = {buffer[15:8] ,data_in};
    assign buffer_after_read[1][15:0] = {buffer[15:9] ,data_in,buffer[0]};
    assign buffer_after_read[2][15:0] = {buffer[15:10],data_in,buffer[1:0]};
    assign buffer_after_read[3][15:0] = {buffer[15:11],data_in,buffer[2:0]};
    assign buffer_after_read[4][15:0] = {buffer[15:12],data_in,buffer[3:0]};
    assign buffer_after_read[5][15:0] = {buffer[15:13],data_in,buffer[4:0]};
    assign buffer_after_read[6][15:0] = {buffer[15:14],data_in,buffer[5:0]};
    assign buffer_after_read[7][15:0] = {buffer[15]   ,data_in,buffer[6:0]};
    assign buffer_after_read[8][15:0] = {data_in,buffer[7:0]};

    reg [15:0] buffer_new_val;
    always @* begin
        case(buffer_pointer)
            5'b01000: buffer_new_val         = buffer_after_read[0][15:0];
            5'b01001: buffer_new_val         = buffer_after_read[1][15:0];
            5'b01010: buffer_new_val         = buffer_after_read[2][15:0];
            5'b01011: buffer_new_val         = buffer_after_read[3][15:0];
            5'b01100: buffer_new_val         = buffer_after_read[4][15:0];
            5'b01101: buffer_new_val         = buffer_after_read[5][15:0];
            5'b01110: buffer_new_val         = buffer_after_read[6][15:0];
            5'b01111: buffer_new_val         = buffer_after_read[7][15:0];
            5'b10000: buffer_new_val         = buffer_after_read[8][15:0];
            default:  buffer_new_val         = 16'b0;
        endcase
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buffer         <= 16'b0;
        end
        else begin
            if((data_out_vld & data_out_rdy) == 1'b1)begin
                buffer         <= buffer << final_len;
            end
            else if((data_in_rdy & data_in_vld) == 1'b1)begin
                buffer         <= buffer_new_val;
            end
            else begin
                buffer         <= buffer;
            end
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            dist_sel <= 1'b0;
        end
        else begin
            if((data_out_rdy & data_out_vld) == 1'b1)begin
                if((dist_sel == 1'b0) && (data_out > 5'd16) && (mode == 1'b1))begin
                    dist_sel <= 1'b1;
                end
                else begin
                    dist_sel <= 1'b0;
                end
            end
            else begin
                dist_sel <= dist_sel;
            end
        end
    end

    //output logic
    assign data_in_rdy  = (~data_out_vld) & (buffer_pointer >= 5'b01000) & (~pending);
    assign huff_addr    = buffer[15:8];
    assign data_out_vld = huff_code_vld & ((5'b10000 - buffer_pointer) >= {1'b0,final_len}) & (~pending);
    assign data_out     = dist_sel ? dist_huff_code : lit_huff_code;


    //extra bit logic
    wire [3:0] lit_ext_bits[28:0];
    wire [3:0] dist_ext_bits[15:0];
    wire [3:0] lit_ext_len,dist_ext_len;
    wire [3:0] final_huff_len,final_ext_len;

    assign lit_ext_len  = lit_ext_bits[data_out];
    assign dist_ext_len = dist_ext_bits[data_out];
    assign final_huff_len = dist_sel ? dist_huff_len : lit_huff_len;
    assign final_ext_len  = dist_sel ? dist_ext_len : lit_ext_len;
    assign final_len    = final_huff_len + final_ext_len;

    //extra bit length table
    //lit
    assign lit_ext_bits[0]  = 4'b0000;
    assign lit_ext_bits[1]  = 4'b0000;
    assign lit_ext_bits[2]  = 4'b0000;
    assign lit_ext_bits[3]  = 4'b0000;
    assign lit_ext_bits[4]  = 4'b0000;
    assign lit_ext_bits[5]  = 4'b0000;
    assign lit_ext_bits[6]  = 4'b0000;
    assign lit_ext_bits[7]  = 4'b0000;
    assign lit_ext_bits[8]  = 4'b0000;
    assign lit_ext_bits[9]  = 4'b0000;
    assign lit_ext_bits[10] = 4'b0000;
    assign lit_ext_bits[11] = 4'b0000;
    assign lit_ext_bits[12] = 4'b0000;
    assign lit_ext_bits[13] = 4'b0000;
    assign lit_ext_bits[14] = 4'b0000;
    assign lit_ext_bits[15] = 4'b0000;
    assign lit_ext_bits[16] = 4'b0000;
    assign lit_ext_bits[17] = 4'b0000;
    assign lit_ext_bits[18] = 4'b0000;
    assign lit_ext_bits[19] = 4'b0000;
    assign lit_ext_bits[20] = 4'b0000;
    assign lit_ext_bits[21] = 4'b0001;
    assign lit_ext_bits[22] = 4'b0001;
    assign lit_ext_bits[23] = 4'b0001;
    assign lit_ext_bits[24] = 4'b0010;
    assign lit_ext_bits[25] = 4'b0011;
    assign lit_ext_bits[26] = 4'b0011;
    assign lit_ext_bits[27] = 4'b0101;
    assign lit_ext_bits[28] = 4'b0110;
    //dist
    assign dist_ext_bits[0]  = 4'b0000;
    assign dist_ext_bits[1]  = 4'b0000;
    assign dist_ext_bits[2]  = 4'b0000;
    assign dist_ext_bits[3]  = 4'b0000;
    assign dist_ext_bits[4]  = 4'b0001;
    assign dist_ext_bits[5]  = 4'b0001;
    assign dist_ext_bits[6]  = 4'b0010;
    assign dist_ext_bits[7]  = 4'b0010;
    assign dist_ext_bits[8]  = 4'b0100;
    assign dist_ext_bits[9]  = 4'b0101;
    assign dist_ext_bits[10] = 4'b0101;
    assign dist_ext_bits[11] = 4'b0101;
    assign dist_ext_bits[12] = 4'b0101;
    assign dist_ext_bits[13] = 4'b0101;
    assign dist_ext_bits[14] = 4'b0101;
    assign dist_ext_bits[15] = 4'b0101;

    //extra bits output logic
    always @* begin
        case({final_huff_len,final_ext_len[2:0]})
            7'b0001_001: ext_bits = {5'b0,buffer[15-1:15-0-1]};
            7'b0001_010: ext_bits = {4'b0,buffer[15-1:15-1-1]};
            7'b0001_011: ext_bits = {3'b0,buffer[15-1:15-2-1]};
            7'b0001_100: ext_bits = {2'b0,buffer[15-1:15-3-1]};
            7'b0001_101: ext_bits = {1'b0,buffer[15-1:15-4-1]};
            7'b0001_110: ext_bits =       buffer[15-1:15-5-1];

            7'b0010_001: ext_bits = {5'b0,buffer[15-2:15-0-2]};
            7'b0010_010: ext_bits = {4'b0,buffer[15-2:15-1-2]};
            7'b0010_011: ext_bits = {3'b0,buffer[15-2:15-2-2]};
            7'b0010_100: ext_bits = {2'b0,buffer[15-2:15-3-2]};
            7'b0010_101: ext_bits = {1'b0,buffer[15-2:15-4-2]};
            7'b0010_110: ext_bits =       buffer[15-2:15-5-2];

            7'b0011_001: ext_bits = {5'b0,buffer[15-3:15-0-3]};
            7'b0011_010: ext_bits = {4'b0,buffer[15-3:15-1-3]};
            7'b0011_011: ext_bits = {3'b0,buffer[15-3:15-2-3]};
            7'b0011_100: ext_bits = {2'b0,buffer[15-3:15-3-3]};
            7'b0011_101: ext_bits = {1'b0,buffer[15-3:15-4-3]};
            7'b0011_110: ext_bits =       buffer[15-3:15-5-3];

            7'b0100_001: ext_bits = {5'b0,buffer[15-4:15-0-4]};
            7'b0100_010: ext_bits = {4'b0,buffer[15-4:15-1-4]};
            7'b0100_011: ext_bits = {3'b0,buffer[15-4:15-2-4]};
            7'b0100_100: ext_bits = {2'b0,buffer[15-4:15-3-4]};
            7'b0100_101: ext_bits = {1'b0,buffer[15-4:15-4-4]};
            7'b0100_110: ext_bits =       buffer[15-4:15-5-4];

            7'b0101_001: ext_bits = {5'b0,buffer[15-5:15-0-5]};
            7'b0101_010: ext_bits = {4'b0,buffer[15-5:15-1-5]};
            7'b0101_011: ext_bits = {3'b0,buffer[15-5:15-2-5]};
            7'b0101_100: ext_bits = {2'b0,buffer[15-5:15-3-5]};
            7'b0101_101: ext_bits = {1'b0,buffer[15-5:15-4-5]};
            7'b0101_110: ext_bits =       buffer[15-5:15-5-5];

            7'b0110_001: ext_bits = {5'b0,buffer[15-6:15-0-6]};
            7'b0110_010: ext_bits = {4'b0,buffer[15-6:15-1-6]};
            7'b0110_011: ext_bits = {3'b0,buffer[15-6:15-2-6]};
            7'b0110_100: ext_bits = {2'b0,buffer[15-6:15-3-6]};
            7'b0110_101: ext_bits = {1'b0,buffer[15-6:15-4-6]};
            7'b0110_110: ext_bits =       buffer[15-6:15-5-6];

            7'b0111_001: ext_bits = {5'b0,buffer[15-7:15-0-7]};
            7'b0111_010: ext_bits = {4'b0,buffer[15-7:15-1-7]};
            7'b0111_011: ext_bits = {3'b0,buffer[15-7:15-2-7]};
            7'b0111_100: ext_bits = {2'b0,buffer[15-7:15-3-7]};
            7'b0111_101: ext_bits = {1'b0,buffer[15-7:15-4-7]};
            7'b0111_110: ext_bits =       buffer[15-7:15-5-7];

            7'b1000_001: ext_bits = {5'b0,buffer[15-8:15-0-8]};
            7'b1000_010: ext_bits = {4'b0,buffer[15-8:15-1-8]};
            7'b1000_011: ext_bits = {3'b0,buffer[15-8:15-2-8]};
            7'b1000_100: ext_bits = {2'b0,buffer[15-8:15-3-8]};
            7'b1000_101: ext_bits = {1'b0,buffer[15-8:15-4-8]};
            7'b1000_110: ext_bits =       buffer[15-8:15-5-8];

            default:     ext_bits = 6'b0;
        endcase
    end

endmodule