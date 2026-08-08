set WRITE_CLK_PERIOD 10.0
set READ_CLK_PERIOD 8.0

create_clock -name write_clk -period $WRITE_CLK_PERIOD [get_ports write_clk]
create_clock -name read_clk  -period $READ_CLK_PERIOD [get_ports read_clk]

set_clock_groups \
    -asynchronous \
    -group [get_clocks write_clk] \
    -group [get_clocks read_clk]

