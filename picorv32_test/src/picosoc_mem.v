module picosoc_mem #(
	parameter integer WORDS = 256,
    parameter INITFILE = "None"
) (
	input clk,
    input resetn,
	input [3:0] wen,
	input [21:0] addr,
	input [31:0] wdata,
	output[31:0] rdata,
    output reg   ready
);

reg [1:0] temp_state;
wire wr = 
    (wen == 4'b0000) ? 1'b0 :
    (wen == 4'b0000) ? 1'b1 :
    (temp_state == 2'b1)
    ;
reg [31:0] rec_data;

always@(posedge clk or negedge resetn) begin
    if (~resetn) begin
        ready <= 1'b0;
        temp_state <= 2'b0;
    end else begin
        if (wen == 4'b0000) begin
            ready <= 1'b1;
            temp_state <= 2'b0;
        end else if(wen == 4'b1111) begin
            ready <= 1'b1;
            temp_state <= 2'b0;
        end else if (temp_state == 1'b0) begin
            temp_state <= 2'b1;
            ready <= 1'b0;
        end else if(temp_state == 2'b1) begin
            temp_state <= 2'h2;
            rec_data <= {
                wen[3] ? wdata[24-:8] : rdata[24-:8],
                wen[2] ? wdata[16-:8] : rdata[16-:8],
                wen[1] ? wdata[8 -:8] : rdata[8 -:8],
                wen[0] ? wdata[0 -:8] : rdata[0 -:8]
            };
        end else if (temp_state == 2'h2) begin
            ready <= 1'b1;
            temp_state <= 2'b0;
        end
    end

end


internal_ram ram(
    .clk(clk), //input clk
    .ad(ad_i), //input [9:0] ad
    .din(temp_state == 2'b0 ? wdata : rec_data), //input [31:0] din
    .dout(rdata), //output [31:0] dout
    .oce(1'b0), //input oce
    .ce(1'b1), //input ce
    .reset(~resetn), //input reset
    .wre(wr) //input wre
);
endmodule

