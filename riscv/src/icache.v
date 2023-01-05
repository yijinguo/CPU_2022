module icache #(
    parameter ICACHE_SIZE = 50
)(
    input wire            clk_in,		
    input wire            rst_in,		
	input wire			  rdy_in,

    input wire [ 7:0]     mem_din,	

    input wire            pc_update,   //1 if pc is updated
    input wire [31:0]     pc_address,   //new pc address

    input wire            out_valid,    //1 if instruction can to be ouput

    output wire           have_out,     //1 if an instr is output
    output wire [31:0]    instr_out,    //new instruction output
    output wire [31:0]    instr_pc_out
);

reg [31:0] instr_cache[ICACHE_SIZE-1:0];  //icache content
reg [31:0] instr_pc[ICACHE_SIZE-1:0];

//reg [ICACHE_SIZE-1:0] valid;  //to record if each index is empty
reg [31:0] current_pc_address;
reg index_head, index_num;
integer not_full;

integer i;

assign have_out = 1;
assign instr_out = instr_cache[index_head];
assign instr_pc_out = instr_pc[index_head];

initial begin
    index_head <= index_head + 1;
end

always @(posedge clk_in) begin
    if (rst_in) begin
        current_pc_address <= 0;
        index_head <= 0;
        index_num <= 0;
        not_full <= 1;
    end
    else if (!rdy_in) begin
        
    end
    else begin
        if (pc_update) begin
            current_pc_address <= pc_update ? pc_address : (current_pc_address + 4*ICACHE_SIZE);
            index_head <= 0;
            index_num <= 0;
            instr_cache[0] <= mem_din; //todo:做一个数值转换
            instr_pc[0] <= pc_update ? pc_address : (current_pc_address + 4*ICACHE_SIZE);
        end
        else begin
            index_num <= index_num + 1;
            instr_cache[index_num] <= mem_din; //todo:做一个数值转换
            instr_pc[index_num] <= current_pc_address + index_num * 4; 
        end
        //icache如果满了,删去已经输出的内容
        if (index_num == ICACHE_SIZE - 2) begin
            for (i=index_head + 1; i<index_num; i=i+1) begin
                instr_cache[i-index_head] <= instr_cache[i];
                instr_pc[i-index_head] <= instr_pc[i];
            end
            index_head <= 0;
            index_num <= index_num - index_head;
        end
        
    end
end

endmodule 