ASFLAGS=-g
LDFLAGS=--nostd
BIN=xsnk
OBJECTS:=$(patsubst %.s,%.o,$(wildcard *.s))

run: all
	./$(BIN)

build: $(BIN)
all: $(BIN)

%.o: %.s
	as $(ASFLAGS) $< -o $@
$(BIN): $(OBJECTS)
	ld $^ $(LDFLAGS) -o $@

clean:
	rm *.o
	rm $(BIN)

.PHONY: clean build all run
