//instructions in reservation station, [2]=0,5,6

`include "define.v"

module rs #(
    parameter RS_SIZE = 10 //need to modify
)(
    input   wire            clk_in,
    input   wire            rst_in,
    input   wire            rdy_in,

    input   wire            from_rob, //1: rob has instr input
    input   wire            entry_in,
    input   wire [3:0]      opcode_in,
    input   wire [31:0]     pc_address_in,
    input   wire [ 4:0]     rs1_in,
    input   wire [ 4:0]     rs2_in,
    input   wire [31:0]     imm_in,

    input   wire            have_cdb_rs,
    input   wire            entry_cdb_rs,           
    input   wire            new_entry_cdb_rs,
    input   wire[31:0]      value_cdb_rs,

    input   wire            have_cdb_branch,
    input   wire            entry_cdb_branch,        
    input   wire            new_entry_cdb_branch,
    input   wire[31:0]      value_cdb_branch,

    input   wire            have_cdb_slb,
    input   wire            entry_cdb_slb,          
    input   wire            new_entry_cdb_slb,
    input   wire[31:0]      value_cdb_slb,
    
    output  wire            rs_full,

    output  wire            have_execute,
    output  reg             entry_execute,
    output  reg [31:0]      result
);

reg [RS_SIZE-1:0] dest_entry[RS_SIZE-1:0];
reg [RS_SIZE-1:0] ready;
reg [3:0] opcode[RS_SIZE-1:0];
reg [31:0] pc_address[RS_SIZE-1:0];
reg [31:0] vj[RS_SIZE-1:0], vk[RS_SIZE-1:0];
reg [RS_SIZE-1:0] qj, qk;
reg [31:0] imm[RS_SIZE-1:0]; 
integer rs_num;

reg [3:0] op;
reg [31:0] op1, op2;

integer i,j;

regfile reg_query_1(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),
    .query      (1),
    .reorder    (0),
    .reorder_entry  (0),
    .reorder_rd     (0),
    .modify     (0),
    .modify_entry   (0),
    .modify_index   (rs1_in),
    .modify_value   (0),

    .query_entry    (qj[rs_num]),
    .query_value    (vj[rs_num])
);

regfile reg_query_2(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),
    .query      (1),
    .reorder    (0),
    .reorder_entry  (0),
    .reorder_rd     (0),
    .modify     (0),
    .modify_entry   (0),
    .modify_index   (rs2_in),
    .modify_value   (0),

    .query_entry    (qk[rs_num]),
    .query_value    (vk[rs_num])
);

assign rs_full = (rs_num == RS_SIZE - 2);

always @(posedge clk_in)begin
    if (rst_in) begin
        rs_num <= 0;
        ready <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        //1.store the instruction from ROB;
        if (from_rob) begin
            dest_entry[rs_num] <= entry_in;
            //ready[rs_num] <= 0;
            opcode[rs_num] <= opcode_in;
            pc_address[rs_num] <= pc_address_in;
            case (opcode_in[2])
                0: begin
                    vj[rs_num] <= imm_in;
                    vk[rs_num] <= pc_address_in;
                    qj[rs_num] <= 0;
                    qk[rs_num] <= 0;
                    ready[rs_num] <= 1;
                end
                5: begin
                    if (qj[rs_num] == 0) begin
                        ready[rs_num] <= 1;
                    end
                    else begin
                        ready[rs_num] <= 0;
                    end
                    qk[rs_num] <= 0;
                end
                6: begin
                    if (qj[rs_num] == 0 && qk[rs_num] == 0) begin
                        ready[rs_num] <= 1;
                    end
                    else begin
                        ready[rs_num] <= 0;
                    end
                end
                default: ;
            endcase
            imm[rs_num] <= imm_in;
            rs_num <= rs_num + 1;  
        end

        //2.recall the feedback from cdb;
        if (have_cdb_rs) begin
            for (i=0;i<rs_num;i=i+1) begin
                if (qj[i]==entry_cdb_rs) begin
                    qj[i] <= (new_entry_cdb_rs==0) ? 0 : new_entry_cdb_rs; 
                    vj[i] <= value_cdb_rs;
                end
                if (qk[i]==entry_cdb_rs) begin
                    qk[i] <= (new_entry_cdb_rs==0) ? 0 : new_entry_cdb_rs; 
                    vk[i] <= value_cdb_rs;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_rs && new_entry_cdb_rs==0)) 
                    && (qk[i]==0 || (qk[i]==entry_cdb_rs && new_entry_cdb_rs==0)) ) begin
                    ready[i] = 1;
                end
            end
        end
        if (have_cdb_branch) begin
            for (i=0;i<rs_num;i=i+1) begin
                if (qj[i]==entry_cdb_branch) begin
                    qj[i] <= (new_entry_cdb_branch==0) ? 0 : new_entry_cdb_branch; 
                    vj[i] <= value_cdb_branch;
                end
                if (qk[i]==entry_cdb_branch) begin
                    qk[i] <= (new_entry_cdb_branch==0) ? 0 : new_entry_cdb_branch; 
                    vk[i] <= value_cdb_branch;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_branch && new_entry_cdb_branch==0)) 
                    && (qk[i]==0 || (qk[i]==entry_cdb_branch && new_entry_cdb_branch==0)) ) begin
                    ready[i] = 1;
                end
            end
        end
        if (have_cdb_slb) begin
            for (i=0;i<rs_num;i=i+1) begin
                if (qj[i]==entry_cdb_slb) begin
                    qj[i] <= (new_entry_cdb_slb==0) ? 0 : new_entry_cdb_slb; 
                    vj[i] <= value_cdb_slb;
                end
                if (qk[i]==entry_cdb_slb) begin
                    qk[i] <= (new_entry_cdb_slb==0) ? 0 : new_entry_cdb_slb; 
                    vk[i] <= value_cdb_slb;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_slb && new_entry_cdb_slb==0)) 
                    && (qk[i]==0 || (qk[i]==entry_cdb_slb && new_entry_cdb_slb==0)) ) begin
                    ready[i] = 1;
                end
            end
        end

    end
end

//3.select the ready ones and excute it, push the exe to the alu;
always @(posedge clk_in) begin
    if (rst_in) begin
        
    end
    else if (!rdy_in) begin
        
    end
    else begin
        i = 0;
        while (!ready[i] && i!=RS_SIZE) i=i+1;
        entry_execute <= (i<rs_num+1) ? dest_entry[i] : 0;
        op1 <= vj[i];
        op2 <= vk[i];
        case (opcode[i])
            `AUIPC: op <= `Add;
            `ADDI: op <= `Add; 
            `SLTI: op <= `Lthan;
            `SLTIU: op <= `Lthan;
            `XORI: op <= `Xor;
            `ORI: op <= `Or;
            `ANDI: op <= `And;
            `SLLI: op <= `Lshift;
            `SRLI: op <= `Rshift;
            `SRAI: op <= `Rshift; 
            `ADD: op <= `Add;
            `SUB: op <= `Sub;
            `SLL: op <= `Lshift;
            `SLT: op <= `Lthan;
            `SLTU: op <= `Lthan;
            `XOR: op <= `Xor;
            `SRL: op <= ``Or;
            `SRA: op <= `Rshift;
            `OR: op <= `Or;
            `AND: op <= `And;
            default: ;
        endcase
        for (j=i; j<rs_num; j=j+1) begin
            dest_entry[j] <= dest_entry[j+1];
            pc_address[j] <= pc_address[j+1];
            ready[j] <= ready[j+1];
            opcode[j] <= opcode[j+1];
            vj[j] <= vj[j+1];
            vk[j] <= vk[j+1];
            qj[j] <= qj[j+1];
            qk[j] <= qk[j+1];
            imm[j] <= imm[j+1];
        end
        rs_num <= rs_num-1;
    end 
end

assign have_execute = (i<rs_num+1);

ALU alu_execute(
    .op1    (op1),
    .op2    (op2),
    .op     (op),
    .result (result)
);
    
endmodule




/*RS的工作
1.store the instruction from ROB;
2.recall the feedback from cdb (commit);
3.select the ready ones and execute it, push the result into cdb;
*/

/*
    struct ReservationStations{
        bool ready = false;
        int only_sl = 3;
        uint code = 0;
        CommandType op {};
        uint vj = 0, qj = 0;
        uint vk = 0, qk = 0;
        uint pc = 0;
        int dest = 0;
        uint A = 0x00000000;
    };
    */