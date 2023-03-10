module qspi_flash_tester(
     input             clk
    ,input      [4:0]  keys
    ,output     [5:0]  leds

    ,inout      [3:0]  q_o
    ,output            sclk
    ,output     [1:0]  csn
);

assign csn[1] = 1'b1;
localparam WAIT_CYCLES = 16'd65530;

localparam S_IDLE = 3'h0;
localparam S_READ = 3'h1;
localparam S_WAIT = 3'h2;

localparam S_W_EN1 = 3'h3;
localparam S_W_Era = 3'h4;
localparam S_W_EN2 = 3'h5;
localparam S_W_Prg = 3'h6;
localparam S_W_DIS = 3'h7;

reg[2:0] curr_state;
reg[2:0] next_state;


reg start;
wire busy;
reg [7:0] cmd;
reg en_write;

reg [31:0] wdata;
wire [31:0] rdata;
wire dataready;
reg wr;

reg has_address;
reg has_data;

assign leds = wdata[5:0];

wire rst_n = keys[0];
reg [15:0] cnt;

reg[31:0] adder;

always@(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        curr_state <= S_IDLE;
    end else begin
        curr_state <= next_state;
    end
end

always@( negedge clk or negedge rst_n ) begin
    if (~rst_n) begin
        next_state <= S_IDLE;
        start      <= 1'b0;
        wdata      <= 32'b0;
        adder      <= 32'b0;
    end else begin
        case (curr_state)
            S_IDLE: begin
                if (cnt == 16'd200) begin
                    next_state <= S_READ;
                    start      <= 1'b1;
                end
            end

            S_READ: begin
                if (dataready) begin
                    wdata      <= rdata;
                    start      <= 1'b0;
                    next_state <= S_WAIT;
                    adder      <= rdata;
                end
            end

            S_WAIT: begin
                case(~keys[4:1])
                    4'b0001: begin
                        adder <= 32'hffffffff + wdata; 
                    end

                    4'b0010: begin
                        adder <= 32'h1        + wdata; 
                    end

                    4'b0100: begin
                        next_state <= S_READ;
                        start      <= 1'b1;
                    end

                    4'b1000: begin
                        next_state <= S_W_EN1;
                        start      <= 1'b1;
                    end
                    default: begin
                        wdata <= adder;
                    end
                endcase
                
            end

            S_W_EN1: begin
                if (dataready) begin
                    start <= 1'b0;
                end  
                if (cnt == WAIT_CYCLES) begin
                    next_state <= S_W_Era;
                    start      <= 1'b1;
                end
            end

            S_W_Era: begin
                // erase sector (4k)
                if (dataready) begin
                    start <= 1'b0;
                end  
                if (cnt == WAIT_CYCLES) begin
                    next_state <= S_W_EN2;
                    start      <= 1'b1;
                end
            end

            S_W_EN2: begin
                if (dataready) begin
                    start <= 1'b0;
                end  
                if (cnt == WAIT_CYCLES) begin
                    next_state <= S_W_Prg;
                    start      <= 1'b1;
                end
            end

            S_W_Prg: begin
                if (dataready) begin
                    start <= 1'b0;
                end  
                if (cnt == WAIT_CYCLES) begin
                    next_state <= S_W_DIS;
                    start      <= 1'b1;
                end
            end

            S_W_DIS: begin
                if (dataready) begin
                    start <= 1'b0;
                end  
                if (cnt == WAIT_CYCLES) begin
                    next_state <= S_WAIT;
                end
            end
        endcase
    end
end

always@(posedge clk or negedge rst_n)begin
    if (~rst_n) begin
        cnt <= 16'b0;
        en_write <= 1'b0;
    end else begin
        case (next_state) 
            S_IDLE: begin
                cnt <= cnt + 16'b1;
            end
            S_READ: begin
                wr          <= 1'b0;
                cmd         <= 8'h03;
                has_address <= 1'b1;
                has_data    <= 1'b1;
            end

            S_WAIT: begin
                
            end

            S_W_EN1: begin
                cmd <= 8'h06;
                has_address <= 1'b0;
                has_data <= 1'b0;
                if (csn[0] == 1'b1) begin
                    cnt <= cnt + 16'b1;
                end else begin
                    cnt <= 16'b0;
                end
            end

            S_W_Era: begin
                cmd <= 8'h20;
                has_address <= 1'b1;
                has_data <= 1'b0;
                if (csn[0] == 1'b1) begin
                    cnt <= cnt + 16'b1;
                end else begin
                    cnt <= 16'b0;
                end
            end

            S_W_EN2: begin
                cmd <= 8'h06;
                has_address <= 1'b0;
                has_data <= 1'b0;
                if (csn[0] == 1'b1) begin
                    cnt <= cnt + 16'b1;
                end else begin
                    cnt <= 16'b0;
                end
            end

            S_W_Prg: begin
                cmd <= 8'h02;
                has_address <= 1'b1;
                has_data <= 1'b1;
                wr <= 1'b1;
                if (~busy && ~csn[0]) begin
                    en_write <= 1'b1;
                end else begin
                    en_write <= 1'b0;
                end
                if (csn[0] == 1'b1) begin
                    cnt <= cnt + 16'b1;
                end else begin
                    cnt <= 16'b0;
                end
            end

            S_W_DIS: begin
                cmd <= 8'h04; // TOOO: fix code
                has_address <= 1'b0;
                has_data <= 1'b0;
                wr <= 1'b0;
                cnt <= 16'b0;
            end

        endcase
    end
end


qspi_serializer qspis(
    .clk_i(~clk),
    .rst_i(~rst_n),

    .start(start),
    .busy(busy),

    .cmd(cmd),
    .cmd_mode(2'b01),

    .addr(32'b0),
    .addr_size(2'b10),
    .addr_mode(has_address ? 2'b01 : 2'b00),

    .alterbytes(32'h00),
    .ab_size(2'b00),
    .ab_mode(2'b00),

    .dummy_cycles(5'd0),
    
    .data_size(2'b00),
    .data_mode(has_data ? 2'b01 : 2'b0),

    .data_in(wdata),
    .data_out(rdata),
    .wr(wr),
    .en_write(en_write),
    .dataready(dataready),
    .q_o(q_o),
    .sclk(sclk),
    .csn(csn[0])
);



endmodule
