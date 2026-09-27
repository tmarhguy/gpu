TEX2D r4, r0
LDU r7, u4
DP3 r5, r1, r7
LDI r8, 0.4
CMP r9, r5, r8
LDI r10, 0.35
LDI r11, 1
SEL r6, r9, r10, r11
MUL r6, r4, r6
OUT 0, r6
END
