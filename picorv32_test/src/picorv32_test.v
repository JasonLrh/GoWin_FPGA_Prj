module picorv32_test(
     input             clk
    ,output     [5:0]  leds
    ,input      [4:0]  keys
    ,output     [1:0]  csn
    ,inout      [3:0]  q_o
    ,output            sclk
);

wire resetn = ~keys[0];

wire [5:0] led_r;
assign leds = ~led_r;

reg clk_div2;
always@(posedge clk or negedge resetn) begin
	if (~resetn) begin
		clk_div2 = 1'b0;
	end else begin
		clk_div2 = ~clk_div2;
	end
end

qspi_flash_tester qtester(
	.clk(clk),
	.keys(keys),
	.leds(led_r),
	.q_o(q_o),
	.csn(csn),
	.sclk(sclk)
);


    wire [31:0] irq = 32'b0;
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