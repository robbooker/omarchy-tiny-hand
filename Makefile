CC ?= cc
CFLAGS ?= -O2 -pipe -std=c11 -fstack-protector-strong -fPIE -fno-record-gcc-switches
WARNINGS := -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2
CPPFLAGS := -D_FORTIFY_SOURCE=3
LDFLAGS ?= -Wl,--as-needed,--build-id=none,-z,relro,-z,now -pie

.PHONY: all build check validate verify-bridge release-build install clean

all: build

build: bin/tiny-hand-bridge

bin/tiny-hand-bridge: src/tiny-hand-bridge.c
	@mkdir -p bin
	$(CC) $(CPPFLAGS) $(CFLAGS) $(WARNINGS) $< -o $@ $(LDFLAGS)

validate:
	omarchy plugin validate .

check: validate
	test -x bin/tiny-hand-bridge
	./tests/test_bridge.sh
	./tests/test_plugin.sh
	qmllint Service.qml BarWidget.qml Panel.qml PointerArt.qml

verify-bridge:
	./scripts/verify-bridge.sh

release-build:
	./scripts/build-bridge.sh bin

install: check
	./scripts/install.sh

clean:
	rm -f -- bin/tiny-hand-bridge
