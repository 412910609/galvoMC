library verilog;
use verilog.vl_types.all;
entity top is
    port(
        sys_clk         : in     vl_logic;
        rst_n           : in     vl_logic;
        xy_clk          : in     vl_logic;
        xy_sync         : in     vl_logic;
        xy_x_data       : in     vl_logic;
        set_x_pos       : out    vl_logic_vector(15 downto 0);
        rec_x_pos       : out    vl_logic_vector(15 downto 0);
        xy_done_flag    : out    vl_logic;
        m_busy          : out    vl_logic;
        m_arrived       : out    vl_logic;
        m_en            : out    vl_logic;
        dir             : out    vl_logic;
        pul             : out    vl_logic
    );
end top;
