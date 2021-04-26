//-------------------------------------------------------------------------------------------------
module usd
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      pe,
	input  wire      ne,

	input  wire      iorq,
	input  wire      wr,
	input  wire      rd,
	input  wire[7:0] d,
	output wire[7:0] q,
	input  wire[7:0] a,

	output reg       cs,
	output wire      ck,
	input  wire      miso,
	output wire      mosi
);
//-------------------------------------------------------------------------------------------------

initial cs = 1'b1;
always @(posedge clock) if(pe) if(!iorq && !wr && a == 8'hE7) cs <= d[0];

//-------------------------------------------------------------------------------------------------

wire iotx = !iorq && !wr && a == 8'hEB;
wire iorx = !iorq && !rd && a == 8'hEB;

reg tx, dtx;
reg rx, drx;

always @(posedge clock) if(pe)
begin
	tx <= 1'b0;
	dtx <= iotx;
	if(iotx && !dtx) tx <= 1'b1;

	rx <= 1'b0;
	drx <= iorx;
	if(iorx && !drx) rx <= 1'b1;
end

//-------------------------------------------------------------------------------------------------

spi Spi
(
	.clock  (clock  ),
	.ce     (ne     ),
	.tx     (tx     ),
	.rx     (rx     ),
	.d      (d      ),
	.q      (q      ),
	.ck     (ck     ),
	.miso   (miso   ),
	.mosi   (mosi   )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
