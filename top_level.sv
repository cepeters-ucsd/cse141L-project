// top level design
module top_level(
    input clk, reset, 
    output logic done
    );

    parameter   D = 10,             // program counter width
                A = 3,             	// ALU command bit width
                R = 3;              // register bit width

    wire[D-1:0] target, 			// jump address
                prog_ctr;

    wire[7:0]   datA, datB, dat0,	// from RegFile
                NonRegData,         // data from ALU or data memory
                RegData,            // data from register file
                DataIn,             // true data into register file
                dmOut;              // data memory output
    
    wire[R-1:0] DestReg,
                ReadAddr;
    
    wire branchEnable;      

    // ALU outputs
    wire[7:0] rslt;         // alu output
    logic   sc_o,           // carry out from shift
            notequal,
            lessthan;

    // ALU inputs
    logic   sc_in;   	    // carry in for shift

    // control output signals
    wire    RegDst,
            Branch,                   // absolute branching
            MemWrite,
            RegWrite,
            MemtoReg,
            RegtoReg,
            SinChange,
            RegRead;                    
    
    wire[8:0]   mach_code;            // machine code
    wire[A-1:0] alu_cmd;                  
    wire[R-1:0] rd_addrA, rd_addrB;    // address pointers to reg_file
    wire[3:0]   immed;
    wire [2:0]  typeselect;

    // machine code breakdown
    assign alu_cmd  = mach_code[8:6];
    assign rd_addrA = mach_code[5:3];
    assign rd_addrB = mach_code[2:0];
    assign immed = mach_code[3:0];
    assign typeselect = mach_code[2:0];

    assign branchEnable = Branch && (notequal || lessthan);  // for bne and blt

    // fetch subassembly
    PC #(.D(D)) pc1 (					  // D sets pc width
            .reset,
            .clk,
            .absjump_en(branchEnable),
            .target,
            .prog_ctr);

    // lookup table to facilitate jumps/branches
    PC_LUT #(.D(D)) pl1 (
            .addr(dat0),
            .target);   

    // contains machine code
    instr_ROM #(.D(D)) ir1(
            .prog_ctr,
            .mach_code);

    // control decoder
    Control ctl1(
            .instr(alu_cmd),
            .typeselect,
            .RegDst, 
            .Branch, 
            .MemWrite,
            .RegWrite,     
            .MemtoReg,
            .RegtoReg,              // enable reg to reg move
            .SinChange,             // enable carry in to change  
            .RegRead);                    

    assign NonRegData = MemtoReg ? dmOut : rslt;        // data for standard operation
    assign RegData = !RegDst ? datA : dat0;             // data for reg to reg moves
    assign DataIn = RegtoReg ? RegData : NonRegData;    // true data into register file
    assign DestReg = RegDst ? rd_addrA : 3'b0;          // which register to write into
    assign ReadAddr = RegRead ? rd_addrA : 3'b0;        // which register to read from

    reg_file #(.pw(R)) rf1(
            .dat_in(DataIn),
            .clk,
            .wr_en(RegWrite),
            .rd_addrA(ReadAddr),
            .rd_addrB(rd_addrB),
            .wr_addr(DestReg),
            .datA_out(datA),
            .datB_out(datB),
            .dat0_out(dat0)); 

    
    alu alu1(
            .alu_cmd,
            .inA(datA),
            .inB(datB),
            .sc_in,                      
            .typeselect,
            .immed,
            .rslt,
            .sc_o,
            .notequal,
            .lessthan);  

    dat_mem dm1(
            .dat_in(datA),          // always writing data from RA
            .clk,
            .wr_en(MemWrite),       // store enable
            .addr(dat0),            // always use R0 as the address
            .dat_out(dmOut));

    

    // sc_in update logic
    always_ff @(posedge clk) begin
        if (reset)
            sc_in <= 1'b0;
        else if (SinChange)
            sc_in <= sc_o;
        else
            sc_in <= sc_in;
    end

    assign done = (mach_code == 0);
 
endmodule