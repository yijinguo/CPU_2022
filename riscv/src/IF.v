module IF (
    input wire          clk_in,		
    input wire          rst_in,		
	input wire			rdy_in,	

    //from icache
    input wire          icache_access_valid, //1 if icache is valid
    input wire [31:0]   icahce_instr_output;

    input wire          rob_full,    //1 if ROB is full
    output wire         instr_ready,
    output wire [31:0]  instr_out, 
);

reg [31:0] instr_queue[20:0]; //the size of instruction_queue can be modified
wire iq_not_full;
wire head, tail;

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
          iq_not_full <= 1;
          head <= 0;
          tail <= 0;
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
        if (iq_not_full && icache_access_valid) begin
            instr_queue[tail] <= icahce_instr_output;
            tail <= tail + 1;
        end
      end
  end

if (head != 0) begin
    integer i;
    for (i = head; i <= tail; i=i+1) begin
        instr_queue[i-head] = instr_queue[i];
    end 
    assign tail = head - tail;
    assign head = 0;
end

if (head == 0 && tail == 0'b19) begin
    assign not_full = 0;
end

if (!rob_full) begin
    assign instr_ready = 1;
    assign instr_out = instr_queue[head];
    assign head = head + 1;
    assign not_full = 1;
end

endmodule