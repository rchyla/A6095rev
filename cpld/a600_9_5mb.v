///////////////////////////////////////////////////////////////////
//
// A6095 - modified A608 project by Sanjyuubi
//
// Original A608 project http://lvd.nedopc.com/Projects/a600_8mb/
//
// CPLD: XC9572XL
//
//
/////////////////////////////////////////////////////////////////////

module a6095v2 (  a1, a2, a3, a4, a5, a6, a7, a8, a9, a10,
						a11, a12, a13, a14, a15 , a16, a17, a18, a19, a20, a21, a22, a23,
						d12, d13, d14, d15,
						as, uds, lds, clk, rw,
						ma0, ma1, ma2, ma3, ma4, ma5, ma6, ma7, ma8, ma9,
						ras0, ras1, ras2, ras3, ras4, lcas, ucas,
						reset, card_on, pcmcia_mode_off, slow_only, rst_cfg
						);


	input a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15 , a16, a17, a18, a19, a20, a21, a22, a23;
	output d12, d13, d14, d15;
	input as, uds, lds, clk, rw;
	output ma0, ma1, ma2, ma3, ma4, ma5, ma6, ma7, ma8, ma9;
	output ras0, ras1, ras2, ras3, ras4, lcas, ucas;
	input reset, card_on, pcmcia_mode_off, slow_only, rst_cfg;
	
	
	
	reg   d12, d13, d14, d15;
	reg   ma0, ma1, ma2, ma3, ma4, ma5, ma6, ma7, ma8, ma9;
	wire  ras0, ras1, ras2, ras3, ras4;
	wire  lcas, ucas;


	reg  mux_switch; // MUX switching
	reg  [3:0] data; // data out

	wire [7:0] high_addr;
	wire [5:0] low_addr;

	
	reg [23:0] cfg_counter;
	
	wire conf_clock; //for configuration
	
	reg rst_cfg_fsm_state;
	reg rst_cfg_switch;
	
	wire [23:0] rst_cfg_counter_threshold;
	

	reg which_ras[0:4]; // which /RAS signal to activate (based on a21-a23)
	reg mem_selected;
	reg rfsh_ras,rfsh_cas; // refresh /RAS, /CAS generators
	reg access_ras,access_cas; // normal access /RAS, /CAS generators
	reg autoconf_on;
	reg [2:0] rfsh_select; // for cycling refresh over every of 5 chips
	
	reg setup_card_on;
	reg setup_pcmcia_mode_off;
	reg setup_slow_only;
	
	//autoconf
	wire link;
	wire [2:0] size;
	wire [7:0] PRODUCT;
	wire [15:0] MANUFACTURER;
	wire [31:0] SERIAL_NUMBER;

	assign PRODUCT = 8'd11;
	assign MANUFACTURER = 16'd7777;
	assign SERIAL_NUMBER = 32'd1234567890;   
	assign link = setup_card_on && !setup_slow_only;
	assign size = setup_pcmcia_mode_off?3'b000:3'b111;
	
	assign write_cycle = (as == 1'b0) && (rw == 1'b0);

	assign high_addr = {a23,a22,a21,a20,a19,a18,a17,a16};
	assign low_addr  = {a6,a5,a4,a3,a2,a1};
	
	assign conf_clock = clk | reset; //toggle config clock when reset is active
	assign rst_cfg_counter_threshold = 24'hFFFFFF; //point of toggling memory configuration (5.5 <-> 9.5MB)

	
	always@(negedge conf_clock)
	begin
	setup_card_on = card_on;
	setup_pcmcia_mode_off = (rst_cfg_switch && !rst_cfg)?!pcmcia_mode_off:pcmcia_mode_off ;
	setup_slow_only = !slow_only; //inverted
	end
	

	
	
	always@(posedge clk)
	begin
	case(rst_cfg_fsm_state)
		1'b0:
		begin
		
		if(reset == 1'b1)
			begin
			cfg_counter = 24'b0;
			rst_cfg_fsm_state = 1'b0;
			end
		else
			begin
			if(cfg_counter != rst_cfg_counter_threshold) cfg_counter = cfg_counter + 1'b1;
			else
				begin
				rst_cfg_switch = !rst_cfg_switch;
				rst_cfg_fsm_state = 1'b1;
				end

			
		end
		end
		
		
		
		1'b1:
		begin
		if(reset == 1'b0) rst_cfg_fsm_state = 1'b1; else rst_cfg_fsm_state = 1'b0;
		end
	
	
	endcase
	end
	

	// chip selector decoder
	always @*
	begin
		casex( high_addr )
		8'b001xxxxx: // $200000-$3fffff
		begin
			{which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <=  5'b10000;  //5'b10000; //RAS0
			mem_selected <= setup_card_on && !setup_slow_only;
		end

		8'b010xxxxx: // $400000-$5fffff
		begin
			{which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <=  5'b01000; // /RAS1
			mem_selected <= setup_card_on && !setup_slow_only;
		end
		
		8'b011xxxxx: // $600000-$7fffff
		
		begin
			{which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <= 5'b00100;//RAS2; //5'b00100; //
			mem_selected <= setup_card_on && setup_pcmcia_mode_off && !setup_slow_only;
		end

		8'b100xxxxx: // $800000-$9fffff
		begin
			{which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <= 5'b00010 ;//RAS3; //5'b00010; // /RAS3
			mem_selected <= setup_card_on && setup_pcmcia_mode_off && !setup_slow_only;
		end

		8'b1100xxxx: // $c00000-$cfffff 1.5MB slow
            begin
            {which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <= 5'b00001 ;//RAS4;//5'b00001; // /RAS4
            mem_selected <= setup_card_on;
            end
      8'b11010xxx: // $d00000-$d7ffff
            begin
            {which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <= 5'b00001 ;//RAS4;//5'b00001; // /RAS4
            mem_selected <= setup_card_on;
            end


		default:
		begin
			{which_ras[0],which_ras[1],which_ras[2],which_ras[3],which_ras[4]} <= 5'b00000; // nothing
			mem_selected <= 1'b0;
		end

		endcase
	end


	// normal cycle generator
	always @(posedge clk, posedge as)
	begin
		if( as == 1'b1 )
		begin // /AS=1
			access_ras <= 1'b0;
			access_cas <= 1'b0;
		end
		else
		begin // /AS=0, positive clock
			access_ras <= 1'b1;
			access_cas <= access_ras; // one clock later
		end
	end

	// MUX switcher generator
	always @(negedge clk, negedge access_ras)
	begin
		if( access_ras == 1'b0 )
		begin // reset on no access_ras
			mux_switch <= 1'b0;
		end
		else
		begin // set to 1 on negedge after beginning of access_ras
			mux_switch <= 1'b1;
		end
	end




	// refresh cycle generator
	always @(negedge clk)
	begin
		if( as == 1'b1 ) // /AS not active
		begin
			rfsh_cas <= ~rfsh_cas;
		end
		else // /AS asserted
		begin
			rfsh_cas <= 1'b0;
		end

		if( (rfsh_cas == 1'b0) && ( as == 1'b1 ) )
		begin
			if (rfsh_select >= 3'b100)
				begin
				rfsh_select <= 3'b000;
				end
			else
				begin
				rfsh_select <= rfsh_select + 1'b1;
				end
			
		end
	end

	always @*
	begin
		rfsh_ras <= rfsh_cas & clk;
	end



	// output signals generator

		assign ras0 = ~( ( which_ras[0] & access_ras ) | ((rfsh_select==3'b000)?rfsh_ras:1'b0) );
		assign ras1 = ~( ( which_ras[1] & access_ras ) | ((rfsh_select==3'b001)?rfsh_ras:1'b0) );
		assign ras2 = ~( ( which_ras[2] & access_ras ) | ((rfsh_select==3'b010)?rfsh_ras:1'b0) );
		assign ras3 = ~( ( which_ras[3] & access_ras ) | ((rfsh_select==3'b011)?rfsh_ras:1'b0) );
		assign ras4 = ~( ( which_ras[4] & access_ras ) | ((rfsh_select==3'b100)?rfsh_ras:1'b0) );
		
		assign lcas = ~( ( ~lds & access_cas & mem_selected ) | rfsh_cas );
		assign ucas = ~( ( ~uds & access_cas & mem_selected ) | rfsh_cas );
	






	// DRAM MAx multiplexor
	always @*
	begin
		if( mux_switch==0 )
			{ ma0,ma1,ma2,ma3,ma4,ma5,ma6,ma7,ma8,ma9 } <= { a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 };
		else // mux_switch==1
			{ ma0,ma1,ma2,ma3,ma4,ma5,ma6,ma7,ma8,ma9 } <= { a11, a12, a13, a14, a15, a16, a17, a18, a19, a20 };
	end
	

	
	
	// autoconfig cycle on/off
	always @(posedge write_cycle, negedge reset)
	begin
		
		if( reset==0) // reset - begin autoconf if not disabled
			begin
			autoconf_on <= 1'b1;

			end
		else
		begin
			if( high_addr==8'hE8 && low_addr[5:2]==4'b1001 ) // $E80048..$E8004E
				autoconf_on <= 1'b0;
		end
	end


	// out autoconfig data
	always @*
	begin
		if( as==1'b0 && rw==1'b1 && high_addr==8'hE8 && autoconf_on==1 )
			{d15,d14,d13,d12} <= data;//datout;
		else
			{d15,d14,d13,d12} <= 4'bZZZZ;
	end

always @*
begin
 case (low_addr [5:0])
 6'h00 : data = {2'b11,link,1'b0};
 //             4'b1110;     // 00/02 - not inverted
 //                ||||
 //                |||+////- Optional ROM vector valid
 //                ||+////// Link into memory free list
 //                ++//////- Board type
 //                          00 : Reserved
 //                          01 : Reserved
 //                          10 : Reserved
 //                          11 : Current style board
 6'h01 : data = {1'b0,size[2:0]};
 //             4'b0000; //
 //                ||||
 //                |+++////- Memory size
 //                |         000 = 8 MB
 //                |         001 = 64 KB
 //                |         010 = 128 KB
 //                |         011 = 256 KB
 //                |         100 = 512 KB
 //                |         101 = 1 MB
 //                |         110 = 2 MB
 //                |         111 = 4 MB
 //                +//////// Chained config request
 6'h02 : data = ~PRODUCT[7:4];   // 04/06 - Product Number
 6'h03 : data = ~PRODUCT[3:0];
 6'h04 : data = ~4'b1100;    // 08/0A
 //                 ||||
 //                 ||++//// Must be zero
 //                 |+////// 0 = can be shut up, 1 = cannot be shut up
 //                 +//////- 0 = any space okey, 1 = 8M space prefered
 6'h05 : data = ~4'b0000;
 //                 ||||
 //                 ++++//// Must be zero
 6'h06 : data = ~4'b0000;    // 0C/0E - Reserved (must be zero)
 6'h07 : data = ~4'b0000;
 6'h08 : data = ~MANUFACTURER[15:12]; // 10/12 - Manufacturer high byte
 6'h09 : data = ~MANUFACTURER[11:8];
 6'h0A : data = ~MANUFACTURER[7:4];  // 14/16 - Manufacturer low byte
 6'h0B : data = ~MANUFACTURER[3:0];
 6'h0C : data = ~SERIAL_NUMBER[31:28]; // 18/1A - Serial number byte 0 (msb)
 6'h0D : data = ~SERIAL_NUMBER[27:24];
 6'h0E : data = ~SERIAL_NUMBER[23:20]; // 1C/1E - Serial number byte 1
 6'h0F : data = ~SERIAL_NUMBER[19:16];
 6'h10 : data = ~SERIAL_NUMBER[15:12]; // 20/22 - Serial number byte 2
 6'h11 : data = ~SERIAL_NUMBER[11:8];
 6'h12 : data = ~SERIAL_NUMBER[7:4];  // 24/26 - Serial number byte 3 (lsb)
 6'h13 : data = ~SERIAL_NUMBER[3:0];
 6'h14 : data = ~4'b0000;    // 28/2A - Optional ROM vector (high byte)
 6'h15 : data = ~4'b0000;
 6'h16 : data = ~4'b0000;    // 2C/2E - Optional ROM vector (low byte)
 6'h17 : data = ~4'b0000;
 6'h18 : data = ~4'b0000;    // 30/32 - Reserved (must be zero)
 6'h19 : data = ~4'b0000;
 6'h1A : data = ~4'b0000;    // 34/36 - Reserved (must be zero)
 6'h1B : data = ~4'b0000;
 6'h1C : data = ~4'b0000;    // 38/3A - Reserved (must be zero)
 6'h1D : data = ~4'b0000;
 6'h1E : data = ~4'b0000;    // 3C/3E - Reserved (must be zero)
 6'h1F : data = ~4'b0000;
 6'h20 : data =  4'b0000;    // 40/42 - Optional control status register
 6'h21 : data =  4'b0000;
 6'h22 : data = ~4'b0000;    // 44/46 - Reserved (must be zero)
 6'h23 : data = ~4'b0000;
 6'h24 : data = ~4'b0000;    // 48/4A - Base address register (write only)
 6'h25 : data = ~4'b0000;
 6'h26 : data = ~4'b0000;    // 4C/4E - Optional shut up address (write only)
 6'h27 : data = ~4'b0000;
 6'h28 : data = ~4'b0000;    // 50/52 - Reserved (must be zero)
 6'h29 : data = ~4'b0000;
 6'h2A : data = ~4'b0000;    // 54/56 - Reserved (must be zero)
 6'h2B : data = ~4'b0000;
 6'h2C : data = ~4'b0000;    // 58/5A - Reserved (must be zero)
 6'h2D : data = ~4'b0000;
 6'h2E : data = ~4'b0000;    // 5C/5E - Reserved (must be zero)
 6'h2F : data = ~4'b0000;
 6'h30 : data = ~4'b0000;    // 60/62 - Reserved (must be zero)
 6'h31 : data = ~4'b0000;
 6'h32 : data = ~4'b0000;    // 64/66 - Reserved (must be zero)
 6'h33 : data = ~4'b0000;
 6'h34 : data = ~4'b0000;    // 68/6A - Reserved (must be zero)
 6'h35 : data = ~4'b0000;
 6'h36 : data = ~4'b0000;    // 6C/6E - Reserved (must be zero)
 6'h37 : data = ~4'b0000;
 6'h38 : data = ~4'b0000;    // 70/72 - Reserved (must be zero)
 6'h39 : data = ~4'b0000;
 6'h3A : data = ~4'b0000;    // 74/76 - Reserved (must be zero)
 6'h3B : data = ~4'b0000;
 6'h3C : data = ~4'b0000;    // 78/7A - Reserved (must be zero)
 6'h3D : data = ~4'b0000;
 6'h3E : data = ~4'b0000;    // 7C/7E - Reserved (must be zero)
 6'h3F : data = ~4'b0000;
 endcase
end


endmodule

