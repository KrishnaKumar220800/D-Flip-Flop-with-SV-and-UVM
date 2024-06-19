module dff_new_uvm(input clk, rst, din, output reg dout);

    //input logic clk, rst, din;
    //output reg dout;
    
    always@(posedge clk) begin
        if(rst)
            dout <= 1'b0;
        else
            dout <= din;
    end
    
endmodule:dff_new_uvm
