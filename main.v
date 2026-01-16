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
    output [6:0] LED7S_out,
    output [3:0] LED7S2_out,
    output [3:0] LED7S3_out,
    output [3:0] LED7S4_out,
    output [3:0] LED7S5_out,
    output [3:0] LED7S6_out,
    output beep
);
    
    wire btn_3;
    assign btn_3 = ~btn_3_raw; // CLR按键取反，按下为高电平

    // 简单按键上升沿检测（同步到 clk_1khz）
    reg btn1_prev, btn2_prev, btn3_prev;
    wire btn1_pressed = btn_1 && !btn1_prev;
    wire btn2_pressed = btn_2 && !btn2_prev;
    wire btn3_pressed = btn_3 && !btn3_prev;
    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            btn1_prev <= 1'b0;
            btn2_prev <= 1'b0;
            btn3_prev <= 1'b0;
        end else begin
            btn1_prev <= btn_1;
            btn2_prev <= btn_2;
            btn3_prev <= btn_3;
        end
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
    reg [2:0] position; //数位

    reg [3:0] now_pills1; // 当前瓶药片数 0~999 个位
    reg [3:0] now_pills2; // 当前瓶药片数 0~999 十位
    reg [3:0] now_pills3; // 当前瓶药片数 0~999 百位
    reg [3:0] now_bottles1; // 已经完成的瓶数 0~99 个位
    reg [3:0] now_bottles2; // 已经完成的瓶数 0~99 十位

    // 状态定义：上电进入 SETTING，按 btn3 确认进入 RUNNING，达到目标瓶数进入 DONE
    localparam SETTING = 2'd0;
    localparam RUNNING = 2'd1;
    localparam DONE    = 2'd2;
    localparam ERROR   = 2'd3;

    reg [1:0] state;


    // 目标/当前数值仍保持每位寄存器表示（便于数码管显示）
    // 已移除漏斗上升沿检测（测试时不使用）
    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            state <= SETTING;
            // 清零当前计数
            now_pills1 <= 4'd0; now_pills2 <= 4'd0; now_pills3 <= 4'd0;
            now_bottles1 <= 4'd0; now_bottles2 <= 4'd0;
            // 初始化目标为
            target_pills1 <= 4'd1; target_pills2 <= 4'd0; target_pills3 <= 4'd0;
            target_bottles1 <= 4'd1; target_bottles2 <= 4'd0;
            position <= 3'd0;
        end else begin
            // 设置态：btn1 切位，btn2 增加所选位，btn3 确认开始计数
            if (state == SETTING) begin
                if (btn1_pressed) begin
                    // 循环切换 0..4（3位药片 + 2位瓶数）
                    if (position == 3'd4) position <= 3'd0;
                    else position <= position + 1'b1;
                end

                if (btn2_pressed) begin
                    case (position)
                        3'd0: target_pills1 <= (target_pills1 == 4'd9) ? 4'd0 : target_pills1 + 1'b1;
                        3'd1: target_pills2 <= (target_pills2 == 4'd9) ? 4'd0 : target_pills2 + 1'b1;
                        3'd2: target_pills3 <= (target_pills3 == 4'd9) ? 4'd0 : target_pills3 + 1'b1;
                        3'd3: target_bottles1 <= (target_bottles1 == 4'd9) ? 4'd0 : target_bottles1 + 1'b1;
                        3'd4: target_bottles2 <= (target_bottles2 == 4'd9) ? 4'd0 : target_bottles2 + 1'b1;
                        default: ;
                    endcase
                end

                if (btn3_pressed) begin
                    // 确认设置，进入计数模式（RUNNING），从 0 开始计数
                    state <= RUNNING;
                    now_pills1 <= 4'd0; now_pills2 <= 4'd0; now_pills3 <= 4'd0;
                    now_bottles1 <= 4'd0; now_bottles2 <= 4'd0;
                end
            end
            // 计数态：去掉对漏斗加药和急停信号的依赖，改为手动 btn2 作为测试计数脉冲
            else if (state == RUNNING) begin
                // 测试用：按 btn2 手动增加药片计数（用于验证计数逻辑）
                if (btn2_pressed) begin
                    // 增加药片计数（逐位进位）
                    if (now_pills1 == 4'd9) begin
                        now_pills1 <= 4'd0;
                        if (now_pills2 == 4'd9) begin
                            now_pills2 <= 4'd0;
                            if (now_pills3 == 4'd9) now_pills3 <= 4'd0;
                            else now_pills3 <= now_pills3 + 1'b1;
                        end else now_pills2 <= now_pills2 + 1'b1;
                    end else now_pills1 <= now_pills1 + 1'b1;

                    // 判断是否达到目标药片数（比较三位）
                    if ((now_pills3 == target_pills3) && (now_pills2 == target_pills2) && (now_pills1 == target_pills1)) begin
                        // 抵达目标：清药片计数，增加瓶数（逐位进位）
                        now_pills1 <= 4'd0; now_pills2 <= 4'd0; now_pills3 <= 4'd0;
                        if (now_bottles1 == 4'd9) begin
                            now_bottles1 <= 4'd0;
                            now_bottles2 <= now_bottles2 + 1'b1;
                        end else now_bottles1 <= now_bottles1 + 1'b1;

                        // 检查是否达到目标瓶数，达到则进入 DONE
                        if ((now_bottles2 == target_bottles2) && (now_bottles1 == target_bottles1)) begin
                            // 达到目标瓶数 -> 完成
                            state <= DONE;
                        end
                    end
                end

                
            end
            // 完成态：短按 btn3 返回设置模式（重置当前计数）
            else if (state == DONE) begin
                if (btn3_pressed) begin
                    state <= SETTING;
                    now_pills1 <= 4'd0; now_pills2 <= 4'd0; now_pills3 <= 4'd0;
                    now_bottles1 <= 4'd0; now_bottles2 <= 4'd0;
                end
            end
            else if (state == ERROR) begin
                // 错误态：按 btn3 返回设置
                if (btn3_pressed) begin
                    state <= SETTING;
                    now_pills1 <= 4'd0; now_pills2 <= 4'd0; now_pills3 <= 4'd0;
                    now_bottles1 <= 4'd0; now_bottles2 <= 4'd0;
                end
            end
        end
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

    // 调试显示：SETTING 显示目标，其他态显示当前
    assign display_1 = state;
    assign display_2 = (state == SETTING) ? target_pills1   : now_pills1;
    assign display_3 = (state == SETTING) ? target_pills2   : now_pills2;
    assign display_4 = (state == SETTING) ? target_pills3   : now_pills3;
    assign display_5 = (state == SETTING) ? target_bottles1 : now_bottles1;
    assign display_6 = (state == SETTING) ? target_bottles2 : now_bottles2;

    reg [0:5] flicker_mask;

    assign LED7S2_out = (((~flicker_mask[1]) | clk_4hz) ? display_2 : 4'hf);
    assign LED7S3_out = (((~flicker_mask[2]) | clk_4hz) ? display_3 : 4'hf);
    assign LED7S4_out = (((~flicker_mask[3]) | clk_4hz) ? display_4 : 4'hf);
    assign LED7S5_out = (((~flicker_mask[4]) | clk_4hz) ? display_5 : 4'hf);
    assign LED7S6_out = (((~flicker_mask[5]) | clk_4hz) ? display_6 : 4'hf);
    assign LED7S_out = 7'b0000000;

    always @(*) begin
        if (state == SETTING) begin
            case (position)
                2'd0 : flicker_mask = 6'b010000;
                2'd1 : flicker_mask = 6'b001000;
                2'd2 : flicker_mask = 6'b000100;
                2'd3 : flicker_mask = 6'b000010;
                2'd4 : flicker_mask = 6'b000001;
            endcase
        end
        else begin
            flicker_mask = 6'b000000;
        end
            
    end
    // ==========================================
    // 蜂鸣器部分（简化：DONE 时 2Hz 蜂鸣用于提示）
    // ==========================================
    // remove complex/undefined signals and keep simple behavior
    assign beep = (state == DONE) ? clk_2hz : 1'b0;

endmodule

