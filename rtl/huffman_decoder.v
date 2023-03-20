module huffman_decoder #(
    parameter HUFF_CODE_LEN = 8,
    parameter HUFF_LEN_LEN  = ceilLog2(HUFF_CODE_LEN + 1)
    )
    (
    input                      clk,
    input                      rst_n,
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

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buffer         <= 16'b0;
        end
        else begin
            if((data_out_vld & data_out_rdy) == 1'b1)begin
                buffer         <= buffer << final_len;
            end
            else if((data_in_rdy & data_in_vld) == 1'b1)begin
                if(buffer_pointer == 6'd16)begin
                    buffer[15:8]         <= data_in;
                    buffer[7:0]          <= buffer[7:0];
                end
                else if(buffer_pointer == 8)begin
                    buffer[15:8]         <= buffer[15:8];
                    buffer[7:0]          <= data_in;
                end
                else begin
                    buffer[15:buffer_pointer]                 <= buffer[15:buffer_pointer];
                    buffer[buffer_pointer-1:buffer_pointer-8] <= data_in;
                    buffer[buffer_pointer-9:0]                <= buffer[buffer_pointer-9:0];
                end

            end
            else begin
                buffer         <= buffer;
            end
        end
    end

    wire


endmodule