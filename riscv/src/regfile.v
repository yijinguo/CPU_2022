module regfile #(
    parameter REG_SIZE = 32
)(
    input   wire        clk_in,
    input   wire        rst_in,
    input   wire        rdy_in,

    input   wire        query,

    input   wire        reorder,
    input   wire        reorder_entry,
    input   wire        reorder_rd,

    input   wire        modify, 
    input   wire        modify_entry,
    input   wire[4:0]   modify_index,
    input   wire[31:0]  modify_value, 
    
    output  wire        qurey_entry,
    output  wire[31:0]  query_value   

);

reg [31:0] register[REG_SIZE-1:0];  //store the information of reg
reg [4:0] reg_entry[REG_SIZE-1:0];
reg busy[REG_SIZE-1:0];

assign qurey_entry = (query && busy[modify_index]) ? reg_entry[modify_index] : 0;
assign query_value = (query && !busy[modify_index]) ? register[modify_index] : 0;


integer i;
always @(posedge clk_in) begin
    if (rst_in) begin
        for (i=0;i<REG_SIZE;i=i+1) begin
            register[i]<=0;
            reg_entry[i]<=0;
            busy[i] <= 0;
        end
    end
    else if (!rdy_in) begin
        
    end
    else begin
        if (reorder) begin
            reg_entry[reorder_rd] <= reorder_entry;
            busy[reorder_rd] <= 1;
        end
        if (modify) begin
            register[modify_index] <= modify_value;
            if (reg_entry[modify_index] == modify_entry) begin
                reg_entry[modify_index] <= 0;
                busy[modify_index] <= 0;
            end
        end 
    end
end
    
endmodule