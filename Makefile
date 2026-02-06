# Makefile for ANEM16pipe GHDL simulation
# Usage:
#   make analyze    - Compile all VHDL files
#   make sim        - Run basic test simulation (backward compat)
#   make test       - Run all tests
#   make test_basic - Run basic instruction tests
#   make test_branch - Run branch tests
#   make test_hazard - Run hazard/forwarding tests
#   make wave       - Run simulation with waveform dump
#   make clean      - Clean build artifacts
#   make assemble   - Assemble test programs
#   make trace_basic - Generate trace for test_basic (golden model comparison)
#   make trace PROG=test_basic - Generate trace for any assembled program
#   make compare    - Compare GHDL vs simulator traces for all tests
#   make compare_basic - Compare traces for a single test

GHDL      ?= ghdl
GHDL_FLAGS = --std=08 --ieee=synopsys
WORK_DIR   = work
ASM        = python3 assembler/assembler.py
SIM        ?= ../anem16sim/builddir/sim

# VHDL source files in dependency order
# Level 0: No dependencies (leaf entities)
SRCS_L0 = \
	ANEM/instrset.vhd \
	ANEM/register.vhd \
	ANEM/registerByte.vhd \
	regbnk/bregister.vhd \
	alu/sum.vhd \
	alu/complement.vhd \
	alu/move.vhd \
	memory/progmem.vhd \
	memory/datamem.vhd \
	mac/mult.vhd \
	mac/accumulate.vhd

# Level 1: Depends on Level 0
SRCS_L1 = \
	alu/alu.vhd \
	regbnk/regbnk.vhd \
	control/ifetch.vhd \
	control/idecode.vhd \
	control/hazunit.vhd \
	control/fwunit.vhd \
	mac/mac.vhd

# Level 2: Depends on Level 1 (top-level)
SRCS_L2 = \
	ANEM/ANEM.vhd

# Test benches
TB_SRCS = \
	tests/tb_basic.vhd \
	tests/tb_branch.vhd \
	tests/tb_hazard.vhd \
	tests/tb_stack.vhd \
	tests/tb_trace.vhd

ALL_SRCS = $(SRCS_L0) $(SRCS_L1) $(SRCS_L2) $(TB_SRCS)

# Test programs
TEST_PROGS = tests/test_basic tests/test_branch tests/test_hazard tests/test_stack

.PHONY: all analyze sim wave clean assemble test trace compare

all: analyze

# Create work directory and analyze all sources
analyze: $(WORK_DIR)
	@echo "=== Analyzing VHDL sources ==="
	cd $(WORK_DIR) && for f in $(SRCS_L0); do \
		echo "  [L0] $$f"; \
		$(GHDL) -a $(GHDL_FLAGS) --workdir=. ../$$f || exit 1; \
	done
	cd $(WORK_DIR) && for f in $(SRCS_L1); do \
		echo "  [L1] $$f"; \
		$(GHDL) -a $(GHDL_FLAGS) --workdir=. ../$$f || exit 1; \
	done
	cd $(WORK_DIR) && for f in $(SRCS_L2); do \
		echo "  [L2] $$f"; \
		$(GHDL) -a $(GHDL_FLAGS) --workdir=. ../$$f || exit 1; \
	done
	cd $(WORK_DIR) && for f in $(TB_SRCS); do \
		echo "  [TB] $$f"; \
		$(GHDL) -a $(GHDL_FLAGS) --workdir=. ../$$f || exit 1; \
	done
	@echo "=== Analysis complete ==="

$(WORK_DIR):
	mkdir -p $(WORK_DIR)

# Assemble test programs
assemble:
	@echo "=== Assembling test programs ==="
	@for prog in $(TEST_PROGS); do \
		echo "  Assembling $$prog.asm"; \
		cd $$(dirname $$prog) && python3 ../assembler/assembler.py $$(basename $$prog) && cd ..; \
	done
	@echo "=== Assembly complete ==="

# Pattern rule: run a single test
test_%: analyze assemble
	@echo "=== Running test: tb_$* ==="
	cp tests/test_$*.contents.txt $(WORK_DIR)/contents.txt
	cd $(WORK_DIR) && $(GHDL) -e $(GHDL_FLAGS) --workdir=. tb_$*
	cd $(WORK_DIR) && $(GHDL) -r $(GHDL_FLAGS) --workdir=. tb_$* \
		--stop-time=50us 2>&1 | tee sim_$*_output.txt
	@echo "=== Test tb_$* complete ==="

# Run all tests
test: test_basic test_branch test_hazard test_stack
	@echo "=== ALL TEST SUITES COMPLETE ==="

# Backward compatibility: make sim = make test_basic
sim: test_basic

# Run simulation with VCD waveform dump
wave: analyze assemble
	@echo "=== Running simulation with waveform dump ==="
	cp tests/test_basic.contents.txt $(WORK_DIR)/contents.txt
	cd $(WORK_DIR) && $(GHDL) -e $(GHDL_FLAGS) --workdir=. tb_basic
	cd $(WORK_DIR) && $(GHDL) -r $(GHDL_FLAGS) --workdir=. tb_basic \
		--stop-time=50us --vcd=waveform.vcd 2>&1 | tee sim_output.txt
	@echo "=== Waveform saved to $(WORK_DIR)/waveform.vcd ==="

# Pattern rule: generate trace for golden model comparison
# Usage: make trace_basic, make trace_branch, etc.
# Or: make trace PROG=test_basic (for external .asm files)
trace_%: analyze assemble
	@echo "=== Generating trace: test_$* ==="
	cp tests/test_$*.contents.txt $(WORK_DIR)/contents.txt
	cd $(WORK_DIR) && $(GHDL) -e $(GHDL_FLAGS) --workdir=. tb_trace
	cd $(WORK_DIR) && $(GHDL) -r $(GHDL_FLAGS) --workdir=. tb_trace \
		-gTRACE_FILE=test_$*.trace --stop-time=100us 2>&1 | tee trace_$*_output.txt
	@echo "=== Trace written to $(WORK_DIR)/test_$*.trace ==="

# Generate trace for an arbitrary program (set PROG=name, must have tests/name.contents.txt)
trace: analyze
	@test -n "$(PROG)" || (echo "Usage: make trace PROG=test_name" && exit 1)
	cp tests/$(PROG).contents.txt $(WORK_DIR)/contents.txt
	cd $(WORK_DIR) && $(GHDL) -e $(GHDL_FLAGS) --workdir=. tb_trace
	cd $(WORK_DIR) && $(GHDL) -r $(GHDL_FLAGS) --workdir=. tb_trace \
		-gTRACE_FILE=$(PROG).trace --stop-time=100us 2>&1 | tee trace_output.txt
	@echo "=== Trace written to $(WORK_DIR)/$(PROG).trace ==="

# Pattern rule: compare GHDL vs simulator traces for a single test
# Generates both traces, filters to MW+END lines, diffs them
compare_%: trace_%
	@echo "=== Comparing traces: test_$* ==="
	$(SIM) -T $(WORK_DIR)/test_$*.sim.trace tests/test_$*.contents.txt > /dev/null 2>&1
	@grep '^MW\|^END' $(WORK_DIR)/test_$*.trace > $(WORK_DIR)/test_$*.ghdl.filtered
	@grep '^MW\|^END' $(WORK_DIR)/test_$*.sim.trace > $(WORK_DIR)/test_$*.sim.filtered
	@if diff -u $(WORK_DIR)/test_$*.ghdl.filtered $(WORK_DIR)/test_$*.sim.filtered > $(WORK_DIR)/test_$*.diff 2>&1; then \
		echo "  PASS test_$*: traces match (MW+END)"; \
	else \
		echo "  FAIL test_$*: traces differ"; \
		cat $(WORK_DIR)/test_$*.diff; \
	fi

# Compare all test programs
compare: compare_basic compare_branch compare_hazard compare_stack
	@echo "=== ALL TRACE COMPARISONS COMPLETE ==="

# Clean build artifacts
clean:
	rm -rf $(WORK_DIR)
	rm -f tests/*.bin tests/*.clean tests/*.ind tests/*.contents.txt
	@echo "=== Cleaned ==="
