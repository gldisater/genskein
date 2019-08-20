#
#----------------------------------------------------------------
# 64-bit x86 assembler code (gnu as) for Skein block functions
#
# Author: Doug Whiting, Hifn/Exar
#
# This code is released to the public domain.
#----------------------------------------------------------------
# $FreeBSD: head/sys/crypto/skein/amd64/skein_block_asm.s 333883 2018-05-19 18:27:14Z mmacy $
#
    .text
    .altmacro
#    .psize 0,128                            #list file has no page boundaries
#
_MASK_ALL_  =  (256+512+1024)               #all three algorithm bits
_MAX_FRAME_ =  240
#
#################
_USE_ASM_	  = SKEIN_USE_ASM
#################
_SKEIN_LOOP       =   SKEIN_LOOP                     #default is fully unrolled for 256/512, twice for 1024
# the unroll counts (0 --> fully unrolled)
SKEIN_ASM_UNROLL  = 0
#################
#
ROUNDS_256  =   72
ROUNDS_512  =   72
ROUNDS_1024 =   80
#################
#
.ifdef SKEIN_CODE_SIZE
_SKEIN_CODE_SIZE = (1)
.else
.ifdef  SKEIN_PERF                           #use code size if SKEIN_PERF is defined
_SKEIN_CODE_SIZE = (1)
.else
_SKEIN_CODE_SIZE = (0)
.endif
.endif
#
#################
#
# define offsets of fields in hash context structure
#
HASH_BITS   =   0                   #bits of hash output
BCNT        =   8 + HASH_BITS       #number of bytes in BUFFER[]
TWEAK       =   8 + BCNT            #tweak values[0..1]
X_VARS      =  16 + TWEAK           #chaining vars
#
#(Note: buffer[] in context structure is NOT needed here :-)
#
KW_PARITY   =   0x1BD11BDAA9FC1A22  #overall parity of key schedule words
FIRST_MASK  =   ~ (1 <<  6)
FIRST_MASK64=   ~ (1 << 62)
#
# rotation constants for Skein
#
RC_256_0_0  = 14
RC_256_0_1  = 16

RC_256_1_0  = 52
RC_256_1_1  = 57

RC_256_2_0  = 23
RC_256_2_1  = 40

RC_256_3_0  =  5
RC_256_3_1  = 37

RC_256_4_0  = 25
RC_256_4_1  = 33

RC_256_5_0  = 46
RC_256_5_1  = 12

RC_256_6_0  = 58
RC_256_6_1  = 22

RC_256_7_0  = 32
RC_256_7_1  = 32

RC_512_0_0  = 46
RC_512_0_1  = 36
RC_512_0_2  = 19
RC_512_0_3  = 37

RC_512_1_0  = 33
RC_512_1_1  = 27
RC_512_1_2  = 14
RC_512_1_3  = 42

RC_512_2_0  = 17
RC_512_2_1  = 49
RC_512_2_2  = 36
RC_512_2_3  = 39

RC_512_3_0  = 44
RC_512_3_1  =  9
RC_512_3_2  = 54
RC_512_3_3  = 56

RC_512_4_0  = 39
RC_512_4_1  = 30
RC_512_4_2  = 34
RC_512_4_3  = 24

RC_512_5_0  = 13
RC_512_5_1  = 50
RC_512_5_2  = 10
RC_512_5_3  = 17

RC_512_6_0  = 25
RC_512_6_1  = 29
RC_512_6_2  = 39
RC_512_6_3  = 43

RC_512_7_0  =  8
RC_512_7_1  = 35
RC_512_7_2  = 56
RC_512_7_3  = 22

RC_1024_0_0 = 24
RC_1024_0_1 = 13
RC_1024_0_2 =  8
RC_1024_0_3 = 47
RC_1024_0_4 =  8
RC_1024_0_5 = 17
RC_1024_0_6 = 22
RC_1024_0_7 = 37

RC_1024_1_0 = 38
RC_1024_1_1 = 19
RC_1024_1_2 = 10
RC_1024_1_3 = 55
RC_1024_1_4 = 49
RC_1024_1_5 = 18
RC_1024_1_6 = 23
RC_1024_1_7 = 52

RC_1024_2_0 = 33
RC_1024_2_1 =  4
RC_1024_2_2 = 51
RC_1024_2_3 = 13
RC_1024_2_4 = 34
RC_1024_2_5 = 41
RC_1024_2_6 = 59
RC_1024_2_7 = 17

RC_1024_3_0 =  5
RC_1024_3_1 = 20
RC_1024_3_2 = 48
RC_1024_3_3 = 41
RC_1024_3_4 = 47
RC_1024_3_5 = 28
RC_1024_3_6 = 16
RC_1024_3_7 = 25

RC_1024_4_0 = 41
RC_1024_4_1 =  9
RC_1024_4_2 = 37
RC_1024_4_3 = 31
RC_1024_4_4 = 12
RC_1024_4_5 = 47
RC_1024_4_6 = 44
RC_1024_4_7 = 30

RC_1024_5_0 = 16
RC_1024_5_1 = 34
RC_1024_5_2 = 56
RC_1024_5_3 = 51
RC_1024_5_4 =  4
RC_1024_5_5 = 53
RC_1024_5_6 = 42
RC_1024_5_7 = 41

RC_1024_6_0 = 31
RC_1024_6_1 = 44
RC_1024_6_2 = 47
RC_1024_6_3 = 46
RC_1024_6_4 = 19
RC_1024_6_5 = 42
RC_1024_6_6 = 44
RC_1024_6_7 = 25

RC_1024_7_0 =  9
RC_1024_7_1 = 48
RC_1024_7_2 = 35
RC_1024_7_3 = 52
RC_1024_7_4 = 23
RC_1024_7_5 = 31
RC_1024_7_6 = 37
RC_1024_7_7 = 20
#----------------------------------------------------------------
#
# MACROS: define local vars and configure stack
#
#----------------------------------------------------------------
# declare allocated space on the stack
.macro StackVar localName,localSize
\localName  =   _STK_OFFS_
_STK_OFFS_  =   _STK_OFFS_+(\localSize)
.endm #StackVar
#
#----------------------------------------------------------------
#
# MACRO: Configure stack frame, allocate local vars
#
.macro Setup_Stack BLK_BITS,KS_CNT,debugCnt
    WCNT    =    (\BLK_BITS)/64
#
_PushCnt_   =   0                   #save nonvolatile regs on stack
  .irp _reg_,rbp,rbx,r12,r13,r14,r15
       pushq    %\_reg_
_PushCnt_ = _PushCnt_ + 1           #track count to keep alignment
  .endr
#
_STK_OFFS_  =   0                   #starting offset from rsp
    #---- local  variables         #<-- rsp
    StackVar    X_stk  ,8*(WCNT)    #local context vars
    StackVar    ksTwk  ,8*3         #key schedule: tweak words
    StackVar    ksKey  ,8*(WCNT)+8  #key schedule: key   words
  .if (SKEIN_ASM_UNROLL && (\BLK_BITS)) == 0
    StackVar    ksRot ,16*(\KS_CNT) #leave space for "rotation" to happen
  .endif
    StackVar    Wcopy  ,8*(WCNT)    #copy of input block
  .if ((8*_PushCnt_ + _STK_OFFS_) % 8) == 0
    StackVar    align16,8           #keep 16-byte aligned (adjust for retAddr?)
tmpStk_\BLK_BITS = align16          #use this
  .endif
    #---- saved caller parameters (from regs rdi, rsi, rdx, rcx)
    StackVar    ctxPtr ,8           #context ptr
    StackVar    blkPtr ,8           #pointer to block data
    StackVar    blkCnt ,8           #number of full blocks to process
    StackVar    bitAdd ,8           #bit count to add to tweak
LOCAL_SIZE  =   _STK_OFFS_          #size of "local" vars
    #----
    StackVar    savRegs,8*_PushCnt_ #saved registers
    StackVar    retAddr,8           #return address
    #---- caller's stack frame (aligned mod 16)
#
# set up the stack frame pointer (rbp)
#
FRAME_OFFS  =   ksTwk + 128         #allow short (negative) offset to ksTwk, kwKey
  .if FRAME_OFFS > _STK_OFFS_       #keep rbp in the "locals" range
FRAME_OFFS  =      _STK_OFFS_
  .endif
F_O         =   -FRAME_OFFS
#
  #put some useful defines in the .lst file (for grep)
__STK_LCL_SIZE_\BLK_BITS = LOCAL_SIZE
__STK_TOT_SIZE_\BLK_BITS = _STK_OFFS_
__STK_FRM_OFFS_\BLK_BITS = FRAME_OFFS
#
# Notes on stack frame setup:
#   * the most frequently used variable is X_stk[], based at [rsp+0]
#   * the next most used is the key schedule arrays, ksKey and ksTwk
#       so rbp is "centered" there, allowing short offsets to the key
#       schedule even in 1024-bit Skein case
#   * the Wcopy variables are infrequently accessed, but they have long
#       offsets from both rsp and rbp only in the 1024-bit case.
#   * all other local vars and calling parameters can be accessed
#       with short offsets, except in the 1024-bit case
#
    subq    $LOCAL_SIZE,%rsp        #make room for the locals
    leaq    FRAME_OFFS(%rsp),%rbp   #maximize use of short offsets
    movq    %rdi, ctxPtr+F_O(%rbp)  #save caller's parameters on the stack
    movq    %rsi, blkPtr+F_O(%rbp)
    movq    %rdx, blkCnt+F_O(%rbp)
    movq    %rcx, bitAdd+F_O(%rbp)
#
.endm #Setup_Stack
#
#----------------------------------------------------------------
#
.macro Reset_Stack
    addq    $LOCAL_SIZE,%rsp        #get rid of locals (wipe)
  .irp _reg_,r15,r14,r13,r12,rbx,rbp
    popq    %\_reg_                 #restore caller's regs
_PushCnt_ = _PushCnt_ - 1
  .endr
  .if _PushCnt_
    .error  "Mismatched push/pops?"
  .endif
.endm # Reset_Stack
#
#----------------------------------------------------------------
#
.macro  addReg dstReg,srcReg_A,srcReg_B,useAddOp,immOffs
  .if \immOffs + 0
       leaq    \immOffs(%\srcReg_A\srcReg_B,%\dstReg),%\dstReg
  .elseif ((\useAddOp + 0) == 0)
    .ifndef ASM_NO_LEA  #lea seems to be faster on Core 2 Duo CPUs!
       leaq   (%\srcReg_A\srcReg_B,%\dstReg),%\dstReg
    .else
       addq    %\srcReg_A\srcReg_B,%\dstReg
    .endif
  .else
       addq    %\srcReg_A\srcReg_B,%\dstReg
  .endif
.endm

# keep Intel-style ordering here, to match addReg
.macro  xorReg dstReg,srcReg_A,srcReg_B
        xorq   %\srcReg_A\srcReg_B,%\dstReg
.endm

# SkeinMix
.macro skeinMix a,b,c
	addReg	\a,\b
	rolq	\c,%\b
	xorReg	\b,\a
.endm

#
#----------------------------------------------------------------
#
.macro C_label lName
 \lName:        #use both "genders" to work across linkage conventions
_\lName:
    .global  \lName
    .global _\lName
.endm
#
#=================================== Skein_256 =============================================
#
.if _USE_ASM_ & 256
#
# void Skein_256_Process_Block(Skein_256_Ctxt_t *ctx,const u08b_t *blkPtr,size_t blkCnt,size_t bitcntAdd)#
#
#################
#
# code
#
C_label Skein_256_Process_Block
    Setup_Stack 256,((ROUNDS_256/8)+1)
    movq    TWEAK+8(%rdi),%r14
    jmp     Skein_256_block_loop
    .p2align 4
    # main hash loop for Skein_256
Skein_256_block_loop:
    #
    # general register usage:
    #   RAX..RDX        = X0..X3
    #   R08..R12        = ks[0..4]
    #   R13..R15        = ts[0..2]
    #   RSP, RBP        = stack/frame pointers
    #   RDI             = round counter or context pointer
    #   RSI             = temp
    #
    movq    TWEAK+0(%rdi)     ,%r13
    addq    bitAdd+F_O(%rbp)  ,%r13  #computed updated tweak value T0
    movq    %r14              ,%r15
    xorq    %r13              ,%r15  #now %r13.%r15 is set as the tweak

    movq    $KW_PARITY        ,%r12
    movq       X_VARS+ 0(%rdi),%r8
    movq       X_VARS+ 8(%rdi),%r9
    movq       X_VARS+16(%rdi),%r10
    movq       X_VARS+24(%rdi),%r11
    movq    %r13,TWEAK+0(%rdi)       #save updated tweak value ctx->h.T[0]
    xorq    %r8               ,%r12  #start accumulating overall parity

    movq    blkPtr +F_O(%rbp) ,%rsi  #esi --> input block
    xorq    %r9               ,%r12
    movq     0(%rsi)          ,%rax  #get X[0..3]
    xorq    %r10              ,%r12
    movq     8(%rsi)          ,%rbx
    xorq    %r11              ,%r12
    movq    16(%rsi)          ,%rcx
    movq    24(%rsi)          ,%rdx

    movq    %rax,Wcopy+ 0+F_O(%rbp)  #save copy of input block
    movq    %rbx,Wcopy+ 8+F_O(%rbp)
    movq    %rcx,Wcopy+16+F_O(%rbp)
    movq    %rdx,Wcopy+24+F_O(%rbp)

    addq    %r8 ,%rax                #initial key injection
    addq    %r9 ,%rbx
    addq    %r10,%rcx
    addq    %r11,%rdx
    addq    %r13,%rbx
    addq    %r14,%rcx

    addq    $WCNT*8,%rsi             #skip the block
    movq    %rsi,blkPtr  +F_O(%rbp)  #update block pointer
    #
    # now the key schedule is computed. Start the rounds
    #
_UNROLL_CNT =   ROUNDS_256/8
