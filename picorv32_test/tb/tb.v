`timescale 1ns/1ns
module tb;

reg clk;

reg [4:0] keys;
wire [5:0] leds;

initial begin
    keys = 4'b0;

    #1 keys[0] = 1'b1;
    #16 keys[0] = 1'b0;


    #8000 keys[4] = 1'b1;
    #11   keys[4] = 1'b0;


    // #50 keys[4] = 1'b1;
    // #10 keys[4] = 1'b0;

end


initial begin
    $dumpvars(0, tb);
    $dumpfile("ok.vvp");
    
    clk = 1'b0;

    #50000 $finish;
end

always #5 begin
    clk = ~clk;
end

wire [3:0] q_o;

reg [31:0] wdata;
wire [31:0] rdata;

qspi_flash_tester qtester(
    .clk(clk),
    .keys(~keys),
    .leds(leds)

);

/*
keys[4:0]:
    [4]: write
    [3]: read
    [2]: add
    [1]: sub


*/





endmodule
