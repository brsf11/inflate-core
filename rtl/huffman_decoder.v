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
            5'd8:    buffer_new_val         = buffer_after_read[0][15:0];
            5'd9:    buffer_new_val         = buffer_after_read[1][15:0];
            5'd10:   buffer_new_val         = buffer_after_read[2][15:0];
            5'd11:   buffer_new_val         = buffer_after_read[3][15:0];
            5'd12:   buffer_new_val         = buffer_after_read[4][15:0];
            5'd13:   buffer_new_val         = buffer_after_read[5][15:0];
            5'd14:   buffer_new_val         = buffer_after_read[6][15:0];
            5'd15:   buffer_new_val         = buffer_after_read[7][15:0];
            5'd16:   buffer_new_val         = buffer_after_read[8][15:0];
            default: buffer_new_val         = 16'b0;
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
    assign data_in_rdy  = (~data_out_vld) & (buffer_pointer >= 5'd8) & (~pending);
    assign huff_addr    = buffer[15:8];
    assign data_out_vld = huff_code_vld & ((5'd16 - buffer_pointer) >= final_len) & (~pending);
    assign data_out     = dist_sel ? dist_huff_code : lit_huff_code;


    //extra bit logic
    wire [3:0] lit_ext_bits[28:0];
    wire [3:0] dist_ext_bits[15:0];
    wire [3:0] lit_ext_len,dist_ext_len;

    assign lit_ext_len  = lit_ext_bits[data_out];
    assign dist_ext_len = dist_ext_bits[data_out];
    assign final_len    = dist_sel ? (dist_huff_len + dist_ext_len) : (lit_huff_len + lit_ext_len);

    //extra bit length table
    //lit
    assign lit_ext_bits[0]  = 4'd0;
    assign lit_ext_bits[1]  = 4'd0;
    assign lit_ext_bits[2]  = 4'd0;
    assign lit_ext_bits[3]  = 4'd0;
    assign lit_ext_bits[4]  = 4'd0;
    assign lit_ext_bits[5]  = 4'd0;
    assign lit_ext_bits[6]  = 4'd0;
    assign lit_ext_bits[7]  = 4'd0;
    assign lit_ext_bits[8]  = 4'd0;
    assign lit_ext_bits[9]  = 4'd0;
    assign lit_ext_bits[10] = 4'd0;
    assign lit_ext_bits[11] = 4'd0;
    assign lit_ext_bits[12] = 4'd0;
    assign lit_ext_bits[13] = 4'd0;
    assign lit_ext_bits[14] = 4'd0;
    assign lit_ext_bits[15] = 4'd0;
    assign lit_ext_bits[16] = 4'd0;
    assign lit_ext_bits[17] = 4'd0;
    assign lit_ext_bits[18] = 4'd0;
    assign lit_ext_bits[19] = 4'd0;
    assign lit_ext_bits[20] = 4'd0;
    assign lit_ext_bits[21] = 4'd1;
    assign lit_ext_bits[22] = 4'd1;
    assign lit_ext_bits[23] = 4'd1;
    assign lit_ext_bits[24] = 4'd2;
    assign lit_ext_bits[25] = 4'd3;
    assign lit_ext_bits[26] = 4'd3;
    assign lit_ext_bits[27] = 4'd5;
    assign lit_ext_bits[28] = 4'd6;
    //dist
    assign dist_ext_bits[0]  = 4'd0;
    assign dist_ext_bits[1]  = 4'd0;
    assign dist_ext_bits[2]  = 4'd0;
    assign dist_ext_bits[3]  = 4'd0;
    assign dist_ext_bits[4]  = 4'd1;
    assign dist_ext_bits[5]  = 4'd1;
    assign dist_ext_bits[6]  = 4'd2;
    assign dist_ext_bits[7]  = 4'd2;
    assign dist_ext_bits[8]  = 4'd4;
    assign dist_ext_bits[9]  = 4'd5;
    assign dist_ext_bits[10] = 4'd5;
    assign dist_ext_bits[11] = 4'd5;
    assign dist_ext_bits[12] = 4'd5;
    assign dist_ext_bits[13] = 4'd5;
    assign dist_ext_bits[14] = 4'd5;
    assign dist_ext_bits[15] = 4'd5;


endmodule