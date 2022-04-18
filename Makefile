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
symbols.o: symbols.h
	cc -x c -g -c $< -o $@
debug: symbols.o all
	# can't use gdb -s as it is bugged
	gdb \
		--ex 'tty /dev/pts/3' \
		--ex 'set confirm no' \
		--ex 'add-symbol-file symbols.o' \
		--ex 'set confirm yes' \
		$(BIN)

debug-server: symbols.o all
	gdbserver localhost:8664 $(BIN)
debug-client: symbols.o all
	gdb \
		--ex 'target remote localhost:8664' \
		--ex 'set confirm no' \
		--ex 'add-symbol-file symbols.o' \
		--ex 'set confirm yes' \
	$(BIN)

clean:
	rm *.o
	rm $(BIN)

.PHONY: clean build all run
