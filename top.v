module top
(
	//系统信号
	input						sys_clk,
	input						rst_n,
	
	//XY2-100协议信号
	/********* XY2-100 ***********/
	input 					xy_clk,
	input						xy_sync,
	input						xy_x_data,
	input						xy_y_data,
	/********* XY2-100 ***********/
	
	//电机控制信号
	/********** Motor ***********/
	input						x_home_done,
	output 	 				x_en,
	output 					x_dir,
	output 					x_step,
	
	input						y_home_done,
	output 					y_en,
	output 					y_dir,
	output 					y_step,
	/********** Motor ***********/
	
	//编码器
	/******** Encoder ***********/
	input 					x_A,		//X轴编码器A相信号输入
	input 					x_B,		//X轴编码器B相信号输入
	input 					x_Z,		//X轴编码器Z相信号输入
	
	input 					y_A,		//Y轴编码器A相信号输入
	input 					y_B,		//Y轴编码器B相信号输入
	input 					y_Z,		//Y轴编码器Z相信号输入
	/******** Encoder ***********/
	
	//测试输出
	output				 	led_x_en,
	output				 	led_y_en

);

wire			xy_done_flag;
wire [15:0]	rec_x_pos;
wire [15:0]	rec_y_pos;
wire			m_x_busy;				//电机忙，正在输出脉冲
wire			m_x_arrived;
wire			m_y_busy;				//电机忙，正在输出脉冲
wire			m_y_arrived;

assign led_x_en = x_home_done;
assign led_y_en = y_home_done;


/***************** 电机速度设定 *****************/
reg  [15:0] set_vel;
reg  [15:0] set_vel_n;
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		set_vel <= 16'd136;					//22*20ns=0.440us/pul，脉冲周期，当一转反馈为2048*18=36864pul/r时，对应速度为3699.1r/min(61.65r/s)
	else											//34*20ns=0.680us/pul，脉冲周期，当一转反馈为2048*18=36864pul/r时，对应速度为2393.5r/min(39.89r/s)
		set_vel <= set_vel_n;				//136*20ns=2.72us/pul，脉冲周期，当一转反馈为2048*18=36864pul/r时，对应速度为598.4r/min(9.97r/s)
end
always @ (*)
begin
	if(!rst_n)
		set_vel_n = 16'd136;
	else
		set_vel_n = set_vel;
end
/***************** 电机速度设定 *****************/

XY2_100 XY2_100_init
(
	.sys_clk		(sys_clk		),
	.rst_n		(rst_n		),
	
	.xy_clk		(xy_clk		),
	.xy_sync		(xy_sync		),
	.xy_x_data	(xy_x_data	),
	.xy_y_data	(xy_y_data	),
	
	.finish_flag(xy_done_flag),
	.out_x_data	(rec_x_pos),
	.out_y_data	(rec_y_pos)
);

motor_control X_motor_init
(
	.sys_clk		(sys_clk		),
	.rst_n		(rst_n		),
	.enc_a		(x_A			),
	.enc_b		(x_B			),
	.enc_z		(x_Z			),
	.home_done	(x_home_done),
	.rec_pos		(rec_x_pos	),
	.set_vel		(set_vel		),
	
	.m_busy		(m_x_busy	),
	.finish_flag(m_x_arrived),
	.m_en			(x_en			),
	.dir			(x_dir		),
	.pul			(x_step		)
);

motor_control Y_motor_init
(
	.sys_clk		(sys_clk		),
	.rst_n		(rst_n		),
	.enc_a		(y_A			),
	.enc_b		(y_B			),
	.enc_z		(y_Z			),
	.home_done	(y_home_done),
	.rec_pos		(rec_y_pos	),
	.set_vel		(set_vel		),
	
	.m_busy		(m_y_busy	),
	.finish_flag(m_y_arrived),
	.m_en			(y_en			),
	.dir			(y_dir		),
	.pul			(y_step		)
);

endmodule
///***************** 等待回原点到位 *********************/
////驱动器上电后会首先进行回零操作，但有可能驱动器被紧急断电，而控制卡不断电的情况
////为了可以重复触发回原点后进行位置偏置，检测回原点到位信号的持续时间来判断驱动器状态
//parameter DELAY_1S = 32'd50_000_000;
//reg [31:0]	x_wait_cnt;
//reg [31:0]	x_wait_cnt_n;
//reg [31:0]	y_wait_cnt;
//reg [31:0]	y_wait_cnt_n;
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		x_wait_cnt <= 32'b0;
//	else
//		x_wait_cnt <= x_wait_cnt_n;
//end
//always @ (*)
//begin
//	if(!x_home_done)						//驱动器回原点完成后，到位信号对应低电平
//		x_wait_cnt_n = 32'b0;
//	else if(x_wait_cnt < DELAY_1S && x_home_done)		//当驱动器持续1s时间内回原点到位信号无效，有2种情况：
//		x_wait_cnt_n = x_wait_cnt + 32'b1;					//1、回原点未完成；2、驱动器断电
//	else																//
//		x_wait_cnt_n = x_wait_cnt;
//end
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		y_wait_cnt <= 32'b0;
//	else
//		y_wait_cnt <= y_wait_cnt_n;
//end
//always @ (*)
//begin
//	if(!y_home_done)						//驱动器回原点完成后，标志位对应低电平
//		y_wait_cnt_n = 32'b0;
//	else if(y_wait_cnt < DELAY_1S && y_home_done)
//		y_wait_cnt_n = y_wait_cnt + 32'b1;
//	else
//		y_wait_cnt_n = y_wait_cnt;
//end
///***************** 等待回原点到位 *********************/
//
///***************** 回原点到位后延时 *********************/
////驱动器回原点首次完成后，电机会有一定的调整，需要留一定的时间
//reg [31:0]	x_delay_cnt;
//reg [31:0]	x_delay_cnt_n;
//reg [31:0]	y_delay_cnt;
//reg [31:0]	y_delay_cnt_n;
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		x_delay_cnt <= 32'b0;
//	else
//		x_delay_cnt <= x_delay_cnt_n;
//end
//always @ (*)
//begin
//	if(x_wait_cnt == DELAY_1S)									//驱动器持续1s时间内回原点到位信号无效，准备下次延时			
//		x_delay_cnt_n = 32'b0;									//在驱动器原点到位后，信号有一定的跳变，用上面的等待计数操作滤除跳变
//	else if(x_delay_cnt < DELAY_1S && !x_home_done)		//驱动器回原点完成后，标志位对应低电平
//		x_delay_cnt_n = x_delay_cnt + 32'b1;
//	else
//		x_delay_cnt_n = x_delay_cnt;
//end
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		y_delay_cnt <= 32'b0;
//	else
//		y_delay_cnt <= y_delay_cnt_n;
//end
//always @ (*)
//begin
//	if(y_wait_cnt == DELAY_1S)						//驱动器回原点完成后，标志位对应低电平
//		y_delay_cnt_n = 32'b0;
//	else if(y_delay_cnt < DELAY_1S && !y_home_done)
//		y_delay_cnt_n = y_delay_cnt + 32'b1;
//	else
//		y_delay_cnt_n = y_delay_cnt;
//end
///***************** 回原点到位后延时 *********************/

///***************** X轴电机位置设定 *****************/
//reg		[15:0]	set_x_pos;				//控制x轴电机输出的位置
//reg		[15:0]	set_x_pos_n;			//
//wire					m_x_busy;				//电机忙，正在输出脉冲
//wire					m_x_arrived;
////时序电路,set_x_pos
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		set_x_pos <= 16'd0;
//	else
//		set_x_pos <= set_x_pos_n;
//end
////组合电路,set_x_pos_n
//always @ (*)
//begin
//	if(!m_x_busy && (x_delay_cnt == DELAY_1S))
//		set_x_pos_n = ((rec_x_pos >> 5) + 16'd1024);
//	else
//		set_x_pos_n = set_x_pos;
//end
///***************** X轴电机位置设定 *****************/

///***************** Y轴电机位置设定 *****************/
//reg		[15:0]	set_y_pos;				//控制y轴电机输出的位置
//reg		[15:0]	set_y_pos_n;			//
//wire					m_y_busy;				//电机忙，正在输出脉冲
//wire					m_y_arrived;
////时序电路,set_y_pos
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		set_y_pos <= 16'd0;
//	else
//		set_y_pos <= set_y_pos_n;
//end
////组合电路,set_y_pos_n
//always @ (*)
//begin
//	if(!m_y_busy && (y_delay_cnt == DELAY_1S))
//		set_y_pos_n = ((rec_y_pos >> 5) + 16'd1024);
//	else
//		set_y_pos_n = set_y_pos;
//end
///***************** Y轴电机位置设定 *****************/
