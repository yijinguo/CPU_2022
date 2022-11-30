//[3]=0 instruction. [2]: jump:1; branch:2; load:3; store:4; expri:5; expr:6
`define     LUI     4'd000
`define     AUIPC   4'd001
`define     JAL     4'd102
`define     JALR    4'd103
`define     BEQ     4'd204
`define     BNE     4'd205
`define     BLT     4'd206
`define     BGE     4'd207
`define     BLTU    4'd208
`define     BGEU    4'd209
`define     LB      4'd310 
`define     LH      4'd311
`define     LW      4'd312 
`define     LBU     4'd313 
`define     LHU     4'd314 
`define     SB      4'd415 
`define     SH      4'd416 
`define     SW      4'd417
`define     ADDI    4'd518 
`define     SLTI    4'd519
`define     SLTIU   4'd520
`define     XORI    4'd521 
`define     ORI     4'd522 
`define     ANDI    4'd523 
`define     SLLI    4'd524 
`define     SRLI    4'd525 
`define     SRAI    4'd526
`define     ADD     4'd627 
`define     SUB     4'd628 
`define     SLL     4'd629 
`define     SLT     4'd630 
`define     SLTU    4'd631 
`define     XOR     4'd632 
`define     SRL     4'd633 
`define     SRA     4'd634 
`define     OR      4'd635 
`define     AND     4'd636

//[3]=1 operand.
`define     Add     4'd1000 //+
`define     Sub     4'd1001 //-
`define     Or      4'd1002 //|
`define     Xor     4'd1003 //^    
`define     And     4'd1004  
`define     Lshift  4'd1005 //<<
`define     Rshift  4'd1006 //>>
`define     Lthan   4'd1007 //<
`define     Lequal  4'd1008 //<=
`define     Rthan   4'd1009 //>
`define     Requal  4'd1010 //>=
`define     Equal   4'd1011 //==
`define     Nequal  4'd1012 //!=