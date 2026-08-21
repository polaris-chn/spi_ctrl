TOP       = tb_ctrl_if
VCS       = vcs
VERDI     = verdi
FILELIST  = filelist.f
SIMV      = simv
FSDB      = tb.fsdb

.PHONY: all comp sim verdi clean

all: comp sim

comp:
	vcs -full64 -sverilog -kdb -q -debug_access+all \
	-timescale=1ns/1ps +define+DUMP_FSDB=1 \
	-LDFLAGS "-Wl,--no-as-needed" \
	-l comp.log \
	-f $(FILELIST) \
	-top $(TOP)
	@echo "***********************************************"
	@echo "Compile finished. Compile log: comp.log"
	@echo "***********************************************"

sim: $(SIMV)
	./$(SIMV) -l sim.log
	@echo "***********************************************"
	@echo "Simulation finished. Sim log: sim.log"
	@echo "FSDB: $(FSDB)"
	@echo "***********************************************"

verdi:
	verdi -ssf $(abspath $(FSDB)) &

clean:
	rm -rf $(SIMV) $(SIMV).daidir csrc *.fsdb *.log *.key *.vpd verdiLog novas.* ucli.key vc_hdrs.h
