module hufftree_gen #(
    parameter HUFF_CODE_LEN = 8,
    parameter HUFF_LEN_LEN  = ceilLog2(HUFF_CODE_LEN + 1)
    )
    (
    input                      clk,
    input                      rst_n,
    input                      inc,
    input [8:0]                tree_num,
    input [4:0]                buff_data,
    input [8:0]                buff_addr_bias,
    output [8:0]               buff_addr,
    output [HUFF_CODE_LEN-1:0] huff_code,
    output [HUFF_CODE_LEN-1:0] huff_addr,
    output [HUFF_LEN_LEN-1:0]  huff_len,
    output                     winc
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

    localparam IDLE                     = 2'b00;
    localparam MATCH                    = 2'b01;
    localparam WRITE                    = 2'b10;

    reg [1:0]               state,nxt_state;
    reg [8:0]               buff_addr_cnt;
    reg [HUFF_LEN_LEN-1:0]  code_len_cnt;
    reg [HUFF_CODE_LEN-1:0] code;
    reg [8:0]               reg_buff_addr_cnt;
    reg [HUFF_LEN_LEN-1:0]  reg_code_len_cnt;
    reg [HUFF_CODE_LEN-1:0] buff_addr_write;
    wire [8:0]              buff_addr_cnt_plus;
    wire [8:0]              reg_buff_addr_cnt_plus;

    assign buff_addr_cnt_plus     = buff_addr_cnt + 1'b1;
    assign reg_buff_addr_cnt_plus = reg_buff_addr_cnt + 1'b1;

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            state <= IDLE;
        end
        else begin
            state <= nxt_state;
        end
    end

    always @* begin
        nxt_state = IDLE;
        case(state)
            IDLE:begin
                nxt_state = inc ? MATCH : IDLE;
            end
            MATCH:begin
                nxt_state = ((reg_code_len_cnt == HUFF_CODE_LEN) & (reg_buff_addr_cnt_plus == tree_num)) ? IDLE : ((buff_data == reg_code_len_cnt) ? WRITE : MATCH);
            end
            WRITE:begin
                nxt_state = ((buff_addr_write + 1'b1) == (1'b1 << (8 - reg_code_len_cnt))) ? MATCH : WRITE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buff_addr_cnt <= 9'b0;
        end
        else begin
            case(nxt_state)
                IDLE: buff_addr_cnt <= 9'b0;
                MATCH:begin
                    if(buff_addr_cnt_plus == tree_num)begin
                        buff_addr_cnt <= 9'b0; 
                    end
                    else begin
                        buff_addr_cnt <= buff_addr_cnt + 1'b1;
                    end
                end
                WRITE: buff_addr_cnt <= buff_addr_cnt;
                default: buff_addr_cnt <= 9'b0;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            code_len_cnt <= 1;
        end
        else begin
            case(nxt_state)
                IDLE: code_len_cnt <= 1;
                MATCH:begin
                    if(buff_addr_cnt_plus == tree_num)begin
                        code_len_cnt <= code_len_cnt + 1'b1; 
                    end
                    else begin
                        code_len_cnt <= code_len_cnt;
                    end
                end
                WRITE: code_len_cnt <= code_len_cnt;
                default: code_len_cnt <= 1;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            code <= 0;
        end
        else begin
            case(state)
                IDLE: code <= 0;
                MATCH:begin
                    if(reg_buff_addr_cnt == 0)begin
                        code <= code << 1;
                    end
                    else begin
                        code <= code;
                    end
                end
                WRITE:begin
                    if(nxt_state == MATCH)begin
                        code <= code + 1'b1;
                    end
                    else begin
                        code <= code;
                    end
                end
                default: code <= 0;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            reg_buff_addr_cnt <= 0;
        end
        else begin
            reg_buff_addr_cnt <= buff_addr_cnt;
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            reg_code_len_cnt <= 0;
        end
        else begin
            reg_code_len_cnt <= code_len_cnt;
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            buff_addr_write <= 0;
        end
        else begin
            case(state)
                IDLE: buff_addr_write <= 0;
                MATCH: buff_addr_write <= 0;
                WRITE:begin
                    if(nxt_state == WRITE)begin
                        buff_addr_write <= buff_addr_write + 1'b1;
                    end
                    else begin
                        buff_addr_write <= 0;
                    end
                end
                default: buff_addr_write <= 0;
            endcase
        end
    end

    wire[HUFF_CODE_LEN-1:0] huff_addr_arry[HUFF_CODE_LEN:0];

    assign buff_addr = buff_addr_cnt + buff_addr_bias;
    assign huff_code = reg_buff_addr_cnt[HUFF_CODE_LEN-1:0];
    assign huff_addr = huff_addr_arry[reg_code_len_cnt];
    assign huff_len  = reg_code_len_cnt;
    assign winc      = state == WRITE;

    genvar i;
    generate
        for(i=0;i<=HUFF_CODE_LEN;i=i+1)begin
            if(i == 0)begin
                assign huff_addr_arry[i] = 0;
            end
            else if(i>0 && i<HUFF_CODE_LEN)begin
                assign huff_addr_arry[i] = {code[i-1:0],buff_addr_write[HUFF_CODE_LEN-i-1:0]};
            end
            else if(i == HUFF_CODE_LEN)begin
                assign huff_addr_arry[i] = code;
            end
        end
    endgenerate


endmodule