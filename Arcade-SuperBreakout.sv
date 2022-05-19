//============================================================================
//  SuperBreakout port to MiSTer
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

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
	output        HDMI_FREEZE,

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

assign VGA_F1    = 0;
assign VGA_SCALER= 0;

assign USER_OUT  = '1;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = ioctl_download;
assign FB_FORCE_BLANK = '0;
assign HDMI_FREEZE = 0;

wire [1:0] ar = status[15:14];


assign VIDEO_ARX = (!ar) ? ((status[2] ) ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2] ) ? 8'd3 : 8'd4) : 12'd0;


/////////////////////////////////////////////////////////

wire clk_sys, clk_vid;

pll pll (
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_vid), // 48 MHz
	.outclk_1(clk_sys)  // 12 MHz
);

/////////////////////////////////////////////////////////

`include "build_id.v"
localparam CONF_STR = {
	"A.SBRKOUT;;",
	"-;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"OHI,Control,Buttons,Analog Stick,Paddle;",
	"-;",
	"OAB,Language,English,German,French,Spanish;",
	"OC,Balls,3,5;",
	"O68,Bonus,200,400,600,900,1200,1600,2000,None;",
	"OJK,Level,Progresive,Cavity,Double;",//DE
	"OL,Test,Off,On;",//F
	"OG,Color,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Serve,Start 1P,Start 2P,Coin;",
	"jn,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};


wire [127:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire  		video_rotated;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;

wire [10:0] ps2_key;
wire  [7:0] paddle;
//wire [24:0] ps2_mouse;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;
wire  [7:0] joya;

wire [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

	.joystick_l_analog_0(joya),
	.paddle_0(paddle),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.video_rotated(video_rotated),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data)

);




wire m_left	   =   joy[1];
wire m_right   =   joy[0];
wire m_serve   =   joy[4] | ~USER_IN[3];

wire m_select1 = status[19]; //Select level Double
wire m_select2 = status[20]; //Select level Progresive

wire m_start1  =  joy[5];
wire m_start2  =  joy[6];
wire m_coin    =  joy[7];

/*
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See Super Breakout manual page 13 for complete information. Active low (0 = On, 1 = Off)
--    1 	2							Language				(00 - English)
--   			3	4					Coins per play		(10 - 1 Coin, 1 Play) 
--						5				3/5 Balls			(1 - 3 Balls)
--							6	7	8	Bonus play			(011 - 600 Progressive, 400 Cavity, 600 Double)
		
SW2 <= "00101011";
*/

wire [7:0] SW1 = {status[11:10],1'b1,1'b0,status[12],status[8:6]};

wire [1:0] steer0;
joy2quad steerjoy2quad0
(
	.CLK(clk_sys),
	//.clkdiv('d22500),
	.clkdiv('d5500),
	
	.right(m_right),
	.left(m_left),

	.steer(steer0)
);

reg use_io = 0; // 1 - use encoder on USER_IN[1:0] pins
always @(posedge clk_sys) begin
reg [1:0] old_io;
reg [1:0] old_steer;

	old_io <= USER_IN[1:0];
	if(old_io != USER_IN[1:0]) use_io <= 1;
	
	old_steer <= steer0;
	if(old_steer != steer0) use_io <= 0;
end

/*			Pot_Comp1_I	: in  std_logic;	-- If you want to use a pot instead, this goes to the output of the comparator
			Serve_LED_O	: out std_logic;	-- Serve button LED (Active low)
			Counter_O	: out std_logic;	-- Coin counter output (Active high)
*/
wire videowht;
wire [7:0] audio1;

wire reset = RESET | status[0] | buttons[1];

super_breakout super_breakout(
	.Reset_n(~reset),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.Video_O(videowht),
	.Video_RGB(videorgb),

	.Audio_O(audio1),
	.Coin1_I(~m_coin),
	.Coin2_I(1'b1),
	
	.Start1_I(~m_start1),
	.Start2_I(~m_start2),
	
	.Serve_I(~m_serve),
	.Select1_I(~m_select1),
	.Select2_I(~m_select2),
	.Slam_I(1),
	.Test_I(~status[21]),
	.Enc_A(use_io ? USER_IN[1] : steer0[1]),
	.Enc_B(use_io ? USER_IN[0] : steer0[0]),
	.Paddle(status[17] ? (joya ^ 8'h80) : status[18] ? paddle : 8'h00),
	.Lamp1_O(),
	.Lamp2_O(),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.clk_12(clk_sys),
	.clk_6_O(ce_pix),
	.SW1_I(SW1)
);
			
///////////////////////////////////////////////////

wire hs,vs,hblank,vblank;

wire ce_pix;
wire [8:0] videorgb;
wire [2:0] r,g;
wire [2:0] b;
assign r={3{videowht}};
assign g={3{videowht}};
assign b={3{videowht}};

wire no_rotate = status[2] | direct_video;

reg HBlank, VBlank;
always @(posedge clk_sys) begin
	reg [10:0] hcnt, vcnt;
	reg old_hbl, old_vbl;

	if(ce_pix) begin
		hcnt <= hcnt + 1'd1;
		old_hbl <= hblank;
		if(old_hbl & ~hblank) begin
			hcnt <= 0;
			
			vcnt <= vcnt + 1'd1;
			old_vbl <= vblank;
			if(old_vbl & ~vblank) vcnt <= 0;
		end
		
		if (hcnt == 37)  HBlank <= 0;
		if (hcnt == 292) HBlank <= 1;
		
		if (vcnt == 0)   VBlank <= 0;
		if (vcnt == 224) VBlank <= 1;
	end
end


arcade_video #(255,9,1) arcade_video
(
	.*,

	.clk_video(clk_vid),
	.RGB_in(~status[16]?videorgb:{r,g,b}),
	.HSync(hs),
	.VSync(vs),
	
	.fx(status[5:3])
);
wire rotate_ccw = 1;
wire flip = 0;
screen_rotate screen_rotate (.*);

reg mute;
always @(posedge clk_sys) begin
	integer cnt;

	mute <= 0;
	if(cnt < 24000000) begin
		mute <= 1;
		cnt <= cnt + 1;
	end

	if(reset) cnt <= 0;
end

assign AUDIO_L={mute ? 8'd0 : audio1, 8'd0};
assign AUDIO_R=AUDIO_L;
assign AUDIO_S = 0;
wire scrap;

endmodule
