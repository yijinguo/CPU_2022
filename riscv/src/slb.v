module slb #(
    parameter SLB_SIZE = 10;
)(
    input   wire            clk_in,
    input   wire            rst_in,
    input   wire            rdy_in,

    input   wire            from_rob,
    input   wire            entry_in,
    input   wire [3:0]      opcode_in,
    input   wire [4:0]      rd_in,
    input   wire            rs1_q_in,
    input   wire            rs2_q_in,    
    input   wire [31:0]     Rrs1_in,
    input   wire [31:0]     Rrs2_in, 
    input   wire [31:0]     imm_in,

    input wire              entry_commit_in,
    input wire              destType_commit_in, //0: mem; 1: reg; (2:branch; 3:jl(jump&link))
    input wire[4:0]         destination_commit_in,
    input wire[31:0]        value_commit_in,

    output  wire            slb_full,

    output  wire            execute_load_or_store, //0:none; 1:load; 2:store
    output  wire            entry_execute,
    output  wire [63:0]     result
);

//load: execute before commit
//store: execute after commit?

wire [SLB_SIZE-1:0] slb_entry;
wire [SLB_SIZE-1:0] state; //0: not ready; 1:ready; 2:waiting(have been commited) 3:executing 
//0:reg be occupied; 1:ready(can be commited); 2:waiting(load_can_read, store_waiting_for_writing); 3:be store_writing/load_reading
reg [3:0] opcode[SLB_SIZE-1:0];
wire [SLB_SIZE-1:0] rs1_q, rs2_q;
reg [31:0] Rrs1[SLB_SIZE-1:0], Rrs2[SLB_SIZE-1:0];
reg [31:0] imm;
reg [63:0] destination[SLB_SIZE-1:0];
reg [63:0] value[SLB_SIZE-1:0];
wire slb_num;

wire executing; //the loc of the instr that is being executing

always @(posedge clk_in) begin
    if (rst_in) begin
        slb_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        //1.store the instruction from ROB;
        if (from_rob) begin
            slb_entry[slb_num] <= entry_in;
            opcode[slb_num] <= opcode_in;
            imm[slb_num] <= imm_in;
            case (opcode_in[2])
                3: //load
                destination[slb_num][4:0] <= rd_in;
                if (rs1_q_in == 0) begin
                    value[slb_num][31:0] <= Rrs1_in + imm_in;
                    state[slb_num] <= 2;
                end
                else begin
                    rs1_q[slb_num] <= rs1_q_in;
                end
                4: //store
                if (rs1_q_in == 0) begin
                    destination[slb_num][31:0] <= Rrs1_in + imm_in;
                end
                else begin
                    rs1_q[slb_num] <= rs1_q_in;
                end
                if (rs2_q_in == 0) begin
                    value[slb_num][31:0] <= Rrs2_in;
                end
                else begin
                    rs2_q[slb_num] <= rs2_q_in;
                end
                if (rs1_q_in == 0 && rs2_q_in == 0) begin
                    state[slb_num] <= 1;
                end
                default: 
            endcase
            slb_num <= slb_num + 1;
        end

        //2.recall the feedback from cdb (commit);
        if (entry_commit_in != 0) begin
            if (destType_commit_in == 1) begin //reg
                integer i;
                for (i=0; i<slb_num; i=i+1) begin
                    if (rs1_q[i] == entry_commit_in) begin
                        rs1_q[i] <= 0;
                        Rrs1[i] <= value_commit_in;
                        if (opcode[i][2] == 3) begin //load
                            value[i] <= value_commit_in + imm[i];
                            state[i] <= 2;
                        end
                        else begin
                            destination[i] <= value_commit_in + imm[i]; 
                        end
                    end
                    if (rs2_q[i] == entry_commit_in) begin
                        rs2_q[i] <= 0;
                        Rrs2[i] <= value_commit_in;
                        if (opcode[i][2] == 4) begin
                            value[i] <= value_commit_in;
                        end
                    end
                    if (opcode[i][2] == 4) begin
                        if ((rs1_q[i]==0 || rs1_q[i]==entry_commit_in) && (rs2_q[i]==0 || rs2_q[i]==entry_commit_in)) begin
                            state[i] <= 1;
                        end
                    end
                end
            end
            else begin //mem: inform slb to execute the entry
                integer i;
                i=0;
                while (slb_entry[i] != entry_commit_in) begin
                    i=i+1;
                end
                state[i] <= 2;
            end
        end

        //3.select the ready one and throw out its entry to rob for commit;
        integer i;
        while (i<slb_num && state[i] != 1) begin
            i=i+1;
        end
        if (i<slb_num) begin 
            if (opcode[i][2] == 3) begin
                execute_load_or_store <= 1;
                entry_execute <= entry[i]; 
                result <= value[i];
                integer j;
                for (j=i;j<slb_num-1;j=j+1) begin
                    slb_entry[j] <= slb_entry[j+1];
                    state[j] <= state[j+1];
                    opcode[j] <= opcode[j+1];
                    rs1_q[j] <= rs1_q[j+1];
                    rs2_q[j] <= rs2_q[j+1];
                    Rrs1[j] <= Rrs1[j+1];
                    Rrs2[j] <= Rrs2[j+1];
                    imm[j] <= imm[j+1];
                    destination[j] <= destination[j+1];
                    value[j] <= value[j+1];
                end
            end
            else begin
                execute_load_or_store <= 2;
                entry_execute <= entry[i];
            end
        end
        else begin
            execute_load_or_store <= 0;
        end

        //4.continue the execution of the instr load/store
        //?
        //todo
    end
end
    
endmodule


/*slb的动作
1.store the instruction from ROB;
2.recall the feedback from cdb (commit);
    1)op[2]=3/4  execute the content
    2)op[2]=0/1/5/6  modify the information
3.select the ready ones(state:1) and throw out its entry;
    1)load: load_reading has completed
    2)store: store waiting for commit to write
4.continue the execution of the instr load/store

*/