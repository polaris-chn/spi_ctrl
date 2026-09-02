set top ctrl_fsm

set stdcells_path /home/nnge/Projects/SMIC/smic_90bcd/ReMTP/Hynitron/libs

#set_app_var syhthetic_library dw_foundation.sldb

set_app_var target_library $stdcells_path/scc90nbcd_hd_rvt_ss_v1p35_125c_basic.db

set_app_var link_library [concat "*" $target_library]

#set link_library  " * $target_library"

set symbol_library {}

# 综合时某个触发器的Q没有接到下游逻辑（悬空），允许DC删掉它
set_app_var compile_delete_unloaded_sequential_cells true
# 层次边界先不动，内部的没有用到的FF仍然要优化掉
set_app_var compile_optimize_unloaded_seq_logic_with_no_bound_opt true
# 不打穿边界，同时内部的常量传播还是要优化
set_app_var compile_enable_constant_propagation_with_no_boundary_opt true
set_app_var compile_seqmap_propagate_constants true
set_app_var compile_seqmap_propagate_high_effort true
set_app_var hdlin_ff_always_sync_set_reset true
# 读rtl时，保留信号原来的名字，不要随便改名或合并中间网名
set_app_var hdlin_keep_signal_name all

# 读rtl时，若状态机/编码是one hot，但编码不完整或只覆盖部分状态，DC仍然按one hot去优化
# 因为one hot逻辑少，时序好
set hdlin_optimize_partial_one_hot_labels true

set_app_var hdlin_seqmap_sync_search_depth 20
# 映射寄存器时，不用输出带反相的FF来实现逻辑
set_app_var compile_seqmap_enable_output_inversion false
# 允许一个FF被分析为多个时钟相关
set_app_var timing_enable_multiple_clocks_per_reg true
# 子模块上没用到的层次端口，不要自动绑定数理/逻辑连接
set_app_var bind_unused_hierarchical_pins false
# 关掉跨层次的inverter优化，DC有时会把反相器挪过模块边界
set_app_var compile_disable_hierarchical_inverter_opt true
# compile_ultra时不要把DW部件打散，DC综合DW时可能会拆掉层次摊成一堆门，告诉DC不要这么做
set_app_var compile_ultra_ungroup_dw false
# 映射时序逻辑时，尽量把一串FF识别成移位寄存器，用库里的shift-register结构优化，面积更好
set_app_var compile_seqmap_identify_shift_register true
# 移位寄存器识别时，如果链路上还有同步控制逻辑，就不要强行按照shift-register来优化
# 即只认干净的移位链；带同步控制的链，保守处理，不强行优化
set_app_var compile_seqmap_identify_shift_register_with_synchronous_logic false

# 同一模块多次例化时，给每份拷贝起不同名字，即“顶层_原名_编号”
set uniquify_naming_style "${top}_%s_%d"
# DC自带命令，即端口名和连到这个端口的线名尽量一样，方便后续读网表、对波形、做LEC
define_name_rules port_name_rules -equal_ports_nets

# DC读rtl时，中间结果存进这个库，定义一个work的design lib，物理目录是当前目录下的./work
define_design_lib work -path "./work"
# 关掉报告输出的分页模式
set enable_page_mode false
# 读rtl时，检查设计里面有没有推断出latch，如果有，就报出来
set hdlin_check_no_latch "true"
# 读rtl时，把嵌套的条件语句尽量合并后再做后续处理
set hdlin_merge_nested_conditional_statements "true"

# 把DC的当前工作设计成顶层模块ctrl_fsm，后面的link，uniquify，compile_ultra等都是作用在这个design上 
current_design $top
# 按link_library, 把设计里例化的子模块、标准单元、宏对上号，连起来
link
# 同一个模块被例化多次时，给每份拷贝起不同模块名，变成独立副本
uniquify
# 对当前设计做一次全面检查，悬空网，未连接端口，多驱动，缺引用，异常结构等，并打印警告/错误
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