module lz_extractor(
    input            clk,
    input            rst_n,
    input            en,
    input            data_in_vld,
    input [4:0]      data_in,
    input [5:0]      ext_bits,
    output           data_in_rdy,
    input            data_out_rdy,
    output [3:0]     data_out,
    output reg       data_out_vld,
    output reg [8:0] buff_read_addr,
    output [8:0]     buff_write_addr,
    input  [3:0]     buff_data_in
);

    reg [4:0] data_in_buffer;
    reg       buffer_vld;
    reg       nxt_buffer_vld;
    reg [5:0] ext_bits_buffer;

    reg commit;

    localparam LIT                     = 2'b00;
    localparam DIST                    = 2'b01;
    localparam COPY                    = 2'b10;

    reg [1:0]               state,nxt_state;

    reg [8:0]  buff_ptr;
    reg [8:0]  len;
    reg [8:0]  nxt_len;
    reg        buff_data_vld;
    wire [8:0] final_len;
    wire [8:0] final_dist;
    reg [8:0]  nxt_buff_read_addr;

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            state <= LIT;
        end
        else begin
            if(en == 1'b0)begin
                state <= LIT;
            end
            else begin
                state <= nxt_state;
            end
        end
    end

    always @* begin
        case(state)
            LIT:begin
                if((buffer_vld == 1'b1) && (data_in_buffer > 5'b10000))begin
                    nxt_state = DIST;
                end
                else begin
                    nxt_state = LIT;
                end
            end
            DIST:begin
                if(buffer_vld == 1'b1)begin
                    nxt_state = COPY;
                end
                else begin
                    nxt_state = DIST;
                end
            end
            COPY:begin
                if((len == 9'b0000_0000_1) && (data_out_vld == 1'b1))begin
                    nxt_state = LIT;
                end
                else begin
                    nxt_state = COPY;
                end
            end
            default:begin
                nxt_state = LIT;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            data_in_buffer  <= 5'b0;
            ext_bits_buffer <= 6'b0;
        end
        else begin
            if(en == 1'b0)begin
                data_in_buffer  <= 5'b0;
                ext_bits_buffer <= 6'b0;
            end
            else begin
                if((data_in_vld == 1'b1) && (data_in_rdy == 1'b1))begin
                    data_in_buffer  <= data_in;
                    ext_bits_buffer <= ext_bits;
                end 
                else begin
                    data_in_buffer  <= data_in_buffer;
                    ext_bits_buffer <= ext_bits_buffer;
                end  
            end
        end 
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            buffer_vld <= 1'b0;
        end
        else begin
            if(en == 1'b0)begin
                buffer_vld <= 1'b0;
            end
            else begin
                buffer_vld <= nxt_buffer_vld;
            end
        end
    end

    always @* begin
        if(data_in_rdy == 1'b1)begin
            nxt_buffer_vld = 1'b1;
        end
        else begin
            if(commit == 1'b1)begin
                nxt_buffer_vld = 1'b0;
            end
            else begin
                nxt_buffer_vld = buffer_vld;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            buff_ptr <= 9'b0;
        end
        else begin
            if(en == 1'b0)begin
                buff_ptr <= 9'b0;
            end
            else begin
                if((data_out_vld == 1'b1) && (data_out_rdy == 1'b1))begin
                    buff_ptr <= buff_ptr + 1'b1;
                end
                else begin
                    buff_ptr <= buff_ptr;
                end
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            len <= 9'b0;
        end
        else begin
            if(en == 1'b0)begin
                len <= 9'b0;
            end
            else begin
                len <= nxt_len;
            end
        end
    end

    always @* begin
        case(state)
            LIT:begin
                nxt_len = (nxt_state == DIST) ? final_len : 9'b0;
            end
            DIST:begin
                nxt_len = len;
            end
            COPY:begin
                nxt_len = ((data_out_rdy == 1'b1) && (data_out_vld == 1'b1)) ? (len - 1'b1) : len;
            end
            default:begin
                nxt_len = 9'b0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            buff_data_vld <= 1'b0;
        end
        else begin
            if(en == 1'b0)begin
                buff_data_vld <= 1'b0;
            end
            else begin
                buff_data_vld <= (state == COPY) ? (((data_out_rdy == 1'b1) && (data_in_vld == 1'b1)) ? 1'b0 : 1'b1) : (1'b0);
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            buff_read_addr <= 9'b0;
        end
        else begin
            if(en == 1'b0)begin
                buff_read_addr <= 9'b0;
            end
            else begin
                buff_read_addr <= nxt_buff_read_addr;
            end
        end
    end

    always @* begin
        case(state)
            LIT:begin
                nxt_buff_read_addr = 9'b0;
            end
            DIST:begin
                if(buffer_vld == 1'b1)begin
                    nxt_buff_read_addr = buff_ptr - final_dist;
                end
                else begin
                    nxt_buff_read_addr = 9'b0;
                end
            end
            COPY:begin
                nxt_buff_read_addr = ((data_out_rdy == 1'b1) && (data_in_vld == 1'b1)) ? (buff_read_addr + 1'b1) : buff_read_addr;
            end
            default:begin
                nxt_buff_read_addr = 9'b0;
            end
        endcase
    end

    //internal comb logic
    always @* begin
        case(state)
            LIT:begin
                if((buffer_vld == 1'b1) && (((data_out_rdy == 1'b1) && (data_in_buffer <= 5'b10000)) | (data_in_buffer > 5'b10000)))begin
                    commit = 1'b1;
                end
                else begin
                    commit = 1'b0;
                end
            end
            DIST:begin
                commit = buffer_vld == 1'b1;
            end
            default:begin
                commit = 1'b0;
            end
        endcase
    end

    //len and dist
    //len
    wire [8:0] len_off[28:17];
    assign len_off[17] = 9'b0_0000_0110;
    assign len_off[18] = 9'b0_0000_1000;
    assign len_off[19] = 9'b0_0000_1010;
    assign len_off[20] = 9'b0_0000_1100;
    assign len_off[21] = 9'b0_0000_1110;
    assign len_off[22] = 9'b0_0001_0010;
    assign len_off[23] = 9'b0_0001_0110;
    assign len_off[24] = 9'b0_0001_1010;
    assign len_off[25] = 9'b0_0010_0010;
    assign len_off[26] = 9'b0_0011_0010;
    assign len_off[27] = 9'b0_0100_0000;
    assign len_off[28] = 9'b0_1000_0010;

    assign final_len   = len_off[data_in_buffer] + {2'b0,ext_bits_buffer,1'b0};

    //dist
    wire [8:0] dist_off[15:0];
    assign dist_off[0]  = 9'b0_0000_0010;
    assign dist_off[1]  = 9'b0_0000_0100;
    assign dist_off[2]  = 9'b0_0000_0110;
    assign dist_off[3]  = 9'b0_0000_1000;
    assign dist_off[4]  = 9'b0_0000_1010;
    assign dist_off[5]  = 9'b0_0000_1110;
    assign dist_off[6]  = 9'b0_0001_0010;
    assign dist_off[7]  = 9'b0_0001_1010;
    assign dist_off[8]  = 9'b0_0010_0010;
    assign dist_off[9]  = 9'b0_0100_0010;
    assign dist_off[10] = 9'b0_1000_0010;
    assign dist_off[11] = 9'b0_1100_0010;
    assign dist_off[12] = 9'b1_0000_0010;
    assign dist_off[13] = 9'b1_0100_0010;
    assign dist_off[14] = 9'b1_1000_0010;
    assign dist_off[15] = 9'b1_1100_0010;

    assign final_dist   = dist_off[data_in_buffer] + {2'b0,ext_bits_buffer,1'b0};

    //output logic
    assign data_in_rdy = (buffer_vld == 1'b0) | commit;
    assign data_out    = (state == COPY) ? buff_data_in[3:0] : data_in_buffer[3:0];

    always @* begin
        case(state)
            LIT:begin
                if((buffer_vld == 1'b1) &&  (data_in_buffer <= 5'b10000))begin
                    data_out_vld = 1'b1;
                end
                else begin
                    data_out_vld = 1'b0;
                end
            end
            COPY:begin
                data_out_vld = buff_data_vld;
            end
            default:begin
                data_out_vld = 1'b0;
            end
        endcase
    end

    assign buff_write_addr = buff_ptr;

endmodule