#include <stdio.h>

#define ASM_MACRO 1
#define _Rbase_ Rbase

#define ROUNDS_256	72
#define ROUNDS_512	72
#define ROUNDS_1024	80

/*
#define ksTwk	(8*3)

#define FRAME_OFFS	(ksTwk + 128)
#define F_O	FRAME_OFFS
*/

#define RC(x,y,z)	RC_ ## x ## _ ## y ## _ ## z

#define RotL(x,BLK_SIZE,ROUND_NUM,MIX_NUM) {\
	printf("\trolq $RC_%d_%d_%d,%%%s\n", BLK_SIZE,ROUND_NUM,MIX_NUM,x);\
	}

#define addReg(x,y)	printf("\tleaq (%%%s, %%%s),%%%s\n", y,x,x);
#define addReg2(x,y,z)	printf("\tleaq (%%%s%d, %%%s),%%%s\n", y,z,x,x);
#define addReg3(x,y,z,i) printf("\tleaq %d(%%%s%d,%%%s),%%%s\n",i,y,z,x,x);
#define addReg4(x,y,i)	printf("\tleaq %d(%%%s,%%%s),%%%s\n",i,y,x,x);

#define xorReg(x,y)	printf("\txorq %%%s, %%%s\n", y,x);

#ifdef ASM_MACRO
#define skeinMix(a,b,c,d,e) {\
	printf("\tskeinMix %s,%s,$RC_%d_%d_%d\n",a,b,e,((c) % 8),d);\
}
#else
#define skeinMix(a,b,c,d,e) {\
	addReg(a,b);\
	RotL(b,e,((c) % 8),d);\
	xorReg(b,a);\
}
#endif


int main() {
	int unroll = 0;
	int Rbase = 0;
	const char *reg[] = {"rax","rbx","rcx","rdx","rbp","rdi","r8", "r9", "r10","r11","r12","r13","r","rsi","r14","r15"};

#define rax reg[0]
#define rbx reg[1]
#define rcx reg[2]
#define rdx reg[3]
#define rbp reg[4]
#define rdi reg[5]
#define r8 reg[6]
#define r9 reg[7]
#define r10 reg[8]
#define r11 reg[9]
#define r12 reg[10]
#define r13 reg[11]
#define r reg[12]
#define rsi reg[13]
#define r14 reg[14]
#define r15 reg[15]

#ifdef SKEIN256

#define skein256_round(a,b,c,d,e)	{\
	skeinMix(a,b,e,0,256);\
	skeinMix(c,d,e,1,256);\
}

	unroll = ROUNDS_256/8;
	
	while (Rbase < (unroll * 2)) {

		printf("\n\t# round %d\n",(4*Rbase+0));
		skein256_round(rax,rbx,rcx,rdx,(4*Rbase+0));

		printf("\n\t#precompute key injection value for %%rcx\n");
		printf("\tleaq (%%r%d,%%r%d),%%rdi\n", (8+(Rbase+3)%5),(13+(Rbase+2)%3));

		printf("\n\t# round %d\n", (4*Rbase+1));
		skein256_round(rax,rdx,rcx,rbx,(4*Rbase+1));

		printf("\n\t#precompute key injection value for %%rbx\n");
		printf("\tleaq (%%r%d,%%r%d),%%rsi\n", ( 8+(Rbase+2) % 5), (13+(Rbase+1) % 3));

		printf("\n\t#round %d\n",(4*Rbase + 2));
		skein256_round(rax,rbx,rcx,rdx,(4*Rbase+2));

		printf("\n\t#round %d\n",(4*Rbase+3));
		skein256_round(rax,rdx,rcx,rbx,(4*Rbase+3));

		printf("\n\t# Key injection\n");
		++Rbase;
		addReg2(rax,r,(8+((_Rbase_+0) % 5)));
		addReg(rbx,rsi);
		addReg(rcx,rdi);
		addReg3(rdx,r,(8+((_Rbase_+3)%5)),_Rbase_);
	}
#elif SKEIN512

#define R_512_Quarter(a,b,c,d) {\
	skeinMix(a,b,c,d,512);\
}

	unroll = ROUNDS_512/8;
	int II = 0;
	int RR = 0;
	while (Rbase < (unroll * 2)) {
		RR = 4*Rbase+0;
		II = (RR/4) + 1; // key injection counter
		
		printf("\n\t#Round %d\n",RR);
		R_512_Quarter(r8,r9,(RR),0);
		printf("\tmovq ksKey+8*(((%d)+3) %% 9)+F_O(%%rbp),%%rax\n",II);
		R_512_Quarter(r10,r11,(RR),1);
		R_512_Quarter(r12,r13,(RR),2);
		printf("\tmovq ksKey+8*(((%d)+4) %% 9)+F_O(%%rbp),%%rbx\n",II);
		R_512_Quarter(r14,r15,(RR),3);

		printf("\n\t# Round %d\n",RR+1);
		R_512_Quarter(r10,r9,RR+1,0);
		printf("\tmovq ksKey+8*(((%d)+5) %% 9)+F_O(%%rbp),%%rcx\n",II);
		R_512_Quarter(r12,r15,RR+1,1);
		R_512_Quarter(r14,r13,RR+1,2);
		printf("\tmovq ksKey+8*(((%d)+6) %% 9)+F_O(%%rbp),%%rdx\n",II);
		R_512_Quarter(r8,r11,RR+1,3);

		printf("\n\t# Round %d\n",RR+2);
		R_512_Quarter(r12,r9,RR+2,0);
		printf("\tmovq ksKey+8*(((%d)+7) %% 9)+F_O(%%rbp),%%rsi\n",II);
		R_512_Quarter(r14,r11,RR+2,1);
		R_512_Quarter(r8,r13,RR+2,2);
		printf("\taddq ksTwk+8*(((%d)+0) %% 3)+F_O(%%rbp),%%rcx\n",II);
		R_512_Quarter(r10,r15,RR+2,3);

		printf("\n\t# Round %d\n",RR+3);
		R_512_Quarter(r14,r9,RR+3,0);
		printf("\taddq ksTwk+8*(((%d)+1)%%3)+F_O(%%rbp),%%rdx\n",II);
		R_512_Quarter(r8,r15,RR+3,1);
		R_512_Quarter(r10,r13,RR+3,2);
		R_512_Quarter(r12,r11,RR+3,3);

		printf("\n\t# inject the key schedule\n");
		printf("\taddq	ksKey+8*(((%d)+0)%%9)+F_O(%%rbp),%%r8\n",II);
		addReg(r11,rax);
		printf("\taddq	ksKey+8*(((%d)+1)%%9)+F_O(%%rbp),%%r9\n",II);
		addReg(r12,rbx);
		printf("\taddq	ksKey+8*(((%d)+2)%%9)+F_O(%%rbp),%%r10\n",II);
		addReg(r13,rcx);
		addReg(r14,rdx);
		addReg4(r15,rsi,II);

		++Rbase;
	}
#elif SKEIN1024

#define r1024_Mix(w0,w1,reg0,reg1,rn0,rn1) {\
	skeinMix(reg0,reg1,rn0,rn1,1024);\
\
	if (((rn0) & 3) == 3) { /* Every 4th rn0, 3,7,11,15 */\
		II = ((rn0)/4) + 1; \
		printf("\taddq ksKey+8*((%d+%d) %% 17)(%%rsp),%%%s\n",II,w0,reg0);\
		printf("\taddq ksKey+8*((%d+%d) %% 17)(%%rsp),%%%s\n",II,w1,reg1);\
\
		if (w1 == 13) \
			printf("\taddq	ksTwk+ 8*((%d+0) %%3)(%%rsp),%%%s\n",II,reg1);\
		else if (w0 == 14)\
			printf("\taddq ksTwk+ 8*((%d+1)%%3)(%%rsp),%%%s\n",II,reg0);\
		else if (w1 == 15)\
			printf("\taddq	$%d,%%%s\n", II, reg1);\
	} \
}

#define r1024_FourRounds(RR) {\
	Rn = RR + 0; \
	printf("\n\t# round %d\n", Rn);\
	r1024_Mix(0, 1, rdi, rsi, Rn, 0);\
	r1024_Mix(2, 3, rbp, rax, Rn, 1);\
	r1024_Mix(4, 5, rcx, rbx, Rn, 2);\
	printf("\tmovq %%rcx,X_stk+8*4(%%rsp)\t#save X4  on  stack (x4/x6 alternate)\n");\
	r1024_Mix(8, 9, r8, r9, Rn, 4);\
	printf("\tmovq X_stk+8*6(%%rsp),%%rcx\t#load X6 from stack \n");\
	r1024_Mix(10,11,r10,r11,Rn,5);\
        r1024_Mix(12,13,r12,r13,Rn,6);\
        r1024_Mix( 6, 7,rcx,rdx,Rn,3);\
        r1024_Mix(14,15,r14,r15,Rn,7);\
\
	Rn = (RR) + 1;\
	printf("\n\t# round %d\n", Rn);\
        r1024_Mix(0, 9,rdi,r9 ,Rn,0);\
        r1024_Mix( 2,13,rbp,r13,Rn,1);\
        r1024_Mix( 6,11,rcx,r11,Rn,2);\
	printf("\tmovq %%rcx,X_stk+8*6(%%rsp)\t#save X6  on  stack (x4/x6 alternate)\n");\
        r1024_Mix(10, 7,r10,rdx,Rn,4);\
	printf("\tmovq X_stk+8*4(%%rsp),%%rcx\t#load X4 from stack\n");\
        r1024_Mix(12, 3,r12,rax,Rn,5);\
        r1024_Mix(14, 5,r14,rbx,Rn,6);\
        r1024_Mix( 4,15,rcx,r15,Rn,3);\
        r1024_Mix( 8, 1,r8 ,rsi,Rn,7);\
\
	Rn = (RR) + 2;\
	printf("\n\t# round %d\n", Rn);\
        r1024_Mix( 0, 7,rdi,rdx,Rn,0);\
        r1024_Mix( 2, 5,rbp,rbx,Rn,1);\
        r1024_Mix( 4, 3,rcx,rax,Rn,2);\
	printf("\tmovq %%rcx,X_stk+8*4(%%rsp)\t#save X4  on  stack (x4/x6 alternate)\n");\
        r1024_Mix(12,15,r12,r15,Rn,4);\
	printf("\tmovq X_stk+8*6(%%rsp),%%rcx\t#load X6 from stack\n");\
        r1024_Mix(14,13,r14,r13,Rn,5);\
        r1024_Mix( 8,11,r8 ,r11,Rn,6);\
        r1024_Mix( 6, 1,rcx,rsi,Rn,3);\
        r1024_Mix(10, 9,r10,r9 ,Rn,7);\
\
	Rn = (RR) + 3;\
	printf("\n\t# round %d\n", Rn);\
        r1024_Mix( 0,15,rdi,r15,Rn,0);\
        r1024_Mix( 2,11,rbp,r11,Rn,1);\
        r1024_Mix( 6,13,rcx,r13,Rn,2);\
	printf("\tmovq %%rcx,X_stk+8*6(%%rsp)\t#save X6  on  stack (x4/x6 alternate)\n");\
        r1024_Mix(14, 1,r14,rsi,Rn,4);\
	printf("\tmovq X_stk+8*4(%%rsp),%%rcx\t#load X4 from stack\n");\
        r1024_Mix( 8, 5,r8 ,rbx,Rn,5);\
        r1024_Mix(10, 3,r10,rax,Rn,6);\
        r1024_Mix( 4, 9,rcx,r9 ,Rn,3);\
        r1024_Mix(12, 7,r12,rdx,Rn,7);\
}

	unroll = ROUNDS_1024/8;
	int II = 0;
	int RR = 0;
	int Rn = 0;
	while (Rbase < (unroll * 2)) {
		r1024_FourRounds ((4*Rbase));
		++Rbase;
	}
#endif

	return 0;
}
