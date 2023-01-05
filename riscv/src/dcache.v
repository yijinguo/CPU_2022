module dcache #(
    parameter DCACHE_SIZE = 50
)(
    input   wire        clk_in,
    input   wire        rst_in,
    input   wire        rdy_in,
    //directly from memory
    input   wire        have_mem_in, 
    input   wire [ 7:0] mem_din,
    //from slb
    input   wire        have_slb_in,
    input   wire        slb_entry,
    input   wire        slb_wr, //1 for write
    input   wire [31:0] slb_mem_addr,
    input   wire [31:0] slb_mem_dout, //only when write

    //the data read from mem
    output  wire        have_mem_out,
    output  wire        mem_entry_out,
    output  wire [31:0] mem_din_out,
    //directly to memory
    output  wire        mem_signal, //0:do nothing
    output  wire [ 7:0] mem_dout,
    output  wire [31:0] mem_a,
    output  wire        mem_wr //1:write; 0:read
);

reg [DCACHE_SIZE-1:0] entry;
reg [DCACHE_SIZE-1:0] wr_signal;
reg [31:0] mem_address[DCACHE_SIZE-1:0];
reg [ 7:0] mem_data[DCACHE_SIZE-1:0];

reg current_entry;
integer dcache_num;
integer i, j;

assign have_mem_out = have_mem_in;
assign mem_din_out = mem_din; //todo: 十六进制和二进制的转化
assign mem_entry_out = current_entry;

assign mem_signal = dcache_num > 0;
assign mem_dout = (dcache_num>0) ? mem_data[0] : 0;
assign mem_a = (dcache_num>0) ? mem_address[0] : 0;
assign mem_wr = (dcache_num>0) ? wr_signal[0] : 0;

always @(posedge clk_in) begin
    if (rst_in) begin
      current_entry <= 0;
      dcache_num <= 0;
    end
    else if (!rdy_in) begin

    end
    else begin
        if (have_slb_in) begin
            entry[dcache_num] <= slb_entry;
            wr_signal[dcache_num] <= slb_wr;
            mem_address[dcache_num] <= slb_mem_addr;
            mem_data[dcache_num] <= slb_mem_dout; //todo : 转进制
            dcache_num <= dcache_num + 1;
        end
        if (dcache_num > 0) begin
            current_entry <= entry[0];
            for (j=0;j<dcache_num-1;j=j+1) begin
                entry[j] <= entry[j+1];
                wr_signal[j] <= wr_signal[j+1];
                mem_address[j] <= mem_address[j+1];
                mem_data[j] <= mem_data[j+1];
            end
            dcache_num <= dcache_num - 1;
        end

    end
end

endmodule //dcache