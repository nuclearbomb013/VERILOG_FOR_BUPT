module test(
    input clk,
    input clr,          // 假定为低电平有效 (根据原代码 negedge)
    output reg [6:0] LED7S,  // 修正为标准 [6:0] 格式，个位秒（手动译码）
    output reg [3:0] LED7S2, // 十位秒（BCD）
    output reg [3:0] LED7S3, // 个位分（BCD）
    output reg [3:0] LED7S4, // 十位分（BCD）
    output reg [3:0] LED7S5, // 个位时（BCD）
    output reg [3:0] LED7S6  // 十位时（BCD）
);

    reg [5:0] sec;
    reg [5:0] min;
    reg [4:0] hour;
    
    // 用于辅助译码的临时变量
    reg [3:0] sec_unit_val; 

    // ==========================================
    // 1. 时钟计数与复位逻辑 (Clock and Reset)
    // ==========================================
    always @(posedge clk or negedge clr) begin
        if (!clr) begin
            // 异步复位：按下复位键时清零
            sec <= 0;
            min <= 0;
            hour <= 0;
        end
        else begin
            // 正常计数逻辑
            if (sec >= 59) begin
                sec <= 0;
                if (min >= 59) begin
                    min <= 0;
                    if (hour >= 23)
                        hour <= 0;
                    else
                        hour <= hour + 1;
                end
                else begin
                    min <= min + 1;
                end
            end
            else begin
                sec <= sec + 1;
            end
        end
    end

    // ==========================================
    // 2. 数位分离与输出逻辑 (Output Process)
    // ==========================================
    always @(*) begin
        // --- 数位分离部分 (完成你的任务1) ---
        
        // 秒 (sec)
        sec_unit_val = sec % 10;     // 取模得个位
        LED7S2       = sec / 10;     // 除法得十位
        
        // 分 (min)
        LED7S3       = min % 10;     // 个位
        LED7S4       = min / 10;     // 十位
        
        // 时 (hour)
        LED7S5       = hour % 10;    // 个位
        LED7S6       = hour / 10;    // 十位

        // --- 手动译码部分 (针对秒的个位) ---
        // 假设是共阴极还是共阳极取决于硬件，这里沿用你提供的编码
        // 4'b0000 -> 7'b1111110 (0x7E, 看起来像共阴极的高电平点亮，或者是共阳极的低电平有效)
        case (sec_unit_val)
			4'd0: LED7S <= 7'b0111111; // 0: a,b,c,d,e,f 亮
            4'd1: LED7S <= 7'b0000110; // 1: b,c 亮
            4'd2: LED7S <= 7'b1011011; // 2: a,b,d,e,g 亮
            4'd3: LED7S <= 7'b1001111; // 3: a,b,c,d,g 亮
            4'd4: LED7S <= 7'b1100110; // 4: b,c,f,g 亮
            4'd5: LED7S <= 7'b1101101; // 5: a,c,d,f,g 亮
            4'd6: LED7S <= 7'b1111100; // 6: c,d,e,f,g 亮
            4'd7: LED7S <= 7'b0000111; // 7: a,b,c 亮
            4'd8: LED7S <= 7'b1111111; // 8: 全亮
            4'd9: LED7S <= 7'b1100111; // 9: a,b,c,f,g 亮
			default: LED7S <= 7'b0000000;
        endcase
    end

endmodule