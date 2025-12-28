.PHONY: all examples clean

all: examples

examples:
	./examples.sh

clean:
	rm -rf bin
