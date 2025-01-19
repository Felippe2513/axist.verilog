AXI Stream Header Insertion Module
Overview
This project provides a Verilog implementation of the axi_stream_insert_header module, designed to process AXI Stream data by inserting a header into the stream. The module takes two AXI Stream signals as input: one for the original data and one for the header to be inserted. The output is a single AXI Stream signal containing the original data with the header inserted. The module also handles the removal of unnecessary bytes at the beginning of the header.

The AXI Stream protocol, including the structure of valid, ready, data, keep, and last signals, is followed throughout the design. The header is inserted between the first and last data, and the module processes the data in compliance with AXI Stream specifications.

Features
Inserts a header into an AXI Stream data stream.
Handles multiple data widths (8, 16, 32, 64, etc.).
Correctly processes the last byte in a data packet, ensuring the integrity of data and header.
Configurable data width and byte count for both data and header signals.
Compliance with AXI Stream handshake protocol: valid, ready, data, keep, last.
Module Interface
Inputs
clk: Clock signal.
rst_n: Active-low reset signal.
valid_in: Indicates if input data is valid.
data_in: Input data stream to which the header will be inserted.
keep_in: Specifies which bytes of the input data are valid.
last_in: Indicates the last byte of input data.
valid_insert: Indicates if the header data is valid.
data_insert: Header data to be inserted.
keep_insert: Specifies which bytes of the header are valid.
byte_insert_cnt: Specifies the number of valid bytes in the header.
Outputs
ready_in: Indicates if the module is ready to receive input data.
valid_out: Indicates if the output data is valid.
data_out: Output data stream with the header inserted.
keep_out: Specifies which bytes of the output data are valid.
last_out: Indicates the last byte of the output data.
ready_out: Indicates if the module is ready to receive output data.
Parameters
DATA_WD: Width of the data signal (default: 32).
DATA_BYTE_WD: Width of the data in bytes (default: DATA_WD / 8).
BYTE_CNT_WD: Width of the byte count signal.
Installation
To use the axi_stream_insert_header module, follow these steps:

Clone the repository to your local machine:

bash
复制代码
git clone https://github.com/yourusername/axi-stream-insert-header.git
Compile the Verilog files using your preferred Verilog synthesis tool (e.g., Xilinx Vivado, Synopsys Design Compiler).

Run simulations to verify the functionality of the module, ensuring the proper insertion of the header and correct data alignment.

Usage
Once the module is integrated into your design, connect the inputs and outputs as described above. The module will insert the header into the incoming AXI Stream data and output the result, maintaining the AXI Stream handshake protocol.

Example
verilog
复制代码
axi_stream_insert_header #(
    .DATA_WD(32),
    .DATA_BYTE_WD(4)
) header_inserter (
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
Simulation
You can verify the functionality of the module by running a testbench that stimulates the module's inputs and checks the outputs.
