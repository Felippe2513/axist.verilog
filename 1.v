module axi_stream_insert_header #(
    parameter DATA_WD = 32,                // 数据宽度
    parameter DATA_BYTE_WD = DATA_WD / 8,  // 数据字节宽度
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD) // 字节计数宽度
) (
    input clk,
    input rst_n,

    // AXI Stream 输入数据
    input valid_in,                      // 输入数据的有效标志
    input [DATA_WD-1:0] data_in,         // 输入数据
    input [DATA_BYTE_WD-1:0] keep_in,    // 输入数据每个字节的有效性标志
    input last_in,                       // 标识输入数据是否为最后一拍
    output ready_in,                     // 输入数据的准备信号（反压）

    // AXI Stream 输出数据，带有插入的 header
    output valid_out,                    // 输出数据的有效标志
    output [DATA_WD-1:0] data_out,       // 输出数据（插入header后的数据）
    output [DATA_BYTE_WD-1:0] keep_out,  // 输出数据每个字节的有效性标志
    output last_out,                     // 标识输出数据是否为最后一拍
    input ready_out,                     // 输出数据的准备信号（反压）

    // 要插入的 header 数据
    input valid_insert,                  // 标识header数据是否有效
    input [DATA_WD-1:0] data_insert,     // 要插入的header数据
    input [DATA_BYTE_WD-1:0] keep_insert,// header数据每个字节的有效性标志
    input [BYTE_CNT_WD-1:0] byte_insert_cnt, // header数据有效字节数
    output ready_insert                  // header数据的准备信号（反压）
);

    // 内部信号声明
    reg r_valid_out, r_last_out, r_inserting_header, r_buffer_valid;
    // r_valid_out: 输出数据有效标志的寄存器
    // r_last_out: 输出数据最后一拍标志的寄存器
    // r_inserting_header: 标记当前是否正在插入header
    // r_buffer_valid: 标记缓冲区是否有效（即是否有header数据可用）

    reg [DATA_WD-1:0] r_data_out, r_buffered_data;
    // r_data_out: 输出数据寄存器
    // r_buffered_data: 缓存的header数据

    reg [DATA_BYTE_WD-1:0] r_keep_out;
    // r_keep_out: 输出数据每个字节的有效性标志寄存器

    reg [BYTE_CNT_WD-1:0] r_byte_cnt;
    // r_byte_cnt: 用于计数当前插入的header字节数

    // 新增反压相关寄存器
    reg r_ready_in, r_ready_insert;
    // r_ready_in: 用于反压输入数据的准备信号寄存器
    // r_ready_insert: 用于反压header数据的准备信号寄存器

    // 输出赋值
    assign valid_out = r_valid_out;
    assign data_out = r_data_out;
    assign keep_out = r_keep_out;
    assign last_out = r_last_out;
    assign ready_in = r_ready_in; // 显式反压寄存器输出
    assign ready_insert = r_ready_insert; // 显式反压寄存器输出

    ///////////////////////////////////////////////////////////////////
    // 显式实现反压机制
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_ready_in <= 1'b0;
            r_ready_insert <= 1'b0;
        end else begin
            // 当前模块是否能够接收上游数据
            r_ready_in <= !r_inserting_header && (!r_buffer_valid || ready_out);

            // 当前模块是否能够接收 header 数据
            r_ready_insert <= (!r_buffer_valid && ready_out);
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 缓冲区逻辑：管理 header 数据的插入
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_buffer_valid <= 1'b0;
            r_buffered_data <= {DATA_WD{1'b0}};
        end else if (valid_insert && r_ready_insert && !r_buffer_valid) begin
            // 缓冲 header 数据
            r_buffer_valid <= 1'b1;
            r_buffered_data <= data_insert;
        end else if (r_buffer_valid && ready_out) begin
            // header 数据被消费后清空缓冲
            r_buffer_valid <= 1'b0;
        end
        /*双通道缓冲设计确保在 header 和主数据流之间切换时，不会因为冲突或延迟而引发数据间的空拍*/
    end

    ///////////////////////////////////////////////////////////////////
    // 插入 header 的状态管理
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 当复位信号 rst_n 为低电平时，初始化状态
            r_inserting_header <= 1'b0; // 设置插入 header 的状态为非激活
            r_byte_cnt <= 0; // 初始化字节计数器为 0
        end else if (valid_insert && !r_inserting_header && r_ready_insert) begin
            // 当有有效的插入请求，当前未在插入 header，并且插入准备就绪时
            r_inserting_header <= 1'b1; // 设置插入 header 的状态为激活
            r_byte_cnt <= byte_insert_cnt; // 设置需要插入的字节数
        end else if (r_inserting_header && r_byte_cnt > 0 && ready_out) begin
            // 当正在插入 header，并且字节计数器大于 0，且输出准备好时
            r_byte_cnt <= r_byte_cnt - 1; // 字节计数器减 1
            if (r_byte_cnt == 1)
                r_inserting_header <= 1'b0; // 如果字节计数器为 1，则在下一个时钟周期后完成插入
            // 这样可以精准控制插入过程，确保插入完成后立即恢复主数据流，使传输无间断，无气泡
        end
    end

    ///////////////////////////////////////////////////////////////////
    // 数据输出逻辑：根据优先级选择输出 header 或主数据流
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_data_out <= {DATA_WD{1'b0}};
            r_keep_out <= {DATA_BYTE_WD{1'b0}};
        end else if (r_buffer_valid) begin
            r_data_out <= r_buffered_data;
            r_keep_out <= keep_insert;
        end else if (valid_in && r_ready_in) begin
             // 处理 last_in 的情况，动态更新 keep_out
            wire [BYTE_CNT_WD-1:0] valid_byte_count; // 最后一拍有效字节数
    wire [DATA_WD-1:0] dynamic_mask;         // 最后一拍动态掩码
    wire [DATA_WD-1:0] data_masked;         // 应用掩码后的数据

    // 计算有效字节数：遍历 keep_in 确定有效字节
    integer i;
    reg [BYTE_CNT_WD-1:0] count_valid_bytes;
    always @(*) begin
        count_valid_bytes = 0;
        for (i = 0; i < DATA_BYTE_WD; i = i + 1) begin
            if (keep_in[i]) begin
                count_valid_bytes = i + 1;
            end
        end
    end

    // 动态掩码生成：根据有效字节数
    assign dynamic_mask = (1 << (count_valid_bytes * 8)) - 1;
    assign data_masked = data_in & dynamic_mask;

    ///////////////////////////////////////////////////////////////////
    // 数据输出逻辑：根据优先级选择输出 header 或主数据流
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            r_data_out <= {DATA_WD{1'b0}};
            r_keep_out <= {DATA_BYTE_WD{1'b0}};
        end else if (r_buffer_valid) begin
            r_data_out <= r_buffered_data;
            r_keep_out <= keep_insert;
        end else if (valid_in && r_ready_in) begin
            if (last_in) begin
                r_data_out <= data_masked; // 最后一拍处理数据
                r_keep_out <= keep_in;     // 最后一拍保留原 keep
            end else begin
                r_data_out <= data_in;     // 常规数据流
                r_keep_out <= keep_in;
            end
        end
    end
    ///////////////////////////////////////////////////////////////////
    // valid_out 的逻辑
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            r_valid_out <= 1'b0;
        else if (ready_out) begin
            // 当下游准备好接收时，更新 valid_out
            r_valid_out <= r_buffer_valid || (valid_in && r_ready_in);
        end
        else begin
            r_valid_out <= r_valid_out;
            //没准备好的时候不变
        end
    end    

    ///////////////////////////////////////////////////////////////////
    // last_out 的逻辑
    ///////////////////////////////////////////////////////////////////
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
            r_last_out <= 1'b0;  // 复位时清除 r_last_out
        else begin
            // 如果 r_buffer_valid 为 1，表示当前数据是头部，不是最后一拍
            if (r_buffer_valid) 
                r_last_out <= 1'b0;
            // 处理最后一拍数据
            else if (valid_in && last_in && ready_out) 
                r_last_out <= 1'b1;  // 数据有效且 ready_out 准备好接收，设置为最后一拍
            else
                r_last_out <= 1'b0;  // 默认情况下不是最后一拍
        end
    end
    
endmodule
