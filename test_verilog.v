module test_verilog(
    input clk,
    input clr,
   output reg [0:6] LED7S
 // output [0:6] LED7S
);

reg [3:0] q;
reg [3:0] d;

// Clock and reset process;negedge clr 

always @(posedge clk or negedge clr) begin 
    if (!clr)
        q <= 4'b0000;
    else if (clk)
        if (q == 4'b1001)
            q <= 4'b0000;
        else
            q <= q + 1;
end

// LED7S output process

always @(q) begin
    case (q)
        4'b0000: LED7S <= 7'b1111110; // X"3F"
        4'b0001: LED7S <= 7'b0110000; // X"06"
        4'b0010: LED7S <= 7'b1101101; // X"5B"
        4'b0011: LED7S <= 7'b1111001; // X"4F"
        4'b0100: LED7S <= 7'b0110011; // X"66"
        4'b0101: LED7S <= 7'b1011011; // X"6D"
        4'b0110: LED7S <= 7'b1011111; // X"7D"
        4'b0111: LED7S <= 7'b1110000; // X"07"
        4'b1000: LED7S <= 7'b1111111; // X"7F"
        4'b1001: LED7S <= 7'b1111011; // X"6F"
        default: LED7S <= 7'b0000000;
    endcase
end


/*
// Assign statement for LED7S
assign LED7S = (q == 4'b0000) ? 7'b1111110 :
               (q == 4'b0001) ? 7'b0110000 :
               (q == 4'b0010) ? 7'b1101101 :
               (q == 4'b0011) ? 7'b1111001 :
               (q == 4'b0100) ? 7'b0110011 :
               (q == 4'b0101) ? 7'b1011011 :
               (q == 4'b0110) ? 7'b1011111 :
               (q == 4'b0111) ? 7'b1110000 :
               (q == 4'b1000) ? 7'b1111111 :
               (q == 4'b1001) ? 7'b1111011 :
               7'b0000000;
*/

endmodule
