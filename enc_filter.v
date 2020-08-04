module enc_filter
(
	input sys_clk,
	
	input filter_nrst,
	input filter_en,
	input enc_a_in,
	input enc_b_in,
	input enc_z_in,
	
	output reg enc_a_out_r = 1'b0,
	output reg enc_b_out_r = 1'b0,
	output reg enc_z_out_r = 1'b0
);

reg[2:0] enc_a_r = 3'd0;
reg[2:0] enc_b_r = 3'd0;
reg[2:0] enc_z_r = 3'd0;

task initData;
	begin
		enc_a_r <= 3'b0;
		enc_b_r <= 3'b0;
		enc_z_r <= 3'b0;		
	end
endtask

always@(posedge sys_clk or negedge filter_nrst)
	begin
		if (!filter_nrst)
			begin
				initData;
			end
		else
			begin
				if (!filter_en)
					begin
						enc_a_out_r <= enc_a_in;
						enc_b_out_r <= enc_b_in;
						enc_z_out_r <= enc_z_in;
					end
				else
					begin
						enc_a_r <= {enc_a_r[1:0],enc_a_in};
						enc_b_r <= {enc_b_r[1:0],enc_b_in};
						enc_z_r <= {enc_z_r[1:0],enc_z_in};
						case (enc_a_r)
							3'b000:	enc_a_out_r <= 1'd0;
							3'b001:	enc_a_out_r <= 1'd0;
							3'b010:	enc_a_out_r <= 1'd0;
							3'b100:	enc_a_out_r <= 1'd0;
							default:	enc_a_out_r <= 1'd1;
						endcase
						
						case (enc_b_r)
							3'b000:	enc_b_out_r <= 1'd0;
							3'b001:	enc_b_out_r <= 1'd0;
							3'b010:	enc_b_out_r <= 1'd0;
							3'b100:	enc_b_out_r <= 1'd0;
							default:	enc_b_out_r <= 1'd1;
						endcase
						
						case (enc_z_r)
							3'b000:	enc_z_out_r <= 1'd0;
							3'b001:	enc_z_out_r <= 1'd0;
							3'b010:	enc_z_out_r <= 1'd0;
							3'b100:	enc_z_out_r <= 1'd0;
							default:	enc_z_out_r <= 1'd1;
						endcase
					end
			end
	end
	
endmodule	