# Timing Constraints for Montgomery Multiplication
# Place this file in your project as constraints/timing_constraints.xdc

# Define primary clock constraint
# This sets the target frequency - Vivado will try to meet this timing
create_clock -period 10.0 -name sys_clk [get_ports clk]

# Alternative frequency examples:
# create_clock -period 5.0 -name sys_clk [get_ports clk]   # 200 MHz
# create_clock -period 8.0 -name sys_clk [get_ports clk]   # 125 MHz
# create_clock -period 20.0 -name sys_clk [get_ports clk]  # 50 MHz

# Set input/output delay constraints relative to clock
set_input_delay -clock sys_clk -max 2.0 [all_inputs]
set_input_delay -clock sys_clk -min 0.5 [all_inputs]
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
set_output_delay -clock sys_clk -min 0.5 [all_outputs]

# Exclude clock from input/output delay constraints
set_input_delay -clock sys_clk 0.0 [get_ports clk]
set_output_delay -clock sys_clk 0.0 [get_ports clk]

# Reset is asynchronous - no timing constraint needed
set_false_path -from [get_ports reset]

# Optional: Set maximum delay for combinational paths
# set_max_delay -from [all_inputs] -to [all_outputs] 10.0

# Optional: Multicycle paths if your design needs more than 1 cycle
# set_multicycle_path -setup 2 -from [get_cells source_reg] -to [get_cells dest_reg]