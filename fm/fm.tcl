set_mismatch_message_filter -warn FMR_ELAB‑147
report_mismatch_message_filters

set_app_var verification_verify_unread_tech_cell_pins true
set_app_var verification_clock_gate_edge_analysis true
set_app_var verification_set_undriven_signals binary:X
set_app_var synopsys_auto_setup_filter {clock_gating verification_set_undriven_signals}
set_app_var synopsys_auto_setup true

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
