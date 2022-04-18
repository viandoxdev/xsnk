// This file is purely for debugging purposes
// (It is loaded as a symbol file by gdb in the make debug targets)
// (It adds the pos and draw_update structs type to avoid typing offsets manually)

struct s_draw_update {
	short x;
	short y;
	void* ascii;
	short ascii_len;
	short has_next;
} __attribute__((packed));
typedef struct s_draw_update s_draw_update;
struct s_pos {
	short x;
	short y;
} __attribute__((packed));
typedef struct s_pos s_pos;

union _all {
	s_draw_update a;
	s_pos b;
};

union _all _;
