/*
In my design, Reorder Buffer is a queue of ROB_SIZE=10. 
A new instruction enters rob at tail. 
The entry will be added unitl it is equal ROB_SIZE and then reset it.
After an instruction is committed, the whole queue will be traersed and moved forward.
*/

`include "define.v"

module rob #(
    parameter ROB_SIZE = 10; //can be modified
)(
    input wire              clk_in,
    input wire              rst_in,
	input wire		        rdy_in,

    input wire              output_or_commit; //0 for doing nothing, 1 for instr_output, 2 for if_commit 

    //if have instr input
    input wire              have_input,
    input wire [31:0]       instr_input,
    input wire [31:0]       instr_input_pc,
    input wire [16:0]       opcode_if,
    input wire [4:0]        rd_if,
    input wire [4:0]        rs1_if,
    input wire [4:0]        rs2_if,
    input wire [31:0]       imm_if,

    //if have cdb feedback
    input wire              have_modify,
    input wire              entry_modify,
    input wire[4:0]         destination_modify,
    input wire[31:0]        value_modify,

    //if need output
    output wire             is_jump, //1 is jump
    output wire             slb_or_rs_or_pc,  //0 arrive slb, 1 arrive rs, 2 arrive pc(branch)
    output wire             entry_out,
    output wire [31:0]      instr_output
    output wire [3:0]       opcode_out,
    //output wire [4:0]       rd_out,
    output wire [31:0]      Rrs1_out,
    output wire             rs1_q_out,
    output wire [31:0]      Rrs2_out,
    output wire             rs2_q_out,
    output wire [31:0]      imm_out,

    output wire             rob_full,   //1 if full
    output wire             rob_empty,  //1 if empty       

    //if need commit
    output wire             entry_commit,
    output wire             destType_commit, //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
    output wire[4:0]        destination_commit,
    output wire[31:0]       value_commit

);
//riscv_instruction
reg[ROB_SIZE-1:0] entry; //.
reg[31:0] instr_origin[ROB_SIZE-1:0]; //.
reg[ROB_SIZE-1:0] state; //0:initial, 1:pending, 2:ready  
reg[3:0] opcode[ROB_SIZE-1:0]; //.
reg[ROB_SIZE-1:0] destType; //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
reg[4:0] destination[ROB_SIZE-1:0];
reg[31:0] value[ROB_SIZE-1:0];
reg[31:0] pc_value[ROB_SIZE-1:0]; //.

wire rob_num; //the next index = the current number 
wire entry_num; //the next entry

reg[4:0] rd[ROB_SIZE-1:0];
reg[4:0] rs1[ROB_SIZE-1:0], rs2[ROB_SIZE-1:0];
wire[ROB_SIZE-1:0] rs1_q, rs2_q;
reg[31:0] imm[ROB_SIZE-1:0]; 


always @(posedge clk_in)
    begin
        if (rst_in) begin
            rob_num <= 0;
            entry_num <= 1;
        end
        else if (!rdy_in) begin

        end
        else begin
            //1.store the instruction from IF;
            if (have_input && rob_num < ROB_SIZE-1) begin
                entry[rob_num] <= entry_num;
                instr_origin[rob_num] <= instr_input;
                pc_value[rob_num] <= instr_input_pc;
                rd[rob_num] <= rd_if;
                rs1[rob_num] <= rs1_if;
                rs2[rob_num] <= rs2_if;
                imm[rob_num] <= imm_if;
                case (opcode_if[6:0])
                    7'b0110111:  //LUI //rd, imm
                        opcode[rob_num] <= `LUI;
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        value[rob_num] <= imm_if;
                        state[rob_num] <= 2;
                    7'b0010111: //AUIPC //rd, imm
                        opcode[rob_num] <= `AUIPC;
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                    7'b1101111: //JAL //rd, imm
                        opcode[rob_num] <= `JAL;
                        destType[rob_num] <= 3;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                    7'b1100111: //JALR //rd, rs1, imm
                        opcode[rob_num] <= `JALR;
                        destType[rob_num] <= 3;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                    7'b1100011: //Branch //rs1, rs2, imm
                        destType[rob_num] <= 2;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `BEQ;
                            3'b001: opcode[rob_num] <= `BNE;
                            3'b100: opcode[rob_num] <= `BLT;
                            3'b101: opcode[rob_num] <= `BGE;
                            3'b110: opcode[rob_num] <= `BLTU;
                            3'b111: opcode[rob_num] <= `BGEU;
                            default: 
                        endcase
                    7'b0000011: //Load //rd, rs1, imm
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `LB;
                            3'b001: opcode[rob_num] <= `LH;
                            3'b010: opcode[rob_num] <= `LW;
                            3'b100: opcode[rob_num] <= `LBU;
                            3'b101: opcode[rob_num] <= `LHU;
                            default:  
                        endcase
                    7'b0100011: //Store //rs1, rs2, imm
                        destType[rob_num] <= 0;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `SB;
                            3'b001: opcode[rob_num] <= `SH;
                            3'b010: opcode[rob_num] <= `SW;
                            default: 
                        endcase
                    7'b0010011: //expi //need rd, rs1, imm
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `ADDI;
                            3'b010: opcode[rob_num] <= `SLTI;
                            3'b011: opcode[rob_num] <= `SLTIU;
                            3'b100: opcode[rob_num] <= `XORI;
                            3'b110: opcode[rob_num] <= `ORI;
                            3'b111: opcode[rob_num] <= `ANDI;
                            3'b001: opcode[rob_num] <= `SLLI;
                            default:  //3'b101
                            case (opcode_if[16:10])
                                7'b0000000: opcode[rob_num] <= `SRLI;
                                7'b0100000: opcode[rob_num] <= `SRAI;
                                default: 
                            endcase
                        endcase
                    7'b0110011:  //exp //need rd, rs1, rs2
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000:
                            case (opcode_if[16:10])
                                7'b0000000: opcode[rob_num] <= `ADD;
                                7'b0100000: opcode[rob_num] <= `SUB;
                                default: 
                            endcase
                            3'b001: opcode[rob_num] <= `SLL;
                            3'b010: opcode[rob_num] <= `SLT;
                            3'b011: opcode[rob_num] <= `SLTU;
                            3'b100: opcode[rob_num] <= `XOR;
                            3'b101: 
                            case (opcode_if[16:10])
                                7'b0000000: opcode[rob_num] <= `SRL;
                                7'b0100000: opcode[rob_num] <= `SRA;
                                default: 
                            endcase
                            3'b110: opcode[rob_num] <= `OR;
                            3'b111: opcode[rob_num] <= `AND;
                            default: 
                        endcase
                    default: 
                endcase

                integer i;

                i = rob_num;
                while (i>=0 && destType[i] != destType[rob_num] && destination[i] != rs1_if) begin
                    i=i-1;
                end
                if (i>=0) begin
                    rs1_q[rob_num] <= entry[i];
                end
                i = rob_num;
                while (i>=0 && destType[i] != destType[rob_num] && destination[i] != rs2_if) begin
                    i=i-1;
                end
                if (i>=0) begin
                    rs2_q[rob_num] <= entry[i];
                end

                for (i=0; i<rob_num; i=i+1) begin
                    if (destType[i] == destType[rob_num]) begin
                        if (rd_if == rs1_if) begin
                            rs1_q = i;
                        end
                        if (rd_if == rs2_if) begin
                            rs2_q = i;
                        end
                    end
                end
                rob_num <= rob_num + 1;
                entry_num <= (entry_num == ROB_SIZE) 1 : (entry_num + 1);
            end   

            //2.if output_or_commit == output
            if (output_or_commit == 1) begin
                //遍历state，找到最上层的0(未被推入任何其他部件)，推入相应位置
                integer i;
                while (state[i] != 0 && i < rob_num) begin
                    i=i+1;
                end
                if (i < rob_num) begin
                    assign entry_out = entry[i];
                    assign instr_output = instr_origin[i];
                    assign opcode_out = opcode[i];
                    //assign rd_out = rd[i];
                    assign rs1_q_out = rs1_q[i];
                    assign rs2_q_out = rs2_q[i];
                    if (rs1_q[i] == 0) begin
                        visit_regfile regfile(
                            .query_or_modify    (0),
                            .reg_index          (rs1[i]),
                            .modify_value       (32'b0),
                            .query_value        (Rrs1_out));
                    end
                    if (rs2_q[i] == 0) begin
                        visit_regfile regfile(
                            .query_or_modify    (0),
                            .reg_index          (rs2[i]),
                            .modify_value       (32'b0),
                            .query_value        (Rrs2_out));
                    end                    
                    assign imm_out = imm[i];
                    case (opcode[i][2])
                        1:  assign is_jump = 1; 
                        2:  assign slb_or_rs_or_pc = 2;
                        3:  assign slb_or_rs_or_pc = 0;
                        4:  assign slb_or_rs_or_pc = 0;
                        default: 
                            assign slb_or_rs_or_pc = 1;
                    endcase
                end
            end 

            //3.recall the feedback from cdb
            if (have_modify) begin
                integer i;
                while (entry[i] != entry_modify && i<rob_num) begin
                    i=i+1;
                end
                if (i<rob_num) begin
                    //destination[i] = destination_modify;
                    value[i] = value_modify;
                end
            end

            //4.if output_or_commit == commit
            if (output_or_commit == 2) begin
                //遍历state，找到最上层的2(可被commit的状态)，并通知相应部件进行执行，推出该指令, 并将整个rob向前移位
                integer j;
                while (state[j] != 2 && j < rob_num) begin
                    j = j + 1;
                end
                if (j < rob_num) begin
                    assign entry_commit = entry[j];
                    assign destType_commit = destType[j];
                    assign destination_commit = destination[j]; 
                    assign value_commit = value[j];
                    integer i;
                    for (i=j;i<rob_num;i=i+1) begin
                        entry[i-1] <= entry[i];
                        instr_origin[i-1] <= entry[i];
                        state[i-1] <= state[i];
                        opcode[i-1] <= opcode[i];
                        destType[i-1] <= destType[i];
                        destination[i-1] <= destination[i];
                        value[i-1] <= value[i];
                        pc_value[i-1] <= pc_value[i];
                        rd[i-1] <= rd[i];
                        rs1[i-1] <= rs1[i];
                        rs2[i-1] <= rs2[i];
                        imm[i-1] <= imm[i];
                    end
                    rob_num <= rob_num-1;
                end     
            end
        end
    end
    
endmodule



/*ROB的工作
1.store the instruction from IF;
    case opcode and fetch the content in ROB(like destType, destination, value and so on)
2.if output_or_commit == output
    fetch the entry that can be output(the first one that not ready)
    need to know :
        1) arrive? rs/pc/slb
        2) the information of the instr
        3) about renaming : if one register is occupied, the entry of rs1 and rs2 that is occupied should be output 
3.recall the feedback from cdb
4.if output_or_commit == commit
    fetch the entry that can be committed (the first one that is ready)
    need to know :
        1)entry
        2)destType
        3)value
*/