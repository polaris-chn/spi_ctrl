# synopsys fomality的脚本，做rtl和综合后网表的形式化等价性验证，确认DC综合没有改功能

# formality专用命令，用来控制某类mismatch相关消息怎么显示，把消息FMR_ELAB-147级别设置成warn，而不是更严重的error
set_mismatch_message_filter -warn FMR_ELAB‑147
# 列出当前设了哪些这类filter，方便确认
report_mismatch_message_filters

# 下面都是formality验证相关app var,规定怎么比，怎么处理特殊情况
set_app_var verification_verify_unread_tech_cell_pins true
set_app_var verification_clock_gate_edge_analysis true
set_app_var verification_set_undriven_signals binary:X
set_app_var synopsys_auto_setup_filter {clock_gating verification_set_undriven_signals}
set_app_var synopsys_auto_setup true

# 告诉formality去读这份svf，svf是DC综合时记下的变换日志：改名，优化，常量传播，插ICG，结构变形等
# formality用它知道RTL是怎么一步步变成网表的，可以更好对齐比较点
set_svf ../dc/output/ctrl_fsm.svf

read_db /home/nnge/Projects/SMIC/smic_90bcd/ReMTP/Hynitron/libs/scc90nbcd_hd_rvt_ss_v1p35_125c_basic.db

read_verilog -r ../rtl/ctrl_fsm.v
set_top ctrl_fsm

read_verilog -i ../dc/output/ctrl_fsm.synthesis.v
set_top ctrl_fsm

match

report_svf_operation -status rejected -message

verify

report_unmatched_points
report_failing_points
report_unverified_points
report_aborted_points
report_not_compared_points

exit
