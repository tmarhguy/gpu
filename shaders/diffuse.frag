TEX2D r4, r0
LDU r7, u4
DP3 r5, r1, r7
LDI r8, 0
MAX r5, r5, r8
LDI r9, 0.28
ADD r5, r5, r9
MUL r6, r4, r5
SAT r6, r6
OUT 0, r6
END
