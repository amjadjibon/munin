.PHONY: all examples games clean test e2e check

ODIN_OPT ?= -o:speed
PYTHON ?= python3

all: examples

examples:
	./examples.sh

games:
	mkdir -p bin
	odin build games/2048 $(ODIN_OPT) -out:bin/2048

test:
	odin test munin
	odin test munin/components

# End-to-end tests drive the built example binaries on a real pty.
# Filter with: make e2e E2E=mouse
e2e: examples
	$(PYTHON) tests/e2e/test_examples.py $(E2E)

check: test examples games e2e

clean:
	rm -rf bin
	rm -rf tests/e2e/__pycache__
