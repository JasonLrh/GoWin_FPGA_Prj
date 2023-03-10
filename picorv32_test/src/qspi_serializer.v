module qspi_serializer(
     input clk_i
    ,input rst_i

    ,input        start
    ,output reg   busy

    // group: command
    ,input [7 :0] cmd
    ,input [31:0] addr
    ,input [31:0] alterbytes
    ,input [1:0]  cmd_mode
    ,input [1:0]  addr_mode
    ,input [1:0]  addr_size
    ,input [1:0]  ab_mode
    ,input [1:0]  ab_size
    ,input [1:0]  data_mode
    ,input [1:0]  data_size
    ,input [4:0]  dummy_cycles

    // group: data
    ,input             wr           // read & write. static
    ,input             en_write     // load [data_in] and read [data_out]  @posedge 
    ,output reg        dataready    // seq data send ok or ready tobe read
    ,input      [31:0] data_in
    ,output reg [31:0] data_out
    
    ,inout [3:0]  q_o
    ,output reg   sclk
    ,output reg   csn
);
/********************************************************************************************************************************
state machine
********************************************************************************************************************************/
localparam S_IDLE   = 3'd0;
localparam S_SWICH  = 3'd1;
localparam S_CMD    = 3'd2;
localparam S_ADDR   = 3'd3;
localparam S_ALBT   = 3'd4;
localparam S_DUMM   = 3'd5;
localparam S_DATA   = 3'd6;
localparam S_Wait   = 3'd7;


localparam M_SSPI   = 2'b01;
localparam M_DSPI   = 2'b10;
localparam M_QSPI   = 2'b11;

reg [2:0] curr_state;
reg [2:0] next_state;
reg [2:0] reco_state;


wire __no_cmd  = (cmd_mode     == 2'h0);
wire __no_addr = (addr_mode    == 2'h0);
wire __no_altb = (ab_mode      == 2'h0);
wire __no_dumm = (dummy_cycles == 5'h0);
wire __no_data = (data_mode    == 2'h0);

wire [2:0] __next_state_should_be = 
    (reco_state < S_CMD  && ~__no_cmd )                  ? S_CMD  :
    (reco_state < S_ADDR && ~__no_addr)                  ? S_ADDR :
    (reco_state < S_ALBT && ~__no_altb)                  ? S_ALBT :
    (reco_state < S_DUMM && ~__no_dumm)                  ? S_DUMM :
    (start == 1'b0 || __no_data) ? S_IDLE : (  // S_DATA
        (wr) ? (
            next_wdata_ready ? S_DATA : S_Wait
        ) : (
            next_wdata_ready ? S_Wait : S_DATA
        )
    );

/********************************************************************************************************************************
data control
if [wr == 1]:
    posedge [en_write] : load write data. [next_wdata_ready == 1]
else:
    drive[dataready == 1] : 
********************************************************************************************************************************/
reg next_wdata_ready;
reg [31:0] data_write;
reg data_has_write;

always@ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        data_write <= 32'b0;
        next_wdata_ready <= 1'b0;
    end else begin
        if (curr_state == S_IDLE) begin
            next_wdata_ready <= 1'b0;
        end else if (wr) begin
            if (en_write) begin
                next_wdata_ready <= 1'b1;
                data_write <= data_in;
            end else if (data_has_write == 1'b1) begin
                next_wdata_ready <= 1'b0;
            end
        end else begin
            if (en_write) begin
                next_wdata_ready <= 1'b0;
            end else if(data_has_write) begin
                next_wdata_ready <= 1'b1;
            end
        end
    end
end

        
            
/********************************************************************************************************************************
mode :
    00: none
    01: single
    10: dual
    11: quad
size :
    00: 8bit
    01: 16
    10: 24
    11: 32

cycles = 
    ((size + 1) << 3) >> (mode - 1) = 
    (size + 1) << (4 - mode)

wire [2:0] sz = size + 1;
wire [5:0] cycles = 
    (mode == 2'b11) ? {2'b0 , sz , 1'b0} :
    (mode == 2'b10) ? {1'b0 , sz , 2'b0} :
    (mode == 2'b01) ? {       sz , 3'b0} :
********************************************************************************************************************************/

wire [2:0] __asize = {1'b0, addr_size} + 3'b1;
wire [2:0] __bsize = {1'b0, ab_size  } + 3'b1;
wire [2:0] __dsize = {1'b0, data_size} + 3'b1;

wire [4:0] __cmd_cycles = 
    (cmd_mode  == 2'b11) ? 4'd2 :
    (cmd_mode  == 2'b10) ? 4'd4 :
                           4'd8 ;

wire [5:0] __addr_cycles = 
    (addr_mode == 2'b11) ? {2'b0 , __asize , 1'b0} :
    (addr_mode == 2'b10) ? {1'b0 , __asize , 2'b0} :
                           {       __asize , 3'b0} ;

wire [5:0] __alby_cycles = 
    (ab_mode   == 2'b11) ? {2'b0 , __bsize , 1'b0} :
    (ab_mode   == 2'b10) ? {1'b0 , __bsize , 2'b0} :
                           {       __bsize , 3'b0} ;

wire [5:0] __data_cycles = // per bytes
    (data_mode == 2'b11) ? {2'b0 , __dsize , 1'b0} :
    (data_mode == 2'b10) ? {1'b0 , __dsize , 2'b0} :
                           {       __dsize , 3'b0} ;

/********************************************************************************************************************************
qspi io
********************************************************************************************************************************/
wire [3:0] q_dir_out = 
    (
        ((curr_state == S_DATA) && (wr == 1'b0)) ||
          curr_state == S_DUMM ||
          curr_state == S_Wait ||
          curr_state == S_SWICH
    ) ? 4'h0 : // read data.
    (cur_mode == M_SSPI) ? 4'b0001 :
    (cur_mode == M_DSPI) ? 4'b0011 :
    (cur_mode == M_QSPI) ? 4'b1111 :
    4'h0;
reg [3:0] q_odata;

genvar i;
generate
    for (i=0; i < 4; i=i+1 ) begin:hist
        assign q_o[i] = (q_dir_out[i]) ? q_odata[i]: 1'hz;
    end
endgenerate

// assign q_o = (q_dir_out) ? q_odata: 4'hz;
wire[3:0] q_idata = q_o;

reg  [6:0] bit_cnt;
wire [5:0] bit_len = bit_cnt[6:1];

reg [31:0] cur_byte;
reg [1 :0] cur_size;
reg [1 :0] cur_mode;

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        curr_state <= S_IDLE;
    end else begin
        curr_state <= next_state;
    end
end

always@ (negedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        next_state     <= S_IDLE;
        reco_state     <= S_IDLE;
        data_has_write <= 1'b0;
        busy           <= 1'b0;
        dataready      <= 1'b0;
    end else begin
        case (curr_state)
            S_IDLE: begin
                if (start) begin
                    reco_state <= S_IDLE;
                    next_state <= S_SWICH;
                end 
                dataready <= 1'b0;
            end

            S_SWICH: begin
                busy       <= 1'b0;
                dataready  <= 1'b0;
                next_state <= __next_state_should_be;
                case (__next_state_should_be) 
                    S_CMD: begin
                        cur_byte <= {24'b0, cmd};
                        cur_size <= 2'b1;
                        cur_mode <= cmd_mode;
                    end
                    S_ADDR: begin
                        cur_byte <= addr;
                        cur_size <= __asize[1:0];
                        cur_mode <= addr_mode;
                    end
                    S_ALBT: begin
                        cur_byte <= alterbytes;
                        cur_size <= __bsize[1:0];
                        cur_mode <= ab_mode;
                    end
                    S_DATA: begin
                        cur_byte <= data_write;
                        cur_size <= __dsize[1:0];
                        cur_mode <= data_mode;
                        data_has_write <= 1'b1;
                        busy           <= 1'b1;
                    end

                    S_IDLE: begin
                        dataready <= 1'b1;
                    end
                endcase
            end

            S_CMD: begin
                if (bit_len == {1'b0, __cmd_cycles}) begin
                    reco_state <= S_CMD;
                    next_state <= S_SWICH;
                end
            end

            S_ADDR: begin
                if (bit_len == __addr_cycles) begin
                    reco_state <= S_ADDR;
                    next_state <= S_SWICH;
                end
            end

            S_ALBT: begin
                if (bit_len == __alby_cycles) begin
                    reco_state <= S_ALBT;
                    next_state <= S_SWICH;
                end
            end

            S_DUMM: begin
                if (bit_len == {1'b0, dummy_cycles}) begin
                    reco_state <= S_DUMM;
                    next_state <= S_SWICH;
                end
            end

            S_DATA: begin
                data_has_write <= 1'b0;
                if (bit_len == __data_cycles ) begin // && data exist.
                    reco_state <= S_DATA;
                    next_state <= S_SWICH;
                    dataready <= 1'b1;
                end
            end

            S_Wait: begin
                if (next_wdata_ready == wr) begin
                    reco_state <= S_Wait;
                    next_state <= S_SWICH;
                end else if (start == 1'b0) begin
                    next_state <= S_IDLE;
                end
            end
        endcase
    end
end

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        csn <= 1'b1;
    end else begin
        if (next_state != S_IDLE && next_state != S_Wait) begin
            bit_cnt <= bit_cnt + 7'b1;
            sclk <= bit_cnt[0];
        end

        if (     
            next_state == S_CMD        || 
            next_state == S_ADDR       ||
            next_state == S_ALBT       ||
           (next_state == S_DATA && wr)) 
        begin
            case (cur_mode) 
                M_SSPI: begin
                    q_odata <= {3'h0, cur_byte[ {cur_size, 3'b0} -  bit_len[4:0]        - 5'b1     ]};
                end

                M_DSPI: begin
                    q_odata <= {2'h0, cur_byte[ {cur_size, 3'b0} - {bit_len[3:0], 1'b0} - 5'b1 -: 2]};
                end

                M_QSPI: begin
                    q_odata <=        cur_byte[ {cur_size, 3'b0} - {bit_len[2:0], 2'b0} - 5'b1 -: 4];
                end
            endcase
        end

        case (next_state)
            S_IDLE: begin
                bit_cnt <= 7'b0;
                sclk <= 1'b0;
                csn <= 1'b1;
            end

            S_SWICH: begin
                bit_cnt <= 7'b0;
                sclk <= 1'b0;
                csn <= 1'b0;
            end

            S_Wait: begin
                bit_cnt <= 7'b0;
                sclk <= 1'b0;
            end

            S_DUMM: begin
                // let output `z
            end

            S_DATA: begin
                if (~wr) begin // read mode
                    if (bit_cnt[0]) begin
                        case (cur_mode) 
                            M_SSPI: begin
                                data_out <= {data_out[30:0], q_idata[1]};
                            end

                            M_DSPI: begin
                                data_out <= {data_out[29:0], q_idata[1:0]};
                            end

                            M_QSPI: begin
                                data_out <= {data_out[27:0], q_idata};
                            end
                        endcase
                    end
                end
            end
        endcase
    end
end

endmodule