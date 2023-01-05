/*
In my design, Reorder Buffer is a queue of ROB_SIZE=10. 
A new instruction enters rob at tail. 
The entry will be added unitl it is equal ROB_SIZE and then reset it.
After an instruction is committed, the whole queue will be traersed and moved forward.
*/

`include "define.v"

module rob #(
    parameter ROB_SIZE = 10 //can be modified
)(
    input wire              clk_in,
    input wire              rst_in,
	input wire		        rdy_in,

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
    input   wire            have_cdb_rs,
    input   wire            entry_cdb_rs,
    input   wire [31:0]     value_cdb_rs,
    input   wire            have_cdb_branch,
    input   wire            entry_cdb_branch,
    input   wire [31:0]     value_cdb_branch,
    input   wire            have_cdb_slb,
    input   wire            entry_cdb_slb,
    input   wire [31:0]     value_cdb_slb,

    output  reg             rd_cdb_rs,
    output  reg             new_entry_cdb_rs,
    output  reg             rd_cdb_branch,
    output  reg             new_entry_cdb_branch,
    output  reg             rd_cdb_slb,
    output  reg             new_entry_cdb_slb,

    //if need output
    output wire             have_out,
    output reg              is_jump, //1 is jump
    output reg              slb_or_rs_or_pc,  //0 arrive slb, 1 arrive rs, 2 arrive pc(branch)
    output wire             entry_out,
    output wire [3:0]       opcode_out,
    output wire [31:0]      pc_address_out,
    output wire [4:0]       rd_out,
    output wire [ 4:0]      rs1_out,
    output wire [ 4:0]      rs2_out,
    output wire [31:0]      imm_out,

    output wire             rob_full,   //1 if full    

    //if need commit
    output wire             have_commit,
    output wire             entry_commit,
    output wire             destType_commit, //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
    output wire             if_pc_change_commit,
    output wire[31:0]       new_pc_address_commit,
    output wire[4:0]        destination_commit,
    output wire[31:0]       value_commit
);

reg[ROB_SIZE-1:0] entry; 
reg[31:0] instr_origin[ROB_SIZE-1:0]; 
reg[ROB_SIZE-1:0] state; //0:initial, 1:pending, 2:ready  
reg[ROB_SIZE-1:0] destType; //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
reg[3:0] opcode[ROB_SIZE-1:0]; 
reg[4:0] destination[ROB_SIZE-1:0];
reg[31:0] value[ROB_SIZE-1:0];
reg[31:0] pc_value[ROB_SIZE-1:0]; 
reg[ROB_SIZE-1:0] pc_change; 

integer rob_num; //the next index = the current number 
integer entry_num; //the next entry

reg[4:0] rd[ROB_SIZE-1:0];
reg[4:0] rs1[ROB_SIZE-1:0], rs2[ROB_SIZE-1:0];
reg[31:0] imm[ROB_SIZE-1:0]; 

integer i, j;
reg destination_cdb;

assign rob_full = (rob_num == ROB_SIZE - 2);

//2.fetch output
//遍历state，找到最上层的0(未被推入任何其他部件)，推入相应位置
initial begin
    i = 0;
    while (state[i] != 0 && i < rob_num) i=i+1;
    if (i < rob_num) begin
        case (opcode[i][2])
            1:  is_jump = 1; 
            2:  slb_or_rs_or_pc = 2;
            3:  slb_or_rs_or_pc = 0;
            4:  slb_or_rs_or_pc = 0;
            default:  slb_or_rs_or_pc = 1;
        endcase
    end
    else begin
        slb_or_rs_or_pc = 3;
    end 
end

assign have_out = (i<rob_num);
assign entry_out = entry[i];
assign opcode_out = opcode[i];
assign pc_address_out = pc_value[i];
assign rd_out = rd[i];
assign rs1_out = rs1[i];
assign rs2_out = rs2[i];
assign imm_out = imm[i];


//4.if output_or_commit == commit
//遍历state，找到最上层的2(可被commit的状态)，并通知相应部件进行执行，推出该指令, 并将整个rob向前移位
initial begin
    j = 0;
    while (state[j] != 2 && j < rob_num) j=j+1;
    i = 0;
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

assign have_commit = (j<rob_num);
assign entry_commit = (j<rob_num) ? entry[j] : 0;
assign destType_commit = destType[j];
assign destination_commit = destination[j]; 
assign value_commit = value[j];    

always @(posedge clk_in) begin
    if (rst_in) begin
        rob_num <= 0;
        entry_num <= 1;
    end
    else if (!rdy_in) begin

    end
    else begin
        //1.store the instruction from IF;
        if (have_input && rob_num < ROB_SIZE-1) begin
            rob_num <= rob_num + 1;
            entry_num <= (entry_num == ROB_SIZE) ? 1 : (entry_num + 1);
            entry[rob_num] <= entry_num;
            instr_origin[rob_num] <= instr_input;
            pc_value[rob_num] <= instr_input_pc;
            rd[rob_num] <= rd_if;
            rs1[rob_num] <= rs1_if;
            rs2[rob_num] <= rs2_if;
            imm[rob_num] <= imm_if;
            case (opcode_if[6:0])
                    7'b0110111: begin //LUI //rd, imm 
                        opcode[rob_num] <= `LUI;
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        value[rob_num] <= imm_if;
                        state[rob_num] <= 2;
                    end
                    7'b0010111: begin //AUIPC //rd, imm
                        opcode[rob_num] <= `AUIPC;
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                    end
                    7'b1101111: begin //JAL //rd, imm
                        opcode[rob_num] <= `JAL;
                        destType[rob_num] <= 3;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        pc_change[rob_num] <= 1;
                    end
                    7'b1100111: begin//JALR //rd, rs1, imm
                        opcode[rob_num] <= `JALR;
                        destType[rob_num] <= 3;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        pc_change[rob_num] <= 1;
                    end
                    7'b1100011: begin //Branch //rs1, rs2, imm
                        destType[rob_num] <= 2;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `BEQ;
                            3'b001: opcode[rob_num] <= `BNE;
                            3'b100: opcode[rob_num] <= `BLT;
                            3'b101: opcode[rob_num] <= `BGE;
                            3'b110: opcode[rob_num] <= `BLTU;
                            3'b111: opcode[rob_num] <= `BGEU;
                            default: opcode[rob_num] <= 0;
                        endcase
                    end
                    7'b0000011: begin //Load //rd, rs1, imm
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `LB;
                            3'b001: opcode[rob_num] <= `LH;
                            3'b010: opcode[rob_num] <= `LW;
                            3'b100: opcode[rob_num] <= `LBU;
                            3'b101: opcode[rob_num] <= `LHU;
                            default: ; 
                        endcase
                    end
                    7'b0100011: begin //Store //rs1, rs2, imm
                        destType[rob_num] <= 0;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000: opcode[rob_num] <= `SB;
                            3'b001: opcode[rob_num] <= `SH;
                            3'b010: opcode[rob_num] <= `SW;
                            default: ;
                        endcase
                    end
                    7'b0010011: begin //expi //need rd, rs1, imm
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
                                default: ;
                            endcase
                        endcase
                    end
                    7'b0110011: begin //exp //need rd, rs1, rs2
                        destType[rob_num] <= 1;
                        destination[rob_num] <= rd_if;
                        state[rob_num] <= 0;
                        case (opcode_if[9:7])
                            3'b000:
                            case (opcode_if[16:10])
                                7'b0000000: opcode[rob_num] <= `ADD;
                                7'b0100000: opcode[rob_num] <= `SUB;
                                default: ;
                            endcase
                            3'b001: opcode[rob_num] <= `SLL;
                            3'b010: opcode[rob_num] <= `SLT;
                            3'b011: opcode[rob_num] <= `SLTU;
                            3'b100: opcode[rob_num] <= `XOR;
                            3'b101: begin
                                case (opcode_if[16:10])
                                    7'b0000000: opcode[rob_num] <= `SRL;
                                    7'b0100000: opcode[rob_num] <= `SRA;
                                    default: ;
                                endcase
                            end
                            3'b110: opcode[rob_num] <= `OR;
                            3'b111: opcode[rob_num] <= `AND;
                            default: ;
                        endcase
                    end
                    default: ; 
            endcase
        end 

        //3.recall the feedback from cdb
        if (have_cdb_rs) begin
            i=0;
            while (i<rob_num && entry[i] != entry_cdb_rs) i=i+1;
            value[i] <= value_cdb_rs;
            rd_cdb_rs <= destination[i];
            state[i] <= 2;
            j=i+1;
            while (j<rob_num && destination[j]!=destination[i]) j=j+1;
            new_entry_cdb_rs <= entry[j];
        end
        if (have_cdb_branch) begin
            i=0;
            while (i<rob_num && entry[i] != entry_cdb_branch) i=i+1;
            value[i] <= value_cdb_branch;
            rd_cdb_branch <= destination[i];
            state[i] <= 2;
            j=i+1;
            while (j<rob_num && destination[j]!=destination[i]) j=j+1;
            new_entry_cdb_branch <= entry[j];
        end
        if (have_cdb_slb) begin
            i=0;
            while (i<rob_num && entry[i] != entry_cdb_slb) i=i+1;
            value[i] <= value_cdb_slb;
            rd_cdb_slb <= destination[i];
            state[i] <= 2;
            j=i+1;
            while (j<rob_num && destination[j]!=destination[i]) j=j+1;
            new_entry_cdb_slb <= entry[j];
        end
        
    end
end    
    
//将最后一个rob的信息输入regfile
regfile reg_qurey(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),

    .query      (0),
    .reorder        (1),
    .reorder_entry  (entry[rob_num]),
    .reorder_rd     (destination[rob_num]),
    
    .modify         (0),
    .modify_entry   (0),
    .modify_index   (0),
    .modify_value   (0),

    .query_entry    (),
    .query_value    ()
);


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