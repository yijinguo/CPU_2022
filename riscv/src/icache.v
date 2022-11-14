module icache #(
      parameter TAG_WIDTH = 20;
      parameter INDEX_SIZE = 30; //need to modify
  )
  (    
    input wire            clk_in,		
    input wire            rst_in,		
	  input wire			      rdy_in,	

    //branch predict
    //todo
    
    //input wire            input_valid,  //1 if need to input new instruction
    input wire [31:0]     input_instr,  //new instruction input

    input wire            pc_update;    //1 if pc is updated
    input wire [31:0]     pc_address;   //new pc address

    input wire            out_valid,    //1 if instruction can to be ouput
    output wire           have_out,     //1 if an instr is output
    output wire [31:0]    instr_out     //new instruction output
  );

reg [31:0] instr_cache[INDEX_SIZE-1:0];  //icache content
reg [INDEX_WIDTH-1:0] valid;  //to record if each index is empty
reg [31:0] current_pc_address;
wire index_head, index_tail;
wire not_full;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
          valid <= 0;
          index_head <= 0;
          index_tail <= 0;
          not_full <= 1;
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
        if (pc_update)
          begin
            valid <= 0;
            index_head <= 0;
            index_tail <= 0;
            current_pc_address <= pc_address;
            not_full <= 1;
          end
        if (not_full) 
          begin
            instr_cache[index_tail] <= input_instr;
            valid[index_tail] <= 1;
            index_tail <= index_tail + 1;
          end
      end
  end

if (index_tail == INDEX_SIZE - 1) begin
  integer i;
  for (i = index_head; i <= index_tail; i=i+1) begin
    instr_cache[i-index_head] = instr_cache[i];
  end 
  assign index_tail = index_tail - index_head;
  assign index_head = 0;
end
if (index_head == 0 && index_tail == INDEX_SIZE - 1) begin
  assign not_full = 0;
end

if (out_valid) begin
  assign have_out = 1;
  assign instr_out = instr_cache[index_head];
  assign index_head = index_head + 1;
  assign not_full = 1;
end 
    
endmodule