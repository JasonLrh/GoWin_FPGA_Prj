module top(
     input clk
    ,input resetn
    
);
    reg [31:0] irq = 32'b0;
    wire mem_valid;
	wire mem_instr;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	wire [31:0] mem_rdata = 
        spimem_ready ? spimem_rdata :
        ram_ready    ? ram_rdata    :
        32'b0;

    wire spimem_ready;
	wire [31:0] spimem_rdata;


	wire ram_ready;
	wire [31:0] ram_rdata;

    wire __address_select_flash = (mem_addr[31:28] == 4'h1);
    wire __address_select_ram   = (mem_addr[31:28] == 4'h2);
	wire mem_ready = 
        (__address_select_flash && spimem_ready) ||
        (__address_select_ram   && ram_ready   )   ;

    parameter [0:0] BARREL_SHIFTER = 1;
	parameter [0:0] ENABLE_MUL = 1;
	parameter [0:0] ENABLE_DIV = 1;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_COMPRESSED = 1;
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_IRQ_QREGS = 0;

	parameter integer MEM_WORDS = 4096;
	parameter [31:0] STACKADDR = 32'h 2000_1000;       // end of memory
	parameter [31:0] PROGADDR_RESET = 32'h 1000_0000; // 1 MB into flash
	parameter [31:0] PROGADDR_IRQ = 32'h 2000_0000;

    picorv32 #(
		.STACKADDR(STACKADDR),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.COMPRESSED_ISA(ENABLE_COMPRESSED),
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_MUL(ENABLE_MUL),
		.ENABLE_DIV(ENABLE_DIV),
		.ENABLE_FAST_MUL(ENABLE_FAST_MUL),
		.ENABLE_IRQ(1),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS)
	) cpu (
		.clk         (clk        ),
		.resetn      (resetn    ),
		.mem_valid   (mem_valid  ),
		.mem_instr   (mem_instr  ),
		.mem_ready   (mem_ready  ),
		.mem_addr    (mem_addr   ),
		.mem_wdata   (mem_wdata  ),
		.mem_wstrb   (mem_wstrb  ),
		.mem_rdata   (mem_rdata  ),
		.irq         (irq        )
	);


    picosoc_mem #(
		.WORDS(MEM_WORDS)
    ) ram (
		.clk  (clk),
		.wen  (__address_select_ram ? mem_wstrb : 4'b0),
		.addr (mem_addr[23:2]),
		.wdata(mem_wdata),
		.rdata(ram_rdata),
        .ready(ram_ready)
	);

    picosoc_mem #(
		.WORDS(MEM_WORDS),
        .INITFILE("./firm/build/verilog.bin")
    ) rom (
		.clk  (clk),
		.wen  (__address_select_flash ? mem_wstrb : 4'b0),
		.addr (mem_addr[23:2]),
		.wdata(mem_wdata),
		.rdata(spimem_rdata),
        .ready(spimem_ready)
	);

endmodule


`define PICORV32_REGS picosoc_regs

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

