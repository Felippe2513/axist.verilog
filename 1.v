module axi_stream_insert_header #(
    parameter DATA_WD = 32,                // 数据宽度
    parameter DATA_BYTE_WD = DATA_WD / 8, // 数据字节宽度
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD) // 字节计数宽度
) (
    input clk,
    input rst_n,

    // AXI Stream 输入数据
    input valid_in,
    input [DATA_WD-1:0] data_in,
    input [DATA_BYTE_WD-1:0] keep_in,
    input last_in,
    output ready_in,

    // AXI Stream 输出数据，带有插入的 header
    output valid_out,
    output [DATA_WD-1:0] data_out,
    output [DATA_BYTE_WD-1:0] keep_out,
    output last_out,
    input ready_out,

    // 要插入的 header 数据
    input valid_insert,
    input [DATA_WD-1:0] data_insert,
    input [DATA_BYTE_WD-1:0] keep_insert,
    input [BYTE_CNT_WD-1:0] byte_insert_cnt,
    output ready_insert
);

    // 内部信号声明
    reg valid_out_reg, last_out_reg, inserting_header, buffer_valid;
    reg [DATA_WD-1:0] data_out_reg, buffered_data;
    reg [DATA_BYTE_WD-1:0] keep_out_reg;
    reg [BYTE_CNT_WD-1:0] byte_cnt;

    // 新增反压相关寄存器
    reg ready_in_reg, ready_insert_reg;

    // 输出赋值
    assign valid_out = valid_out_reg;
    assign data_out = data_out_reg;
    assign keep_out = keep_out_reg;
    assign last_out = last_out_reg;
    assign ready_in = ready_in_reg; // 显式反压寄存器输出
    assign ready_insert = ready_insert_reg; // 显式反压寄存器输出

    ///////////////////////////////////////////////////////////////////
    // 显式实现反压机制
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ready_in_reg <= 1'b0;
            ready_insert_reg <= 1'b0;
        end else begin
            // 当前模块是否能够接收上游数据
            ready_in_reg <= !inserting_header && (!buffer_valid || ready_out);

            // 当前模块是否能够接收 header 数据
            ready_insert_reg <= (!buffer_valid && ready_out);
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 缓冲区逻辑：管理 header 数据的插入
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            buffer_valid <= 1'b0;
            buffered_data <= {DATA_WD{1'b0}};
        end else if (valid_insert && ready_insert_reg && !buffer_valid) begin
            // 缓冲 header 数据
            buffer_valid <= 1'b1;
            buffered_data <= data_insert;
        end else if (buffer_valid && ready_out) begin
            // header 数据被消费后清空缓冲
            buffer_valid <= 1'b0;
        end
        /*双通道缓冲设计确保在 header 和主数据流之间切换时，不会因为冲突或延迟而引发数据间的空拍*/
    end

    ///////////////////////////////////////////////////////////////////
    // 插入 header 的状态管理
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inserting_header <= 1'b0;
            byte_cnt <= 0;
        end else if (valid_insert && !inserting_header && ready_insert_reg) begin
            inserting_header <= 1'b1;
            byte_cnt <= byte_insert_cnt;
        end else if (inserting_header && byte_cnt > 0 && ready_out) begin
            byte_cnt <= byte_cnt - 1;
            if (byte_cnt == 1)
                inserting_header <= 1'b0; // 完成插入，cnt精准控制插入，插入完成后恢复主数据流使传输无间断，无气泡
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 数据输出逻辑：根据优先级选择输出 header 或主数据流
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            data_out_reg <= {DATA_WD{1'b0}};
            keep_out_reg <= {DATA_BYTE_WD{1'b0}};
        end else if (buffer_valid) begin
            data_out_reg <= buffered_data;
            keep_out_reg <= keep_insert;
        end else if (valid_in && ready_in_reg) begin
             // 处理 last_in 的情况，动态更新 keep_out
            if (last_in) begin
                // 处理最后一拍的有效字节
                case (keep_in)
                4'b1111: keep_out_reg <= 4'b1111;  // 所有字节有效
                4'b1110: keep_out_reg <= 4'b1110;  // 最后一个字节无效
                4'b1100: keep_out_reg <= 4'b1100;  // 最后两个字节无效
                4'b1000: keep_out_reg <= 4'b1000;  // 最后三个字节无效
                default: keep_out_reg <= 4'b0000;  // 无效的 keep_in
                endcase
            end else begin
                // 不是最后一拍，所有字节有效
                keep_out_reg <= keep_in;
            end
            data_out_reg <= data_in;//其次再输出主数据流
        end
    end

    ///////////////////////////////////////////////////////////////////
    // valid_out 的逻辑
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            valid_out_reg <= 1'b0;
        else if (ready_out) begin
            // 当下游准备好接收时，更新 valid_out
            valid_out_reg <= buffer_valid || (valid_in && ready_in);
        end
        else begin
            valid_out_reg <= valid_out_reg;
            //没准备好的时候不变
        end
    end    

    ///////////////////////////////////////////////////////////////////
    // last_out 的逻辑
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            last_out_reg <= 1'b0;
        else if (buffer_valid) begin
             // Header 数据永远不是最后一拍
            last_out_reg <= 1'b0;
        end else if (valid_in && last_in && ready_out) begin
             // 主数据流的最后一拍
            last_out_reg <= 1'b1;
        end else begin
            last_out_reg <= 1'b0;
        end
    end

endmodule