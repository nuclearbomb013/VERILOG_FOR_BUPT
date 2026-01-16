module main(
    input clk_1hz,       // 1Hz 秒时钟 (控制总时长)
    input clk_1khz,      // 1000Hz 音频时钟 (控制嘀嘀嘀的节奏)
    input btn_1,     // Pulse 
    input btn_2,     // QD
    input btn_3_raw,     // CLR(需要翻转)
    input emergncy_stop, // 急停开关
    input switch_clr,      // 复位开关
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
    assign hopper_level = ((simu_hopper_stop & state == RUNNING) ? 1'b0 : clk_1hz) | simu_hopper_add; 
    // 漏斗装药原信号，假设每秒自动装药只在运行状态下有效
    wire hopper_signal;
    assign conveyor_signal = ~simu_conveyor_stop; // 传送带正常运行信号

    // ==========================================
    // 漏斗脉冲转换
    // ==========================================
    reg hopper_level_prev; // 漏斗装药信号
    assign hopper_signal = (hopper_level_prev == 1'b0 && hopper_level == 1'b1);

    always @(posedge clk_1khz) begin
        hopper_level_prev <= hopper_level;
    end

    // ==========================================
    // 分频
    // ==========================================
    reg [9:0] cnt1k;
    reg clk_4hz; // 4Hz 时钟，用于数码管动画、数码管闪烁和蜂鸣器
    reg clk_2hz; // 2Hz 时钟，用于数码管蜂鸣器
    reg clk_timer; // 计时器时钟，用于切换计时器和漏斗计时器

    always @(posedge clk_1khz) begin
        if (cnt1k == 1000-1) begin
            cnt1k <= 0;
            clk_timer <= ~clk_timer;
        end else
            cnt1k <= cnt1k + 1;
        
        if (cnt1k == 0 || cnt1k == 500)
            clk_2hz <= ~clk_2hz;
        
        if (cnt1k == 0 || cnt1k == 250 || cnt1k == 500 || cnt1k == 750)
            clk_4hz <= ~clk_4hz;
    end
    
    // ==========================================
    // 主状态机
    // ==========================================
    
    reg [3:0] target_pills1; // 设定每瓶药片数 0~999 个位
    reg [3:0] target_pills2; // 设定每瓶药片数 0~999 十位
    reg [3:0] target_pills3; // 设定每瓶药片数 0~999 百位
    reg [3:0] target_bottles1; // 设定总瓶数 0~99 个位
    reg [3:0] target_bottles2; // 设定总瓶数 0~99 十位
    reg position; //数位

    reg [3:0] now_pills1; // 当前瓶药片数 0~999 个位
    reg [3:0] now_pills2; // 当前瓶药片数 0~999 十位
    reg [3:0] now_pills3; // 当前瓶药片数 0~999 百位
    reg [3:0] now_bottles1; // 已经完成的瓶数 0~99 个位
    reg [3:0] now_bottles2; // 已经完成的瓶数 0~99 十位

    reg [3:0] switch_timer; // 切换计时器，用于判断下一瓶是否到位
    reg [3:0] hopper_timer; // 漏斗计时器，用于判断漏斗是否缺料

    parameter [2:0]
        SETTING  = 3'b000, // 0
        RUNNING  = 3'b001, // 1
        SWITCHING = 3'b010, // 2
        DONE     = 3'b011, // 3
        ERROR    = 3'b100, // 4
        FATAL    = 3'b101; // 5
    reg [2:0] state; // 状态机状态 
    reg [2:0] state_next; // 状态机下一状态

    // 组合逻辑负责判断
    
    always @(*) begin
        state_next = state;
        if (emergncy_stop) begin
            state_next = FATAL; // 急停开关触发，报严重错误
        end else begin
            case (state)
                SETTING: begin
                end
                RUNNING: begin
                    if (now_pills == target_pills) begin
                        if (now_bottles == target_bottles)
                            state_next = DONE; //装瓶完毕
                        else 
                            state_next = SWITCHING; //切换瓶
                    end else if (hopper_timer == 0) begin
                        state_next = ERROR; // 未收到漏斗信号，报缺料错误
                    end
                end
                SWITCHING: begin
                    if (switch_timer == 0) begin
                        if () // 检测装药数量
                            state_next = FATAL; // 装药数量异常，报超标严重错误
                        else if (conveyor_signal)
                            state_next = RUNNING; // 传送带正常运行，开始装瓶
                        else
                            state_next = ERROR; // 传送带停止，报传送带错误
                    end
                end
                DONE: begin
                    if () // 接受任意按钮信号
                        state_next = SETTING; // 复位
                end
                ERROR: begin
                    if (conveyor_signal || hopper_timer != 0) // 若恢复正常
                        state_next = RUNNING; // 继续工作
                end
                FATAL: begin
                    if () // 接受任意按钮信号
                        state_next = SETTING; // 复位
                end
            endcase
        end
    end
    
    // 时序逻辑负责处理和转移
    always @(posedge clk_1khz) begin
        if (clk_1khz) begin
            if (state == state_next) begin  
                case (state) // 工作逻辑
                    SETTING: begin
                    end
                    RUNNING: begin
                        // 进行计数
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
            end else begin 
                case (state_next) // 状态转移
                    SETTING: begin
                    end
                    RUNNING: begin
                        // 进入运行态，计数器清零，蜂鸣器短鸣
                    end
                    SWITCHING: begin
                        // 进入切换态，设置切换计时器2s
                    end
                    DONE: begin
                        
                    end
                    ERROR: begin
                    end
                    FATAL: begin
                    end
                endcase
                state <= state_next;
            end
        end 

        
    end

    // 切换计时器逻辑
    always @(posedge clk_timer) begin
        if (switch_timer != 0)
            switch_timer <= switch_timer - 1;
    end

    // 漏斗计时器逻辑
    always @(posedge clk_timer) begin
        if (hopper_timer != 0)
            hopper_timer <= hopper_timer - 1;
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
    assign display_1 = state;
    assign display_2 = state == SETTING ? target_pills1 : now_pills1;
    assign display_3 = state == SETTING ? target_pills2 : now_pills2;
    assign display_4 = state == SETTING ? target_pills3 : now_pills3;
    assign display_5 = state == SETTING ? target_bottles1 : now_bottles1;
    assign display_6 = state == SETTING ? target_bottles2 : now_bottles2;

    reg [0:5] flicker_mask;

    assign LED7S2_out = ~ flicker_mask[1] | clk_4hz ? display_2 : 4'hf;
    assign LED7S3_out = ~ flicker_mask[2] | clk_4hz ? display_3 : 4'hf;
    assign LED7S4_out = ~ flicker_mask[3] | clk_4hz ? display_4 : 4'hf;
    assign LED7S5_out = ~ flicker_mask[4] | clk_4hz ? display_5 : 4'hf;
    assign LED7S6_out = ~ flicker_mask[5] | clk_4hz ? display_6 : 4'hf;
    assign LED7S_out = (~ flicker_mask[0] | clk_4hz) ?
                        ((display_1 == 0) ? 7'b1001001 : 
                         (display_1 == 1) ? ((anim == 1) ? 7'b0001001 :
                                           (anim == 2) ? 7'b0010010 : 7'b0100100) :
                         (display_1 == 2) ? ((anim == 1) ? 7'b0110000 :
                                           (anim == 2) ? 7'b1000000 : 7'b0000110) :
                         (display_1 == 3) ? ((anim == 1) ? 7'b0111111 :
                                           (anim == 2) ? 7'b0111111 : 7'b0000000) :
                         (display_1 == 4) ? 7'b1111001 :
                         (display_1 == 5) ? 7'b1110001 : 7'b0000000) : 7'b0000000;

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
    reg [4:0] beep_timer; // 蜂鸣器计时器(单位：250ms)
    assign beep_always = state == DONE;
    assign beep_2hz = state == ERROR;
    assign beep_4hz = state == FATAL;
    
    always @(clk_4hz) begin
        if (beep_timer != 0)
            beep_timer <= beep_timer - 1;
    end

    assign beep = ((beep_timer | beep_always) | (beep_2hz & clk_2hz) | (beep_4hz & clk_4hz)) & clk_1khz;

endmodule