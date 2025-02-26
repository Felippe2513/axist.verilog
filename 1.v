module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input clk,
    input rst_n,
    // AXI Stream input original data
    input valid_in,
    input [DATA_WD-1 : 0] data_in,
    input [DATA_BYTE_WD-1 : 0] keep_in,
    input last_in,
    output ready_in,
    // AXI Stream output with header inserted
    output valid_out,
    output [DATA_WD-1 : 0] data_out,
    output [DATA_BYTE_WD-1 : 0] keep_out,
    output last_out,
    input ready_out,
    // The header to be inserted to AXI Stream input
    input valid_insert,
    input [DATA_WD-1 : 0] data_insert,
    input [DATA_BYTE_WD-1 : 0] keep_insert,
    input [BYTE_CNT_WD-1 : 0] byte_insert_cnt,
    output ready_insert
);
// Your code here

reg [DATA_WD - 1 : 0]               data_insert_r;
reg [DATA_BYTE_WD - 1 : 0]          keep_insert_r;
reg [BYTE_CNT_WD-1 : 0]             byte_insert_cnt_r;

reg [DATA_WD - 1 : 0]               data_in_r;
reg                                 last_in_r;
reg [DATA_BYTE_WD - 1 : 0]          keep_in_r;

reg                                 last_out_r;
reg [DATA_WD - 1 : 0]               data_out_r;
reg                                 valid_out_r;
reg [DATA_BYTE_WD - 1 : 0]          keep_out_r;

reg                                 ready_insert_r;

/*-----------------------------------------------------header_insert-----------------------------------------------*/
assign ready_insert = ready_out && ready_insert_r;                          

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        data_insert_r     <= 0;
        keep_insert_r     <= 0;
        byte_insert_cnt_r <= 0;
        ready_insert_r    <= 1;
    end
    else if(ready_out)begin
        if(valid_in&&valid_insert)begin
            if(last_in_r || (keep_insert != keep_insert_r))begin                                            //第一个数据用keep_insert判断截取方式，将data_insert有效字节存入data_insert_r
                case(keep_insert)
                    4'b0001:begin
                    data_insert_r <= {{3{8'h00}},data_insert[7 : 0]};
                    end
                    4'b0011:begin
                    data_insert_r <= {{2{8'h00}},data_insert[15 : 0]};
                    end
                    4'b0111:begin
                    data_insert_r <= {{8'h00},data_insert[23 : 0]};
                    end
                    4'b1111:begin
                    data_insert_r <= {data_insert[31 : 0]};
                    end
                    default:begin
                    data_insert_r <= {data_insert};
                    end
                endcase
                keep_insert_r     <= keep_insert;
                byte_insert_cnt_r <= byte_insert_cnt;
                ready_insert_r    <= 0;
            end
            else begin                                                       //之后数据用keep_insert_r判断截取方式，将data_in_r有效字节存入data_insert_r
                case(keep_insert_r)
                    4'b0001:begin
                    data_insert_r <= {{3{8'h00}},data_in_r[7 : 0]};
                    end
                    4'b0011:begin
                    data_insert_r <= {{2{8'h00}},data_in_r[15 : 0]};
                    end
                    4'b0111:begin
                    data_insert_r <= {{8'h00},data_in_r[23 : 0]};
                    end
                    4'b1111:begin
                    data_insert_r <= {data_in_r[31 : 0]};
                    end
                    default:begin
                    data_insert_r <= data_insert_r;
                    end
                endcase
                keep_insert_r     <= keep_insert_r;
                byte_insert_cnt_r <= byte_insert_cnt_r;
                ready_insert_r    <= ready_insert_r;
            end
        end 
        else begin                                                          //valid_insert=1 判断一笔data_insert传输完成，复位insert
            keep_insert_r     <= 0;
            data_insert_r     <= 0;
            byte_insert_cnt_r <= 0;
            ready_insert_r    <= 1;
        end
    end
    else begin                                                             //中断传输，立即缓存当前数据
        keep_insert_r     <= keep_insert_r;
        data_insert_r     <= data_insert_r;
        byte_insert_cnt_r <= byte_insert_cnt_r;
        ready_insert_r    <= ready_insert_r;
    end
end

/*-----------------------------------------------------data_in-------------------------------------------------------*/
assign ready_in = ready_out;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        data_in_r <= 0;
        last_in_r <= 0;
        keep_in_r <= 0;
    end
    else if(ready_out)begin
        if(valid_in&&valid_insert)begin
            data_in_r <= data_in;
            last_in_r <= last_in;
            keep_in_r <= keep_in;
        end
        else begin
            data_in_r <= 0;
            last_in_r <= 0;
            keep_in_r <= 0;
        end
    end
    else begin
        data_in_r <= data_in_r;
        last_in_r <= last_in_r;
        keep_in_r <= keep_in_r;
    end    
end

/*-----------------------------------------------------data_out------------------------------------------------------*/

assign data_out = data_out_r;
assign valid_out = valid_out_r || last_out_r;
assign keep_out = keep_out_r;
assign last_out = last_out_r;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        data_out_r <= 0;
        keep_out_r <= 0;
        last_out_r <= 0;
    end
    else if (ready_out) begin
            case({keep_insert_r,keep_in_r})
            8'b0001_1000:begin
                data_out_r <= {data_insert_r[7:0],data_in_r[31:24],{2{8'h00}}};    
                keep_out_r <= 4'b1110;
                last_out_r <= 1;
            end 
            8'b0001_1100:begin
                data_out_r <= {data_insert_r[7:0],data_in_r[31:16],{8'h00}};    
                keep_out_r <= 4'b1110;
                last_out_r <= 1;
            end          
            8'b0001_1110:begin
                data_out_r <= {data_insert_r[7:0],data_in_r[31:8]};    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end
            8'b0001_1111:begin
                data_out_r <= {data_insert_r[7:0],data_in_r[31:8]};    
                keep_out_r <= 4'b1111;
                if(last_in_r) 
                    last_out_r <= 1;
                else 
                    last_out_r <= 0;
            end
            8'b0011_1000:begin
                data_out_r <= {data_insert_r[15:0],data_in_r[31:24],{2{8'h00}}};    
                keep_out_r <= 4'b1110;
                last_out_r <= 1;
            end 
            8'b0011_1100:begin
                data_out_r <= {data_insert_r[15:0],data_in_r[31:16]};    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end          
            8'b0011_1110:begin
                data_out_r <= {data_insert_r[15:0],data_in_r[31:16]};    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end
            8'b0011_1111:begin
                data_out_r <= {data_insert_r[15:0],data_in_r[31:16]};    
                keep_out_r <= 4'b1111;
                if(last_in_r)
                    last_out_r <= 1;
                else
                    last_out_r <= 0;
            end
            8'b0111_1000:begin
                data_out_r <= {data_insert_r[23:0],data_in_r[31:24]};    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end
            8'b0111_1100:begin
                data_out_r <= {data_insert_r[23:0],data_in_r[31:24]};    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end 
            8'b0111_1110:begin
                data_out_r <= {data_insert_r[23:0],data_in_r[31:24]};    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end
            8'b0111_1111:begin
                data_out_r <= {data_insert_r[23:0],data_in_r[31:24]};    
                keep_out_r <= 4'b1111;
                if(last_in_r)
                    last_out_r <= 1;
                else
                    last_out_r <= 0;
            end
            8'b1111_1000:begin
                data_out_r <= data_insert_r;    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end
            8'b1111_1100:begin
                data_out_r <= data_insert_r;    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end 
            8'b1111_1110:begin
                data_out_r <= data_insert_r;    
                keep_out_r <= 4'b1111;
                last_out_r <= 1;
            end
            8'b1111_1111:begin
                data_out_r <= data_insert_r;    
                keep_out_r <= 4'b1111;
                if(last_in_r)
                    last_out_r <= 1;
                else
                    last_out_r <= 0;
            end
            default: begin
                data_out_r <= 0;
                keep_out_r <= 0;
                last_out_r <= 0;
            end                        
            endcase           
        end
    else begin
        data_out_r <= data_out_r;
        keep_out_r <= keep_out_r;
        last_out_r <= last_out_r;
    end
end

always @(posedge clk  or negedge rst_n) begin
    if(!rst_n) begin
        valid_out_r <= 0;
    end
    else if(valid_insert&&valid_in)begin
        if(!keep_insert_r)begin
            valid_out_r <= 0;
        end
        else begin
            valid_out_r <= 1;
        end
    end
    else begin
        valid_out_r <= 0;
    end
end
endmodule
