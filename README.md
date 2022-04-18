# xsnk - Snake, in x86\_64 assembly

> Linux only, no std

This is a simple snake game in the terminal, in about 750 lines of assembly.

## Building

Use the makefile, there is a build target.

## Running

either

```bash
make run
```

or build then

```bash
./xsnk
```

## Debugging

The debug targets are used to debug xsnk using gdb:

 - The `debug` target starts gdb and redirects output to `/dev/pts/3` (should be a terminal)
 - The `debug-server` and `debug-client` targets are meant to be used in two different terminal, one terminal with the server will display the application (and accept inputs, this is the whole reason these targets exists), and the client one will be for gdb control.

All these targets load the symbols from symbols.h, these are structs used for debugging in gdb they are prefixed by `s_`.

> Fun fact, I learned while making this project that instead of doing:
> ```assembly
> leaq symbol(%rip), %rax
> movq (%rax), %rax
> ```
> you could just do:
> ```asm
> movq symbol(%rip), %rax
> ```
> So some of the code is still using the top thing.
