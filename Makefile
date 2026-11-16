# Makefile - shortcuts for run_tests.py  (Owner: Kunal Dev Sahu)
# Windows users without make can call  python run_tests.py  directly.
PY ?= python3
PROG ?= fibonacci

.PHONY: all test unit programs run wave clean

all: test

test:                 ## unit tests + all programs
	$(PY) run_tests.py

unit:                 ## only module testbenches
	$(PY) run_tests.py --unit

programs:             ## only whole-CPU program tests
	$(PY) run_tests.py --programs

run:                  ## run one program:  make run PROG=bubble_sort
	$(PY) run_tests.py --run $(PROG)

wave:                 ## waveform for one program, opens GTKWave
	$(PY) run_tests.py --run $(PROG) --wave
	gtkwave build/$(PROG).vcd &

clean:
	rm -rf build
