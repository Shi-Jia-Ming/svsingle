`timescale 1ns / 1ps        // 定义仿真时间单位（1ns）和时间精度（1ps）
`include "tools.v"          // 包含工具函数的头文件
module mycpu_top(
    // 时钟和复位信号
    input          clk,         // 时钟信号
    input          resetn,      // 复位信号
    // inst sram interface 指令寄存器接口（只读）
    output         inst_sram_we,        // 写使能（固定为 0，不写指令）
    output  [31:0] inst_sram_addr,      // 指令存储器地址（PC值）
    output  [31:0] inst_sram_wdata,     // 写数据（未使用）
    input   [31:0] inst_sram_rdata,     // 读取的指令
    // data sram interface 数据存储器接口（读写）
    output         data_sram_we,        // 数据存储器使能
    output  [31:0] data_sram_addr,      // 数据地址（ALU计算结果）
    output  [31:0] data_sram_wdata,     // 写数据（寄存器 Rk 或 Rd 的值）
    input   [31:0] data_sram_rdata,     // 读取的数据
    // trace debug interface 调试接口（用于跟踪寄存器写回）
    output  [31:0] debug_wb_pc,         // PC 值
    output  [ 3:0] debug_wb_rf_we,      // 寄存器写使能（4 位，表示 4 个寄存器）
    output  [ 4:0] debug_wb_rf_wnum,    // 写入的寄存器编号
    output  [31:0] debug_wb_rf_wdata    // 写入的数据
);

// 复位信号处理（同步化）
logic         reset;
always @(posedge clk) reset <= ~resetn;     // 将低电平复位转为高电平有效

// 复位后valid有效，CPU开始工作（控制CPU是否运行）
logic         valid;

always @(posedge clk) begin         // 时钟上升沿触发
    if (reset) begin
        valid <= 1'b0;              // 复位时暂停
    end
    else begin
        valid <= 1'b1;              // 复位后开始工作
    end
end

// 指令执行相关信号
logic [31:0] seq_pc;                // 顺序 PC  PC + 4
logic [31:0] nextpc;                // 下一周期 PC（跳转或顺序）
logic        br_taken;              // 跳转发生标志
logic [31:0] br_target;             // 跳转目标地址
logic [31:0] inst;                  // 当前指令
logic [31:0] pc;                    // 当前 PC（程序计数器）

// 控制信号
logic [11:0] alu_op;                // 运算器控制信号，ALU操作码（12种运算）
logic        load_op;               // 加载指令标志（未使用）
logic        src1_is_pc;            // ALU 第一个操作数选择（PC或寄存器）
logic        src2_is_imm;           // ALU 第二个操作数选择（立即数或寄存器）
logic        res_from_mem;          // 自数据存储器的结果（用于加载指令）
logic        dst_is_r1;             // 目标寄存器是否为x1（用于bl指令）
logic        gr_we;                 // 寄存器写使能
logic        mem_we;                // 存储器写使能
logic        src_reg_is_rd;         // rd是否为源操作数
logic [4: 0] dest;                  // 目的寄存器编号
logic [31:0] rj_value;              // 寄存器Rj的值
logic [31:0] rkd_value;             // 寄存器 Rk或Rd的值
logic [31:0] imm;                   // 立即数（符号扩展后）
logic [31:0] br_offs;               // br跳转的偏移量
logic [31:0] jirl_offs;             // jirl跳转的偏移量

// 指令字段分解
logic [ 5:0] op_31_26;              // 分段译码，指令的31~26位
logic [ 3:0] op_25_22;              // 分段译码，指令的25~22位
logic [ 1:0] op_21_20;              // 分段译码，指令的21~20位
logic [ 4:0] op_19_15;              // 分段译码，指令的19~15位
logic [ 4:0] rd;                    // rd字段（目标寄存器）
logic [ 4:0] rj;                    // rj字段（源寄存器1）
logic [ 4:0] rk;                    // rk字段（源寄存器2）
logic [11:0] i12;                   // 立即数12位
logic [19:0] i20;                   // 立即数20位
logic [15:0] i16;                   // 立即数16位
logic [25:0] i26;                   // 立即数26位

// 分段译码输出（One-hot编码）
logic [63:0] op_31_26_d;            // 分段译码输出 onehot
logic [15:0] op_25_22_d;            // 分段译码输出 onehot
logic [ 3:0] op_21_20_d;            // 分段译码输出 onehot
logic [31:0] op_19_15_d;            // 分段译码输出 onehot

// 指令类型标志
logic        inst_add_w;            // add.w指令
logic        inst_sub_w;            // sub.w指令
logic        inst_slt;              // slt.w指令
logic        inst_sltu;             // sltu.w指令
logic        inst_nor;              // nor.w指令
logic        inst_and;              // and.w指令
logic        inst_or;               // or.w指令
logic        inst_xor;              // xor.w指令
logic        inst_slli_w;           // slli.w指令
logic        inst_srli_w;           // srli.w指令
logic        inst_srai_w;           // srai.w指令
logic        inst_addi_w;           // addi.w指令
logic        inst_ld_w;             // ld.w指令
logic        inst_st_w;             // st.w指令
logic        inst_jirl;             // jirl指令
logic        inst_b;                // b指令
logic        inst_bl;               // bl指令
logic        inst_beq;              // beq指令
logic        inst_bne;              // bne指令
logic        inst_lu12i_w;          // lu12i.w指令

// 立即数扩展控制
logic        need_ui5;              // 需要无符号5位立即数（移位指令）
logic        need_si12;             // 需要有符号12位立即数（addi、ld、st指令）
logic        need_si16;             // 需要有符号16位立即数（jirl、beq、bne指令）
logic        need_si20;             // 需要有符号20位立即数（lu12i指令）
logic        need_si26;             // 需要有符号26位立即数（b、bl指令）
logic        src2_is_4;             // ALU第二个操作数为4（用于jirl/bl）

//寄存器文件接口
logic [ 4:0] rf_raddr1;
logic [31:0] rf_rdata1;
logic [ 4:0] rf_raddr2;
logic [31:0] rf_rdata2;
logic        rf_we   ;
logic [ 4:0] rf_waddr;
logic [31:0] rf_wdata;

//运算器接口
logic [31:0] alu_src1   ;
logic [31:0] alu_src2   ;
logic [31:0] alu_result ;

//数据存储器输出
logic [31:0] mem_result;

////////////////////////////取指阶段（IF）///////////////////////////////
assign seq_pc       = pc + 3'h4;                        // 顺序执行，PC + 4
assign nextpc       = br_taken ? br_target : seq_pc;    // 下一周期的PC，跳转或顺序执行

// always @(nextpc) begin
//     if (inst_jirl) begin
//         $display("[Verilog] branch taken jirl, nextpc = %h", nextpc);
//     end
//     else if (inst_bl) begin
//         $display("[Verilog] branch taken bl, nextpc = %h", nextpc);
//     end
//     else if (inst_b) begin
//         $display("[Verilog] branch taken b, nextpc = %h", nextpc);
//     end
//     else if (inst_beq) begin
//         $display("[Verilog] branch taken beq, nextpc = %h", nextpc);
//     end
//     else if (inst_bne) begin
//         $display("[Verilog] branch taken bne, nextpc = %h", nextpc);
//     end
//     else if (!br_taken) begin
//         $display("[Verilog] nextpc = %h", nextpc);
//     end
// end

// PC寄存器更新
always @(posedge clk) begin
    if (reset) begin
        pc <= 32'h1bfffffc;     // trick: to make nextpc be 0x1c000000 during reset 
        // $display("[Verilog] reset");
    end
    else begin
        pc <= nextpc;           // 复位后更新PC
        // $display("[Verilog] nextpc = %h, br_taken = %b, br_target = %h", nextpc, br_taken, br_target);
    end
end

assign inst_sram_we    = 1'b0;  // 当前实验不需要写指令存储器，写信号无效
assign inst_sram_addr  = pc;    // 地址为当前 PC
assign inst_sram_wdata = 32'b0; // 写数据无效
assign inst            = inst_sram_rdata;   // 读取的指令

////////////////////////////指令译码（ID）/////////////////////////////////
// 分解指令字段
assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];      // 目标寄存器
assign rj   = inst[ 9: 5];      // 源寄存器1
assign rk   = inst[14:10];      // 源寄存器2

// 立即数字段
assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

// 指令译码器（将指令字段转为 One-hot 编码）
decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

// 具体指令识别（组合逻辑）
assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
assign inst_auipc  = op_31_26_d[6'h05] &  inst[25];     // WRONG 

// ALU操作码生成
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

// 立即数扩展控制
assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

// 立即数生成（符号扩展）
assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

// br指令偏移地址计算
assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;
// jirl指令偏移地址计算
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

// 寄存器读控制，beq、bne、st.w指令 rd为源操作数
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
//bl指令的目的寄存器为r1
assign dst_is_r1     = inst_bl;
//寄存器写入的指令
assign gr_we = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | 
               inst_xor | inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | 
               inst_lu12i_w | inst_auipc | inst_bl;

assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

////////////////////////////指令执行（EX）///////////////////////////////////
//跳转指令处理
assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :
                                        inst_jirl ? (rj_value + jirl_offs) :
                                        32'hx;  // 未知指令 fallback

assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

//运算器
alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),           // WRONG 这里将 src1 更改为 src2
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
);

////////////////////////////访存//////////////////////////////
assign data_sram_we    = mem_we && valid;
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value;

wire [31:0] final_result;       // WRONG 声明final_result为32位

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem ? mem_result : alu_result;

// always @(final_result) begin
//     $display("[Verilog] mem_result = %h", mem_result);
//     $display("[Verilog] alu_result = %h", alu_result);
//     $display("[Verilog] res_from_mem = %h", res_from_mem);
//     $display("[Verilog] final_result = %h", final_result);
// end

//////////////////////////数据写回////////////////////////////////////////
assign rf_we    = gr_we && valid;
assign rf_waddr = dest;
assign rf_wdata = final_result;

// debug info generate
assign debug_wb_pc       = pc;
assign debug_wb_rf_we   = {4{rf_we}};
assign debug_wb_rf_wnum  = dest;
assign debug_wb_rf_wdata = final_result;


// always @(posedge clk) begin
//     if (inst_add_w) begin
//         $display("[Verilog] inst_add_w");
//     end
//     else if (inst_sub_w) begin
//         $display("[Verilog] inst_sub_w");
//     end
//     else if (inst_slt) begin
//         $display("[Verilog] inst_slt");
//     end
//     else if (inst_sltu) begin
//         $display("[Verilog] inst_sltu");
//     end
//     else if (inst_nor) begin
//         $display("[Verilog] inst_nor");
//     end
//     else if (inst_and) begin
//         $display("[Verilog] inst_and");
//     end
//     else if (inst_or) begin
//         $display("[Verilog] inst_or");
//     end
//     else if (inst_xor) begin
//         $display("[Verilog] inst_xor");
//     end
//     else if (inst_slli_w) begin
//         $display("[Verilog] inst_slli_w");
//     end
//     else if (inst_srli_w) begin
//         $display("[Verilog] inst_srli_w");
//     end
//     else if (inst_srai_w) begin
//         $display("[Verilog] inst_srai_w");
//     end
//     else if (inst_addi_w) begin
//         $display("[Verilog] inst_addi_w");
//     end
//     else if (inst_ld_w) begin
//         $display("[Verilog] inst_ld_w");
//     end
//     else if (inst_st_w) begin
//         $display("[Verilog] inst_st_w");
//     end
//     else if (inst_jirl) begin
//         $display("[Verilog] inst_jirl");
//     end
//     else if (inst_b) begin
//         $display("[Verilog] inst_b");
//     end
//     else if (inst_bl) begin
//         $display("[Verilog] inst_bl");
//     end
//     else if (inst_beq) begin
//         $display("[Verilog] inst_beq");
//     end
//     else if (inst_bne) begin
//         $display("[Verilog] inst_bne");
//     end
//     else if (inst_lu12i_w) begin
//         $display("[Verilog] inst_lu12i_w");
//     end
//     else begin
//         $display("[Verilog] unknown instruction");
//     end
// end

// always @(debug_wb_pc) begin
//     $display("[Verilog] debug_wb_pc = %h, debug_wb_rf_we = %b, debug_wb_rf_wnum = %d, debug_wb_rf_wdata = %h", 
//         debug_wb_pc, debug_wb_rf_we, debug_wb_rf_wnum, debug_wb_rf_wdata);
//     // $display("[Verilog] rf_we: %b", rf_we);
//     $display("[Verilog] gr_we: %b", gr_we);
//     if (inst_add_w) begin
//         $display("[Verilog] inst_add_w");
//     end
//     else if (inst_sub_w) begin
//         $display("[Verilog] inst_sub_w");
//     end
//     else if (inst_slt) begin
//         $display("[Verilog] inst_slt");
//     end
//     else if (inst_sltu) begin
//         $display("[Verilog] inst_sltu");
//     end
//     else if (inst_nor) begin
//         $display("[Verilog] inst_nor");
//     end
//     else if (inst_and) begin
//         $display("[Verilog] inst_and");
//     end
//     else if (inst_or) begin
//         $display("[Verilog] inst_or");
//     end
//     else if (inst_xor) begin
//         $display("[Verilog] inst_xor");
//     end
//     else if (inst_slli_w) begin
//         $display("[Verilog] inst_slli_w");
//     end
//     else if (inst_srli_w) begin
//         $display("[Verilog] inst_srli_w");
//     end
//     else if (inst_srai_w) begin
//         $display("[Verilog] inst_srai_w");
//     end
//     else if (inst_addi_w) begin
//         $display("[Verilog] inst_addi_w");
//     end
//     else if (inst_ld_w) begin
//         $display("[Verilog] inst_ld_w");
//     end
//     else if (inst_st_w) begin
//         $display("[Verilog] inst_st_w");
//     end
//     else if (inst_jirl) begin
//         $display("[Verilog] inst_jirl");
//     end
//     else if (inst_b) begin
//         $display("[Verilog] inst_b");
//     end
//     else if (inst_bl) begin
//         $display("[Verilog] inst_bl");
//     end
//     else if (inst_beq) begin
//         $display("[Verilog] inst_beq");
//     end
//     else if (inst_bne) begin
//         $display("[Verilog] inst_bne");
//     end
//     else if (inst_lu12i_w) begin
//         $display("[Verilog] inst_lu12i_w");
//     end
//     else begin
//         $display("[Verilog] unknown instruction");
//     end
// end

endmodule
