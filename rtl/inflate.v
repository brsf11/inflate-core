module inflate(
    input            clk,
    input            rst_n,
    input            start,
    input            exit,
    input  [7:0]     data_in,
    input            data_in_vld,
    output reg       data_in_rdy,
    output reg [7:0] data_out,
    output           data_out_vld,
    input            data_out_rdy,
    //intr
    output           decode_finish
);

    localparam IDLE                     = 3'b000;
    localparam CCL_IN                   = 3'b001;
    localparam CCL_GEN                  = 3'b010;
    localparam UNISQ                    = 3'b011;
    localparam LITCODE                  = 3'b100;
    localparam DISTCODE                 = 3'b101;
    localparam DECODE                   = 3'b110;

    reg [2:0] state,nxt_state;

    reg [5:0] cnt,nxt_cnt;
    reg       isZero;
    reg       nxt_isZero;

    reg [9:0]  data_in_buffer;
    reg [9:0]  nxt_data_in_buffer;
    reg [3:0]  data_in_buffer_ptr;
    reg [3:0]  nxt_data_in_buffer_ptr;
    wire [2:0] CCL;
    wire       CCL_commit;
    wire       CCL_in_rdy;

    reg data_out_buffer_vld,nxt_data_out_buffer_vld;
    reg data_out_buffer_ptr,nxt_data_out_buffer_ptr;
    reg [7:0] nxt_data_out;

    //connnections
    //output
    //U_BUFFER_MEM
    wire [4:0] U_BUFFER_MEM_rdata;
    //HUFF_MEM
    wire [4:0] U_LIT_CODE_rdata,U_DIST_CODE_rdata;
    wire [3:0] U_LIT_LEN_rdata, U_DIST_LEN_rdata;
    //U_HUFFTREE_GEN
    wire [8:0] U_HUFFTREE_GEN_buff_addr;
    wire [4:0] U_HUFFTREE_GEN_huff_code;
    wire [7:0] U_HUFFTREE_GEN_huff_addr;
    wire [3:0] U_HUFFTREE_GEN_huff_len;
    wire       U_HUFFTREE_GEN_winc;
    wire       U_HUFFTREE_GEN_finish;
    //U_HUFFMAN_DECODER
    wire       U_HUFFMAN_DECODER_data_in_rdy;
    wire [7:0] U_HUFFMAN_DECODER_huff_addr;
    wire       U_HUFFMAN_DECODER_data_out_vld;
    wire [4:0] U_HUFFMAN_DECODER_data_out;
    wire [5:0] U_HUFFMAN_DECODER_ext_bits;
    //U_LZ_EXTRACTOR
    wire       U_LZ_EXTRACTOR_data_in_rdy;
    wire [3:0] U_LZ_EXTRACTOR_data_out;
    wire       U_LZ_EXTRACTOR_data_out_vld;
    wire [8:0] U_LZ_EXTRACTOR_buff_read_addr;
    wire [8:0] U_LZ_EXTRACTOR_buff_write_addr;
    //U_SQ_EXTRACTOR
    wire       U_SQ_EXTRACTOR_data_in_rdy;
    wire [8:0] U_SQ_EXTRACTOR_buff_addr;
    wire [4:0] U_SQ_EXTRACTOR_buff_data;
    wire       U_SQ_EXTRACTOR_winc;
    wire       U_SQ_EXTRACTOR_finish;

    //input
    //U_BUFFER_MEM
    reg [8:0] U_BUFFER_MEM_raddr,U_BUFFER_MEM_waddr;
    reg [4:0] U_BUFFER_MEM_wdata;
    reg       U_BUFFER_MEM_winc;
    //HUFF_MEM
    wire [7:0] U_LIT_DIST_raddr,U_LIT_DIST_waddr;
    wire [4:0] U_LIT_CODE_wdata,U_DIST_CODE_wdata;
    wire [3:0] U_LIT_LEN_wdata, U_DIST_LEN_wdata;
    wire       U_LIT_winc,U_DIST_winc;
    //U_HUFFTREE_GEN
    reg       U_HUFFTREE_GEN_inc;
    reg [5:0] U_HUFFTREE_GEN_tree_num;
    wire [4:0] U_HUFFTREE_GEN_buff_data;
    reg [5:0] U_HUFFTREE_GEN_buff_addr_bias;
    //U_HUFFMAN_DECODER
    reg       U_HUFFMAN_DECODER_pending;
    reg       U_HUFFMAN_DECODER_flush;
    reg       U_HUFFMAN_DECODER_data_in_vld;
    wire [7:0] U_HUFFMAN_DECODER_data_in; 
    wire [3:0] U_HUFFMAN_DECODER_lit_huff_len;
    wire [4:0] U_HUFFMAN_DECODER_lit_huff_code;
    wire [3:0] U_HUFFMAN_DECODER_dist_huff_len;
    wire [4:0] U_HUFFMAN_DECODER_dist_huff_code;
    reg       U_HUFFMAN_DECODER_mode;
    wire       U_HUFFMAN_DECODER_data_out_rdy;
    //U_LZ_EXTRACTOR
    reg       U_LZ_EXTRACTOR_en;
    wire       U_LZ_EXTRACTOR_data_in_vld;
    wire [4:0] U_LZ_EXTRACTOR_data_in;
    wire [5:0] U_LZ_EXTRACTOR_ext_bits;
    wire       U_LZ_EXTRACTOR_data_out_rdy;
    wire [3:0] U_LZ_EXTRACTOR_buff_data_in;
    //U_SQ_EXTRACTOR
    reg       U_SQ_EXTRACTOR_flush;
    wire [4:0] U_SQ_EXTRACTOR_data_in;
    wire       U_SQ_EXTRACTOR_data_in_vld;

    //cnt logic
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            cnt <= 6'b0;
        end
        else begin
            cnt <= nxt_cnt;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            isZero <= 1'b0;
        end
        else begin
            isZero <= nxt_isZero;
        end
    end

    always @* begin
        if(isZero == 1'b1)begin
            if((U_HUFFMAN_DECODER_data_out_vld == 1'b1) && (U_HUFFMAN_DECODER_data_out_rdy == 1'b1))begin
                nxt_isZero = 1'b0;
            end
            else begin
                nxt_isZero = 1'b1;
            end
        end
        else begin
            if((U_HUFFMAN_DECODER_data_out_vld == 1'b1) && (U_HUFFMAN_DECODER_data_out_rdy == 1'b1) && (U_HUFFMAN_DECODER_data_out == 5'b01001))begin
                nxt_isZero = 1'b1;
            end
            else begin
                nxt_isZero = 1'b0;
            end
        end
    end

    always @* begin
        case(state)
            CCL_IN:begin
                nxt_cnt = CCL_commit ? (cnt + 1'b1) : cnt;
            end
            UNISQ:begin
                if((U_HUFFMAN_DECODER_data_out_vld == 1'b1) && (U_HUFFMAN_DECODER_data_out_rdy == 1'b1))begin
                    nxt_cnt = cnt + (isZero ? (U_HUFFMAN_DECODER_data_out + 5'b00011) : ((U_HUFFMAN_DECODER_data_out == 5'b01001) ? 5'b0 : 5'b00001));
                end
                else begin
                    nxt_cnt = cnt;
                end
            end
            default:begin
                nxt_cnt = 6'b0;
            end
        endcase
    end

    //CCL depackage buffer
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            data_in_buffer <= 10'b0;
        end
        else begin
            data_in_buffer <= nxt_data_in_buffer;
        end
    end

    always @* begin
        if(state == CCL_IN)begin
            if(CCL_commit == 1'b1)begin
                nxt_data_in_buffer = data_in_buffer >> 3;
            end
            else if((data_in_rdy == 1'b1) && (data_in_vld == 1'b1)) begin
                case(data_in_buffer_ptr)
                    4'b0000: nxt_data_in_buffer = {4'b0,data_in[7:2]};
                    4'b0001: nxt_data_in_buffer = {3'b0,data_in[7:1]};
                    4'b0010: nxt_data_in_buffer = {2'b0,data_in[7:0]};
                    4'b0011: nxt_data_in_buffer = {1'b0,data_in[7:0],data_in_buffer[0]};
                    4'b0100: nxt_data_in_buffer = {data_in[7:0],data_in_buffer[1:0]};
                    4'b0101: nxt_data_in_buffer = 10'b0;
                    4'b0110: nxt_data_in_buffer = 10'b0;
                    4'b0111: nxt_data_in_buffer = 10'b0;
                    4'b1000: nxt_data_in_buffer = 10'b0;
                    4'b1001: nxt_data_in_buffer = 10'b0;
                    4'b1010: nxt_data_in_buffer = 10'b0;
                    4'b1011: nxt_data_in_buffer = 10'b0;
                    4'b1100: nxt_data_in_buffer = 10'b0;
                    4'b1101: nxt_data_in_buffer = 10'b0;
                    4'b1110: nxt_data_in_buffer = 10'b0;
                    4'b1111: nxt_data_in_buffer = 10'b0;
                    default: nxt_data_in_buffer = 10'b0;
                endcase
            end
            else begin
                nxt_data_in_buffer = data_in_buffer;
            end
        end
        else begin
            nxt_data_in_buffer = 10'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            data_in_buffer_ptr <= 4'b0;
        end
        else begin
            data_in_buffer_ptr <= nxt_data_in_buffer_ptr;
        end
    end

    always @* begin
        if(state == CCL_IN)begin
            if(CCL_commit == 1'b1)begin
                nxt_data_in_buffer_ptr = data_in_buffer_ptr - 4'b0011;
            end
            else if((data_in_rdy == 1'b1) && (data_in_vld == 1'b1)) begin
                nxt_data_in_buffer_ptr = data_in_buffer_ptr + 4'b1000;
            end
            else begin
                nxt_data_in_buffer_ptr = data_in_buffer_ptr;
            end
        end
        else begin
            nxt_data_in_buffer_ptr = 4'b0;
        end
    end

    assign CCL        = {data_in_buffer[0],data_in_buffer[1],data_in_buffer[2]};
    assign CCL_commit = (state == CCL_IN) & (data_in_buffer_ptr >= 4'b0101);
    assign CCL_in_rdy = data_in_buffer_ptr < 4'b0101;


    
    //Internal logic
    //Connections
    //HUFF_MEM
    assign U_LIT_DIST_raddr  = U_HUFFMAN_DECODER_huff_addr;
    assign U_LIT_DIST_waddr  = U_HUFFTREE_GEN_huff_addr;
    assign U_LIT_CODE_wdata  = U_HUFFTREE_GEN_huff_code;
    assign U_DIST_CODE_wdata = U_HUFFTREE_GEN_huff_code;
    assign U_LIT_LEN_wdata   = U_HUFFTREE_GEN_huff_len;
    assign U_DIST_LEN_wdata  = U_HUFFTREE_GEN_huff_len;
    assign U_LIT_winc        = ((state == LITCODE) | (state == CCL_GEN)) & U_HUFFTREE_GEN_winc;
    assign U_DIST_winc       = (state == DISTCODE) & U_HUFFTREE_GEN_winc;
    //HUFFTREE_GEN
    assign U_HUFFTREE_GEN_buff_data = U_BUFFER_MEM_rdata;
    //HUFFMAN_DECODER
    assign U_HUFFMAN_DECODER_data_in        = {data_in[0],data_in[1],data_in[2],data_in[3],data_in[4],data_in[5],data_in[6],data_in[7]};
    assign U_HUFFMAN_DECODER_lit_huff_len   = U_LIT_LEN_rdata;
    assign U_HUFFMAN_DECODER_lit_huff_code  = U_LIT_CODE_rdata;
    assign U_HUFFMAN_DECODER_dist_huff_len  = U_DIST_LEN_rdata;
    assign U_HUFFMAN_DECODER_dist_huff_code = U_DIST_CODE_rdata;
    assign U_HUFFMAN_DECODER_data_out_rdy   = (state == DECODE) ? U_LZ_EXTRACTOR_data_in_rdy : U_SQ_EXTRACTOR_data_in_rdy;
    //LZ_EXTRACTOR
    assign U_LZ_EXTRACTOR_data_in_vld       = U_HUFFMAN_DECODER_data_out_vld;
    assign U_LZ_EXTRACTOR_data_in           = U_HUFFMAN_DECODER_data_out;
    assign U_LZ_EXTRACTOR_ext_bits          = U_HUFFMAN_DECODER_ext_bits;
    assign U_LZ_EXTRACTOR_data_out_rdy      = ((data_out_rdy == 1'b1) && (data_out_vld == 1'b1)) | (data_out_vld == 1'b0);
    assign U_LZ_EXTRACTOR_buff_data_in      = U_BUFFER_MEM_rdata[3:0];
    //SQ_EXTRACTOR
    assign U_SQ_EXTRACTOR_data_in           = U_HUFFMAN_DECODER_data_out;
    assign U_SQ_EXTRACTOR_data_in_vld       = U_HUFFMAN_DECODER_data_out_vld;

    always @* begin
        case(state)
            IDLE:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = 9'b0;
                U_BUFFER_MEM_waddr            = 9'b0;
                U_BUFFER_MEM_wdata            = 5'b0;
                U_BUFFER_MEM_winc             = 1'b0;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = 1'b0;
                U_HUFFTREE_GEN_tree_num       = 6'b0;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b1;
                U_HUFFMAN_DECODER_flush       = 1'b1;
                U_HUFFMAN_DECODER_data_in_vld = 1'b0;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b1;
            end
            CCL_IN:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = 9'b0;
                U_BUFFER_MEM_waddr            = {3'b0,cnt};
                U_BUFFER_MEM_wdata            = {2'b0,CCL};
                U_BUFFER_MEM_winc             = CCL_commit;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = 1'b0;
                U_HUFFTREE_GEN_tree_num       = 6'b0;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b1;
                U_HUFFMAN_DECODER_flush       = 1'b1;
                U_HUFFMAN_DECODER_data_in_vld = 1'b0;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b1;
            end
            CCL_GEN:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = U_HUFFTREE_GEN_buff_addr;
                U_BUFFER_MEM_waddr            = 9'b0;
                U_BUFFER_MEM_wdata            = 5'b0;
                U_BUFFER_MEM_winc             = 1'b0;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = ~U_HUFFTREE_GEN_finish;
                U_HUFFTREE_GEN_tree_num       = 6'b001010;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b1;
                U_HUFFMAN_DECODER_flush       = 1'b1;
                U_HUFFMAN_DECODER_data_in_vld = 1'b0;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b1;
            end
            UNISQ:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = 9'b0;
                U_BUFFER_MEM_waddr            = U_SQ_EXTRACTOR_buff_addr;
                U_BUFFER_MEM_wdata            = U_SQ_EXTRACTOR_buff_data;
                U_BUFFER_MEM_winc             = U_SQ_EXTRACTOR_winc;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = 1'b0;
                U_HUFFTREE_GEN_tree_num       = 6'b0;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = (cnt >= 6'b101101) ? 1'b1 : 1'b0;
                U_HUFFMAN_DECODER_flush       = 1'b0;
                U_HUFFMAN_DECODER_data_in_vld = data_in_vld;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b0;
            end
            LITCODE:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = U_HUFFTREE_GEN_buff_addr;
                U_BUFFER_MEM_waddr            = 9'b0;
                U_BUFFER_MEM_wdata            = 5'b0;
                U_BUFFER_MEM_winc             = 1'b0;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = ~U_HUFFTREE_GEN_finish;
                U_HUFFTREE_GEN_tree_num       = 6'b011101;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b1;
                U_HUFFMAN_DECODER_flush       = 1'b0;
                U_HUFFMAN_DECODER_data_in_vld = 1'b0;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b1;
            end
            DISTCODE:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = U_HUFFTREE_GEN_buff_addr;
                U_BUFFER_MEM_waddr            = 9'b0;
                U_BUFFER_MEM_wdata            = 5'b0;
                U_BUFFER_MEM_winc             = 1'b0;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = ~U_HUFFTREE_GEN_finish;
                U_HUFFTREE_GEN_tree_num       = 6'b010000;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b011101;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b1;
                U_HUFFMAN_DECODER_flush       = 1'b0;
                U_HUFFMAN_DECODER_data_in_vld = 1'b0;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b1;
            end
            DECODE:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = U_LZ_EXTRACTOR_buff_read_addr;
                U_BUFFER_MEM_waddr            = U_LZ_EXTRACTOR_buff_write_addr;
                U_BUFFER_MEM_wdata            = {1'b0,U_LZ_EXTRACTOR_data_out};
                U_BUFFER_MEM_winc             = U_LZ_EXTRACTOR_data_out_vld & U_LZ_EXTRACTOR_data_out_rdy;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = 1'b0;
                U_HUFFTREE_GEN_tree_num       = 6'b0;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b0;
                U_HUFFMAN_DECODER_flush       = 1'b0;
                U_HUFFMAN_DECODER_data_in_vld = data_in_vld;
                U_HUFFMAN_DECODER_mode        = 1'b1;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b1;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b0;
            end
            default:begin
                //U_BUFFER_MEM
                U_BUFFER_MEM_raddr            = 9'b0;
                U_BUFFER_MEM_waddr            = 9'b0;
                U_BUFFER_MEM_wdata            = 5'b0;
                U_BUFFER_MEM_winc             = 1'b0;
                //U_HUFFTREE_GEN
                U_HUFFTREE_GEN_inc            = 1'b0;
                U_HUFFTREE_GEN_tree_num       = 6'b0;
                U_HUFFTREE_GEN_buff_addr_bias = 6'b0;
                //U_HUFFMAN_DECODER
                U_HUFFMAN_DECODER_pending     = 1'b1;
                U_HUFFMAN_DECODER_flush       = 1'b1;
                U_HUFFMAN_DECODER_data_in_vld = 1'b0;
                U_HUFFMAN_DECODER_mode        = 1'b0;
                //U_LZ_EXTRACTOR
                U_LZ_EXTRACTOR_en             = 1'b0;
                //U_SQ_EXTRACTOR
                U_SQ_EXTRACTOR_flush          = 1'b1;
            end
        endcase
    end


    //state machine
    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            state <= IDLE;
        end
        else begin
            state <= nxt_state;
        end
    end

    always @* begin
        case(state)
            IDLE:begin
                nxt_state = start ? CCL_IN : IDLE;
            end
            CCL_IN:begin
                if((CCL_commit == 1'b1) && (cnt == 6'b00_1001))begin
                    nxt_state = CCL_GEN;
                end
                else begin
                    nxt_state = CCL_IN;
                end
            end
            CCL_GEN:begin
                nxt_state = U_HUFFTREE_GEN_finish ? UNISQ : CCL_GEN;
            end
            UNISQ:begin
                nxt_state = U_SQ_EXTRACTOR_finish ? LITCODE : UNISQ;
            end
            LITCODE:begin
                nxt_state = U_HUFFTREE_GEN_finish ? DISTCODE : LITCODE;
            end
            DISTCODE:begin
                nxt_state = U_HUFFTREE_GEN_finish ? DECODE : DISTCODE;
            end
            DECODE:begin
                if(((U_HUFFMAN_DECODER_data_out_vld == 1'b1) && (U_HUFFMAN_DECODER_data_out_rdy == 1'b1) && (U_HUFFMAN_DECODER_data_out == 5'b1_0000)) || (exit == 1'b1))begin
                    nxt_state = IDLE;
                end
                else begin
                    nxt_state = DECODE;
                end
            end
            default: nxt_state = IDLE;
        endcase
    end


    //Instantiation
    block_ram #(
        .ADDR_WIDTH (9),
        .DATA_WIDTH (5)
    ) U_BUFFER_MEM
    (
        .clk        (clk  ),
        .raddr      (U_BUFFER_MEM_raddr),
        .rdata      (U_BUFFER_MEM_rdata),
        .waddr      (U_BUFFER_MEM_waddr),
        .wdata      (U_BUFFER_MEM_wdata),
        .winc       (U_BUFFER_MEM_winc )
    );

    block_ram #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (5)
    ) U_LIT_CODE
    (
        .clk        (clk  ),
        .raddr      (U_LIT_DIST_raddr),
        .rdata      (U_LIT_CODE_rdata),
        .waddr      (U_LIT_DIST_waddr),
        .wdata      (U_LIT_CODE_wdata),
        .winc       (U_LIT_winc)
    );

    block_ram #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (4)
    ) U_LIT_LEN
    (
        .clk        (clk  ),
        .raddr      (U_LIT_DIST_raddr),
        .rdata      (U_LIT_LEN_rdata),
        .waddr      (U_LIT_DIST_waddr),
        .wdata      (U_LIT_LEN_wdata),
        .winc       (U_LIT_winc)
    );

    block_ram #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (5)
    ) U_DIST_CODE
    (
        .clk        (clk  ),
        .raddr      (U_LIT_DIST_raddr),
        .rdata      (U_DIST_CODE_rdata),
        .waddr      (U_LIT_DIST_waddr),
        .wdata      (U_DIST_CODE_wdata),
        .winc       (U_DIST_winc)
    );

    block_ram #(
        .ADDR_WIDTH (8),
        .DATA_WIDTH (4)
    ) U_DIST_LEN
    (
        .clk        (clk  ),
        .raddr      (U_LIT_DIST_raddr),
        .rdata      (U_DIST_LEN_rdata),
        .waddr      (U_LIT_DIST_waddr),
        .wdata      (U_DIST_LEN_wdata),
        .winc       (U_DIST_winc)
    );

    hufftree_gen #(
        .HUFF_CODE_LEN                     (8                                      ),
        .HUFF_LEN_LEN                      (4                                      )
    ) U_HUFFTREE_GEN
    (
        .clk                               (clk                                    ),
        .rst_n                             (rst_n                                  ),
        .inc                               (U_HUFFTREE_GEN_inc                     ),
        .tree_num                          (U_HUFFTREE_GEN_tree_num                ),
        .buff_data                         (U_HUFFTREE_GEN_buff_data               ),
        .buff_addr_bias                    (U_HUFFTREE_GEN_buff_addr_bias          ),
        .buff_addr                         (U_HUFFTREE_GEN_buff_addr               ),
        .huff_code                         (U_HUFFTREE_GEN_huff_code               ),
        .huff_addr                         (U_HUFFTREE_GEN_huff_addr               ),
        .huff_len                          (U_HUFFTREE_GEN_huff_len                ),
        .winc                              (U_HUFFTREE_GEN_winc                    ),
        .finish                            (U_HUFFTREE_GEN_finish                  )
    );

    huffman_decoder #(
        .HUFF_CODE_LEN                     (8                                      ),
        .HUFF_LEN_LEN                      (4                                      )
    ) U_HUFFMAN_DECODER
    (
        .clk                               (clk                                    ),
        .rst_n                             (rst_n                                  ),
        .pending                           (U_HUFFMAN_DECODER_pending              ),
        .flush                             (U_HUFFMAN_DECODER_flush                ),
        .data_in_vld                       (U_HUFFMAN_DECODER_data_in_vld          ),
        .data_in                           (U_HUFFMAN_DECODER_data_in              ),
        .data_in_rdy                       (U_HUFFMAN_DECODER_data_in_rdy          ),
        .huff_addr                         (U_HUFFMAN_DECODER_huff_addr            ),
        .lit_huff_len                      (U_HUFFMAN_DECODER_lit_huff_len         ),
        .lit_huff_code                     (U_HUFFMAN_DECODER_lit_huff_code        ),
        .dist_huff_len                     (U_HUFFMAN_DECODER_dist_huff_len        ),
        .dist_huff_code                    (U_HUFFMAN_DECODER_dist_huff_code       ),
        .mode                              (U_HUFFMAN_DECODER_mode                 ),            //mode 0 refers to standard mode, 1 refers to lz sequence decode mode
        .data_out_vld                      (U_HUFFMAN_DECODER_data_out_vld         ),
        .data_out                          (U_HUFFMAN_DECODER_data_out             ),
        .data_out_rdy                      (U_HUFFMAN_DECODER_data_out_rdy         ),
        .ext_bits                          (U_HUFFMAN_DECODER_ext_bits             )
    );

    lz_extractor U_LZ_EXTRACTOR(
        .clk                               (clk                                    ),
        .rst_n                             (rst_n                                  ),
        .en                                (U_LZ_EXTRACTOR_en                      ),
        .data_in_vld                       (U_LZ_EXTRACTOR_data_in_vld             ),
        .data_in                           (U_LZ_EXTRACTOR_data_in                 ),
        .ext_bits                          (U_LZ_EXTRACTOR_ext_bits                ),
        .data_in_rdy                       (U_LZ_EXTRACTOR_data_in_rdy             ),
        .data_out_rdy                      (U_LZ_EXTRACTOR_data_out_rdy            ),
        .data_out                          (U_LZ_EXTRACTOR_data_out                ),
        .data_out_vld                      (U_LZ_EXTRACTOR_data_out_vld            ),
        .buff_read_addr                    (U_LZ_EXTRACTOR_buff_read_addr          ),
        .buff_write_addr                   (U_LZ_EXTRACTOR_buff_write_addr         ),
        .buff_data_in                      (U_LZ_EXTRACTOR_buff_data_in            )
    );

    sq_extractor U_SQ_EXTRACTOR(
        .clk                               (clk                                    ),
        .rst_n                             (rst_n                                  ),
        .flush                             (U_SQ_EXTRACTOR_flush                   ),
        .data_in                           (U_SQ_EXTRACTOR_data_in                 ),
        .data_in_vld                       (U_SQ_EXTRACTOR_data_in_vld             ),
        .data_in_rdy                       (U_SQ_EXTRACTOR_data_in_rdy             ),
        .buff_addr                         (U_SQ_EXTRACTOR_buff_addr               ),
        .buff_data                         (U_SQ_EXTRACTOR_buff_data               ),
        .winc                              (U_SQ_EXTRACTOR_winc                    ),
        .finish                            (U_SQ_EXTRACTOR_finish                  )
    );

    //Output logic
    always @* begin
        case(state)
            IDLE:begin
                data_in_rdy = 1'b0;
            end
            CCL_IN:begin
                data_in_rdy = CCL_in_rdy;
            end
            CCL_GEN:begin
                data_in_rdy = 1'b0;
            end
            UNISQ:begin
                data_in_rdy = U_HUFFMAN_DECODER_data_in_rdy;
            end
            LITCODE:begin
                data_in_rdy = 1'b0;
            end
            DISTCODE:begin
                data_in_rdy = 1'b0;
            end
            DECODE:begin
                data_in_rdy = U_HUFFMAN_DECODER_data_in_rdy;
            end
            default: data_in_rdy = 1'b0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            data_out <= 8'b0;
        end
        else begin
            data_out <= nxt_data_out;
        end
    end

    always @* begin
        if((U_LZ_EXTRACTOR_data_out_rdy == 1'b1) && (U_LZ_EXTRACTOR_data_out_vld == 1'b1))begin
            nxt_data_out = data_out_buffer_ptr ? {U_LZ_EXTRACTOR_data_out,data_out[3:0]} : {data_out[3:0],U_LZ_EXTRACTOR_data_out};
        end
        else begin
            nxt_data_out = data_out;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            data_out_buffer_vld <= 1'b0;
        end
        else begin
            if(state == IDLE)begin
                data_out_buffer_vld <= 1'b0;
            end
            else begin
                data_out_buffer_vld <= nxt_data_out_buffer_vld;
            end
        end
    end

    always @* begin
        if(data_out_buffer_vld == 1'b1)begin
            if((data_out_rdy == 1'b1) && (data_out_buffer_vld == 1'b1))begin
                nxt_data_out_buffer_vld = 1'b0;
            end
            else begin
                nxt_data_out_buffer_vld = 1'b1;
            end
        end
        else begin
            if((data_out_buffer_ptr == 1'b1) && (U_LZ_EXTRACTOR_data_out_rdy == 1'b1) && (U_LZ_EXTRACTOR_data_out_vld == 1'b1))begin
                nxt_data_out_buffer_vld = 1'b1;
            end
            else begin
                nxt_data_out_buffer_vld = 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            data_out_buffer_ptr <= 1'b0;
        end
        else begin
            if(state == IDLE)begin
                data_out_buffer_ptr <= 1'b0;
            end
            else begin
                data_out_buffer_ptr <= nxt_data_out_buffer_ptr;
            end
        end
    end

    always @* begin
        if((U_LZ_EXTRACTOR_data_out_rdy == 1'b1) && (U_LZ_EXTRACTOR_data_out_vld == 1'b1))begin
            nxt_data_out_buffer_ptr = ~data_out_buffer_ptr;
        end
        else begin
            nxt_data_out_buffer_ptr = data_out_buffer_ptr;
        end
    end

    assign data_out_vld  = data_out_buffer_vld;
    assign decode_finish = (state != IDLE) & (nxt_state == IDLE);

endmodule