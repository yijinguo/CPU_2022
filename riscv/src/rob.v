module rob #(
    parameter ROB_SIZE = 10; //need to modify
)
(
    input wire             clk_in,
    input wire             rst_in,
	input wire		        rdy_in,

    input wire             have_input,
    input wire [31:0]      instr_input,
    input wire             need_output,
    input wire [16:0]      opcode_if,
    input wire [4:0]       rd_if,
    input wire [4:0]       rs1_if,
    input wire [4:0]       rs2_if,
    input wire [31:0]      imm_if,

    output wire             lsb_or_rs,  //1 arrive lsb
    output wire [31:0]      instr_output
    output wire [16:0]      opcode_out,
    output wire [4:0]       rd_out,
    output wire [4:0]       rs1_out,
    output wire [4:0]       rs2_out,
    output wire [31:0]      imm_out,
    output wire             rob_full   //1 if full
    output wire             rob_empty  //1 if empty

);
//riscv_instruction
reg[31:0] instr_origin[ROB_SIZE-1:0];
reg[16:0] opcode[ROB_SIZE-1:0];  //14:12+6:0
 
wire queue_num;

always @(posedge clk_in)
    begin
        if (rst_in) begin
            queue_num <= 0;
        end
        else if (!rdy_in) begin

        end
        else begin
            if (have_input && queue_num < ROB_SIZE-1) begin
                instr_origin[queue_num] <= instr_input;
               //todo
            end    
            if (need_output && queue_num > 0) begin
                if (opcode[0][6:0] == 7'b0000011 || opcode[0][6:0] == 7'b0100011) begin
                    assign lsb_or_rs = 1;
                end
                else begin
                    assign lsb_or_rs = 0;
                end
                assign instr_output = instr_origin[0];
                assign opcode_out = opcode[0];
                //todo
            end
            assign rob_empty = (queue_num == 0);
            assign rob_full = (queue_num == ROB_SIZE-1);
        end
    end
    
endmodule


/*
    struct ReorderBuffer{
        int entry = 0;
        Code code {};
        State state = Pending;
        int destType = -1; //0:内存；1:寄存器; 2:PC; 3:Jump指令
        uint destination = 0;
        uint value = 0;
        uint pcvalue = 0;
        //int nextEntry = 0;
    };
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