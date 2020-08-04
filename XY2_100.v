module XY2_100
(
	input 			sys_clk,
	input 			rst_n,
	
	input 			xy_clk,
	input 			xy_sync,
	input 			xy_x_data,
	input 			xy_y_data,
	
	output reg			finish_flag,
	output reg [15:0]	out_x_data,
	output reg [15:0]	out_y_data
);

parameter IDLE = 	2'b00;
parameter READ =	2'b01;
parameter END  =	2'b11;

reg	[ 1:0]	state_current;
reg	[ 1:0]	state_next;
reg 	[ 1:0]	det_sync_edge;
wire	[ 1:0]	det_sync_edge_n;
reg				sync_posedge_reg;
wire				sync_posedge_reg_n;
reg 	[ 1:0]	det_clk_edge;
wire	[ 1:0]	det_clk_edge_n;
reg				clk_negedge_reg;
wire				clk_negedge_reg_n;
reg	[ 4:0] 	bit_cnt;
reg	[ 4:0] 	bit_cnt_n;
reg	[19:0]	shift_x_data;
reg	[19:0]	shift_x_data_n;
//reg	[15:0]	out_x_data;
reg	[15:0]	out_x_data_n;
reg	[19:0]	shift_y_data;
reg	[19:0]	shift_y_data_n;
//reg	[15:0]	out_y_data;
reg	[15:0]	out_y_data_n;
//reg				finish_flag;
reg				finish_flag_n;

/******************* 检测 XY_SYNC 信号的上升沿 *******************/
//时序电路,det_sync_edge
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		det_sync_edge <= 2'b00;
	else
		det_sync_edge <= det_sync_edge_n;
end
//组合电路
assign det_sync_edge_n = {det_sync_edge[0], xy_sync};

//时序电路,sync_posedge_reg
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		sync_posedge_reg <= 1'b0;
	else
		sync_posedge_reg <= sync_posedge_reg_n;
end
//组合电路
assign sync_posedge_reg_n = (det_sync_edge == 2'b01) ? 1'b1 : 1'b0;
/******************* 检测 XY_SYNC 信号的上升沿 *******************/

/******************* 检测 XY_CLK 信号的下降沿 *******************/
//时序电路,det_clk_edge
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		det_clk_edge <= 2'b00;
	else
		det_clk_edge <= det_clk_edge_n;
end
//组合电路
assign det_clk_edge_n = {det_clk_edge[0], xy_clk};

//时序电路,clk_negedge_reg
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		clk_negedge_reg <= 1'b0;
	else
		clk_negedge_reg <= clk_negedge_reg_n;
end
//组合电路
assign clk_negedge_reg_n = (det_clk_edge == 2'b10) ? 1'b1 : 1'b0;
/******************* 检测 XY_CLK 信号的下降沿 *******************/

/******************* 实现XY2-100协议解析的状态机 *******************/
//时序电路，用来给 state_current 寄存器赋值
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		state_current <= IDLE;
	else
		state_current <= state_next;
end

//组合电路，用来实现状态机
always @ (*)
begin
	case(state_current)
		IDLE:
			if(sync_posedge_reg)
				state_next = READ;
			else
				state_next = state_current;
		READ:
			if(bit_cnt == 5'd20)
				state_next = END;
			else 
				state_next = state_current;
		END:
			if(finish_flag)
				state_next = IDLE;
			else
				state_next = state_current;
		default:
			state_next = IDLE;
	endcase
end
/******************* 实现XY2-100协议解析的状态机 *******************/

//时序电路,bit_cnt
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		bit_cnt <= 5'b0;
	else
		bit_cnt <= bit_cnt_n;
end

//组合电路,bit_cnt_n
always @ (*)
begin
	if(bit_cnt >= 5'd20 || state_current != READ)
		bit_cnt_n = 5'd0;
	else if(state_current == READ && clk_negedge_reg)
		bit_cnt_n = bit_cnt + 5'b1;
	else 
		bit_cnt_n = bit_cnt;
end

/****************** 获取 X 轴位置数据 **************/
//时序电路,shift_x_data
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		shift_x_data <= 20'b0;
	else
		shift_x_data <= shift_x_data_n;
end
//组合电路,shift_x_data_n
always @ (*)
begin
	if(state_current == READ && clk_negedge_reg)
		shift_x_data_n = {shift_x_data[18:0], xy_x_data};
	else 
		shift_x_data_n = shift_x_data;
end

//时序电路,out_x_data
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		out_x_data <= 16'h8000;
	else
		out_x_data <= out_x_data_n;
end
//组合电路,out_x_data_n
always @ (*)
begin
	if(bit_cnt == 5'd20)
		out_x_data_n = shift_x_data[16:1];
	else 
		out_x_data_n = out_x_data;
end
/****************** 获取 X 轴位置数据 **************/

/****************** 获取 Y 轴位置数据 **************/
//时序电路,shift_y_data
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		shift_y_data <= 20'b0;
	else
		shift_y_data <= shift_y_data_n;
end
//组合电路,shift_y_data_n
always @ (*)
begin
	if(state_current == READ && clk_negedge_reg)
		shift_y_data_n = {shift_y_data[18:0], xy_y_data};
	else 
		shift_y_data_n = shift_y_data;
end

//时序电路,out_y_data
always @ (posedge sys_clk or negedge rst_n)
begin
	if(!rst_n)
		out_y_data <= 16'h8000;
	else
		out_y_data <= out_y_data_n;
end
//组合电路,out_y_data_n
always @ (*)
begin
	if(bit_cnt == 5'd20)
		out_y_data_n = shift_y_data[16:1];
	else 
		out_y_data_n = out_y_data;
end
/****************** 获取 Y 轴位置数据 **************/

/****************** XY2-100一帧数据传输完成标志 **************/
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
	if(bit_cnt == 5'd20)
		finish_flag_n = 1'b1;
	else 
		finish_flag_n = 1'b0;
end
/****************** XY2-100一帧数据传输完成标志 **************/

endmodule

