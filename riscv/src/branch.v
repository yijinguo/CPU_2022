`include "define.v"

module branch #(
    parameter BRANCH_SIZE = 10
)(
    input   wire            clk_in,
    input   wire            rst_in,
	input   wire		    rdy_in,

    //if rob have input
    input   wire            have_input,
    input   wire            entry_input,
    input   wire [3:0]      opcode_input,
    input   wire [31:0]     pc_address_input,
    input   wire [ 4:0]     rs1_input,
    input   wire [ 4:0]     rs2_input,
    input   wire [31:0]     imm_input,
    
    //if cdb have update
    input   wire            have_cdb_rs,
    input   wire            entry_cdb_rs,
    input   wire            new_entry_cdb_rs,
    input   wire [31:0]     value_cdb_rs,

    input   wire            have_cdb_branch,
    input   wire            entry_cdb_branch,
    input   wire            new_entry_cdb_branch,
    input   wire [31:0]     value_cdb_branch,

    input   wire            have_cdb_slb,
    input   wire            entry_cdb_slb,
    input   wire            new_entry_cdb_slb,
    input   wire [31:0]     value_cdb_slb,

    //if have output: to cdb
    output  wire            have_out,
    output  wire            entry_out,
    //output  reg             destType_out, //branch:0;jump:1
    output  reg             if_pc_change_out,
    output  reg [31:0]      new_pc_address_out,
    output  reg [31:0]      value_out
);


reg [3:0] opcode[BRANCH_SIZE-1:0];
reg [31:0] pc_address[BRANCH_SIZE-1:0];
reg [BRANCH_SIZE-1:0] entry;
reg [BRANCH_SIZE-1:0] ready;
reg [31:0] vj[BRANCH_SIZE-1:0], vk[BRANCH_SIZE-1:0];
reg [BRANCH_SIZE-1:0] qj, qk;
reg [31:0] imm[BRANCH_SIZE-1:0]; 

integer branch_num;

integer i, j;

regfile reg_query_1(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),
    .query      (1),
    .reorder    (0),
    .reorder_entry  (0),
    .reorder_rd     (0),
    .modify         (0),
    .modify_entry   (0),
    .modify_index   (rs1_input),
    .modify_value   (0),

    .query_entry    (qj[branch_num]),
    .query_value    (vj[branch_num])
);

regfile reg_query_2(
    .clk_in     (clk_in),
    .rst_in     (rst_in),
    .rdy_in     (rdy_in),
    .query      (1),
    .reorder    (0),
    .reorder_entry  (0),
    .reorder_rd     (0),
    .modify         (0),
    .modify_entry   (0),
    .modify_index   (rs2_input),
    .modify_value   (0),

    .query_entry    (qk[branch_num]),
    .query_value    (vk[branch_num])
);


//push result into cdb
initial begin
    i = 0;
    while (!ready[i] && i<branch_num) i=i+1;
    case (opcode[i])
                `BEQ: begin
                    //destType_out <= 0;
                    if (vj[i]==vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                end
                `BNE: begin
                    //destType_out <= 0;
                    if (vj[i]!=vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                end
                `BLT: begin
                    //destType_out <= 0;
                    if (vj[i]<vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                end
                `BGE: begin
                    //destType_out <= 0;
                    if (vj[i]>=vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                end
                `BLTU: begin
                    //destType_out <= 0;
                    if (vj[i]<vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                end
                `BGEU: begin
                    //destType_out <= 0;
                    if (vj[i]>=vk[i]) begin
                        if_pc_change_out <= 1;
                        new_pc_address_out <= pc_address[i] + imm[i];
                    end
                    else begin
                        if_pc_change_out <= 0;
                    end
                end
                `JAL: begin
                    //destType_out <= 1;
                    if_pc_change_out <= 1;
                    value_out <= pc_address[i] + 4;
                    new_pc_address_out <= pc_address[i] + imm[i];
                end
                `JALR: begin
                    //destType_out <= 1;
                    if_pc_change_out <= 1;
                    value_out <= pc_address[i] + 4;
                    new_pc_address_out <= vj[i] + imm[i];
                end
                default: ;
    endcase
    for (j=i; j<branch_num-1; j=j+1) begin
        opcode[j]<=opcode[j+1];
        pc_address[j]<=pc_address[j+1];
        entry[j]<=entry[j+1];
        ready[j]<=ready[j+1];
        vj[j]<=vj[j+1];
        vk[j]<=vk[j+1];
        qj[j]<=qj[j+1];
        qk[j]<=qk[j+1];
        imm[j]<=imm[j+1];
    end
    branch_num <= branch_num-1;
end

assign have_out = (i<branch_num); 
assign entry_out = entry[i];

always @(posedge clk_in) begin
    if (rst_in) begin
        branch_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        //rob have input
        if (have_input) begin
            opcode[branch_num] <= opcode_input;
            pc_address[branch_num] <= pc_address_input;
            entry[branch_num] <= entry_input;
            imm[branch_num] <= imm_input;
            case (opcode_input[2])
                1: begin
                    if (opcode_input == `JAL) begin
                        qj[branch_num] <= 0;
                        qk[branch_num] <= 0;
                        ready[branch_num] <= 1;
                    end
                    else begin
                        qk[branch_num] <= 0;
                        ready[branch_num] <= qj[branch_num]==0;
                    end
                end
                default: ready[branch_num] <= (!qj[branch_num] && !qk[branch_num]);
            endcase
            branch_num <= branch_num + 1;
        end
        
        //if cdb have data

        if (have_cdb_rs) begin
            for (i=0;i<branch_num;i=i+1) begin
                if (qj[i]==entry_cdb_rs) begin
                    qj[i] <= (new_entry_cdb_rs==0) ? 0 : new_entry_cdb_rs;
                    vj[i] <= value_cdb_rs;
                end
                if (qk[i]==entry_cdb_rs) begin
                    qk[i] <= (new_entry_cdb_rs==0) ? 0 : new_entry_cdb_rs;
                    vk[i] <= value_cdb_rs;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_rs && new_entry_cdb_rs==0)) 
                && ( qk[i]==0 || (qk[i]==entry_cdb_rs && new_entry_cdb_rs==0)) ) begin
                    ready[i] <= 1;
                end
            end
        end

        if (have_cdb_branch) begin
            for (i=0;i<branch_num;i=i+1) begin
                if (qj[i]==entry_cdb_branch) begin
                    qj[i] <= (new_entry_cdb_branch==0) ? 0 : new_entry_cdb_branch;
                    vj[i] <= value_cdb_branch;
                end
                if (qk[i]==entry_cdb_branch) begin
                    qk[i] <= (new_entry_cdb_branch==0) ? 0 : new_entry_cdb_branch;
                    vk[i] <= value_cdb_branch;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_branch && new_entry_cdb_branch==0)) 
                && ( qk[i]==0 || (qk[i]==entry_cdb_branch && new_entry_cdb_branch==0)) ) begin
                    ready[i] <= 1;
                end
            end
        end

        if (have_cdb_slb) begin
            for (i=0;i<branch_num;i=i+1) begin
                if (qj[i]==entry_cdb_slb) begin
                    qj[i] <= (new_entry_cdb_slb==0) ? 0 : new_entry_cdb_slb;
                    vj[i] <= value_cdb_slb;
                end
                if (qk[i]==entry_cdb_slb) begin
                    qk[i] <= (new_entry_cdb_slb==0) ? 0 : new_entry_cdb_slb;
                    vk[i] <= value_cdb_slb;
                end
                if ( (qj[i]==0 || (qj[i]==entry_cdb_slb && new_entry_cdb_slb==0)) 
                && ( qk[i]==0 || (qk[i]==entry_cdb_slb && new_entry_cdb_slb==0)) ) begin
                    ready[i] <= 1;
                end
            end
        end



    end
end

    
endmodule