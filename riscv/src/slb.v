module slb #(
    parameter SLB_SIZE = 10
)(
    input   wire            clk_in,
    input   wire            rst_in,
    input   wire            rdy_in,

    input   wire            from_rob,
    input   wire            entry_in,
    input   wire [3:0]      opcode_in,
    input   wire [4:0]      rd_in, 
    input   wire [ 4:0]     rs1_in,
    input   wire [ 4:0]     rs2_in, 
    input   wire [31:0]     imm_in,


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

    input   wire            have_mem_in, //only for load
    input   wire            mem_entry_in,
    input   wire[31:0]      mem_din,

    output  wire            slb_full,
    output  reg             have_cdb_out, //only for load
    output  reg             entry_out,
    output  reg [31:0]      value_out,

    output  reg             slb_need,
    output  reg             mem_entry_out,
    output  reg             mem_wr, //r/w signal
    output  reg [31:0]      mem_addr,
    output  reg [31:0]      mem_dout //only when write
);


reg [SLB_SIZE-1:0] slb_entry;
reg [SLB_SIZE-1:0] state; //0: not ready; 1:ready; 2:waiting(have been commited) 3:completed
reg [3:0] opcode[SLB_SIZE-1:0];
reg [31:0] vj[SLB_SIZE-1:0], vk[SLB_SIZE-1:0];
reg [SLB_SIZE-1:0] qj, qk;
reg [31:0] imm;
reg [63:0] destination[SLB_SIZE-1:0];
reg [63:0] value[SLB_SIZE-1:0];
integer slb_num;

assign slb_full = (slb_num == SLB_SIZE-2);

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

    .query_entry    (qj[slb_num]),
    .query_value    (vj[slb_num])
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

    .query_entry    (qj[slb_num]),
    .query_value    (vj[slb_num])
);

integer i, j;

always @(posedge clk_in) begin
    if (rst_in) begin
        slb_num <= 0;
        state <= 0;
        qj <= 0;
        qk <= 0;
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
                3: begin//load
                    destination[slb_num][4:0] <= rd_in;
                    state[slb_num] <= (qj[slb_num]==0);
                    if (qj[slb_num]==0) value[slb_num][31:0] <= vj[slb_num] + imm_in;
                    qk[slb_num] <= 0;
                end
                4: begin //store
                    if (qj[slb_num]==0) destination[slb_num] <= vj[slb_num] + imm_in;
                    state[slb_num] <= (qj[slb_num]==0 && qk[slb_num]==0);
                end
                default: ;
            endcase
            slb_num <= slb_num + 1;
        end

        //2.recall the feedback from cdb (commit);
         if (have_cdb_rs) begin
            for (i=0;i<slb_num;i=i+1) begin
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
                    state[i] <= 1;
                end
            end
        end

        if (have_cdb_branch) begin
            for (i=0;i<slb_num;i=i+1) begin
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
                    state[i] <= 1;
                end
            end
        end

        if (have_cdb_slb) begin
            for (i=0;i<slb_num;i=i+1) begin
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
                    state[i] <= 1;
                end
            end
        end

        //3.respond to the data from mem 
        if (have_mem_in) begin
            i = 0;
            while (i<slb_num && slb_entry[i] != mem_entry_in) i=i+1;  
            value[i] <= mem_din;          
        end

        //4.select the ready one and throw out its entry to rob for commit;
        i = 0;
        while (i<slb_num && state[i] != 1) i=i+1;
        slb_need <= (i<slb_num);
        if (i<slb_num) begin
            mem_entry_out <= slb_entry[i];
            case (opcode[i][2])
                3: begin//load
                    mem_wr <= 0;
                    mem_addr <= destination[i];
                end
                4: begin //store
                    mem_wr <= 1; //1 for write
                    mem_addr <= destination[i];
                    mem_dout <= value[i];
                end
                default: ;
            endcase
        end
     
        //5.deal with the one that has completed
        //store : how to report to rob?
        i = 0;
        while (i<slb_num && state[i] != 2 ) i=i+1;
        have_cdb_out <= (i<slb_num);
        if (i<slb_num) begin
            entry_out <= slb_entry[i];
            value_out <= value[i];
        end
        for (j=i;j<slb_num-1;j=j+1) begin
            slb_entry[j] <= slb_entry[j+1];
            state[j] <= state[j+1];
            opcode[j] <= opcode[j+1];
            vj[j] <= vj[j+1];
            vk[j] <= vk[j+1];
            qj[j] <= qj[j+1];
            qk[j] <= qk[j+1];
            imm[j] <= imm[j+1];
            destination[j] <= destination[j+1];
            value[j] <= value[j+1];
        end

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