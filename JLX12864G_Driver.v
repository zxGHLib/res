module JLX12864G_Driver
(
	input				clk,			//12MHz系统时钟
	input				rst_n,		//系统复位，低有效
    input       [31:0]  Tem, 
    input       [31:0]  Hum,
    input       [31:0]  Vol,	
	input       [87:0]	wifi_data,	
	input       [19:0] f_data_bcd,
	input       [19:0] f_data_bcd0,
    input       [1:0]  wave,

	output	reg			lcd_rst,	//LCD液晶屏复位
	output	reg			lcd_csn,	//LCD背光控制
	output	reg			lcd_dcn,	//LCD数据指令控制
	output	reg			lcd_clk,	//LCD时钟信号
	output	reg			lcd_dat  	//LCD数据信号
);
	
	localparam			INIT_DEPTH = 16'd12; //LCD初始化的命令的数量
	
	localparam			IDLE	=	3'd0;
	localparam			MAIN	=	3'd1;
	localparam			INIT	=	3'd2;
	localparam			SCAN	=	3'd3;
	localparam			WRITE	=	3'd4;
	localparam			DELAY	=	3'd5;
	
	localparam			LOW		=	1'b0;
	localparam			HIGH	=	1'b1;
	localparam			CMD		=	1'b0;
	localparam			DATA	=	1'b1;
	
	reg			[7:0]	reg_init	[11:0];
	reg 		[47:0]	mem			[132:0];
	
	reg			[7:0]	x_ph, x_pl, y_p;
	reg			[7:0]	num;
	reg			[(8*16-1):0]	char;
	reg			[7:0]	data_reg;				//
	reg			[3:0]	cnt_main;
	reg			[2:0]	cnt_init;
	reg			[3:0]	cnt_scan;
	reg			[5:0]	cnt_write;
	reg			[15:0]	cnt_delay, num_delay, cnt;
	reg			[2:0] 	state = IDLE, state_back = IDLE;
	
		
	reg         [7:0] data1,data2,data3;
	wire [7:0]   f1,f2,f3,f4,f5;
	
	assign f1={4'b0,f_data_bcd[19:16]};
	assign f2={4'b0,f_data_bcd[15:12]};
	assign f3={4'b0,f_data_bcd[11:8]};
	assign f4={4'b0,f_data_bcd[7:4]};
	assign f5={4'b0,f_data_bcd[3:0]};
	wire [7:0]   v1,v2,v3,v4,v5;
	
	assign v1={4'b0,f_data_bcd0[19:16]};
	assign v2={4'b0,f_data_bcd0[15:12]};
	assign v3={4'b0,f_data_bcd0[11:8]};
	assign v4={4'b0,f_data_bcd0[7:4]};
	assign v5={4'b0,f_data_bcd0[3:0]};
	always @(posedge clk or negedge rst_n)
    begin
	if(!rst_n) begin data1 <= 8'd63;data2<=8'd63;data3<=8'd63;end
	else case(wave)
		2'b00: begin data1 <= 8'd115;data2<=8'd105;data3<=8'd110; end// 正弦波
		2'b01: begin data1 <= 8'd115;data2<=8'd97;data3<=8'd119; end//锯齿波
		2'b10: begin data1 <= 8'd115;data2<=8'd113;data3<=8'd117; end//方波
		2'b11: begin data1 <= 8'd116;data2<=8'd114;data3<=8'd105; end	//三角波
		default:begin data1 <= 8'd63;data2<=8'd63;data3<=8'd63; end
		endcase
        end
	
	
	
	
	
	always@(posedge clk or negedge rst_n) begin
		if(!rst_n) begin
			cnt_main <= 4'd0;
			x_ph <= 8'd0; x_pl <= 8'd0; y_p <= 8'd0;
			num <= 8'd0; char <= " ";
			cnt_init <= 3'd0; cnt_scan <= 4'd0; cnt_write <= 6'd0;
			cnt_delay <= 16'd0; num_delay <= 16'd50; cnt <= 16'd0;
			data_reg <= 8'd0;
			lcd_rst <= HIGH; lcd_dcn <= CMD; lcd_csn <= HIGH; lcd_clk <= HIGH; lcd_dat <= LOW;
			state <= IDLE; state_back <= IDLE;
		end else begin
			case(state)
				IDLE:begin
						cnt_main <= 4'd0;
						x_ph <= 8'd0; x_pl <= 8'd0; y_p <= 8'd0;
						num <= 8'd0; char <= " ";
						cnt_init <= 3'd0; cnt_scan <= 4'd0; cnt_write <= 6'd0;
						cnt_delay <= 16'd0; num_delay <= 16'd50; cnt <= 16'd0;
						data_reg <= 8'd0;
						lcd_rst <= HIGH; lcd_dcn <= CMD; lcd_csn <= HIGH; lcd_clk <= HIGH; lcd_dat <= LOW;
						state <= MAIN; state_back <= MAIN;
					end
				MAIN:begin
						if(cnt_main >= 4'd15) cnt_main <= 4'd9;
						else cnt_main <= cnt_main + 1'b1;
						case(cnt_main)	//MAIN状态
							4'd0:	begin state <= INIT; end
							4'd1:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb0; num <= 5'd16; char <= "Tem:    $C      ";state <= SCAN; end
							4'd2:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb1; num <= 5'd16; char <= "Hum:    %       ";state <= SCAN; end
							4'd3:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb2; num <= 5'd16; char <= "Vol:    v       ";state <= SCAN; end
							4'd4:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb3; num <= 5'd16; char <= "WAVE:           ";state <= SCAN; end
							4'd5:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb4; num <= 5'd16; char <= "FREQ:           ";state <= SCAN; end
							4'd6:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb5; num <= 5'd16; char <= "VPP:            ";state <= SCAN; end
					     	4'd7:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb6; num <= 5'd16; char <= "WIFI:           ";state <= SCAN; end
							4'd8:	begin x_ph <= 8'h10; x_pl <= 8'h00; y_p <= 8'hb7; num <= 5'd16; char <= "                ";state <= SCAN; end 
							4'd9:	begin x_ph <= 8'h12; x_pl <= 8'h00; y_p <= 8'hb0; num <= 5'd4; char <= Tem;                state <= SCAN; end
							4'd10:	begin x_ph <= 8'h12; x_pl <= 8'h00; y_p <= 8'hb1; num <= 5'd4; char <= Hum;                state <= SCAN; end
							4'd11:	begin x_ph <= 8'h12; x_pl <= 8'h00; y_p <= 8'hb2; num <= 5'd4; char <= Vol;                state <= SCAN; end
							4'd12:	begin x_ph <= 8'h12; x_pl <= 8'h08; y_p <= 8'hb3; num <= 5'd3; char <= {data1,data2,data3}; state <= SCAN; end
							4'd13:	begin x_ph <= 8'h12; x_pl <= 8'h08; y_p <= 8'hb4; num <= 5'd7; char <= {f1,f2,f3,f4,f5,8'd72,8'd122};state <= SCAN; end
							4'd14:	begin x_ph <= 8'h12; x_pl <= 8'h08; y_p <= 8'hb5; num <= 5'd5; char <= {v2,".",v3,v4,"V"}; state <= SCAN; end	
							4'd15:	begin x_ph <= 8'h12; x_pl <= 8'h08; y_p <= 8'hb6; num <= 5'd11; char <= wifi_data		  ;state <= SCAN; end
							default: state <= IDLE;
						endcase
					end
				INIT:begin	//初始化状态
						case(cnt_init)
							3'd0:	begin lcd_rst <= LOW; cnt_init <= cnt_init + 1'b1; end	//复位有效
							3'd1:	begin num_delay <= 16'd5000; state <= DELAY; state_back <= INIT; cnt_init <= cnt_init + 1'b1; end	//延时大于3us
							3'd2:	begin lcd_rst <= HIGH; cnt_init <= cnt_init + 1'b1; end	//复位恢复
							3'd3:	begin num_delay <= 16'd5000; state <= DELAY; state_back <= INIT; cnt_init <= cnt_init + 1'b1; end	//延时大于220us
							3'd4:	begin 
										if(cnt>=INIT_DEPTH) begin	//当73条指令及数据发出后，配置完成
											cnt <= 16'd0;
											cnt_init <= cnt_init + 1'b1;
										end else begin
											data_reg <= reg_init[cnt];	
											if(cnt<=16'd3) num_delay <= 16'd5000; //前4条指令需要较长延时
											else num_delay <= 16'd5;
											cnt <= cnt + 16'd1;
											lcd_dcn <= CMD; 
											state <= WRITE;
											state_back <= INIT;
										end
									end
							3'd5:	begin cnt_init <= 1'b0; state <= MAIN; end	//初始化完成，返回MAIN状态
							default: state <= IDLE;
						endcase
					end
				SCAN:begin	//刷屏状态，从RAM中读取数据刷屏
						if(cnt_scan == 4'd11) begin
							if(num>=1'b1) cnt_scan <= 4'd3;
							else cnt_scan <= cnt_scan + 1'b1;
						end else if(cnt_scan == 4'd12) cnt_scan <= 1'b0;
						else cnt_scan <= cnt_scan + 1'b1;
						case(cnt_scan)
							4'd0:	begin lcd_dcn <= CMD; data_reg <= y_p; state <= WRITE; state_back <= SCAN; end
							4'd1:	begin lcd_dcn <= CMD; data_reg <= x_ph; state <= WRITE; state_back <= SCAN; end
							4'd2:	begin lcd_dcn <= CMD; data_reg <= x_pl; state <= WRITE; state_back <= SCAN; end
							
							4'd3:	begin num <= num - 1'b1;end
							4'd4:	begin lcd_dcn <= DATA; data_reg <= 8'h00; state <= WRITE; state_back <= SCAN; end
							4'd5:	begin lcd_dcn <= DATA; data_reg <= 8'h00; state <= WRITE; state_back <= SCAN; end
							4'd6:	begin lcd_dcn <= DATA; data_reg <= mem[char[(num*8)+:8]][47:40]; state <= WRITE; state_back <= SCAN; end
							4'd7:	begin lcd_dcn <= DATA; data_reg <= mem[char[(num*8)+:8]][39:32]; state <= WRITE; state_back <= SCAN; end
							4'd8:	begin lcd_dcn <= DATA; data_reg <= mem[char[(num*8)+:8]][31:24]; state <= WRITE; state_back <= SCAN; end
							4'd9:	begin lcd_dcn <= DATA; data_reg <= mem[char[(num*8)+:8]][23:16]; state <= WRITE; state_back <= SCAN; end
							4'd10:	begin lcd_dcn <= DATA; data_reg <= mem[char[(num*8)+:8]][15: 8]; state <= WRITE; state_back <= SCAN; end
							4'd11:	begin lcd_dcn <= DATA; data_reg <= mem[char[(num*8)+:8]][ 7: 0]; state <= WRITE; state_back <= SCAN; end
							4'd12:	begin state <= MAIN; end
							
							default: state <= IDLE;
						endcase
					end
				WRITE:begin	//WRITE状态，将数据按照SPI时序发送给屏幕
						if(cnt_write >= 6'd17) cnt_write <= 1'b0;
						else cnt_write <= cnt_write + 1'b1;
						case(cnt_write)
							6'd0:	begin lcd_csn <= LOW; end	//9位数据最高位为命令数据控制位
							6'd1:	begin lcd_clk <= LOW; lcd_dat <= data_reg[7]; end	//先发高位数据
							6'd2:	begin lcd_clk <= HIGH; end
							6'd3:	begin lcd_clk <= LOW; lcd_dat <= data_reg[6]; end
							6'd4:	begin lcd_clk <= HIGH; end
							6'd5:	begin lcd_clk <= LOW; lcd_dat <= data_reg[5]; end
							6'd6:	begin lcd_clk <= HIGH; end
							6'd7:	begin lcd_clk <= LOW; lcd_dat <= data_reg[4]; end
							6'd8:	begin lcd_clk <= HIGH; end
							6'd9:	begin lcd_clk <= LOW; lcd_dat <= data_reg[3]; end
							6'd10:	begin lcd_clk <= HIGH; end
							6'd11:	begin lcd_clk <= LOW; lcd_dat <= data_reg[2]; end
							6'd12:	begin lcd_clk <= HIGH; end
							6'd13:	begin lcd_clk <= LOW; lcd_dat <= data_reg[1]; end
							6'd14:	begin lcd_clk <= HIGH; end
							6'd15:	begin lcd_clk <= LOW; lcd_dat <= data_reg[0]; end	//后发低位数据
							6'd16:	begin lcd_clk <= HIGH; end
							6'd17:	begin lcd_csn <= HIGH; state <= DELAY; end	//
							default: state <= IDLE;
						endcase
					end
				DELAY:begin	//延时状态
						if(cnt_delay >= num_delay) begin
							cnt_delay <= 16'd0;
							state <= state_back; 
						end else cnt_delay <= cnt_delay + 1'b1;
					end
				default:state <= IDLE;
			endcase
		end
	end
	
	// data for init
	always@(posedge rst_n)	//LCD初始化的命令及数据
		begin
			reg_init[0]		=	{8'he2}; 
			reg_init[1]		=	{8'h2c}; 
			reg_init[2]		=	{8'h2e}; 
			reg_init[3]		=	{8'h2f}; 
			reg_init[4]		=	{8'h23}; 
			reg_init[5]		=	{8'h81}; 
			reg_init[6]		=	{8'h28}; 
			reg_init[7]		=	{8'ha2}; 
			reg_init[8]		=	{8'hc8}; 
			reg_init[9]		=	{8'ha0}; 
			reg_init[10]	=	{8'h40}; 
			reg_init[11]	=	{8'haf}; 
		end
	
	//initial for memory register
	always@(posedge rst_n)
		begin
			//以数字直接值为地址
			mem[  0]= {8'h00, 8'h3E, 8'h51, 8'h49, 8'h45, 8'h3E};   // 0
			mem[  1]= {8'h00, 8'h00, 8'h42, 8'h7F, 8'h40, 8'h00};   // 1
			mem[  2]= {8'h00, 8'h42, 8'h61, 8'h51, 8'h49, 8'h46};   // 2
			mem[  3]= {8'h00, 8'h21, 8'h41, 8'h45, 8'h4B, 8'h31};   // 3
			mem[  4]= {8'h00, 8'h18, 8'h14, 8'h12, 8'h7F, 8'h10};   // 4
			mem[  5]= {8'h00, 8'h27, 8'h45, 8'h45, 8'h45, 8'h39};   // 5
			mem[  6]= {8'h00, 8'h3C, 8'h4A, 8'h49, 8'h49, 8'h30};   // 6
			mem[  7]= {8'h00, 8'h01, 8'h71, 8'h09, 8'h05, 8'h03};   // 7
			mem[  8]= {8'h00, 8'h36, 8'h49, 8'h49, 8'h49, 8'h36};   // 8
			mem[  9]= {8'h00, 8'h06, 8'h49, 8'h49, 8'h29, 8'h1E};   // 9
			
			//以字符ASCII码为地址
			mem[ 32]= {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};   // sp 
			mem[ 33]= {8'h00, 8'h00, 8'h00, 8'h2f, 8'h00, 8'h00};   // !  
			mem[ 34]= {8'h00, 8'h00, 8'h07, 8'h00, 8'h07, 8'h00};   // 
			mem[ 35]= {8'h00, 8'h14, 8'h7f, 8'h14, 8'h7f, 8'h14};   // #
			mem[ 36]= {8'h00, 8'h06, 8'h09, 8'h09, 8'h06, 8'h00};   // $
			mem[ 37]= {8'h42, 8'h25, 8'h12, 8'h48, 8'hA4, 8'h42};   // %
			mem[ 38]= {8'h00, 8'h36, 8'h49, 8'h55, 8'h22, 8'h50};   // &
			mem[ 39]= {8'h00, 8'h00, 8'h05, 8'h03, 8'h00, 8'h00};   // '
			mem[ 40]= {8'h00, 8'h00, 8'h1c, 8'h22, 8'h41, 8'h00};   // {
			mem[ 41]= {8'h00, 8'h00, 8'h41, 8'h22, 8'h1c, 8'h00};   // )
			mem[ 42]= {8'h00, 8'h14, 8'h08, 8'h3E, 8'h08, 8'h14};   // *
			mem[ 43]= {8'h00, 8'h08, 8'h08, 8'h3E, 8'h08, 8'h08};   // +
			mem[ 44]= {8'h00, 8'h00, 8'h00, 8'hA0, 8'h60, 8'h00};   // ,
			mem[ 45]= {8'h00, 8'h08, 8'h08, 8'h08, 8'h08, 8'h08};   // -
			mem[ 46]= {8'h00, 8'h00, 8'h60, 8'h60, 8'h00, 8'h00};   // .
			mem[ 47]= {8'h00, 8'h20, 8'h10, 8'h08, 8'h04, 8'h02};   // /
			mem[ 48]= {8'h00, 8'h3E, 8'h51, 8'h49, 8'h45, 8'h3E};   // 0
			mem[ 49]= {8'h00, 8'h00, 8'h42, 8'h7F, 8'h40, 8'h00};   // 1
			mem[ 50]= {8'h00, 8'h42, 8'h61, 8'h51, 8'h49, 8'h46};   // 2
			mem[ 51]= {8'h00, 8'h21, 8'h41, 8'h45, 8'h4B, 8'h31};   // 3
			mem[ 52]= {8'h00, 8'h18, 8'h14, 8'h12, 8'h7F, 8'h10};   // 4
			mem[ 53]= {8'h00, 8'h27, 8'h45, 8'h45, 8'h45, 8'h39};   // 5
			mem[ 54]= {8'h00, 8'h3C, 8'h4A, 8'h49, 8'h49, 8'h30};   // 6
			mem[ 55]= {8'h00, 8'h01, 8'h71, 8'h09, 8'h05, 8'h03};   // 7
			mem[ 56]= {8'h00, 8'h36, 8'h49, 8'h49, 8'h49, 8'h36};   // 8
			mem[ 57]= {8'h00, 8'h06, 8'h49, 8'h49, 8'h29, 8'h1E};   // 9
			mem[ 58]= {8'h00, 8'h00, 8'h36, 8'h36, 8'h00, 8'h00};   // :
			mem[ 59]= {8'h00, 8'h00, 8'h56, 8'h36, 8'h00, 8'h00};   // ;
			mem[ 60]= {8'h00, 8'h08, 8'h14, 8'h22, 8'h41, 8'h00};   // <
			mem[ 61]= {8'h00, 8'h14, 8'h14, 8'h14, 8'h14, 8'h14};   // =
			mem[ 62]= {8'h00, 8'h00, 8'h41, 8'h22, 8'h14, 8'h08};   // >
			mem[ 63]= {8'h00, 8'h02, 8'h01, 8'h51, 8'h09, 8'h06};   // ?
			mem[ 64]= {8'h00, 8'h32, 8'h49, 8'h59, 8'h51, 8'h3E};   // @
			mem[ 65]= {8'h00, 8'h7C, 8'h12, 8'h11, 8'h12, 8'h7C};   // A
			mem[ 66]= {8'h00, 8'h7F, 8'h49, 8'h49, 8'h49, 8'h36};   // B
			mem[ 67]= {8'h00, 8'h3E, 8'h41, 8'h41, 8'h41, 8'h22};   // C
			mem[ 68]= {8'h00, 8'h7F, 8'h41, 8'h41, 8'h22, 8'h1C};   // D
			mem[ 69]= {8'h00, 8'h7F, 8'h49, 8'h49, 8'h49, 8'h41};   // E
			mem[ 70]= {8'h00, 8'h7F, 8'h09, 8'h09, 8'h09, 8'h01};   // F
			mem[ 71]= {8'h00, 8'h3E, 8'h41, 8'h49, 8'h49, 8'h7A};   // G
			mem[ 72]= {8'h00, 8'h7F, 8'h08, 8'h08, 8'h08, 8'h7F};   // H
			mem[ 73]= {8'h00, 8'h00, 8'h41, 8'h7F, 8'h41, 8'h00};   // I
			mem[ 74]= {8'h00, 8'h20, 8'h40, 8'h41, 8'h3F, 8'h01};   // J
			mem[ 75]= {8'h00, 8'h7F, 8'h08, 8'h14, 8'h22, 8'h41};   // K
			mem[ 76]= {8'h00, 8'h7F, 8'h40, 8'h40, 8'h40, 8'h40};   // L
			mem[ 77]= {8'h00, 8'h7F, 8'h02, 8'h0C, 8'h02, 8'h7F};   // M
			mem[ 78]= {8'h00, 8'h7F, 8'h04, 8'h08, 8'h10, 8'h7F};   // N
			mem[ 79]= {8'h00, 8'h3E, 8'h41, 8'h41, 8'h41, 8'h3E};   // O
			mem[ 80]= {8'h00, 8'h7F, 8'h09, 8'h09, 8'h09, 8'h06};   // P
			mem[ 81]= {8'h00, 8'h3E, 8'h41, 8'h51, 8'h21, 8'h5E};   // Q
			mem[ 82]= {8'h00, 8'h7F, 8'h09, 8'h19, 8'h29, 8'h46};   // R
			mem[ 83]= {8'h00, 8'h46, 8'h49, 8'h49, 8'h49, 8'h31};   // S
			mem[ 84]= {8'h00, 8'h01, 8'h01, 8'h7F, 8'h01, 8'h01};   // T
			mem[ 85]= {8'h00, 8'h3F, 8'h40, 8'h40, 8'h40, 8'h3F};   // U
			mem[ 86]= {8'h00, 8'h1F, 8'h20, 8'h40, 8'h20, 8'h1F};   // V
			mem[ 87]= {8'h00, 8'h3F, 8'h40, 8'h38, 8'h40, 8'h3F};   // W
			mem[ 88]= {8'h00, 8'h63, 8'h14, 8'h08, 8'h14, 8'h63};   // X
			mem[ 89]= {8'h00, 8'h07, 8'h08, 8'h70, 8'h08, 8'h07};   // Y
			mem[ 90]= {8'h00, 8'h61, 8'h51, 8'h49, 8'h45, 8'h43};   // Z
			mem[ 91]= {8'h00, 8'h00, 8'h7F, 8'h41, 8'h41, 8'h00};   // [
			mem[ 92]= {8'h00, 8'h55, 8'h2A, 8'h55, 8'h2A, 8'h55};   // .
			mem[ 93]= {8'h00, 8'h00, 8'h41, 8'h41, 8'h7F, 8'h00};   // ]
			mem[ 94]= {8'h00, 8'h04, 8'h02, 8'h01, 8'h02, 8'h04};   // ^
			mem[ 95]= {8'h00, 8'h40, 8'h40, 8'h40, 8'h40, 8'h40};   // _
			mem[ 96]= {8'h00, 8'h00, 8'h01, 8'h02, 8'h04, 8'h00};   // '
			mem[ 97]= {8'h00, 8'h20, 8'h54, 8'h54, 8'h54, 8'h78};   // a
			mem[ 98]= {8'h00, 8'h7F, 8'h48, 8'h44, 8'h44, 8'h38};   // b
			mem[ 99]= {8'h00, 8'h38, 8'h44, 8'h44, 8'h44, 8'h20};   // c
			mem[100]= {8'h00, 8'h38, 8'h44, 8'h44, 8'h48, 8'h7F};   // d
			mem[101]= {8'h00, 8'h38, 8'h54, 8'h54, 8'h54, 8'h18};   // e
			mem[102]= {8'h00, 8'h08, 8'h7E, 8'h09, 8'h01, 8'h02};   // f
			mem[103]= {8'h00, 8'h18, 8'hA4, 8'hA4, 8'hA4, 8'h7C};   // g
			mem[104]= {8'h00, 8'h7F, 8'h08, 8'h04, 8'h04, 8'h78};   // h
			mem[105]= {8'h00, 8'h00, 8'h44, 8'h7D, 8'h40, 8'h00};   // i
			mem[106]= {8'h00, 8'h40, 8'h80, 8'h84, 8'h7D, 8'h00};   // j
			mem[107]= {8'h00, 8'h7F, 8'h10, 8'h28, 8'h44, 8'h00};   // k
			mem[108]= {8'h00, 8'h00, 8'h41, 8'h7F, 8'h40, 8'h00};   // l
			mem[109]= {8'h00, 8'h7C, 8'h04, 8'h18, 8'h04, 8'h78};   // m
			mem[110]= {8'h00, 8'h7C, 8'h08, 8'h04, 8'h04, 8'h78};   // n
			mem[111]= {8'h00, 8'h38, 8'h44, 8'h44, 8'h44, 8'h38};   // o
			mem[112]= {8'h00, 8'hFC, 8'h24, 8'h24, 8'h24, 8'h18};   // p
			mem[113]= {8'h00, 8'h18, 8'h24, 8'h24, 8'h18, 8'hFC};   // q
			mem[114]= {8'h00, 8'h7C, 8'h08, 8'h04, 8'h04, 8'h08};   // r
			mem[115]= {8'h00, 8'h48, 8'h54, 8'h54, 8'h54, 8'h20};   // s
			mem[116]= {8'h00, 8'h04, 8'h3F, 8'h44, 8'h40, 8'h20};   // t
			mem[117]= {8'h00, 8'h3C, 8'h40, 8'h40, 8'h20, 8'h7C};   // u
			mem[118]= {8'h00, 8'h1C, 8'h20, 8'h40, 8'h20, 8'h1C};   // v
			mem[119]= {8'h00, 8'h3C, 8'h40, 8'h30, 8'h40, 8'h3C};   // w
			mem[120]= {8'h00, 8'h44, 8'h28, 8'h10, 8'h28, 8'h44};   // x
			mem[121]= {8'h00, 8'h1C, 8'hA0, 8'hA0, 8'hA0, 8'h7C};   // y
			mem[122]= {8'h00, 8'h44, 8'h64, 8'h54, 8'h4C, 8'h44};   // z
			mem[123]= {8'h14, 8'h14, 8'h14, 8'h14, 8'h14, 8'h14};   // horiz lines
		end
	
endmodule

