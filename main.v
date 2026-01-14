module main(
    input clk_1hz,            // 1Hz 秒时钟 (控制总时长)
    input clk_1khz,      // 1000Hz 音频时钟 (控制嘀嘀嘀的节奏)
    input button_1,     // Pulse 
    input button_2,     // QD
    input button_3_raw,     // CLR(需要翻转)
    input switch_clr,      // 复位信号
    input switch_setting,  // 校时设定开关
    input switch_alarm, // 闹钟开关
    input switch_stopwatch, // 秒表开关
    input switch_debug1, // 调试开关1
    input switch_debug2, // 调试开关2
    input switch_debug3, // 调试开关3
    output [6:0] LED7S_out,
    output [3:0] LED7S2_out,
    output [3:0] LED7S3_out,
    output [3:0] LED7S4_out,
    output [3:0] LED7S5_out,
    output [3:0] LED7S6_out,
    output beep
);
    assign button_3 = ~button_3_raw; // 翻转

    // ==========================================
    // 精确计时和分频
    // ==========================================    

    reg [9:0] cnt1000;
    reg clk_4hz;
    reg rhythm; // 音频用节拍信号

    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            cnt1000 <= 10'd0;
        end
        else begin        
            if (cnt1000 >= 10'd999) 
                cnt1000 <= 10'd0;
            else 
                cnt1000 <= cnt1000 + 1'b1;

            if (cnt1000 == 10'd249 || cnt1000 == 10'd499 || cnt1000 == 10'd749 || cnt1000 == 10'd999)
            clk_4hz <= ~clk_4hz;

            if (cnt1000 == 10'd0 || cnt1000 == 10'd200 || cnt1000 == 10'd400)
                rhythm <= 1'b1;
            
            if (cnt1000 == 10'd100 || cnt1000 == 10'd300 || cnt1000 == 10'd500)
                rhythm <= 1'b0;
        end

    end

    // ==========================================
    // 显示译码
    // ==========================================
    
    wire [3:0] display_1;
    wire [3:0] display_2;
    wire [3:0] display_3;
    wire [3:0] display_4;
    wire [3:0] display_5;
    wire [3:0] display_6;

    assign display_1 = 4'd1;
    assign display_2 = 4'd2;
    assign display_3 = 4'd3;
    assign display_4 = 4'd4;
    assign display_5 = 4'd5;
    assign display_6 = 4'd6;

    reg [0:5] flicker_mask;

    assign LED7S2_out = ~ flicker_mask[1] | clk_4hz ? display_2 : 4'hf;
    assign LED7S3_out = ~ flicker_mask[2] | clk_4hz ? display_3 : 4'hf;
    assign LED7S4_out = ~ flicker_mask[3] | clk_4hz ? display_4 : 4'hf;
    assign LED7S5_out = ~ flicker_mask[4] | clk_4hz ? display_5 : 4'hf;
    assign LED7S6_out = ~ flicker_mask[5] | clk_4hz ? display_6 : 4'hf;
    assign LED7S_out = (~ flicker_mask[0] | clk_4hz) ? 
        ((display_1 == 4'h0) ? 7'b0111111 :
        (display_1 == 4'h1) ? 7'b0000110 :
        (display_1 == 4'h2) ? 7'b1011011 :
        (display_1 == 4'h3) ? 7'b1001111 :
        (display_1 == 4'h4) ? 7'b1100110 :
        (display_1 == 4'h5) ? 7'b1101101 :
        (display_1 == 4'h6) ? 7'b1111100 :
        (display_1 == 4'h7) ? 7'b0000111 :
        (display_1 == 4'h8) ? 7'b1111111 :
        (display_1 == 4'h9) ? 7'b1100111 :
        7'b0000000) : 7'b0000000;

    always @(*) begin
        flicker_mask[3] = switch_debug2;
        flicker_mask[4] = switch_debug3;
    end

    // ==========================================
    // 音频部分
    // ==========================================

    reg [4:0] beep_timer;
    assign beep_enable = (beep_timer != 0) || switch_debug1;
    assign beep = beep_enable && rhythm && clk_1khz;

    always @(posedge clk_1hz) begin
        if (beep_timer > 0) beep_timer <= beep_timer - 1;

        if (switch_debug2)
            beep_timer <= 4'd5;
        
    end

endmodule