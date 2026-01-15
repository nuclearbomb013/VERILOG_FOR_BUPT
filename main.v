module main(
    input clk_1hz,       // 1Hz 秒时钟 (控制总时长)
    input clk_1khz,      // 1000Hz 音频时钟 (控制嘀嘀嘀的节奏)
    input btn_1,     // Pulse 
    input btn_2,     // QD
    input btn_3_raw,     // CLR(需要翻转)
    input simu_hopper_stop, // 漏斗停止信号
    input simu_hopper_add,  // 漏斗手动增加
    input simu_conveyor_stop, // 传送带停止信号
    input debug_1,
    input debug_2,
    input debug_3,
    input debug_4,
    output [6:0] LED7S_out,
    output [3:0] LED7S2_out,
    output [3:0] LED7S3_out,
    output [3:0] LED7S4_out,
    output [3:0] LED7S5_out,
    output [3:0] LED7S6_out,
    output beep
);

    assign btn_3 = ~btn_3_raw;
    assign hopper_signal = simu_hopper_stop? 1'b0 : clk_1hz;

    // ==========================================
    // 分频
    // ==========================================
    reg [9:0] cnt1k;
    reg clk_4hz;
    reg clk_2hz;

    always @(posedge clk_1khz) begin
        if cnt1k == 1000-1:
            cnt1k <= 0;
        else
            cnt1k <= cnt1k + 1;
        
        if (cnt1k == 0 or cnt1k == 500)
            clk_4hz <= ~clk_4hz;
        
        if (cnt1k == 0 or cnt1k == 250 or cnt1k == 500 or cnt1k == 750)
            clk_2hz <= ~clk_2hz;
    end
    

    // ==========================================
    // 显示译码
    // ==========================================
    // 修改 display_1 ~ display_6 的值即可修改显示内容
    // 修改 flicker_mask[0...5] 的值即可启动/关闭闪烁


    wire [3:0] display_1;
    wire [3:0] display_2;
    wire [3:0] display_3;
    wire [3:0] display_4;
    wire [3:0] display_5;
    wire [3:0] display_6;

    // 调试显示
    assign display_1 = 4'h1;
    assign display_2 = 4'h2;
    assign display_3 = 4'h3;
    assign display_4 = 4'h4;
    assign display_5 = 4'h5;
    assign display_6 = 4'h6;

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

    // ==========================================
    // 蜂鸣器部分
    // ==========================================
    reg [4:0] beep_timer;

    assign beep = ((debug_1) | (debug2 & clk_2hz) | (debug3 & clk_4hz)) & clk_1khz;

endmodule