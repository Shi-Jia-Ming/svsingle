`timescale 1ns / 1ps
module alu(
  input  [11:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  output [31:0] alu_result
);

logic op_add;   //add operation
logic op_sub;   //sub operation
logic op_slt;   //signed compared and set less than
logic op_sltu;  //unsigned compared and set less than
logic op_and;   //bitwise and
logic op_nor;   //bitwise nor
logic op_or;    //bitwise or
logic op_xor;   //bitwise xor
logic op_sll;   //logic left shift
logic op_srl;   //logic right shift
logic op_sra;   //arithmetic right shift
logic op_lui;   //Load Upper Immediate

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];

logic [31:0] add_sub_result;
logic [31:0] slt_result;
logic [31:0] sltu_result;
logic [31:0] and_result;
logic [31:0] nor_result;
logic [31:0] or_result;
logic [31:0] xor_result;
logic [31:0] lui_result;
logic [31:0] sll_result;
logic [63:0] sr64_result;
logic [31:0] sr_result;


// 32-bit adder
logic [31:0] adder_a;
logic [31:0] adder_b;
logic        adder_cin;
logic [31:0] adder_result;
logic        adder_cout;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + {31'h0000_0000, adder_cin};

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (alu_src1[31] &~ alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
//assign or_result  = alu_src1 | alu_src2 | alu_result;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = alu_src2;

// SLL result
assign sll_result = alu_src1 << alu_src2[4:0];   //rj << i5  //alu_src2 << alu_src1[4:0];

// SRL, SRA result
//assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0]; //rj >> i5
assign sr64_result = {{32{op_sra & alu_src1[31]}}, alu_src1[31:0]} >> alu_src2[4:0]; //rj >> i5
assign sr_result   = sr64_result[31:0];//sr64_result[30:0]

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl|op_sra}} & sr_result);


// always @(alu_result) begin
//   if (op_add) begin
//     $display("add, alu_op: %b, alu_src1: %h, alu_src2: %h, add_result: %h", alu_op, alu_src1, alu_src2, alu_result);
//   end
//   else if (op_sub) begin
//     $display("sub, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_slt) begin
//     $display("slt, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_sltu) begin
//     $display("sltu, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_and) begin
//     $display("and, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_nor) begin
//     $display("nor, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_or) begin
//     $display("or, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_xor) begin
//     $display("xor, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_sll) begin
//     $display("sll, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_srl) begin
//     $display("srl, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_sra) begin
//     $display("sra, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
//   else if (op_lui) begin
//     $display("lui, alu_op: %b, alu_src1: %h, alu_src2: %h", alu_op, alu_src1, alu_src2);
//   end
// end

endmodule
