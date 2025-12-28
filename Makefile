.PHONY: all examples clean test

all: examples

examples:
	./examples.sh

test:
	odin test munin

clean:
	rm -rf bin
