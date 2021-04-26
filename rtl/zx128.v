//-------------------------------------------------------------------------------------------------
module zx128
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,  // 56.7504 MHz
	output wire       pce,    // pixel ce

	input  wire       power,
	input  wire       reset,

	output wire[ 1:0] blank,  // video
	output wire[ 1:0] sync,
	output wire[23:0] rgb,

	input  wire       ear,    // audio
	output wire[11:0] left,
	output wire[11:0] right,

	input  wire       strobe, // keyboard
	input  wire       press,
	input  wire[ 7:0] code,

	input  wire[ 5:0] joy0,   // joystick
	input  wire[ 5:0] joy1,

//	input  wire       mouses, // mouse
//	input  wire[ 2:0] mouseb,
//	input  wire[ 8:0] mousex,
//	input  wire[ 8:0] mousey,

	output wire       usdCs,  // sd
	output wire       usdCk,
	input  wire       usdMiso,
	output wire       usdMosi,

	output wire       ramCs,  // sdram
	output wire       ramRas,
	output wire       ramCas,
	output wire       ramWe,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBa,
	output wire[12:0] ramA
);
//-------------------------------------------------------------------------------------------------

reg[3:0] ce;
always @(negedge clock) if(power) ce <= ce+1'd1;

wire pe7M0 = power & ~ce[0] & ~ce[1] &  ce[2];
wire ne7M0 = power & ~ce[0] & ~ce[1] & ~ce[2];

wire pe3M5 = power & ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne3M5 = power & ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

assign pce = ne7M0;

//-------------------------------------------------------------------------------------------------

reg mreqt23iorqtw3;
always @(posedge clock) if(pc3M5) mreqt23iorqtw3 <= mreq & ioFE & io7FFD;

reg cpuck;
always @(posedge clock) if(ne7M0) cpuck <= !(cpuck && contend);

wire contend = !(vduCn && cpuck && mreqt23iorqtw3 && ((a[15:14] == 2'b01) || ramCn || !ioFE));

wire pc3M5 = pe3M5 & contend;
wire nc3M5 = ne3M5 & contend;

//-------------------------------------------------------------------------------------------------

wire rst = ready & reset & keyF6;
wire nmi = keyF5;

reg mi = 1'b1;
always @(posedge clock) if(pc3M5) mi <= vduI;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.clock  (clock  ),
	.cep    (pc3M5  ),
	.cen    (nc3M5  ),
	.reset  (rst    ),
	.nmi    (nmi    ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.m1     (m1     ),
	.mi     (mi     ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

reg mic;
reg speaker;
reg[2:0] border;

always @(posedge clock) if(ne7M0) if(!ioFE && !wr) { speaker, mic, border } <= q[4:0];

//-------------------------------------------------------------------------------------------------

wire[ 7:0] memQ;
wire[ 7:0] vq;
wire[12:0] va;

memory Memory
(
	.clock  (clock  ),
	.ce     (pc3M5  ),
	.power  (power  ),
	.ready  (ready  ),
	.reset  (rst    ),
	.rfsh   (rfsh   ),
	.iorq   (iorq   ),
	.mreq   (mreq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.m1     (m1     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.vce    (ne7M0  ),
	.vq     (vq     ),
	.va     (va     ),
	.cn     (ramCn  ),
	.ramCs  (ramCs  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramWe  (ramWe  ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBa  (ramBa  ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

video Video
(
	.clock  (clock  ),
	.ce     (ne7M0  ),
	.border (border ),
	.blank  (blank  ),
	.sync   (sync   ),
	.rgb    (rgb    ),
	.cn     (vduCn  ),
	.rd     (vduRd  ),
	.bi     (vduI   ),
	.d      (vq     ),
	.a      (va     )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] spdQ;

wire[7:0] psgA1;
wire[7:0] psgB1;
wire[7:0] psgC1;

wire[7:0] psgA2;
wire[7:0] psgB2;
wire[7:0] psgC2;

wire[7:0] saaL;
wire[7:0] saaR;

audio Audio
(
	.speaker(speaker),
	.mic    (mic    ),
	.ear    (ear    ),
	.spd    (spdQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  ),
	.saaL   (saaL   ),
	.saaR   (saaR   ),
	.left   (left   ),
	.right  (right  )
);

//-------------------------------------------------------------------------------------------------

wire[4:0] keyQ;
wire[7:0] keyA = a[15:8];

keyboard Keyboard
(
	.clock  (clock  ),
	.strobe (strobe ),
	.pressed(press  ),
	.code   (code   ),
	.f6     (keyF6  ),
	.f5     (keyF5  ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------
/*
reg[7:0] mx;
reg[7:0] my;

always @(posedge clock) if(mouses)
begin
	mx <= mx+(mousex[7:0]-(mousex[8] ? 9'h100 : 9'h000));
	my <= my+(mousey[7:0]-(mousey[8] ? 9'h100 : 9'h000));
end
*/
//-------------------------------------------------------------------------------------------------

wire[7:0] usdQ;
wire[7:0] usdA = a[7:0];

usd uSD
(
	.clock  (clock  ),
	.pe     (pe7M0  ),
	.ne     (ne7M0  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.q      (usdQ   ),
	.a      (usdA   ),
	.cs     (usdCs  ),
	.ck     (usdCk  ),
	.miso   (usdMiso),
	.mosi   (usdMosi)
);

//-------------------------------------------------------------------------------------------------

wire[7:4] spdA = a[7:4];

specdrum Specdrum
(
	.clock  (clock  ),
	.ce     (pe3M5  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (spdQ   ),
	.a      (spdA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7: 0] psgQ;
wire[15:14] psgAh = a[15:14];
wire[ 1: 1] psgAl = a[1];

turbosound Turbosound
(
	.clock  (clock  ),
	.ce     (pe3M5  ),
	.reset  (rst    ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.ah     (psgAh  ),
	.al     (psgAl  ),
	.q      (psgQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  )
);

//-------------------------------------------------------------------------------------------------

reg[2:0] saac;
wire saace = saac == 6;
always @(posedge clock) if(saace) saac <= 1'd0; else saac <= saac+1'd1;

saa1099 saa1099
(
	.clk_sys(clock  ),
	.ce     (saace  ),
	.rst_n  (rst    ),
	.cs_n   (!(!ioFF && !wr)),
	.a0     (a[8]   ),
	.wr_n   (wr     ),
	.din    (q      ),
	.out_l  (saaL   ),
	.out_r  (saaR   )
);

//-------------------------------------------------------------------------------------------------

wire ioFE = !(!iorq && !a[0]);                     // ula
wire ioDF = !(!iorq && !a[5]);                     // kempston
wire ioEB = !(!iorq && a[7:0] == 8'hEB);           // usd
wire ioFF = !(!iorq && a[7:0] == 8'hFF);           // saa

wire ioFFFD = !(!iorq && a[15] && a[14] && !a[1]); // psg
wire io7FFD = !(!iorq && !a[15] && !a[1]);         // paging

//wire ioFFDF = !(!iorq &&  a[10] && a[9] &&  a[8] && !a[5]); // kmouse y
//wire ioFBDF = !(!iorq && !a[10] && a[9] &&  a[8] && !a[5]); // kmouse x
//wire ioFEDF = !(!iorq           && a[9] && !a[8] && !a[5]); // kmouse buttons

assign d
	= !mreq ? memQ

	: !ioFFFD ? psgQ

//	: !ioFFDF ? my
//	: !ioFBDF ? mx
//	: !ioFEDF ? { 5'b11111, mouseb }

	: !ioFE ? { 1'b1, ear|speaker, 1'b1, keyQ }
	: !ioDF ? { 2'b00, joy0|joy1 }
	: !ioEB ? usdQ

	: !iorq & vduRd ? vq
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
