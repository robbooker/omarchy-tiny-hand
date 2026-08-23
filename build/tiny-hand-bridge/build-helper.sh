#!/bin/sh
set -eu

umask 022
source_file=/src/tiny-hand-bridge.c
output_file=/out/tiny-hand-bridge

test -f "$source_file"
test -d /out

echo "source:"
sha256sum "$source_file"
echo "toolchain:"
gcc --version | sed -n '1p'
ld --version | sed -n '1p'
strip --version | sed -n '1p'
echo "dependencies:"
dpkg-query -W -f='${Package}=${Version}\n' \
  gcc gcc-12 cpp-12 libgcc-12-dev libgcc-s1 libc6 libc6-dev linux-libc-dev \
  binutils binutils-common binutils-x86-64-linux-gnu | LC_ALL=C sort

gcc \
  -O2 \
  -std=c11 \
  -Wall -Wextra -Werror -Wpedantic -Wconversion -Wshadow -Wformat=2 \
  -Wdate-time -Wformat-security \
  -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
  -fPIE -fno-record-gcc-switches \
  -ffile-prefix-map=/src=. -fdebug-prefix-map=/src=. \
  -Wl,--as-needed -Wl,--build-id=none -Wl,-z,relro,-z,now -pie \
  -o /tmp/tiny-hand-bridge.unstripped \
  "$source_file"

strip --strip-unneeded --enable-deterministic-archives \
  /tmp/tiny-hand-bridge.unstripped
cp /tmp/tiny-hand-bridge.unstripped "$output_file"
chmod 0755 "$output_file"
