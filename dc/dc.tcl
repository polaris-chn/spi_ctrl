set top ctrl_fsm

set stdcells_path /home/nnge/Projects/SMIC/smic_90bcd/ReMTP/Hynitron/libs

#set_app_var syhthetic_library dw_foundation.sldb

set_app_var target_library $stdcells_path/scc90nbcd_hd_rvt_ss_v1p35_125c_basic.db

set_app_var link_library [concat "*" $target_library]

#set link_library  " * $target_library"

set symbol_library {}

set_app_var compile_delete_unloaded_sequential_cells true
set_app_var compile_optimize_unloaded_seq_logic_with_no_bound_opt true
set_app_var compile_enable_constant_propagation_with_no_boundary_opt true
set_app_var compile_seqmap_propagate_constants true
set_app_var compile_seqmap_propagate_high_effort true
set_app_var hdlin_ff_always_sync_set_reset true
set_app_var hdlin_keep_signal_name all

set hdlin_optimize_partial_one_hot_labels true

set_app_var hdlin_seqmap_sync_search_depth 20
set_app_var compile_seqmap_enable_output_inversion false
set_app_var timing_enable_multiple_clocks_per_reg true
set_app_var bind_unused_hierarchical_pins false
set_app_var compile_disable_hierarchical_inverter_opt true
set_app_var compile_ultra_ungroup_dw false
set_app_var compile_seqmap_identify_shift_register true
set_app_var compile_seqmap_identify_shift_register_with_synchronous_logic false

set uniquify_naming_style "${top}_%s_%d"
define_name_rules port_name_rules -equal_ports_nets

define_design_lib work -path "./work"
set enable_page_mode false
set hdlin_check_no_latch "true"
set hdlin_merge_nested_conditional_statements "true"


current_design $top
link
uniquify

check_design

#need_modify
set_drive 0.0002 [all_inputs]
set_input_transition -max 0.25 [all_inputs]

set_load 0.2 [all_outputs]
set_max_fanout 32 [current_design]
#*****************************************************************************

#25M overconstrained 25%
set clk_period 30
set unc_perc 0.2

set clk_name CLK
#set_operating_conditions "typical"

#set_app_var auto_wire_load_selection false
#set_wire_load_mode enclosed
set_drive 0 {CLK}

#set_driving_cell -cell BUFV0 -pin I [all_inputs]
set_driving_cell -lib_cell BUFV2_7TR [all_inputs] -no_design_rule

create_clock -name $clk_name -period $clk_period [get_ports $clk_name]
set_clock_uncertainty -setup [expr $clk_period*$unc_perc] [get_clocks $clk_name]
set_clock_uncertainty -hold [expr $clk_period*$unc_perc] [get_clocks $clk_name]


set_max_transition 0.25 [current_design]
set_input_delay [expr $clk_period*0.75] -clock $clk_name [all_inputs]
set_output_delay [expr $clk_period*0.75] -clock $clk_name [all_outputs]

#set_operation_condition -max WORST -max_library

#set_max_leakage_power 0

set_max_area 0

#set dont use instance

set_dont_use [get_lib_cells {*/CLK* */V0* */PULL*}]
set_dont_touch_network [get_ports $clk_name]

#Input driving cell models
set_operating_conditions ss_v1p35_125c


set_fix_multiple_port_nets -feedthroughs
set_fix_multiple_port_nets -all -buffer_constants

compile_ultra -no_autoungroup -gate_clock

check_design
report_reference -nosplit -hierarchy > ../rep/${top}.reference
report_qor > ../rep/${top}.qor

report_constraint -all_violators > ../rep/all_viosl.rpts
report_area > ../rep/area.rpts

report_power > ../rep/power.rpts
check_design > ../rep/design_check.rpts

set_svf -off
change_name -rules verilog -hierarchy

write -format ddc -hierarchy -output ../output/${top}.synthesis.ddc
write -format verilog -hierarchy -output ../output/${top}.synthesis.v

write_sdf ../output/${top}.synthesis.sdf
write_sdc ../output/${top}.synthesis.sdc


exit