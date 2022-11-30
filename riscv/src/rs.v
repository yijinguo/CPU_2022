//instructions in reservation station, [2]=0,5,6

module rs #(
    parameter RS_SIZE = 10; //need to modify
)(
    input   wire            clk_in,
    input   wire            rst_in,
    input   wire            rdy_in,

    input   wire            from_rob, //1: rob has instr input
    input   wire            entry_in,
    input   wire [31:0]     instr_input
    input   wire [3:0]     opcode_in,
    //input wire [4:0]      rd_in,
    input   wire [4:0]      rs1_in,
    input   wire            rs1_q,
    input   wire [4:0]      rs2_in,
    input   wire            rs2_q,
    input   wire [31:0]     imm_in,

    input   wire            have_commit,
    input   wire            entry_commit,
    //input wire            destType_commit, //0: mem; 1: reg; 2:branch; 3:jl(jump&link)
    input   wire[4:0]       destination_commit,
    input   wire[31:0]      value_commit,

    input   wire            need_execute,
    
    output  wire            rs_full,

    output  wire            have_execute
);

reg[4:0] dest_entry[RS_SIZE-1:0];
reg[31:0] instr_origin[RS_SIZE-1:0];
wire[RS_SIZE-1:0] ready;
reg [16:0] opcode[RS_SIZE-1:0];
reg [4:0] vj[RS_SIZE-1:0], vk[RS_SIZE-1:0];
wire [RS_SIZE-1:0] qj, qk;
reg [31:0] imm[RS_SIZE-1:0]; 
wire rs_num;


always @(posedge clk_in)begin
    if (rst_in) begin
        rs_num <= 0;
    end
    else if (!rdy_in) begin
      
    end
    else begin
        //1.store the instruction from ROB;
        if (from_rob) begin
            instr_origin[rs_num] <= instr_input;
            dest_entry[rs_num] <= entry_in;
            ready[rs_num] <= 0;
            opcode[rs_num] <= opcode_in;
            if (rs1_q != 0) begin
                qj[rs_num] <= rs1_q;
            end 
            else begin
                vj[rs_num] <= rs1_in;
            end
            if (rs2_q != 0) begin
                qk[rs_num] <= rs2_q;
            end 
            else begin
                vk[rs_num] <= rs2_in;
            end
            imm[rs_num] <= imm_in;
            rs_num <= rs_num + 1;    
        end

        //2.recall the feedback from cdb (commit);
        if (have_commit) begin
            integer i;
            for (i=0; i< rs_num; i=i+1) begin
                if (qj[i] == entry_commit) begin
                    vj[i] = value_commit[4:0];
                    qj[i] = 0;
                end
                if (qk[i] == entry_commit) begin
                    vk[i] = value_commit[4:0];
                    qk[i] = 0;
                end
                if (qj[i] == 0 && qk[i] == 0) begin
                    ready[i] = 1;
                end
            end
        end

        //3.select the ready ones and excute it, push the exe to the alu;
        if (need_execute) begin
            integer i;
            while (!ready[i] && i!=RS_SIZE) begin
                i=i+1;
            end
            if (i==RS_SIZE) begin
                have_execute <= 0;
            end
            else begin
                have_execute <= 1;

            end
        end

        
    end
end

    
endmodule




/*RS的工作
1.store the instruction from ROB;
2.recall the feedback from cdb (commit);
3.select the ready ones and excute it, push the result inti cdb;
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