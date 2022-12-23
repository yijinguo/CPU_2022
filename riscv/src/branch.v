`include "define.v"

module branch #(
    parameter BRANCH_SIZE = 10;
)(
    input   wire            clk_in,
    input   wire            rst_in,
	input   wire		    rdy_in,

    //if rob have input
    input   wire            have_input,
    input   wire            entry_input,
    input   wire [31:0]     instr_input,
    input   wire [3:0]      opcode_input,
    input   wire [31:0]     pc_address_input,
    input   wire            rs1_input,
    input   wire [31:0]     Rs1_value,
    input   wire            rs2_input,
    input   wire [4:0]      Rs2_value,
    input   wire [31:0]     imm_input,
    
    //if cdb have update
    input   wire            have_modify,
    input   wire            entry_modify,
    input   wire [31:0]     value_modify,

    //if have output
    output  wire            have_out,
    output  wire            entry_out,
    output  wire            destType_out, //branch:0;jump:1
    output  wire            if_pc_change_out,
    output  wire [31:0]     new_pc_address_out,
    output  wire [31:0]     value_out

);

reg [31:0] instr_origin[BRANCH_SIZE-1:0];
reg [3:0] opcode[BRANCH_SIZE-1:0];
reg [31:0] pc_address[BRANCH_SIZE-1:0];
wire [BRANCH_SIZE-1:0] entry;
wire [BRANCH_SIZE-1:0] ready;
reg [31:0] vj[BRANCH_SIZE-1:0], vk[BRANCH_SIZE-1:0];
wire [RS_SIZE-1:0] qj, qk;
reg [31:0] imm[BRANCH_SIZE-1:0]; 

wire branch_num;

always @(posedge clk_in) begin
    if (rst_in) begin
        branch_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        //rob have input
        if (have_input) begin
            instr_origin[branch_num] <= instr_input;
            opcode[branch_num] <= opcode_input;
            pc_address[branch_num] <= pc_address_input;
            entry[branch_num] <= entry_input;
            imm[branch_num] <= imm_input;
            if (!rs1_input && !rs2_input) begin
                ready[branch_num] <= 1;
            end
            else begin
                ready[branch_num] <= 0;
            end
            if (rs1_input) begin
                qj[branch_num] <= rs1_input;
            end
            else begin
                vj[branch_num] <= Rs1_value;
            end
            if (rs2_input) begin
                qk[branch_num] <= rs2_input;
            end
            else begin
                vk[branch_num] <= Rs2_value;
            end
            branch_num <= branch_num + 1;
        end

        //push result into cdb
        integer i;
        while (!ready[i] && i<BRANCH_SIZE) begin
            i=i+1;
        end
        if (i==BRANCH_SIZE) begin
            have_out <= 0;
        end
        else begin
            have_out <= 1;
            entry_out <= entry[i];
            case (opcode[i])
                `BEQ: 
                    destType_out <= 0;
                    if (vj[i]==vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                `BNE:
                    destType_out <= 0;
                    if (vj[i]!=vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                `BLT:
                    destType_out <= 0;
                    if (vj[i]<vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                `BGE:
                    destType_out <= 0;
                    if (vj[i]>=vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                `BLTU:
                    destType_out <= 0;
                    if (vj[i]<vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                `BGEU:
                    destType_out <= 0;
                    if (vj[i]>=vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                `JAL:
                    destType_out <= 1;
                    if_pc_change_out <= 1;
                    value_out <= pc_address[i] + 4;
                    new_pc_address_out <= pc_address[i] + imm[i];
                `JALR: 
                    destType_out <= 1;
                    if_pc_change_out <= 1;
                    value_out <= pc_address[i] + 4;
                    new_pc_address_out <= vj[i] + imm[i];
                default: 
            endcase
            integer j;
            for (j=i; j<branch_num-1; j=j+1) begin
                instr_origin[j]<=instr_origin[j+1];
                opcode[j]<=opcode[j+1];
                pc_address[j]<=pc_address[j+1];
                entry[j]<=entry[j+1];
                ready[j]<=ready[j+1];
                vj[j]<=vj[j+1], vk[j]<=vk[j+1];
                qj[j]<=qj[j+1], qk[j]<=qk[j+1];
                imm[j]<=imm[j+1];
            end
            branch_num <= branch_num-1;
        end
        
        //if cdb have data




    end
  end






    
endmodule