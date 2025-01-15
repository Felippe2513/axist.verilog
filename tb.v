module tb_axi_stream_insert_header;

    // Parameter Definitions
    parameter DATA_WD = 32;                // 数据宽度
    parameter DATA_BYTE_WD = DATA_WD / 8; // 数据字节宽度
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD); // 字节计数宽度

    // DUT Signal Declarations
    reg clk, rst_n;
    reg valid_in, valid_insert, last_in;
    reg [DATA_WD-1:0] data_in, data_insert;
    reg [DATA_BYTE_WD-1:0] keep_in, keep_insert;
    reg [BYTE_CNT_WD-1:0] byte_insert_cnt;
    wire ready_in, ready_insert;
    wire valid_out, last_out;
    wire [DATA_WD-1:0] data_out;
    wire [DATA_BYTE_WD-1:0] keep_out;
    reg ready_out;

    // DUT Instance
    axi_stream_insert_header #(
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD),
        .BYTE_CNT_WD(BYTE_CNT_WD)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .keep_in(keep_in),
        .last_in(last_in),
        .ready_in(ready_in),
        .valid_out(valid_out),
        .data_out(data_out),
        .keep_out(keep_out),
        .last_out(last_out),
        .ready_out(ready_out),
        .valid_insert(valid_insert),
        .data_insert(data_insert),
        .keep_insert(keep_insert),
        .byte_insert_cnt(byte_insert_cnt),
        .ready_insert(ready_insert)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz Clock
    end

    // Reset Generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    // AXI Protocol-Compliant Valid Signal Generation
    initial begin
        valid_in = 0;
        valid_insert = 0;
        ready_out = 0;
        last_in = 0;
        data_in = 0;
        data_insert = 0;
        keep_in = 0;
        keep_insert = 0;
        byte_insert_cnt = 0;

        @(posedge rst_n);
        repeat (100) begin
            // Ready Signal Randomization
            ready_out = $random % 2;

            // Valid Signal Control
            if (!valid_in || (valid_in && ready_in)) begin
                // Only change valid_in when it is not set or it has been consumed
                valid_in = $random % 2; // Randomize valid_in
                if (valid_in) begin
                    data_in = $random;
                    keep_in = $random % (1 << DATA_BYTE_WD);
                    last_in = $random % 2;
                end
            end

            if (!valid_insert || (valid_insert && ready_insert)) begin
                // Only change valid_insert when it is not set or it has been consumed
                valid_insert = $random % 2; // Randomize valid_insert
                if (valid_insert) begin
                    data_insert = $random;
                    keep_insert = $random % (1 << DATA_BYTE_WD);
                    byte_insert_cnt = $random % DATA_BYTE_WD;
                end
            end

            // Delay for Random Behavior
            repeat ($urandom_range(1, 5)) @(posedge clk);
        end
    end

    // AXI Protocol Checker
// AXI Protocol Checker
    always @(posedge clk) begin
        if (valid_in && ~ready_in) begin
            if (valid_in != 1) begin
                // Valid must remain high if ready_in is low
                $display("ERROR: AXI protocol violation: valid_in dropped without ready_in!");
                $stop;
            end
        end

    
        if (valid_out && ~ready_out) begin
            // Valid must remain high if ready_out is low
            if (valid_out != 1) begin
                $display("ERROR: AXI protocol violation: valid_out dropped without ready_out!");
                $stop;
            end
        end
    
        if (valid_in && ready_in) begin
            $display("Data transferred: data_in=%h, keep_in=%b, last_in=%b", data_in, keep_in, last_in);
        end

        if (valid_out && ready_out) begin
            $display("Data output: data_out=%h, keep_out=%b, last_out=%b", data_out, keep_out, last_out);
        end
    end

    // Monitor Header Insertion
    always @(posedge clk) begin
        if (valid_insert && ready_insert) begin
            $display("Header Inserted: data_insert=%h, keep_insert=%b, byte_insert_cnt=%d", 
                     data_insert, keep_insert, byte_insert_cnt);
        end
    end

endmodule
