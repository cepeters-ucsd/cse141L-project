// 8 bits wide, 256-word (byte) deep memory array
module dat_mem (
    input[7:0] dat_in,
    input      clk,
    input      wr_en,	          // write enable
    input[7:0] addr,		      // address pointer
    output logic[7:0] dat_out
    );

    logic[7:0] core[256];       // 2-dim array - 8 wide x 256 deep

    // reads are combinational; no enable or clock required
    assign dat_out = core[addr];

    // writes are sequential (clocked) -- occur on stores or pushes 
    always @(posedge clk) begin
        if(wr_en) begin
            core[addr] = dat_in;
        end
    end 

endmodule