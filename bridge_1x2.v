/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

//*************************************************************************
//   > File Name   : bridge_1x2.v
//   > Description : bridge between cpu_data and data ram, confreg
//   
//     master:    cpu_data
//                   |  \
//     1 x 2         |   \  
//     bridge:       |    \                    
//                   |     \       
//     slave:   data_ram  confreg
//
//   > Author      : LOONGSON
//   > Date        : 2017-08-04
//*************************************************************************
`timescale 1ns / 1ps
`define CONF_ADDR_BASE 32'h1faf_0000
`define CONF_ADDR_MASK 32'h1fff_0000 //for bfaf or 1faf
module bridge_1x2(                                 
    input  wire                          clk,          // clock 
    input  wire                          resetn,       // reset, active low
    // master : cpu data
    input  wire                          cpu_data_we,      // cpu data write byte enable
    input  wire [31                  :0] cpu_data_addr,    // cpu data address
    input  wire [31                  :0] cpu_data_wdata,   // cpu data write data
    output wire [31                  :0] cpu_data_rdata,   // cpu data read data
    // slave : data ram 
    output wire                          data_sram_en,     // access data_sram enable
    output wire                          data_sram_we,     // write enable 
    output wire [31                  :0] data_sram_addr,   // address
    output wire [31                  :0] data_sram_wdata,  // data in
    input  wire [31                  :0] data_sram_rdata,  // data out
    // slave : confreg 
    output wire                          conf_en,          // access confreg enable 
    output wire                          conf_we,          // access confreg enable 
    output wire [31                  :0] conf_addr,        // address
    output wire [31                  :0] conf_wdata,       // write data
    input  wire [31                  :0] conf_rdata        // read data
);
    wire sel_sram;  // cpu data is from data ram
    wire sel_conf;  // cpu data is from confreg

    assign sel_conf = (cpu_data_addr & `CONF_ADDR_MASK) == `CONF_ADDR_BASE;
    assign sel_sram = !sel_conf;

    // data sram
    assign data_sram_en    = sel_sram;
    assign data_sram_we    = cpu_data_we;
    assign data_sram_addr  = cpu_data_addr;
    assign data_sram_wdata = cpu_data_wdata;

    // confreg
    assign conf_en    = sel_conf;
    assign conf_we    = cpu_data_we;
    assign conf_addr  = cpu_data_addr;
    assign conf_wdata = cpu_data_wdata;

    assign cpu_data_rdata = {32{sel_sram}} & data_sram_rdata
                          | {32{sel_conf}} & conf_rdata;

endmodule

