    # end of rounds
    #################
    # feedforward:   ctx->X[i] = X[i] ^ w[i], {i=0..7}
    .irp _Rn_,8,9,10,11,12,13,14,15
  .if (\_Rn_ == 8)
    movq    $FIRST_MASK64,%rbx
  .endif
      xorq  Wcopy+8*(\_Rn_-8)+F_O(%rbp),%r\_Rn_  #feedforward XOR
      movq  %r\_Rn_,X_VARS+8*(\_Rn_-8)(%rdi)     #and store result
  .if (\_Rn_ == 14)
    andq    TWEAK+ 8(%rdi),%rbx
  .endif
    .endr

    # go back for more blocks, if needed
    decq    blkCnt+F_O(%rbp)
    jnz     Skein_512_block_loop
    movq    %rbx,TWEAK + 8(%rdi)

    Reset_Stack
    ret
Skein_512_Process_Block_End:
#
#
.if _SKEIN_CODE_SIZE
C_label Skein_512_Process_Block_CodeSize
    movq    $(Skein_512_Process_Block_End-Skein_512_Process_Block),%rax
    ret
#
C_label Skein_512_Unroll_Cnt
  .if _UNROLL_CNT <> (ROUNDS_512/8)
    movq    $_UNROLL_CNT,%rax
  .else
    xorq    %rax,%rax
  .endif
    ret
.endif
#
.endif # _USE_ASM_ & 512
#
#=================================== Skein1024 =============================================
.if _USE_ASM_ & 1024
#
# void Skein1024_Process_Block(Skein_1024_Ctxt_t *ctx,const u08b_t *blkPtr,size_t blkCnt,size_t bitcntAdd)#
#
#################
# use details of permutation to make register assignments
# 
o1K_rdi =  0        #offsets in X[] associated with each register
o1K_rsi =  1 
o1K_rbp =  2 
o1K_rax =  3 
o1K_rcx =  4        #rcx is "shared" with X6, since X4/X6 alternate
o1K_rbx =  5 
o1K_rdx =  7 
o1K_r8  =  8  
o1K_r9  =  9  
o1K_r10 = 10
o1K_r11 = 11
o1K_r12 = 12
o1K_r13 = 13
o1K_r14 = 14
o1K_r15 = 15
#
rIdx_offs = tmpStk_1024
#
################
# code
#
C_label Skein1024_Process_Block
#
    Setup_Stack 1024,((ROUNDS_1024/8)+1),WCNT
    movq    TWEAK+ 8(%rdi),%r9
    jmp     Skein1024_block_loop
    # main hash loop for Skein1024
    .p2align 4
Skein1024_block_loop:
    # general register usage:
    #   RSP              = stack pointer
    #   RAX..RDX,RSI,RDI = X1, X3..X7 (state words)
    #   R8 ..R15         = X8..X15    (state words)
    #   RBP              = temp (used for X0 and X2)
    #
    movq         TWEAK+     0(%rdi),%r8
    addq         bitAdd+  F_O(%rbp),%r8    #computed updated tweak value T0
    movq    %r9 ,%r10 
    xorq    %r8 ,%r10                      #%rax/%rbx/%rcx = tweak schedule
    movq    %r8 ,TWEAK+     0(%rdi)        #save updated tweak value ctx->h.T[0]
    movq    %r8 ,ksTwk+ 0+F_O(%rbp)
    movq    %r9 ,ksTwk+ 8+F_O(%rbp)        #keep values in %r8 ,%r9  for initial tweak injection below
    movq    %r10,ksTwk+16+F_O(%rbp)
    movq         blkPtr +F_O(%rbp),%rsi    # rsi --> input block
    movq        $KW_PARITY        ,%rax    #overall key schedule parity

    # the logic here assumes the set {rdi,rsi,rbp,rax} = X[0,1,2,3]
    .irp _rN_,0,1,2,3,4,6                  #process the "initial" words, using r14/r15 as temps
      movq       X_VARS+8*\_rN_(%rdi),%r14  #get state word
      movq              8*\_rN_(%rsi),%r15  #get msg   word
      xorq  %r14,%rax                      #update key schedule overall parity
      movq  %r14,ksKey +8*\_rN_+F_O(%rbp)   #save key schedule word on stack
      movq  %r15,Wcopy +8*\_rN_+F_O(%rbp)   #save local msg Wcopy 
      addq  %r15,%r14                      #do the initial key injection
      movq  %r14,X_stk +8*\_rN_    (%rsp)   #save initial state var on stack
    .endr
    # now process the rest, using the "real" registers 
    #     (MUST do it in reverse order to inject tweaks r8/r9 first)
    .irp _rr_,r15,r14,r13,r12,r11,r10,r9,r8,rdx,rbx
_oo_ = o1K_\_rr_                           #offset assocated with the register
      movq  X_VARS+8*_oo_(%rdi),%\_rr_     #get key schedule word from context
      movq         8*_oo_(%rsi),%rcx       #get next input msg word
      movq  %\_rr_, ksKey +8*_oo_(%rsp)    #save key schedule on stack
      xorq  %\_rr_, %rax                   #accumulate key schedule parity
      movq  %rcx,Wcopy+8*_oo_+F_O(%rbp)    #save copy of msg word for feedforward
      addq  %rcx,%\_rr_                    #do the initial  key  injection
      .if    _oo_ == 13                    #do the initial tweak injection
        addReg \_rr_,r8                     #          (only in words 13/14)
      .elseif _oo_ == 14
        addReg \_rr_,r9 
      .endif
    .endr
    movq    %rax,ksKey+8*WCNT+F_O(%rbp)    #save key schedule parity
    addq     $8*WCNT,%rsi                  #bump the msg ptr
    movq     %rsi,blkPtr+F_O(%rbp)         #save bumped msg ptr
    # re-load words 0..4 from stack, enter the main loop
    .irp _rr_,rdi,rsi,rbp,rax,rcx          #(no need to re-load x6, already on stack)
      movq  X_stk+8*o1K_\_rr_(%rsp),%\_rr_ #re-load state and get ready to go!
    .endr
    #
    #################
    # now the key schedule is computed. Start the rounds
    #
_UNROLL_CNT =   ROUNDS_1024/8

