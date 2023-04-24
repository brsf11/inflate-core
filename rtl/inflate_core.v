module inflate(
    input              clk,
    input              rst_n,
    //APB Slave intf
    input              PWRITE,
    input              PSEL,
    input              PENABLE,
    input [31:0]       PWDATA,PADDR,
    output reg[31:0]   PRDATA,
    //AHB Slave intf
    input              HREADY,
    input [31:0]       HRDATA,
    output [31:0]      HADDR,
    output reg[1:0]    HTRANS,
    //FIFO intf
    output [15:0]      data_out,
    output             data_out_vld,
    input              data_out_rdy,
    //intr
    output             decode_finish
);

parameter IDLE = 2'b00;
parameter ADDR = 2'b01;
parameter DATA = 2'b10;
parameter WAIT = 2'b11;

reg[1:0] state,nxt_state;
//APB
reg[31:0] RDADDR;
reg       DMA_start;
reg[31:0] nxt_RDADDR;
reg       nxt_DMA_start;

reg[31:0] PADDR_Reg;
reg WriteEnb;
//inflate
wire[7:0] inflate_data_in;
wire      inflate_data_in_vld;
wire      inflate_data_in_rdy;
wire[7:0] inflate_data_out;
wire      inflate_data_out_vld;
wire      inflate_data_out_rdy;
//inflate input buffer
reg       HRDATA_reg_pop;
reg[15:0] HRDATA_reg;
reg       inflate_input_buffer_push;
reg[15:0] inflate_input_buffer;
reg[1:0]  inflate_input_buffer_vld;
reg[15:0] nxt_inflate_input_buffer;
reg[1:0]  nxt_inflate_input_buffer_vld;
//inflate output buffer
reg[7:0]  inflate_output_buffer;
reg       inflate_output_buffer_vld;
reg[7:0]  nxt_inflate_output_buffer;
reg       nxt_inflate_output_buffer_vld;
//inflate output fifo
wire        fifo_winc;
wire        fifo_rinc;
wire [15:0] fifo_wdata;
wire        fifo_wfull;
wire        fifo_rempty;
wire [15:0] fifo_rdata;


always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)begin
        state <= IDLE;
    end
    else begin
        state <= nxt_state;
    end
end

always @(*) begin
    nxt_state  = IDLE;
    nxt_RDADDR                = RDADDR;
    nxt_DMA_start             = DMA_start;
    HTRANS                    = 2'b00;
    inflate_input_buffer_push = 1'b0;
    case(state)
        IDLE:begin
            if(DMA_start == 1'b1)begin
                nxt_state = ADDR;
            end
            else begin
                nxt_state = IDLE;
            end
        end
        ADDR:begin
            if((decode_finish | (~DMA_start)) == 1'b1)begin
                nxt_state = IDLE;
                nxt_DMA_start = 1'b0;
            end
            else begin
                HTRANS = 2'b10;
                if(HREADY == 1'b1)begin
                    nxt_state = DATA;
                    nxt_RDADDR = RDADDR + 1'b1;
                end
                else begin
                    nxt_state = ADDR;
                end
            end
        end
        DATA:begin
            if((decode_finish | (~DMA_start)) == 1'b1)begin
                nxt_state = IDLE;
                nxt_DMA_start = 1'b0;
            end
            else begin
                if((inflate_input_buffer_vld == 2'b00) || ((inflate_input_buffer_vld == 2'b01) && (inflate_data_in_rdy == 1'b1)))begin
                    if(HREADY == 1'b1)begin
                        nxt_state = ADDR;
                        inflate_input_buffer_push = 1'b1;
                    end
                    else begin
                        nxt_state = DATA;
                    end
                end
                else begin
                    if(HREADY == 1'b1)begin
                        nxt_state = WAIT;
                    end
                    else begin
                        nxt_state = DATA;
                    end
                end
            end
        end
        WAIT:begin
            if((decode_finish | (~DMA_start)) == 1'b1)begin
                nxt_state = IDLE;
                nxt_DMA_start = 1'b0;
            end
            else begin
                if((inflate_input_buffer_vld == 2'b00)  || ((inflate_input_buffer_vld == 2'b01) && (inflate_data_in_rdy == 1'b1)))begin
                    nxt_state = ADDR;
                    inflate_input_buffer_push = 1'b1;
                end
                else begin
                    nxt_state = WAIT;
                end
            end
        end
    endcase
end

//inflate input buffer
always @(posedge clk) begin
    inflate_input_buffer <= nxt_inflate_input_buffer;
end

always @(*) begin
    case(inflate_input_buffer_vld)
        2'b00:begin
            if(inflate_input_buffer_push == 1'b1)begin
                if(inflate_data_in_rdy == 1'b1)begin
                    nxt_inflate_input_buffer = HRDATA[15:0];
                end
                else begin
                    nxt_inflate_input_buffer = HRDATA[15:0];
                end
            end
            else begin
                nxt_inflate_input_buffer = inflate_input_buffer;
            end
        end
        2'b01:begin
            if(inflate_data_in_rdy == 1'b1)begin
                if(inflate_input_buffer_push == 1'b1)begin
                    nxt_inflate_input_buffer = HRDATA[15:0];
                end
                else begin
                    nxt_inflate_input_buffer = inflate_input_buffer;
                end
            end
            else begin
                nxt_inflate_input_buffer = inflate_input_buffer;
            end
        end
        2'b10:begin
            nxt_inflate_input_buffer = inflate_input_buffer;
        end
        default:begin
            nxt_inflate_input_buffer = inflate_input_buffer;
        end
    endcase
end

always @(*) begin
    case(inflate_input_buffer_vld)
        2'b00:begin
            if(inflate_input_buffer_push == 1'b1)begin
                if(inflate_data_in_rdy == 1'b1)begin
                    nxt_inflate_input_buffer_vld = 2'b01;
                end
                else begin
                    nxt_inflate_input_buffer_vld = 2'b10;
                end
            end
            else begin
                nxt_inflate_input_buffer_vld = 2'b00;
            end
        end
        2'b01:begin
            if(inflate_data_in_rdy == 1'b1)begin
                if(inflate_input_buffer_push == 1'b1)begin
                    nxt_inflate_input_buffer_vld = 2'b10;
                end
                else begin
                    nxt_inflate_input_buffer_vld = 2'b00;
                end
            end
            else begin
                nxt_inflate_input_buffer_vld = 2'b01;
            end
        end
        2'b10:begin
            if(inflate_data_in_rdy == 1'b1)begin
                nxt_inflate_input_buffer_vld = 2'b01;
            end
            else begin
                nxt_inflate_input_buffer_vld = 2'b10;
            end
        end
        default:begin
            nxt_inflate_input_buffer_vld = 2'b00;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)begin
        inflate_input_buffer_vld <= 2'b00;
    end
    else begin
        if((decode_finish | (~DMA_start)) == 1'b1)begin
            inflate_input_buffer_vld <= 2'b00;
        end
        else begin
            inflate_input_buffer_vld <= nxt_inflate_input_buffer_vld;
        end
    end
end



always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        PADDR_Reg  <= 32'b0;
        WriteEnb   <=     0;
    end
    else begin
        PADDR_Reg  <= PADDR;
        WriteEnb   <= PSEL&PWRITE;

        if(WriteEnb&PENABLE)begin
            case(PADDR_Reg[3:0])
                4'h0:begin
                    RDADDR <= PWRDATA;
                end
                4'h4:begin
                    DMA_start <= PWRDATA[0];
                end
            endcase
        end

    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        RDADDR     <= 32'b0;
    end
    else begin
        if(WriteEnb && PENABLE && (PADDR_Reg[2] == 1'b0))begin
            RDADDR <= PWDATA;
        end
        else begin
            RDADDR <= nxt_RDADDR;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        DMA_start     <= 1'b0;
    end
    else begin
        if(WriteEnb && PENABLE && (PADDR_Reg[2] == 1'b1))begin
            DMA_start <= PWDATA[0];
        end
        else begin
            DMA_start <= nxt_DMA_start;
        end
    end
end

//HRDATA reg
always @(posedge clk) begin
    if(HRDATA_reg_pop == 1'b1)begin
        HRDATA_reg <= HRDATA[15:0];
    end
end

inflate inflate(
    .clk            (clk                 ),
    .rst_n          (rst_n               ),
    .start          (DMA_start           ),
    .exit           (~DMA_start          ),
    .data_in        (inflate_data_in     ),
    .data_in_vld    (inflate_data_in_vld ),
    .data_in_rdy    (inflate_data_in_rdy ),
    .data_out       (inflate_data_out    ),
    .data_out_vld   (inflate_data_out_vld),
    .data_out_rdy   (inflate_data_out_rdy),
    .decode_finish  (decode_finish       )
);

//inflate output buffer
always @(posedge clk) begin
    inflate_output_buffer <= nxt_inflate_output_buffer;
end

always @(*) begin
    if(inflate_output_buffer_vld == 1'b1)begin
        
    end
    else begin
        
    end
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)begin
        inflate_output_buffer_vld <= 1'b0;
    end
    else begin
        if((decode_finish | (~DMA_start)) == 1'b1)begin
            inflate_output_buffer_vld <= 1'b0;
        end
        else begin
            inflate_output_buffer_vld <= nxt_inflate_output_buffer_vld;
        end
    end
end

FIFO_synq_flush #(
                .width (16),
                .depth (3)
                ) fifo
                (
                .clk      (clk        ),
                .rst_n    (rst_n      ),
                .flush    (~DMA_start ),
                .winc     (fifo_winc  ),
                .rinc     (fifo_rinc  ),
                .wdata    (fifo_wdata ),
                .wfull    (fifo_wfull ),
                .rempty   (fifo_rempty),
                .rdata    (fifo_rdata )
                );

endmodule