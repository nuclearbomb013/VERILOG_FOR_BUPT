module main(
    input clk_1hz,       // 1Hz 秒时钟 (控制总时长)
    input clk_1khz,      // 1000Hz 音频时钟 (控制嘀嘀嘀的节奏)
    input btn_1,     // Pulse 
    input btn_2,     // QD
    input btn_3_raw,     // CLR(需要翻转)
    input emergncy_stop, // 急停开关
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
    reg clk_4hz; // 4Hz 时钟，用于数码管动画、数码管闪烁和蜂鸣器
    reg clk_2hz; // 2Hz 时钟，用于数码管蜂鸣器
    reg clk_timer; // 计时器时钟，用于切换计时器和漏斗计时器

    always @(posedge clk_1khz) begin
        if (cnt1k == 1000-1)
            cnt1k <= 0;
            clk_timer <= ~clk_timer;
        else
            cnt1k <= cnt1k + 1;
        
        if (cnt1k == 0 || cnt1k == 500)
            clk_2hz <= ~clk_2hz;
        
        if (cnt1k == 0 || cnt1k == 250 || cnt1k == 500 || cnt1k == 750)
            clk_4hz <= ~clk_4hz;
    end
    
    // ==========================================
    // 主状态机
    // ==========================================
    
    reg [9:0] target_pills; // 设定每瓶药片数 0~999
    reg [6:0] target_bottles; // 设定总瓶数 0~99

    reg [9:0] now_pills; // 当前瓶药片数 0~999
    reg [6:0] now_bottles; // 已经完成的瓶数 0~99

    reg [3:0] switch_timer; // 切换计时器，用于判断下一瓶是否到位
    reg [3:0] hopper_timer; // 漏斗计时器，用于判断漏斗是否缺料

    parameter [2:0]
        SETTING  = 3'b000,
        RUNNING  = 3'b001,
        SWITCHING = 3'b010,
        DONE     = 3'b011;
        ERROR    = 3'b100;
        FATAL    = 3'b101;
    reg [2:0] state; // 状态机状态 
    reg [2:0] state_next; // 状态机下一状态

    // 组合逻辑负责判断
    
    always @(*) begin
        case (state)
            SETTING: begin
            end
            RUNNING: begin
            end
            SWITCHING: begin
            end
            DONE: begin
            end
            ERROR: begin
            end
            FATAL: begin
            end
        endcase
    end
    
    // 时序逻辑负责转移
    always @(posedge clk_1khz) begin
        state <= state_next;
    end

    // 切换计时器逻辑
    always @(posedge clk_timer) begin
        
    end

    // 漏斗计时器逻辑
    always @(posedge clk_timer) begin
        
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
        ((anim == 1) ? 7'b0001001 :
         (anim == 2) ? 7'b0010010 : 7'b0100100) : 7'b0000000; // 显示动画

    reg [1:0] anim; // 3帧动画表示

    always @(posedge clk_4hz) begin
        if (anim == 2)
            anim <= 0;
        else
            anim <= anim + 1;
    end


    // ==========================================
    // 蜂鸣器部分
    // ==========================================
    reg [4:0] beep_timer;

    assign beep = ((debug_1) | (debug_2 & clk_2hz) | (debug_3 & clk_4hz)) & clk_1khz;

endmodule