module encoder
(
	input sys_clk,
	
	input enc_nrst,
	input enc_a,
	input enc_b,
	input enc_z,
	
	output reg signed[31:0] enc_pos_r = 32'b0,
	output reg signed[31:0] enc_vel_r = 32'b0
);

/*******************编码器数字滤波器******************/
wire enc_filter_a;
wire enc_filter_b;
wire enc_filter_z;
enc_filter enc_filter_init
(
	.sys_clk(sys_clk),
	
	.filter_nrst(enc_nrst),
	.filter_en(1'b1),
	.enc_a_in(enc_a),
	.enc_b_in(enc_b),
	.enc_z_in(enc_z),
	
	.enc_a_out_r(enc_filter_a),
	.enc_b_out_r(enc_filter_b),
	.enc_z_out_r(enc_filter_z)
	
);
/*******************编码器数字滤波器******************/

/****************上升沿与下降沿检测进程****************/
wire enc_a_rise_eage/* synthesis keep */;
wire enc_a_fall_eage/* synthesis keep */;
wire enc_b_rise_eage/* synthesis keep */;
wire enc_b_fall_eage/* synthesis keep */;
reg[1:0] enc_a_eage_r = 2'b00;
reg[1:0] enc_b_eage_r = 2'b00;
assign enc_a_rise_eage = (enc_a_eage_r == 2'b01);
assign enc_a_fall_eage = (enc_a_eage_r == 2'b10);
assign enc_b_rise_eage = (enc_b_eage_r == 2'b01);
assign enc_b_fall_eage = (enc_b_eage_r == 2'b10);
always @(posedge sys_clk or negedge enc_nrst)
	begin
		if (!enc_nrst)
			begin
				enc_a_eage_r <= 2'b00;
				enc_b_eage_r <= 2'b00;
			end
		else
			begin
				enc_a_eage_r <= {enc_a_eage_r[0],enc_filter_a};
				enc_b_eage_r <= {enc_b_eage_r[0],enc_filter_b};
			end
	end
/****************上升沿与下降沿检测进程****************/

//编码器原理：
//	编码器正转状态转换表：00 -> 10 -> 11 -> 01 -> 00
// 编码器反转状态转换表：00 -> 01 -> 11 -> 10 -> 00
// 利用上述两张表，根据当前状态与上一次状态对比找到表中的位置，然后进行相应的加减计数操作。
// 四个状态意味着实现了四倍频。

/******************获取编码器位置V2.0*****************/
//note:此版本的代码相对于V2.0较为难看，但是不会有V1.0版本中的小瑕疵
reg[1:0] last_statsu_r = 2'b00;
always @( posedge sys_clk or negedge enc_nrst)
	begin
		if (!enc_nrst)
			begin
				last_statsu_r <= 2'b00;
				enc_pos_r <= 32'b0;
			end
		else
			if ((enc_a_rise_eage) || (enc_a_fall_eage) || 
				 (enc_b_rise_eage) || (enc_b_fall_eage))
				begin					
					case ({enc_filter_a,enc_filter_b})
						2'b00:
								if (last_statsu_r == 2'b01)
									enc_pos_r <= enc_pos_r + 1;
								else if (last_statsu_r == 2'b10)
									enc_pos_r <= enc_pos_r - 1;
								else
									enc_pos_r <= enc_pos_r;
						2'b01:
								if (last_statsu_r == 2'b11)
									enc_pos_r <= enc_pos_r + 1;
								else if (last_statsu_r == 2'b00)
									enc_pos_r <= enc_pos_r - 1;
								else
									enc_pos_r <= enc_pos_r;
						2'b11:
								if (last_statsu_r == 2'b10)
									enc_pos_r <= enc_pos_r + 1;
								else if (last_statsu_r == 2'b01)
									enc_pos_r <= enc_pos_r - 1;
								else
									enc_pos_r <= enc_pos_r;
						2'b10:
								if (last_statsu_r == 2'b00)
									enc_pos_r <= enc_pos_r + 1;
								else if (last_statsu_r == 2'b11)
									enc_pos_r <= enc_pos_r - 1;
								else
									enc_pos_r <= enc_pos_r;
						default:   ;
					endcase
					last_statsu_r <= {enc_a,enc_b};
				end		
			else
				enc_pos_r <= enc_pos_r; //没什么用,就是与if配对用的
			
	end
/******************获取编码器位置V2.0*****************/

/********************获取编码器速度*******************/
reg[15:0] div_cnt = 0;
reg signed[31:0] last_enc_pos_r = 0;
always @(posedge sys_clk or negedge enc_nrst)
	begin
		if (!enc_nrst)
			begin
				div_cnt <= 0;
				enc_vel_r <= 0;
				last_enc_pos_r <= 0;
			end
		else
			begin
				div_cnt <= div_cnt + 1'd1;
				if (div_cnt >= 50000)   //单位：p/ms
					begin
						enc_vel_r <= enc_pos_r - last_enc_pos_r;
						div_cnt <= 0;
						last_enc_pos_r <= enc_pos_r;
					end
			end

	end
/********************获取编码器速度*******************/

endmodule
