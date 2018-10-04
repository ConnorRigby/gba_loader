# ifeq ($(ERL_EI_INCLUDE_DIR),)
# $(error ERL_EI_INCLUDE_DIR not set. Invoke via mix)
# endif

# ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
# ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR)

LDFLAGS ?=
CFLAGS ?=

all: priv priv/gba_loader 
HERE = $(PWD)

priv:
	mkdir -p priv

priv/gba_loader: src/multiboot.c
	$(CC) src/multiboot.c -o $@

clean:
	$(RM) priv/gba_loader
