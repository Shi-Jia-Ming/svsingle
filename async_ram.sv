`timescale 1ns / 1ps
module async_ram #(
    parameter ADDR_WIDTH = 15,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1 << ADDR_WIDTH
)(
	clk,
   address,
   rdata,
   wdata,
   we
);

input                  clk;
input [ADDR_WIDTH-1:0] address;
input                  we;

output [DATA_WIDTH-1:0] rdata;
input  [DATA_WIDTH-1:0] wdata;

logic [DATA_WIDTH-1:0] ram [0:DEPTH-1];
logic [DATA_WIDTH-1:0] data_out;

assign rdata = (!we) ? data_out : {DATA_WIDTH{1'bz}};

always_ff @(posedge clk)
begin : MEM_WRITE
    if (we) begin
        ram[address] <= wdata;
    end
end

	assign data_out = !we? ram[address]:32'bz;

// always @* 
// begin : MEM_READ
//     if (!we) begin
//         data_out = ram[address];
//     end
// end
endmodule

module inst_ram #(
	parameter ADDR_WIDTH = 15,
	parameter DATA_WIDTH = 32,
	parameter DEPTH = 1 << ADDR_WIDTH
)
(
	input  clk,
	input  we,
	input  [ADDR_WIDTH-1:0] a,
	input  [DATA_WIDTH-1:0] d,
	output [DATA_WIDTH-1:0] spo
);
	async_ram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH))
		async_ram1(
			.clk    (clk),
			.address(a),
			.rdata(spo),
			.wdata(d),
			.we(we)
		);
		initial begin
			$readmemb("inst_ram.mif", async_ram1.ram);
		end
endmodule

module data_ram #(
	parameter ADDR_WIDTH = 15,
	parameter DATA_WIDTH = 32,
	parameter DEPTH = 1 << ADDR_WIDTH
)
(
	input  clk,
	input  we,
	input  [ADDR_WIDTH-1:0] a,
	input  [DATA_WIDTH-1:0] d,
	output [DATA_WIDTH-1:0] spo
);
	async_ram #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH))
		async_ram2(
			.clk    (clk),
			.address(a),
			.rdata(spo),
			.wdata(d),
			.we(we)
		);
endmodule