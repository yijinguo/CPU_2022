module IF #(
  parameter IF_SIZE = 20; //need to modify
)
(
  input wire          clk_in,		
  input wire          rst_in,		
	input wire			    rdy_in,	

  //from icache
  input  wire         icache_have_input,
  input  wire [31:0]  icache_instr_input,
  input  wire         rob_not_full,    //1 if ROB is not full

  output wire [31:0]  instr_output,
  output wire [16:0]  opcode_out,
  output wire [4:0]   rd_out,
  output wire [4:0]   rs1_out,
  output wire [4:0]   rs2_out,
  output wire [31:0]  imm_out,
  output wire         if_branch,
  output wire         IF_full,
  output wire         IF_empty

);

reg [31:0] instr_queue[IF_SIZE-1:0]; //the size of instruction_queue can be modified
reg[16:0] opcode[IF_SIZE-1:0];  //14:12+6:0
reg[4:0] rd[IF_SIZE-1:0];      //11:7
reg[4:0] rs1[IF_SIZE-1:0];     //19:15
reg[4:0] rs2[IF_SIZE-1:0];     //24:20
reg[31:0] imm[IF_SIZE-1:0];    
wire queue_num;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        current_queue_num <= 0;
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
        if (icache_have_input && queue_num < IF_SIZE-1) begin
          instr_queue[queue_num] <= icache_instr_input;
          opcode[queue_num][6:0] <= icache_instr_input[6:0];
          opcode[queue_num][9:7] <= icache_instr_input[14:12];
          opcode[queue_num][16:10] <= icache_instr_input[31:25];
          rs1[queue_num][19:15] <= icache_instr_input[19:15];
          rs2[queue_num][24:20] <= icache_instr_input[24:20];
          rd[queue_num] <= icache_instr_input[11:7];
          queue_num <= queue_num + 1;
          case (opcode[queue_num][6:0])
            7'b0110111: imm[queue_num][31:12] <= icache_instr_input[31:12];
            7'b0010111: imm[queue_num][31:12] <= icache_instr_input[31:12];                    
            7'b1101111: imm[queue_num][20|10:1|11|19:12] <= icache_instr_input[31:12]; 
            7'b1100111: imm[queue_num][11:0] <= icache_instr_input[31:20];
            7'b1100011: 
              imm[queue_num][12|10:5] <= icache_instr_input[31:25];
              if_branch <= 1;
            7'b0000011: imm[queue_num][11:0] <= icache_instr_input[31:20];
            7'b0100011: 
              imm[queue_num][11:5] <= icache_instr_input[31:25];
              imm[queue_num][4:0] <= icache_instr_input[11:7];
            7'b0010011: 
              case (opcode[queue_num][9:7])
                3'b001:  imm[queue_num][4:0] <= icache_instr_input[24:20];
                3'b101:  imm[queue_num][4:0] <= icache_instr_input[24:20];
                default: imm[queue_num][11:0] <= icache_instr_input[31:20];
              endcase
            default: 
          endcase
        end

        if (rob_not_full && queue_num > 0) begin
          assign instr_output = instr_queue[0];
          assign opcode_out = opcode[0];
          assign rd_out = rd[0];
          assign rs1_out = rs1[0];
          assign rs2_out = rs2[0];
          assign imm_out = imm[0];
          integer i;
          for (i=0; i<queue_num-1; i=i+1) begin
            instr_queue[i] <= instr_queue[i+1];
            opcode[i] = opcode[i+1];
            rd[i] = rd[i+1];
            rs1[i] = rs1[i+1];
            rs2[i] = rs2[i+1];
            imm[i] = imm[i+1];
          end
          queue_num <= queue_num - 1;
        end

        assign IF_empty = (queue_num == 0);
        assign IF_full = (queue_num == IF_SIZE-1);

      end
  end



endmodule