module block_ram #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 5
)
(
    input                       clk,
    input  [ADDR_WIDTH-1:0]     raddr,
    output reg [DATA_WIDTH-1:0] rdata,
    input  [ADDR_WIDTH-1:0]     waddr,
    input  [DATA_WIDTH-1:0]     wdata,
    input                       winc
);

    (* ram_style="block" *)reg [DATA_WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];

    always @(posedge clk) begin
        if(winc == 1'b1)begin
            mem[waddr] <= wdata;
        end
    end

    always @(posedge clk) begin
        rdata <= mem[raddr];
    end

endmodule