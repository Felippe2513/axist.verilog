`timescale 1ns/1ns
module tb_axi_stream_insert_header (); 
	reg rst_n;
	reg clk;
	
	initial begin
		clk = 0;
		forever #(5) clk = ~clk;
	end

	initial begin
		rst_n <= 0;
		#10 rst_n <= 1;
	end

	// 收发变量
	parameter 					DATA_WD = 32;
	parameter 					DATA_BYTE_WD = DATA_WD / 8;

	reg 					    valid_in;
	reg [DATA_WD-1 : 0] 		data_in;
	reg [DATA_BYTE_WD-1 : 0] 	keep_in;
	reg 						last_in;
	wire 						ready_in;

	reg  						valid_insert;
	reg [DATA_WD-1 : 0] 		data_insert;
	reg [DATA_BYTE_WD-1 : 0] 	keep_insert;
	reg [1 : 0] 				byte_insert_cnt;
	wire 						ready_insert;

	wire 						valid_out;
	wire [DATA_WD-1 : 0] 		data_out;
	wire [DATA_BYTE_WD-1 : 0] 	keep_out;
	wire 						last_out;
	reg 						ready_out;

	integer i;

	axi_stream_insert_header #(
			.DATA_WD			(DATA_WD),
			.DATA_BYTE_WD		(DATA_BYTE_WD)
		) inst_axi_stream_insert_header (
			.clk 				(clk),
			.rst_n 				(rst_n),
			.valid_in 			(valid_in),
			.data_in 			(data_in),
			.keep_in 			(keep_in),
			.last_in 			(last_in),
			.ready_in 			(ready_in),
			.valid_insert 		(valid_insert),
			.data_insert 		(data_insert),
			.keep_insert 		(keep_insert),
			.ready_insert 		(ready_insert),
			.byte_insert_cnt	(byte_insert_cnt),
			.valid_out 			(valid_out),
			.data_out 			(data_out),
			.keep_out 			(keep_out),
			.last_out 			(last_out),
			.ready_out			(ready_out)
		);

	task init();begin
		valid_in 				<= 0;
		data_in 				<= 0;
		keep_in 				<= 0;
		last_in 				<= 0;
		valid_insert 			<= 0;
		data_insert 			<= 0;
		keep_insert 			<= 0;
		byte_insert_cnt 		<= 0;
		ready_out 				<= 0;	
		@(posedge clk);
		ready_out 				<= 1;
		valid_insert 			<= 1;
		valid_in 				<= 1;
		repeat(4)@(posedge clk);
	end
	endtask

	task data_unready();begin
		keep_in       		<= keep_in;
		last_in       		<= last_in;
		data_in       		<= data_in;
	end
	endtask

	task data_ready(input last_n);begin
		keep_in       <= 4'b1111;
		last_in       <= last_n;
		data_in       <= {$random};
	end
	endtask

	task insert_unready();begin
		data_insert 		<= data_insert;
		keep_insert  		<= keep_insert;
		byte_insert_cnt 	<= byte_insert_cnt;
	end
	endtask

	task insert_ready();begin
		data_insert   	   <= {$random};
		keep_insert   	   <= 4'b0111;
		byte_insert_cnt    <= byte_insert_cnt;
	end
	endtask

	task driver();begin
		case ({ready_in,ready_insert}) 
		2'b00: begin
			data_unready();
			insert_unready();
			@(posedge clk);
		end	
		2'b01: begin
			data_unready();
			insert_ready();
			@(posedge clk);
		end
		2'b11: begin
			data_ready(0);
			insert_ready();
			@(posedge clk);
		end
		2'b10: begin
			data_ready(0);
			insert_unready();
			@(posedge clk);
		end
		default: begin
			data_ready(0);
			insert_ready();
			@(posedge clk);
		end			
		endcase	
	end
	endtask

	task driver_last();begin
		case ({ready_in,ready_insert}) 
		2'b00: begin
			data_unready();
			insert_unready();
			@(posedge clk);
		end	
		2'b01: begin
			data_unready();
			insert_ready();
			@(posedge clk);
		end
		2'b11: begin
			data_ready(1);
			insert_ready();
			@(posedge clk);
		end
		2'b10: begin
			data_ready(1);
			insert_unready();
			@(posedge clk);
		end
		default: begin
			data_ready(1);
			insert_ready();
			@(posedge clk);
		end			
		endcase	
	end
	endtask

	task nextdata();begin
		keep_in       <= 4'b1111;
		last_in       <= 0;
		data_in       <= {$random};
		repeat(2)@(posedge clk);
		valid_insert  <= 0;
	end
	endtask

	task last2();begin
		keep_in       <= 4'b1110;
		last_in       <= 1;
		data_in       <= {$random};
		@(posedge clk);
		last_in       <= 0;
	end
	endtask

	task close();begin
		valid_in  	  <= 0;
		valid_insert  <= 0;
		repeat(2)@(posedge clk);
		ready_out     <= 0;
		@(posedge clk);
	end
	endtask	

	initial begin
		init();
		for (i=0; i< 6; i = i + 1) begin
			driver();
			if(i <= 3 && i >= 1)
				ready_out <= 0;
			else
				ready_out <= 1;		
		end
		driver_last();

		for (i=0; i< 6; i = i + 1) begin
			driver();			
		end
		driver_last();
		close();
	end

	initial begin
      forever begin
         #100;
         if ($time >= 1000)  $finish ;
      end
   end

endmodule
