TOP       = tb_xm25q512f
VCS       = vcs
VERDI     = verdi
FILELIST  = filelist.f
SIMV      = simv
FSDB      = tb.fsdb

export VCS_HOME ?= /home/synopsys/vcs-mx/O-2018.09-SP2
export PATH     := $(VCS_HOME)/bin:$(PATH)

.PHONY: all comp sim verdi clean

all: comp sim

comp:
	$(VCS) -full64 -sverilog -kdb -q -debug_access+all \
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
	$(VERDI) -ssf $(abspath $(FSDB)) &

clean:
	rm -rf $(SIMV) $(SIMV).daidir csrc *.fsdb *.log *.key *.vpd verdiLog novas.* ucli.key vc_hdrs.h
