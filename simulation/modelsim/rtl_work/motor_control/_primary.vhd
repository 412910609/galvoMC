library verilog;
use verilog.vl_types.all;
entity motor_control is
    generic(
        M_ST_IDLE       : vl_logic_vector(0 to 1) := (Hi0, Hi0);
        M_ST_PWM        : vl_logic_vector(0 to 1) := (Hi0, Hi1);
        M_ST_DONE       : vl_logic_vector(0 to 1) := (Hi1, Hi0)
    );
    port(
        sys_clk         : in     vl_logic;
        rst_n           : in     vl_logic;
        set_pos         : in     vl_logic_vector(15 downto 0);
        set_vel         : in     vl_logic_vector(15 downto 0);
        m_busy          : out    vl_logic;
        finish_flag     : out    vl_logic;
        dir             : out    vl_logic;
        pul             : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of M_ST_IDLE : constant is 1;
    attribute mti_svvh_generic_type of M_ST_PWM : constant is 1;
    attribute mti_svvh_generic_type of M_ST_DONE : constant is 1;
end motor_control;
