//-------------------------------------------------------------------------------------------------
module emu
//-------------------------------------------------------------------------------------------------
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);
//-------------------------------------------------------------------------------------------------

///////// Default values for ports not used in this core /////////

assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign LED_POWER = 0;
assign BUTTONS = 0;

//-------------------------------------------------------------------------------------------------

`include "build_id.v" 
localparam CONF_STR =
{
	"zx128;;",
	"S,VHD;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v1.0 ",`BUILD_DATE
};

wire[31:0] status;
wire[10:0] ps2_key;
wire[24:0] ps2_mouse;
wire[15:0] joystick_0;
wire[15:0] joystick_1;
wire[31:0] sd_lba;
wire[ 7:0] sd_buff_din;
wire[ 7:0] sd_buff_dout;
wire[ 8:0] sd_buff_addr;
wire[63:0] img_size;
wire[ 1:0] buttons;
wire[ 1:0] ar = status[9:8];
wire forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.conf_str(CONF_STR),

	.status(status),
	.status_menumask({status[5]}),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_lba(sd_lba),
	.sd_ack(sd_ack),
	.sd_ack_conf(sd_ack_conf),
	.sd_buff_wr(sd_buff_wr),
	.sd_buff_din(sd_buff_din),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_addr(sd_buff_addr),

	.img_size(img_size),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler)
);

//-------------------------------------------------------------------------------------------------

wire clk_sys;
wire power;

pll pll
(
	.refclk  (CLK_50M),
	.rst     (0      ),
	.locked  (power  ),
	.outclk_0(clk_sys), // 56.7500 MHz (should be 56.7504 MHz)
	.outclk_1(clk_sdr), // 56.7500 MHz -90º
	.outclk_2(clk_sd )  // 14.0123 MHz (should be 14.0000 MHz)
);

//-------------------------------------------------------------------------------------------------

ltc2308_tape ltc2308_tape
(
	.clk(CLK_50M),
	.ADC_BUS(ADC_BUS),
	.dout(tape_adc),
	.active(tape_adc_act)
);

//-------------------------------------------------------------------------------------------------

wire sdmiso = vsd_sel ? vsdmiso : SD_MISO;

reg vsd_sel = 0;
always @(posedge clk_sys) if(img_mounted) vsd_sel <= |img_size;

sd_card sd_card
(
	.clk_sys(clk_sys),
	.reset(~reset),

	.sdhc(1),

	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_lba(sd_lba),
	.sd_ack(sd_ack),
	.sd_ack_conf(sd_ack_conf),

	.sd_buff_wr(sd_buff_wr),
	.sd_buff_din(sd_buff_din),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_addr(sd_buff_addr),

	.clk_spi(clk_sys),

	.sck(sdck),
	.ss(sdss | ~vsd_sel),
	.mosi(sdmosi),
	.miso(vsdmiso)
);

assign SD_CS   = sdss   |  vsd_sel;
assign SD_SCK  = sdck   & ~vsd_sel;
assign SD_MOSI = sdmosi & ~vsd_sel;

reg sd_act;

always @(posedge clk_sys) begin
	reg old_mosi, old_miso;
	integer timeout = 0;

	old_mosi <= sdmosi;
	old_miso <= sdmiso;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if((old_mosi ^ sdmosi) || (old_miso ^ sdmiso)) timeout <= 0;
end

//-------------------------------------------------------------------------------------------------

reg ps2k10d, strobe;
always @(posedge clk_sys) begin ps2k10d <= ps2_key[10]; strobe <= ps2k10d != ps2_key[10]; end

//-------------------------------------------------------------------------------------------------

reg ps2m24d, mouses;
always @(posedge clk_sys) begin ps2m24d <= ps2_mouse[24]; mouses <= ps2m24d != ps2_mouse[24]; end

wire[2:0] mouseb = ~{ ps2_mouse[2], ps2_mouse[0], ps2_mouse[1] };
wire[8:0] mousex = { ps2_mouse[4], ps2_mouse[15: 8] };
wire[8:0] mousey = { ps2_mouse[5], ps2_mouse[23:16] };

//-------------------------------------------------------------------------------------------------

wire ce_pix;
wire reset = ~(RESET | status[0] | buttons[1]);

wire[ 1:0] blank;
wire[ 1:0] sync;
wire[23:0] rgb;

wire ear = ~tape_adc;
wire[11:0] laudio;
wire[11:0] raudio;

wire press = ~ps2_key[9];
wire[7:0] code = ps2_key[7:0];

wire[5:0] joy0 = joystick_0[5:0];
wire[5:0] joy1 = joystick_1[5:0];

zx128 ZX128
(
	.clock  (clk_sys),
	.pce    (ce_pix ),

	.power  (power  ),
	.reset  (reset  ),

	.blank  (blank  ),
	.sync   (sync   ),
	.rgb    (rgb    ),

	.ear    (ear    ),
	.left   (laudio ),
	.right  (raudio ),

	.strobe (strobe ),
	.press  (press  ),
	.code   (code   ),

//	.mouses (mouses ),
//	.mouseb (mouseb ),
//	.mousex (mousex ),
//	.mousey (mousey ),

	.joy0   (joy0   ),
	.joy1   (joy1   ),

	.usdCk  (sdck   ),
	.usdCs  (sdss   ),
	.usdMiso(sdmiso ),
	.usdMosi(sdmosi ),

	.ramCs  (SDRAM_nCS ),
	.ramRas (SDRAM_nRAS),
	.ramCas (SDRAM_nCAS),
	.ramWe  (SDRAM_nWE ),
	.ramDqm ({SDRAM_DQMH,SDRAM_DQML}),
	.ramDQ  (SDRAM_DQ  ),
	.ramBa  (SDRAM_BA  ),
	.ramA   (SDRAM_A   )
);

//-------------------------------------------------------------------------------------------------

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL  = ce_pix;

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

assign VGA_DE    = ~|blank;
assign VGA_HS    = sync[0];
assign VGA_VS    = sync[1];
assign VGA_R     = rgb[23:16];
assign VGA_G     = rgb[15: 8];
assign VGA_B     = rgb[ 7: 0];

assign AUDIO_MIX = 0;
assign AUDIO_S   = 0;
assign AUDIO_L   = { 1'd0, laudio, 3'd0 };
assign AUDIO_R   = { 1'd0, raudio, 3'd0 };

assign LED_USER  = vsd_sel & sd_act;
assign LED_DISK  = { 1'b1, ~vsd_sel & sd_act };

assign SDRAM_CLK = clk_sdr;
assign SDRAM_CKE = 1'b1;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
