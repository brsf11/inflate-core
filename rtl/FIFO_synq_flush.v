module FIFO_synq_flush #(parameter width = 8,
                        parameter depth = 3)
                        (input wire            clk,rst_n,
                        input wire             flush,
                        input wire             winc,rinc,
                        input wire[width-1:0]  wdata,
                        output wire            wfull,rempty,
                        output wire[width-1:0] rdata);

    reg[width-1:0] mem[2**depth-1:0];
    reg[depth:0]   pwrite,pread;
    wire[depth:0]  pwrite_next,pread_next;

    always @(posedge clk) begin
        if(!rst_n)begin
            pwrite <= 0;
            pread  <= 0;
        end
        else begin
            if(flush == 1'b1)begin
                pwrite <= 0;
                pread  <= 0; 
            end
            else begin
                pwrite <= pwrite_next;
                pread  <= pread_next; 
            end
        end
    end

    always @(posedge clk) begin
        if(rst_n)begin
            if((~wfull)&winc)begin
                mem[pwrite[depth-1:0]] <= wdata;
            end
        end
    end


    assign pwrite_next[depth:0] = pwrite[depth:0] + ((~wfull)&winc?1'b1:1'b0);
    assign pread_next[depth:0]  = pread[depth:0]  + ((~rempty)&rinc?1'b1:1'b0);

    assign wfull  = (pwrite[depth]^pread[depth])&(pwrite[depth-1:0] == pread[depth-1:0]);
    assign rempty = pread[depth:0] == pwrite[depth:0];

    assign rdata  = mem[pread[depth-1:0]];

endmodule