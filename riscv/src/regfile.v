module regfile #(
    parameter REG_SIZE = 32;
)(
    input   wire        query_or_modify, //0:query;1:modify
    input   wire[4:0]   reg_index,
    input   wire[63:0]  modify_value, //if modify
    
    output  wire[63:0]  query_value   //if query
    
);

reg[63:0] register[REG_SIZE-1:0];  //store the information of reg

if (query_or_modify == 0) begin
    assign query_value = register[reg_index];
end
else begin
    register[reg_index] <= modify_value;
end
    
endmodule