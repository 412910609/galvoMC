library verilog;
use verilog.vl_types.all;
entity XY2_100 is
    generic(
        IDLE            : vl_logic_vector(0 to 1) := (Hi0, Hi0);
        READ            : vl_logic_vector(0 to 1) := (Hi0, Hi1);
        \END\           : vl_logic_vector(0 to 1) := (Hi1, Hi1)
    );
    port(
        sys_clk         : in     vl_logic;
        rst_n           : in     vl_logic;
        xy_clk          : in     vl_logic;
        xy_sync         : in     vl_logic;
        xy_x_data       : in     vl_logic;
        finish_flag     : out    vl_logic;
        out_x_data      : out    vl_logic_vector(15 downto 0)
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of IDLE : constant is 1;
    attribute mti_svvh_generic_type of READ : constant is 1;
    attribute mti_svvh_generic_type of \END\ : constant is 1;
end XY2_100;
