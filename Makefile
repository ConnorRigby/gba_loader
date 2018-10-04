ifeq ($(ERL_EI_INCLUDE_DIR),)
$(error ERL_EI_INCLUDE_DIR not set. Invoke via mix)
endif

ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR)

WIRINGPI_CFLAGS ?= -I$(PWD)/src/wifinwPi/wiringPi
WIRINGPI_LDFLAGS ?= -L$(HERE)/priv/ -lwiringPi
LDFLAGS ?=
CFLAGS ?=

all: wiringpi priv priv/gba_loader 
HERE = $(PWD)

priv:
	mkdir -p priv

priv/gba_loader: src/multiboot.c
	$(CC) $(WIRINGPI_CFLAGS) $(WIRINGPI_LDFLAGS) src/multiboot.c -o $@
	cp $(HERE)/priv/libwiringPi.so rootfs_overlay/usr/lib

wiringpi:
	cd src/wifinwPi/wiringPi && $(MAKE) && cp libwiringPi.so.2.46 $(HERE)/priv/libwiringPi.so

winingpi-clean:
	cd src/wifinwPi/wiringPi && $(MAKE) clean

clean: winingpi-clean
	$(RM) priv/gba_loader
	$(RM) priv/multiboot_mb.gba
