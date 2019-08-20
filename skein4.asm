
    # end of rounds
    #################
    #
    # feedforward:   ctx->X[i] = X[i] ^ w[i], {i=0..15}
    movq    %rdx,X_stk+8*o1K_rdx(%rsp) #we need a register. x6 already on stack
    movq       ctxPtr(%rsp),%rdx
    
    .irp _rr_,rdi,rsi,rbp,rax,rcx,rbx,r8,r9,r10,r11,r12,r13,r14,r15   #do all but x6,x7
_oo_ = o1K_\_rr_
      xorq  Wcopy +8*_oo_(%rsp),%\_rr_ #feedforward XOR
      movq  %\_rr_,X_VARS+8*_oo_(%rdx) #save result into context
      .if (_oo_ ==  9)
        movq   $FIRST_MASK64 ,%r9
      .endif
      .if (_oo_ == 14)
        andq   TWEAK+ 8(%rdx),%r9
      .endif
    .endr
    # 
    movq         X_stk +8*6(%rsp),%rax #now process x6,x7 (skipped in .irp above)
    movq         X_stk +8*7(%rsp),%rbx
    xorq         Wcopy +8*6(%rsp),%rax
    xorq         Wcopy +8*7(%rsp),%rbx
    movq    %rax,X_VARS+8*6(%rdx)
    decq             blkCnt(%rsp)      #set zero flag iff done
    movq    %rbx,X_VARS+8*7(%rdx)

    # go back for more blocks, if needed
    movq             ctxPtr(%rsp),%rdi #don't muck with the flags here!
    lea          FRAME_OFFS(%rsp),%rbp
    jnz     Skein1024_block_loop
    movq    %r9 ,TWEAK+   8(%rdx)
    Reset_Stack
    ret
#
Skein1024_Process_Block_End:
#
#
.if _SKEIN_CODE_SIZE
C_label Skein1024_Process_Block_CodeSize
    movq    $(Skein1024_Process_Block_End-Skein1024_Process_Block),%rax
    ret
#
C_label Skein1024_Unroll_Cnt
  .if _UNROLL_CNT <> (ROUNDS_1024/8)
    movq    $_UNROLL_CNT,%rax
  .else
    xorq    %rax,%rax
  .endif
    ret
.endif
#
.endif # _USE_ASM_ and 1024
#
#----------------------------------------------------------------
#   .section .note.GNU-stack,"",@progbits

    .end
