.PHONY: all examples games clean test check

ODIN_OPT ?= -o:speed

all: examples

examples:
	./examples.sh

games:
	mkdir -p bin
	odin build games/2048 $(ODIN_OPT) -out:bin/2048

test:
	odin test munin
	odin test munin/components

check: test examples games

clean:
	rm -rf bin
