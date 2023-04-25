module inflate_core(
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

// ceilLog2 function
function integer ceilLog2 (input integer n);
begin:CEILOG2
    integer m;
    m                     = n - 1;
    for (ceilLog2 = 0; m > 0; ceilLog2 = ceilLog2 + 1)
    m                     = m >> 1;
end
endfunction

parameter IDLE = 2'b00;
parameter ADDR = 2'b01;
parameter DATA = 2'b10;
parameter WAIT = 2'b11;

reg[1:0] state,nxt_state;
//APB
reg[31:0] RDADDR;
reg       DMA_start;
reg       FIFO_flush;
reg[31:0] nxt_RDADDR;
reg       nxt_DMA_start;

reg[31:0] PADDR_Reg;
reg       WriteEnb;
//inflate
reg[7:0]  inflate_data_in;
reg       inflate_data_in_vld;
wire      inflate_data_in_rdy;
wire[7:0] inflate_data_out;
wire      inflate_data_out_vld;
wire      inflate_data_out_rdy;
//inflate input buffer
reg       HRDATA_reg_push;
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
wire       fifo_src_vld;
wire[15:0] fifo_src_data;
wire       fifo_dst_rdy;
wire       fifo_src_rdy;
wire       fifo_afull;
wire       fifo_ovfl;
wire       fifo_dst_vld;
wire[15:0] fifo_dst_data;
wire       fifo_aempty;
wire       fifo_udfl;
wire[3:0]  fifo_cnt;


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
    HRDATA_reg_push            = 1'b0;
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
                        nxt_RDADDR = RDADDR + 2'b10;
                    end
                    else begin
                        nxt_state = DATA;
                    end
                end
                else begin
                    if(HREADY == 1'b1)begin
                        nxt_state = WAIT;
                        HRDATA_reg_push = 1'b1;
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
                    nxt_RDADDR = RDADDR + 2'b10;
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
                    nxt_inflate_input_buffer = (state == DATA) ? (RDADDR[1] ? HRDATA[31:16] : HRDATA[15:0]) : HRDATA_reg;
                end
                else begin
                    nxt_inflate_input_buffer = (state == DATA) ? (RDADDR[1] ? HRDATA[31:16] : HRDATA[15:0]) : HRDATA_reg;
                end
            end
            else begin
                nxt_inflate_input_buffer = inflate_input_buffer;
            end
        end
        2'b01:begin
            if(inflate_data_in_rdy == 1'b1)begin
                if(inflate_input_buffer_push == 1'b1)begin
                    nxt_inflate_input_buffer = (state == DATA) ? (RDADDR[1] ? HRDATA[31:16] : HRDATA[15:0]) : HRDATA_reg;
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
                inflate_data_in     = (state == DATA) ? (RDADDR[1] ? HRDATA[23:16] : HRDATA[7:0]) : HRDATA_reg[7:0];
                inflate_data_in_vld = 1'b1;
                if(inflate_data_in_rdy == 1'b1)begin
                    nxt_inflate_input_buffer_vld = 2'b01;
                end
                else begin
                    nxt_inflate_input_buffer_vld = 2'b10;
                end
            end
            else begin
                inflate_data_in = inflate_input_buffer[7:0];
                inflate_data_in_vld = 1'b0;
                nxt_inflate_input_buffer_vld = 2'b00;
            end
        end
        2'b01:begin
            inflate_data_in = inflate_input_buffer[15:8];
            inflate_data_in_vld = 1'b1;
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
            inflate_data_in = inflate_input_buffer[7:0];
            inflate_data_in_vld = 1'b1;
            if(inflate_data_in_rdy == 1'b1)begin
                nxt_inflate_input_buffer_vld = 2'b01;
            end
            else begin
                nxt_inflate_input_buffer_vld = 2'b10;
            end
        end
        default:begin
            inflate_data_in = inflate_input_buffer[7:0];
            inflate_data_in_vld = 1'b1;
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

//APB
//APB Write
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)begin
        WriteEnb  <= 1'b0;
        PADDR_Reg <= 32'b0;
    end
    else begin
        WriteEnb  <= PWRITE&PSEL;
        PADDR_Reg <= PADDR;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        RDADDR     <= 32'b0;
    end
    else begin
        if(WriteEnb && PENABLE && (PADDR_Reg[3:2] == 2'b00))begin
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
        if(WriteEnb && PENABLE && (PADDR_Reg[3:2] == 2'b01))begin
            DMA_start <= PWDATA[0];
        end
        else begin
            DMA_start <= nxt_DMA_start;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        FIFO_flush     <= 1'b0;
    end
    else begin
        if(WriteEnb && PENABLE && (PADDR_Reg[3:2] == 2'b10))begin
            FIFO_flush <= PWDATA[0];
        end
        else begin
            FIFO_flush <= 1'b0;
        end
    end
end

//APB Read
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0)begin
        PRDATA <= 32'b0;
    end
    else begin
        if((PSEL == 1'b1) && (PENABLE == 1'b0) && (PWRITE == 1'b0))begin
            case(PADDR[4:2])
                3'b000:  PRDATA <= RDADDR;
                3'b001:  PRDATA <= {31'b0,DMA_start};
                3'b010:  PRDATA <= {31'b0,FIFO_flush};
                3'b011:  PRDATA <= {28'b0,fifo_cnt};
                3'b100:  PRDATA <= {16'b0,fifo_dst_data};
            endcase
        end
    end
end

//HRDATA reg
always @(posedge clk) begin
    if(HRDATA_reg_push == 1'b1)begin
        HRDATA_reg <= RDADDR[1] ? HRDATA[31:16] : HRDATA[15:0];
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

assign inflate_data_out_rdy = (~inflate_output_buffer_vld) | fifo_src_rdy;

//inflate output buffer
always @(posedge clk) begin
    inflate_output_buffer <= nxt_inflate_output_buffer;
end

always @(*) begin
    if(inflate_output_buffer_vld == 1'b1)begin
        if((inflate_data_out_rdy == 1'b1) && (inflate_data_out_vld == 1'b1))begin
            nxt_inflate_output_buffer = inflate_output_buffer;
        end
        else begin
            nxt_inflate_output_buffer = inflate_output_buffer;
        end
    end
    else begin
        if((inflate_data_out_rdy == 1'b1) && (inflate_data_out_vld == 1'b1))begin
            nxt_inflate_output_buffer = inflate_data_out;
        end
        else begin
            nxt_inflate_output_buffer = inflate_output_buffer;
        end
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

always @(*) begin
    if(inflate_output_buffer_vld == 1'b1)begin
        if((inflate_data_out_rdy == 1'b1) && (inflate_data_out_vld == 1'b1))begin
            nxt_inflate_output_buffer_vld = 1'b0;
        end
        else begin
            nxt_inflate_output_buffer_vld = 1'b1;
        end
    end
    else begin
        if((inflate_data_out_rdy == 1'b1) && (inflate_data_out_vld == 1'b1))begin
            nxt_inflate_output_buffer_vld = 1'b1;
        end
        else begin
            nxt_inflate_output_buffer_vld = 1'b0;
        end
    end
end

CM_FIFO
   #(
    .FIFO_DEPTH               (8                                             ),
    .DATA_WIDTH               (16                                            ),
    .REG_OUT                  (0                                             ),
    .NO_RST                   (0                                             )
    ) out_fifo
    (
    .clk         (clk           ),
    .rst_n       (rst_n         ),
    .flush       (FIFO_flush    ),
    .src_vld     (fifo_src_vld  ),
    .src_data    (fifo_src_data ),
    .afull_th    (4'b1000       ),
    .dst_rdy     (fifo_dst_rdy  ),
    .aempty_th   (4'b0000       ),
    .src_rdy     (fifo_src_rdy  ),
    .afull       (fifo_afull    ),
    .ovfl        (fifo_ovfl     ),
    .dst_vld     (fifo_dst_vld  ),
    .dst_data    (fifo_dst_data ),
    .aempty      (fifo_aempty   ),
    .udfl        (fifo_udfl     ),
    .cnt         (fifo_cnt      )
    );

assign fifo_src_vld  = inflate_output_buffer_vld & inflate_data_out_vld;
assign fifo_src_data = {inflate_data_out,inflate_output_buffer};
assign fifo_dst_rdy  = data_out_rdy | ((PSEL == 1'b1) && (PENABLE == 1'b0) && (PWRITE == 1'b0) && (PADDR[4:2] == 3'b100));

//output logic
assign HADDR        = RDADDR;
assign data_out     = fifo_dst_data;
assign data_out_vld = fifo_dst_vld;

endmodule