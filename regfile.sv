`timescale 1ns / 1ps
module regfile(   
     input  wire        clk,
    // READ PORT 1
    input  wire [ 4:0] raddr1,
    output wire [31:0] rdata1,
    // READ PORT 2
    input  wire [ 4:0] raddr2,
    output wire [31:0] rdata2,
    // WRITE PORT
    input  wire        we,       //write enable, HIGH valid
    input  wire [ 4:0] waddr,
    input  wire [31:0] wdata
    );

  logic [31:0] rf[31:0];

  always_ff @(posedge clk)
    if (we) rf[waddr] <= wdata;	

  assign rdata1 = (raddr1 != 0) ? rf[raddr1] : 0;
  assign rdata2 = (raddr2 != 0) ? rf[raddr2] : 0;
endmodule

