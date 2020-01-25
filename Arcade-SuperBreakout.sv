//============================================================================
//  SuperBreakout port to MiSTer
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
//   
//============================================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);





assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_DISK  = lamp1;
assign LED_POWER = lamp2;
assign LED_USER  = ioctl_download;

`include "build_id.v"
localparam CONF_STR = {
	"A.SBRKOUT;;",
	"-;",
	"H0O1,Aspect Ratio,Original,Wide;",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"OAB,Language,English,German,French,Spanish;",
	"OC,Balls,3,5;",
	"O68,Bonus,200,400,600,900,1200,1600,2000,None;",
	"OD,Test,Off,On;",
	"OE,Color,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Release,Select,Start 1P,Start 2P,Coin;",
	"jn,A,X,Start,Select,R;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;


wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire [10:0] ps2_key;
//wire [24:0] ps2_mouse;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy0 =  joystick_0;
wire [15:0] joy1 =  joystick_1;

wire [21:0] gamma_bus;

hps_io #(.STRLEN(($size(CONF_STR)>>3) )/*, .PS2DIV(1000), .WIDE(0)*/) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),

        .buttons(buttons),
        .status(status),
        .status_menumask(direct_video),
        .forced_scandoubler(forced_scandoubler),
        .gamma_bus(gamma_bus),
        .direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	
	.ps2_key(ps2_key)
);



wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
//			'hX75: btn_up          <= pressed; // up
//			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_serve       <= pressed; // space
			'h014: btn_serve       <= pressed; // ctrl

			'h005: btn_start_1     <= pressed; // F1
			'h006: btn_start_2     <= pressed; // F2
			
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
//                        'h02D: btn_up_2        <= pressed; // R
//                        'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_serve_2     <= pressed; // A

			
			
		endcase
	end
end

//reg btn_up    = 0;
//reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_serve  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin_1=0;
reg btn_coin_2=0;
reg btn_left_2=0;
reg btn_right_2=0;
reg btn_serve_2=0;


wire m_left	=  btn_left  | joy0[1];
wire m_right	=  btn_right | joy0[0];
wire m_serve	=  btn_serve_2|btn_serve| joy0[4]|joy1[4];
wire m_select	=  joy0[5];


wire m_left_2	=  btn_left_2|joy1[1];
wire m_right_2	=  btn_right_2| joy1[0];
wire m_select_2	=  joy1[5];


wire m_start1 = btn_start_1 | joy0[6] | joy1[6];
wire m_start2 = btn_start_2 | joy0[7] | joy1[7];
wire m_coin   = btn_coin_1  | joy0[8] | joy1[8];



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
wire [1:0] steer1;

joy2quad steerjoy2quad0
(
	.CLK(clk_sys),
	//.clkdiv('d22500),
	.clkdiv('d5500),
	
	.right(m_right),
	.left(m_left),
	
	.steer(steer0)
);
joy2quad steerjoy2quad1
(
	.CLK(clk_sys),
	//.clkdiv('d22500),
	.clkdiv('d5500),
	
	.right(m_right_2),
	.left(m_left_2),
	
	.steer(steer1)
);



/*			Pot_Comp1_I	: in  std_logic;	-- If you want to use a pot instead, this goes to the output of the comparator
			Serve_LED_O	: out std_logic;	-- Serve button LED (Active low)
			Counter_O	: out std_logic;	-- Coin counter output (Active high)
*/
wire videowht;
wire lamp1,lamp2;

super_breakout super_breakout(
	.Reset_n(~(RESET | status[0] | buttons[1] | ioctl_download)),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.Video_O(videowht),
	.Video_RGB(videorgb),

	.Audio_O(audio1),
	.Coin1_I(~(m_coin)),
	.Coin2_I(~(btn_coin_2)),
	
	.Start1_I(~(m_start1 )),
	.Start2_I(~(m_start2 )),
	
	.Serve_I(~m_serve),
	.Select1_I(~m_select),
	.Select2_I(~m_select_2),
	.Slam_I(1),
	.Test_I	(~status[13]),
	.Enc_A(steer0[1]),
	.Enc_B(steer0[0]),
	.Lamp1_O(lamp1),
	.Lamp2_O(lamp2),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hbl0),
	.vblank_O(vbl0),
	.clk_12(clk_12),
	.clk_6_O(CLK_VIDEO_2),
	.SW1_I(SW1)
	);
			
			
wire [7:0] audio1;
wire [1:0] video;
wire [3:0] videor;
///////////////////////////////////////////////////
//wire clk_sys, clk_ram, clk_ram2, clk_pixel, locked;
wire clk_sys,locked;
wire clk_48,clk_24,clk_12,clk_6,clk_3,CLK_VIDEO_2;



wire hs,vs,hblank,vblank,hbl0,vbl0;

assign hblank=hbl0;
assign vblank=vbl0;


assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

wire [7:0] videorgb;
wire [2:0] r,g;
wire [1:0] b;
assign r={videowht,videowht,videowht};
assign g={videowht,videowht,videowht};
assign b={videowht,videowht};

reg ce_pix;
always @(posedge clk_48) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

wire no_rotate = status[2] | direct_video;

arcade_video #(320,240,8) arcade_video
(
	.*,

	.clk_video(clk_48),
	.RGB_in(~status[14]?videorgb:{r,g,b}),
//	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),
	.rotate_ccw(1),
	
	.fx(status[5:3]),
);


assign AUDIO_L={audio1,8'b00000000};
assign AUDIO_R=AUDIO_L;
assign AUDIO_S = 0;
wire scrap;
assign clk_sys=clk_12;

pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_24	),        // 24 MHz
	.outclk_1	( clk_12	),        // 12 MHz
	.outclk_2	( clk_6	),        // 6 MHz
	.outclk_3	( clk_3	),        // 3 MHz
	.outclk_4	( clk_48	)        // 48 MHz
	 );

endmodule
