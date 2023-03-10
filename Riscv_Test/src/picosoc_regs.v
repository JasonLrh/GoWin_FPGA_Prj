module picosoc_regs (
	input clk, wen,
	input [5:0] waddr,
	input [5:0] raddr1,
	input [5:0] raddr2,
	input [31:0] wdata,
	output [31:0] rdata1,
	output [31:0] rdata2
);
    picoregs_ram regs_ram(
        .clka(clk), //input clka
        .ada(wen ? waddr[4:0]: raddr1[4:0]), //input [4:0] ada
        .douta(rdata1), //output [31:0] douta
        .dina(wdata), //input [31:0] dina
        .wrea(wen), //input wrea
        .cea(1'b1), //input cea
        .ocea(1'b0), //input ocea
        .reseta(1'b0), //input reseta

        .clkb(clk), //input clkb
        .adb(raddr2[4:0]), //input [4:0] adb
        .doutb(rdata2), //output [31:0] doutb
        .dinb(32'h0), //input [31:0] dinb
        .wreb(1'b0), //input wreb
        .ceb(1'b1), //input ceb
        .oceb(1'b0), //input oceb
        .resetb(1'b0) //input resetb
    );
endmodule