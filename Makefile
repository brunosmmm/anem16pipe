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

GHDL      ?= ghdl
GHDL_FLAGS = --std=08 --ieee=synopsys
WORK_DIR   = work
ASM        = python3 assembler/assembler.py

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
	tests/tb_hazard.vhd

ALL_SRCS = $(SRCS_L0) $(SRCS_L1) $(SRCS_L2) $(TB_SRCS)

# Test programs
TEST_PROGS = tests/test_basic tests/test_branch tests/test_hazard

.PHONY: all analyze sim wave clean assemble test

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
test: test_basic test_branch test_hazard
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

# Clean build artifacts
clean:
	rm -rf $(WORK_DIR)
	rm -f tests/*.bin tests/*.clean tests/*.ind tests/*.contents.txt
	@echo "=== Cleaned ==="
