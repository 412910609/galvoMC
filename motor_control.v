module motor_control
(
	input sys_clk,
	input rst_n,
	
	input enc_a,
	input enc_b,
	input enc_z,
	
	input	home_done,
	input [15:0] rec_pos,
	input [15:0] set_vel,
	
	output reg m_busy,
	output reg finish_flag,
 	output reg m_en,
	output reg dir,
	output reg pul
);

reg [15:0]	set_pos;				//控制电机输出的位置
reg [15:0]	set_pos_n;			//set_pos 的下一状态
//reg 			m_en;
reg			m_en_n;				//电机使能控制，低电平 0 有效
reg			dir_n;
reg			pul_n;
reg [15:0]  time_cnt;
reg [15:0]  time_cnt_n;
reg [15:0]	half_vel;
reg [15:0]	pul_cnt;
reg [15:0]  pul_cnt_n;
reg [15:0]	aim_pos;
reg [15:0]	aim_pos_n;
reg [15:0]  now_pos;
reg [15:0]  now_pos_n;
//reg			m_busy;
reg			m_busy_n;
reg			finish_flag_n;
wire[31:0]	enc_pos;				//编码器位置(进行了4倍频),单位：pulse
wire[31:0]	enc_vel;				//编码器速度,单位：pulse/ms

//组合电路,half_vel
always @ (*)
begin
	half_vel = set_vel >> 1;
end

/***************** 等待回原点到位 *********************/
//驱动器上电后会首先进行回零操作，但有可能驱动器被紧急断电，而控制卡不断电的情况
//为了可以重复触发回原点后进行位置偏置，检测回原点到位信号的持续时间来判断驱动器状态
//回零未完成该信号为高电平，回零完成后该信号为低电平（但信号会有跳变），检测高电平持续时间
//当高电平持续时间超过指定时长（200ms），认为电机回零没完成或电机发生断电
parameter DELAY_1S = 28'd50_000_000 - 28'd1;
parameter DELAY_500MS = 28'd25_000_000;
parameter DELAY_200MS = 28'd10_000_000;
//reg [23:0]	wait_cnt;
//reg [23:0]	wait_cnt_n;
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		wait_cnt <= 24'b0;
//	else
//		wait_cnt <= wait_cnt_n;
//end
//always @ (*)
//begin
//	if(!home_done)													//驱动器回原点完成后，到位信号对应低电平
//		wait_cnt_n = 24'b0;
//	else if(wait_cnt < DELAY_200MS && home_done)				//当驱动器持续1s时间内回原点到位信号无效，有2种情况：
//		wait_cnt_n = wait_cnt + 24'b1;						//1、回原点未完成；2、驱动器断电
//	else																//
//		wait_cnt_n = wait_cnt;
//end

wire wait_finish;
wire [27:0]	wait_cnt;
IP_COUNT wait_counter(											//使用计数器的IP核进行计数，保证数据的可靠性，设置为50_000_000计数溢出
	.sclr			(!home_done	),									//一出现回零完成（低电平），就清除等待计数
	.clock		(sys_clk		),									//使用50MHz系统时钟，计数50_000_000对应1s
	.cnt_en		(home_done	),									//回零到位信号为高电平就进行计数
	.cout			(wait_finish),									//溢出标志位
	.q				(wait_cnt	)									//等待的计数值
);
/***************** 等待回原点到位 *********************/

/***************** 回原点到位后延时 *********************/
//驱动器回原点首次完成后，电机会有一定的调整，需要留一定的时间
//回零完成后到位信号为低电平（会有跳变），当低电平能够出现指定次数后（并不是持续时间）进行位置脉冲的发送
//reg [31:0]	delay_cnt;
//reg [31:0]	delay_cnt_n;
//always @ (posedge sys_clk or negedge rst_n)
//begin
//	if(!rst_n)
//		delay_cnt <= 32'b0;
//	else
//		delay_cnt <= delay_cnt_n;
//end
//always @ (*)
//begin
//	if(wait_finish)									//驱动器持续1s时间内回原点到位信号无效，准备下次延时			
//		delay_cnt_n = 32'b0;										//在驱动器原点到位后，信号有一定的跳变，用上面的等待计数操作滤除跳变
//	else if(delay_cnt < DELAY_1S && !home_done)			//驱动器回原点完成后，标志位对应低电平
//		delay_cnt_n = delay_cnt + 32'b1;
//	else
//		delay_cnt_n = delay_cnt;
//end
wire delay_finish;
wire [27:0]	delay_cnt;
IP_COUNT delay_counter(
	.sclr			(wait_cnt >= DELAY_200MS),						//当回零信号保持高电平大于指定时长，表明电机未回零，清除到位延时计数器
	.clock		(sys_clk		),
	.cnt_en		(!home_done	&& (delay_cnt < DELAY_1S)),	//当回零完成，到位信号为低电平，开始计数直到技术满50_000_000-1
	.cout			(delay_finish),									//计数值满后，计数值保持，溢出信号保持为高电平
	.q				(delay_cnt	)
);
/***************** 回原点到位后延时 *********************/

/***************** 电机位置设定 *****************/
//时序电路,set_pos
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		set_pos <= 16'd0;
	else
		set_pos <= set_pos_n;
end
//组合电路,set_pos_n
always @ (*)
begin
	if(wait_cnt >= DELAY_200MS)						//当电机上电后自动回零，回零未完成当前位置和设定位置都清零
		set_pos_n = 16'd0;				
	else if(!m_busy && delay_finish)					//回零成功后延时一秒再设定位置，此时电机回零并通过驱动器偏置后位于35°位置（作为驱动器的零点）
		set_pos_n = (rec_pos >> 5);					//XY2-100初始值在行程中间位置，即8000h，对应偏置后的45°位置			
	else														//XY2-100设定值对应-10°~+10°，即电机实际运转在35°~55°之间
		set_pos_n = set_pos;
end
/***************** 电机位置设定 *****************/

/******************* 位置差值 *******************/
//时序电路,aim_pos
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		aim_pos <= 16'b0;
	else
		aim_pos <= aim_pos_n;
end
//组合电路,aim_pos_n
always @ (*)
begin
	if (set_pos >= now_pos)
		aim_pos_n = set_pos - now_pos;
	else
		aim_pos_n = now_pos - set_pos;
end
/******************* 位置差值 *******************/

/******************* 电机使能 *******************/
//时序电路,m_en
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		m_en <= 1'b1;
	else
		m_en <= m_en_n;
end
//组合电路,m_en_n
always @ (*)
begin
	if(aim_pos != 16'd0)
		m_en_n = 1'b0;
	else
		m_en_n = m_en;
end
/******************* 电机使能 *******************/

/******************* 电机方向 *******************/
//时序电路,dir
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		dir <= 1'b1;										//默认初始方向为正方向
	else
		dir <= dir_n;
end
//组合电路,dir_n
always @ (*)
begin
	if(set_pos > now_pos)
		dir_n = 1'b1;
	else if(set_pos < now_pos)
		dir_n = 1'b0;
	else
		dir_n = dir;
end
/******************* 电机方向 *******************/

/****************** 电机状态切换 *****************/
parameter M_ST_IDLE = 2'b00;
parameter M_ST_PWM  = 2'b01;
parameter M_ST_DONE = 2'b10;

reg [1:0]	m_cur_state;
reg [1:0]	m_nex_state;
//时序电路，电机当前状态
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		m_cur_state <= M_ST_IDLE;
	else
		m_cur_state <= m_nex_state;
end
//组合电路，电机的下一个状态
always @ (*)
begin
	case(m_cur_state)
		M_ST_IDLE:
			if(aim_pos > 0 && !m_busy)
				m_nex_state = M_ST_PWM;
			else
				m_nex_state = m_cur_state;
		M_ST_PWM:
			if(pul_cnt == aim_pos)
				m_nex_state = M_ST_DONE;
			else
				m_nex_state = m_cur_state;
		M_ST_DONE:
			m_nex_state = M_ST_IDLE;
		default:
			m_nex_state = M_ST_IDLE;
	endcase
end
/****************** 电机状态切换 *****************/

/****************** 定时器 *****************/	
//时序电路,time_cnt
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		time_cnt <= 16'd0;
	else
		time_cnt <= time_cnt_n;
end
//组合电路,time_cnt_n
always @ (*)
begin
	if(m_cur_state != M_ST_PWM || time_cnt >= set_vel)
		time_cnt_n = 16'd0;
	else if(m_cur_state == M_ST_PWM)
		time_cnt_n = time_cnt + 16'b1;
	else
		time_cnt_n = time_cnt;
end
/****************** 定时器 *****************/	

/****************** 生成电机脉冲 *****************/	
//时序电路,pul
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		pul <= 1'b0;
	else
		pul <= pul_n;
end
//组合电路,pul_n
always @ (*)
begin
	if(time_cnt == set_vel)
		pul_n = 1'b0;
	else if(time_cnt == half_vel)
		pul_n = 1'b1;
	else
		pul_n = pul;
end
/****************** 生成电机脉冲 *****************/	

/****************** 脉冲计数 *****************/	
//时序电路,pul_cnt
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		pul_cnt <= 16'b0;
	else
		pul_cnt <= pul_cnt_n;
end
//组合电路,pul_cnt_n
always @ (*)
begin
	if(time_cnt == set_vel)
		pul_cnt_n = pul_cnt + 1'b1;
	else if(pul_cnt == aim_pos)
		pul_cnt_n = 16'b0;
	else
		pul_cnt_n = pul_cnt;
end	
/****************** 脉冲计数 *****************/	

/****************** 脉冲发完标志 *****************/	
//时序电路,finish_flag
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		finish_flag <= 1'b0;
	else
		finish_flag <= finish_flag_n;
end
//组合电路,finish_flag_n
always @ (*)
begin
	if(m_cur_state == M_ST_DONE)
		finish_flag_n = 1'b1;
	else
		finish_flag_n = 1'b0;
end
/****************** 脉冲发完标志 *****************/	

/****************** 更新当前位置 *****************/	
//时序电路,now_pos
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		now_pos <= 16'd0;
	else
		now_pos <= now_pos_n;
end
//组合电路,now_pos_n
always @ (*)
begin
	if(wait_cnt >= DELAY_200MS)									//当回原点没有完成时清除当前位置
		now_pos_n = 16'd0;											//将当前位置清零，保证回零后当前位置对应实际的起始位置
	else if(m_cur_state == M_ST_DONE)
		now_pos_n = set_pos;
	else
		now_pos_n = now_pos;
end
/****************** 更新当前位置 *****************/	

/****************** 电机忙状态 *****************/	
//时序电路,m_busy
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		m_busy <= 1'b0;
	else
		m_busy <= m_busy_n;
end
//组合电路,m_busy_n
always @ (*)
begin
	if(m_cur_state != M_ST_IDLE)
		m_busy_n = 1'b1;
	else if(finish_flag)
		m_busy_n = 1'b0;
	else
		m_busy_n = m_busy;
end
/****************** 电机忙状态 *****************/	

encoder enc_init(
	.sys_clk			(sys_clk		),
	.enc_nrst		(rst_n && delay_finish),
	
	.enc_a			(enc_a		),
	.enc_b			(enc_b		),
	.enc_z			(enc_z		),
	
	.enc_pos_r		(enc_pos		),
	.enc_vel_r		(enc_vel		)
);

endmodule	

