
#
    movq    ctxPtr +F_O(%rbp),%rdi           #restore rdi --> context

    #----------------------------
    # feedforward:   ctx->X[i] = X[i] ^ w[i], {i=0..3}
    movq    $FIRST_MASK64 ,%r14
    xorq    Wcopy + 0+F_O (%rbp),%rax
    xorq    Wcopy + 8+F_O (%rbp),%rbx
    xorq    Wcopy +16+F_O (%rbp),%rcx
    xorq    Wcopy +24+F_O (%rbp),%rdx
    andq    TWEAK + 8     (%rdi),%r14
    movq    %rax,X_VARS+ 0(%rdi)             #store final result
    movq    %rbx,X_VARS+ 8(%rdi)        
    movq    %rcx,X_VARS+16(%rdi)        
    movq    %rdx,X_VARS+24(%rdi)        

    # go back for more blocks, if needed
    decq    blkCnt+F_O(%rbp)
    jnz     Skein_256_block_loop
    movq    %r14,TWEAK + 8(%rdi)
    Reset_Stack
    ret
Skein_256_Process_Block_End:

#
.if _SKEIN_CODE_SIZE
C_label  Skein_256_Process_Block_CodeSize
    movq    $(Skein_256_Process_Block_End-Skein_256_Process_Block),%rax
    ret
#
C_label Skein_256_Unroll_Cnt
  .if _UNROLL_CNT <> ROUNDS_256/8
    movq    $_UNROLL_CNT,%rax
  .else
    xorq    %rax,%rax
  .endif
    ret
.endif
#
.endif #_USE_ASM_ & 256
#
#=================================== Skein_512 =============================================
#
.if _USE_ASM_ & 512
#
# void Skein_512_Process_Block(Skein_512_Ctxt_t *ctx,const u08b_t *blkPtr,size_t blkCnt,size_t bitcntAdd)
#
# X[i] == %r[8+i]          #register assignments for X[] values during rounds (i=0..7)
#
#################
# instantiated code
#
C_label Skein_512_Process_Block
    Setup_Stack 512,ROUNDS_512/8
    movq    TWEAK+ 8(%rdi),%rbx
    jmp     Skein_512_block_loop
    .p2align 4
    # main hash loop for Skein_512
Skein_512_block_loop:
    # general register usage:
    #   RAX..RDX       = temps for key schedule pre-loads
    #   R8 ..R15       = X0..X7
    #   RSP, RBP       = stack/frame pointers
    #   RDI            = round counter or context pointer
    #   RSI            = temp
    #
    movq    TWEAK +  0(%rdi),%rax
    addq    bitAdd+F_O(%rbp),%rax     #computed updated tweak value T0
    movq    %rbx,%rcx
    xorq    %rax,%rcx                 #%rax/%rbx/%rcx = tweak schedule
    movq    %rax,TWEAK+ 0    (%rdi)   #save updated tweak value ctx->h.T[0]
    movq    %rax,ksTwk+ 0+F_O(%rbp)
    movq    $KW_PARITY,%rdx
    movq    blkPtr +F_O(%rbp),%rsi    #%rsi --> input block
    movq    %rbx,ksTwk+ 8+F_O(%rbp)
    movq    %rcx,ksTwk+16+F_O(%rbp)
    .irp _Rn_,8,9,10,11,12,13,14,15
      movq  X_VARS+8*(\_Rn_-8)(%rdi),%r\_Rn_
      xorq  %r\_Rn_,%rdx              #compute overall parity
      movq  %r\_Rn_,ksKey+8*(\_Rn_-8)+F_O(%rbp)
    .endr                             #load state into %r8 ..%r15, compute parity
      movq  %rdx,ksKey+8*(8)+F_O(%rbp)#save key schedule parity

    addReg   r13,rax                  #precompute key injection for tweak
    addReg   r14, rbx
    movq     0(%rsi),%rax             #load input block
    movq     8(%rsi),%rbx 
    movq    16(%rsi),%rcx 
    movq    24(%rsi),%rdx 
    addReg   r8 , rax                 #do initial key injection
    addReg   r9 , rbx
    movq    %rax,Wcopy+ 0+F_O(%rbp)   #keep local copy for feedforward
    movq    %rbx,Wcopy+ 8+F_O(%rbp)
    addReg   r10, rcx
    addReg   r11, rdx
    movq    %rcx,Wcopy+16+F_O(%rbp)
    movq    %rdx,Wcopy+24+F_O(%rbp)

    movq    32(%rsi),%rax
    movq    40(%rsi),%rbx 
    movq    48(%rsi),%rcx 
    movq    56(%rsi),%rdx
    addReg   r12, rax
    addReg   r13, rbx
    addReg   r14, rcx
    addReg   r15, rdx
    movq    %rax,Wcopy+32+F_O(%rbp)    
    movq    %rbx,Wcopy+40+F_O(%rbp)    
    movq    %rcx,Wcopy+48+F_O(%rbp)    
    movq    %rdx,Wcopy+56+F_O(%rbp)    

    addq    $8*WCNT,%rsi              #skip the block
    movq    %rsi,blkPtr+F_O(%rbp)     #update block pointer
    #
    #################
    # now the key schedule is computed. Start the rounds
    #
_UNROLL_CNT =   ROUNDS_512/8

