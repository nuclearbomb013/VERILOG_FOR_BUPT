module test(
    input clk,
    input clk_audio,          // 音频时钟 CP2(PIN_57): 1KHz/100Hz
    input clr,
    output reg [6:0] LED7S,
    output reg [3:0] LED7S2,
    output reg [3:0] LED7S3,
    output reg [3:0] LED7S4,
    output reg [3:0] LED7S5,
    output reg [3:0] LED7S6,
    output beep               // 扬声器输出 PIN_52 (改为wire)
);

    // 报时使能信号
    reg beep_en;
    // 蜂鸣器输出 = 使能信号 AND 音频时钟
    assign beep = beep_en & clk_audio;

    // 最小位宽 BCD 计数器
    reg [3:0] sec_l;   // 秒个位 0-9 (4位)
    reg [2:0] sec_h;   // 秒十位 0-5 (3位)
    reg [3:0] min_l;   // 分个位 0-9 (4位)
    reg [2:0] min_h;   // 分十位 0-5 (3位)
    reg [3:0] hour_l;  // 时个位 0-9 (4位)
    reg [1:0] hour_h;  // 时十位 0-2 (2位)
    // 总计: 4+3+4+3+4+2 = 20 位寄存器

    // 进位信号 (组合逻辑)
    wire sec_l_max, sec_h_max, min_l_max, min_h_max, hour_max;
    
    assign sec_l_max = (sec_l == 4'b1001);
    assign sec_h_max = (sec_h == 3'b101);
    assign min_l_max = (min_l == 4'b1001);
    assign min_h_max = (min_h == 3'b101);
    assign hour_max  = (hour_h == 2'b10) & (hour_l == 4'b0011);

    // ==========================================
    // 时钟计数逻辑 (级联计数器)
    // ==========================================
    always @(posedge clk or negedge clr) begin
        if (!clr) begin
            sec_l  <= 4'b0000;
            sec_h  <= 3'b000;
            min_l  <= 4'b0000;
            min_h  <= 3'b000;
            hour_l <= 4'b0000;
            hour_h <= 2'b00;
        end
        else begin
            // 秒个位
            if (sec_l_max)
                sec_l <= 4'b0000;
            else
                sec_l <= sec_l + 1'b1;
            
            // 秒十位
            if (sec_l_max) begin
                if (sec_h_max)
                    sec_h <= 3'b000;
                else
                    sec_h <= sec_h + 1'b1;
            end
            
            // 分个位
            if (sec_l_max & sec_h_max) begin
                if (min_l_max)
                    min_l <= 4'b0000;
                else
                    min_l <= min_l + 1'b1;
            end
            
            // 分十位
            if (sec_l_max & sec_h_max & min_l_max) begin
                if (min_h_max)
                    min_h <= 3'b000;
                else
                    min_h <= min_h + 1'b1;
            end
            
            // 时个位和十位
            if (sec_l_max & sec_h_max & min_l_max & min_h_max) begin
                if (hour_max) begin
                    hour_l <= 4'b0000;
                    hour_h <= 2'b00;
                end
                else if (hour_l == 4'b1001) begin
                    hour_l <= 4'b0000;
                    hour_h <= hour_h + 1'b1;
                end
                else begin
                    hour_l <= hour_l + 1'b1;
                end
            end
        end
    end

    // ==========================================
    // 输出赋值
    // ==========================================
    always @(*) begin
        LED7S2 = {1'b0, sec_h};
        LED7S3 = min_l;
        LED7S4 = {1'b0, min_h};
        LED7S5 = hour_l;
        LED7S6 = {2'b00, hour_h};

        case (sec_l)
            4'b0000: LED7S = 7'b0111111;
            4'b0001: LED7S = 7'b0000110;
            4'b0010: LED7S = 7'b1011011;
            4'b0011: LED7S = 7'b1001111;
            4'b0100: LED7S = 7'b1100110;
            4'b0101: LED7S = 7'b1101101;
            4'b0110: LED7S = 7'b1111100;
            4'b0111: LED7S = 7'b0000111;
            4'b1000: LED7S = 7'b1111111;
            4'b1001: LED7S = 7'b1100111;
            default: LED7S = 7'b0000000;
        endcase
        
        // 整点报时逻辑 (测试模式：每分钟报时)
        // 秒=50~58: 预报（间隔响）
        // 秒=59: 过渡
        // 秒=00~04: 正点连续响5秒
        if (sec_h == 3'b101 && sec_l >= 4'b0000 && sec_l <= 4'b1000) begin
            // 50-58秒：预报阶段，偶数秒响
            beep_en = ~sec_l[0];
        end
        else if (sec_h == 3'b101 && sec_l == 4'b1001) begin
            // 59秒：响
            beep_en = 1'b1;
        end
        else if (sec_h == 3'b000 && sec_l <= 4'b0100) begin
            // 00-04秒：正点连续响5秒
            beep_en = 1'b1;
        end
        else begin
            beep_en = 1'b0;
        end
    end

endmodule
