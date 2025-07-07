set freq 300.0; # MHz
set period [expr {1.0/$freq * 1000}];   # ns
create_clock -name clk -period $period [get_ports clk]
