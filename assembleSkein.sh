#!/bin/sh -x

rm a.out
cc -DSKEIN256 genskein.c
./a.out > skein256.txt

rm a.out
cc -DSKEIN512 genskein.c
./a.out > skein512.txt

rm a.out
cc -DSKEIN1024 genskein.c
./a.out > skein1024.txt

rm skein_block_asm.S
cat skein1.asm > skein_block_asm.S 
cat skein256.txt  >> skein_block_asm.S
cat skein2.asm   >> skein_block_asm.S
cat skein512.txt  >> skein_block_asm.S
cat skein3.asm   >> skein_block_asm.S
cat skein1024.txt  >> skein_block_asm.S
cat skein4.asm   >> skein_block_asm.S

cc -integrated-as -c skein_block_asm.S -DSKEIN_USE_ASM=1792 -o skein_block_asm.o

# cp skein_block_asm.S /usr/src/sys/crypto/skein/amd64/skein_block_asm.S
