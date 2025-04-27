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
//   > File Name   : soc_top.v
//   > Description : SoC, included cpu, 2 x 3 bridge,
//                   inst ram, confreg, data ram
// 
//           -------------------------
//           |           cpu         |
//           -------------------------
//         inst|                  | data
//             |                  | 
//             |        ---------------------
//             |        |    1 x 2 bridge   |
//             |        ---------------------
//             |             |            |           
//             |             |            |           
//      -------------   -----------   -----------
//      | inst ram  |   | data ram|   | confreg |
//      -------------   -----------   -----------
//
//   > Author      : LOONGSON
//   > Date        : 2017-08-04
//*************************************************************************

`timescale 1ns / 1ps
`include "async_ram.sv"
`default_nettype none

//for simulation:
//1. if define SIMU_USE_PLL = 1, will use clk_pll to generate cpu_clk/timer_clk,
//   and simulation will be very slow.
//2. usually, please define SIMU_USE_PLL=0 to speed up simulation by assign
//   cpu_clk/timer_clk = clk.
//   at this time, cpu_clk/timer_clk frequency are both 100MHz, same as clk.
`define SIMU_USE_PLL 0 //set 0 to speed up simulation

module soc_lite_top #(parameter SIMULATION=1'b0)
(
    input          resetn, 
    input          clk,

    //------gpio-------
    output  [15:0] led,
    output  [1 :0] led_rg0,
    output  [1 :0] led_rg1,
    output  [7 :0] num_csn,
    output  [6 :0] num_a_g,
    output  [31:0] num_data,
    input   [7 :0] switch_1, //修改switch，C语言关键字
    output  [3 :0] btn_key_col,
    input   [3 :0] btn_key_row,
    input   [1 :0] btn_step,

    // trace debug interface
    output  [31:0] debug_wb_pc,
    output  [ 3:0] debug_wb_rf_wen,
    output  [ 4:0] debug_wb_rf_wnum,
    output  [31:0] debug_wb_rf_wdata,
    output  open_trace
);
//debug signals
// logic [31:0] debug_wb_pc;
// logic [3 :0] debug_wb_rf_we;
// logic [4 :0] debug_wb_rf_wnum;
// logic [31:0] debug_wb_rf_wdata;

//clk and resetn
logic cpu_clk;
logic timer_clk;
logic cpu_resetn;
always @(posedge cpu_clk)
begin
    cpu_resetn <= resetn;
end
assign cpu_clk = clk; //sim
// generate if(SIMULATION && `SIMU_USE_PLL==0)
// begin: speedup_simulation
//     assign cpu_clk   = clk;
//     assign timer_clk = clk;
// end
// else
// begin: pll
//     clk_pll clk_pll
//     (
//         .clk_in1 (clk),
//         .cpu_clk (cpu_clk),
//         .timer_clk (timer_clk)
//     );
// end
// endgenerate

//cpu inst sram

logic        cpu_inst_we;
logic [31:0] cpu_inst_addr;
logic [31:0] cpu_inst_wdata;
logic [31:0] cpu_inst_rdata;
//cpu data sram
logic        cpu_data_we;
logic [31:0] cpu_data_addr;
logic [31:0] cpu_data_wdata;
logic [31:0] cpu_data_rdata;

//data sram
logic        data_sram_en;
logic        data_sram_we;
logic [31:0] data_sram_addr;
logic [31:0] data_sram_wdata;
logic [31:0] data_sram_rdata;

//conf
logic        conf_en;
logic        conf_we;
logic [31:0] conf_addr;
logic [31:0] conf_wdata;
logic [31:0] conf_rdata;

//cpu
mycpu_top cpu(
    .clk              (cpu_clk       ),
    .resetn           (cpu_resetn    ),  //low active

    .inst_sram_we     (cpu_inst_we   ),
    .inst_sram_addr   (cpu_inst_addr ),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_rdata  (cpu_inst_rdata),
   
    .data_sram_we     (cpu_data_we   ),
    .data_sram_addr   (cpu_data_addr ),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_rdata  (cpu_data_rdata),

    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_wen   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

//inst ram
inst_ram inst_ram
(
    .clk   (cpu_clk            ),   
    .we    (cpu_inst_we        ),   
    .a     (cpu_inst_addr[16:2]), //17:2  
    .d     (cpu_inst_wdata     ),   
    .spo   (cpu_inst_rdata     )   
);

//logic cpu_data_en = 1'b1;

bridge_1x2 bridge_1x2(
    .clk             ( cpu_clk         ), // i, 1                 
    .resetn          ( cpu_resetn      ), // i, 1                 
	  
//    .cpu_data_en     ( cpu_data_en     ), //i sim add
    .cpu_data_we     ( cpu_data_we     ), // i, 4                 
    .cpu_data_addr   ( cpu_data_addr   ), // i, 32                
    .cpu_data_wdata  ( cpu_data_wdata  ), // i, 32                
    .cpu_data_rdata  ( cpu_data_rdata  ), // o, 32                

    .data_sram_en    ( data_sram_en    ),			   
    .data_sram_we    ( data_sram_we    ), // o, 4                 
    .data_sram_addr  ( data_sram_addr  ), // o, `DATA_RAM_ADDR_LEN
    .data_sram_wdata ( data_sram_wdata ), // o, 32                
    .data_sram_rdata ( data_sram_rdata ), // i, 32                

    .conf_en         ( conf_en         ), // o, 1                 
    .conf_we         ( conf_we         ), // o, 4                 
    .conf_addr       ( conf_addr       ), // o, 32                
    .conf_wdata      ( conf_wdata      ), // o, 32                
    .conf_rdata      ( conf_rdata      )  // i, 32                
 );

//data ram
data_ram data_ram
(
    .clk   (cpu_clk            ),   
    .we    (data_sram_we & data_sram_en),   
    .a     (data_sram_addr[16:2]),   //17：2
    .d     (data_sram_wdata    ),   
    .spo   (data_sram_rdata    )   
);

//confreg
confreg #(.SIMULATION(SIMULATION)) u_confreg
(
    .clk          ( cpu_clk    ),  // i, 1   
    .timer_clk    ( timer_clk  ),  // i, 1   
    .resetn       ( cpu_resetn ),  // i, 1    
    .conf_en      ( conf_en    ),  // i, 1      
    .conf_we      ( conf_we    ),  // i, 4      
    .conf_addr    ( conf_addr  ),  // i, 32        
    .conf_wdata   ( conf_wdata ),  // i, 32         
    .conf_rdata   ( conf_rdata ),  // o, 32         
    .led          ( led        ),  // o, 16   
    .led_rg0      ( led_rg0    ),  // o, 2      
    .led_rg1      ( led_rg1    ),  // o, 2      
    .num_csn      ( num_csn    ),  // o, 8      
    .num_a_g      ( num_a_g    ),  // o, 7      
    .num_data     ( num_data   ),  // o, 32
    .switch_1     ( switch_1     ),  // i, 8     
    .btn_key_col  ( btn_key_col),  // o, 4          
    .btn_key_row  ( btn_key_row),  // i, 4           
    .btn_step     ( btn_step   ),  // i, 2   
    .open_trace  (open_trace)  //add for verilator
);

endmodule

