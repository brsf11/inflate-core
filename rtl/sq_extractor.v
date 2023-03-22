module sq_extractor(
    input            clk,rst_n,
    input [4:0]      data_in,
    input            data_in_vld,
    output reg       data_in_rdy,
    output [8:0]     buff_addr,
    output reg [4:0] buff_data,
    output reg       winc,
    output           finish
);

    reg [5:0] tree_cnt;
    reg [4:0] zero_cnt;
    reg [4:0] nxt_zero_cnt;
    reg [1:0] writting_zero;
    reg [1:0] nxt_writting_zero;
    
    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            tree_cnt <= 6'b0;
        end
        else begin
            if(winc == 1'b1)begin
                if(tree_cnt >= 6'b101100)begin
                    tree_cnt <= 6'd0;
                end
                else begin
                    tree_cnt <= tree_cnt + 1'b1;
                end
            end
            else begin
                tree_cnt <= tree_cnt;
            end
        end
    end

    always @(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            zero_cnt <= 5'b0;
        end
        else begin
            zero_cnt <= nxt_zero_cnt;
        end
    end

    always @* begin
        if(writting_zero[1] == 1'b1)begin
            if(winc == 1'b1)begin
                nxt_zero_cnt = zero_cnt - 1'b1;
            end
            else begin
                nxt_zero_cnt = zero_cnt;
            end
        end
        else if(writting_zero[0] == 1'b1) begin
            if(data_in_vld == 1'b1)begin
                nxt_zero_cnt = data_in + 5'b00011;
            end
            else begin
                nxt_zero_cnt = 5'b0;
            end
        end
        else begin
            nxt_zero_cnt = 5'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0)begin
            writting_zero <= 2'b00;
        end
        else begin
            writting_zero <= nxt_writting_zero;
        end
    end

    always @* begin
        if(writting_zero == 2'b00)begin
            if((data_in_vld == 1'b1) && (data_in == 5'b01001))begin
                nxt_writting_zero = 2'b01;
            end
            else begin
                nxt_writting_zero = writting_zero;
            end
        end
        else if(writting_zero == 2'b01)begin
            if(data_in_vld == 1'b1)begin
                nxt_writting_zero = 2'b10;
            end
            else begin
                nxt_writting_zero = writting_zero;
            end
        end
        else if(writting_zero == 2'b10)begin
            if((winc == 1'b1) && (zero_cnt == 5'b00001))begin
                nxt_writting_zero = 2'b00;
            end
            else begin
                nxt_writting_zero = writting_zero;
            end
        end
        else begin
            nxt_writting_zero = 2'b00;
        end
    end

    //output logic
    always @* begin
        case(writting_zero)
            2'b00:begin
                data_in_rdy = 1'b1;
                buff_data   = data_in;
                winc        = (data_in == 5'b01001) ? 1'b0 : data_in_vld;
            end
            2'b01:begin
                data_in_rdy = 1'b1;
                buff_data   = 5'b0;
                winc        = 1'b0;
            end
            2'b10:begin
                data_in_rdy = 1'b0;
                buff_data   = 5'b0;
                winc        = 1'b1;
            end
            default:begin
                data_in_rdy = 1'b0;
                buff_data   = 5'b0;
                winc        = 1'b0;
            end
        endcase
    end

    assign finish    = (tree_cnt >= 6'b101100) & winc; 
    assign buff_addr = {3'b0,tree_cnt};

endmodule