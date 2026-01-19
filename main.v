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
    reg btn1_prev, btn2_prev;
    wire btn1_pressed = btn_1 && !btn1_prev;
    wire btn2_pressed = btn_2 && !btn2_prev;

    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            btn1_prev <= 1'b0;
            btn2_prev <= 1'b0;
        end else begin
            btn1_prev <= btn_1;
            btn2_prev <= btn_2;
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

    // 临时变量：用于在一个时钟周期内计算“下一值”，避免用旧值比较引发的越界问题
    reg [3:0] np1, np2, np3, nb1, nb2;
    
    // 状态定义：上电进入 SETTING，按 btn3 确认进入 RUNNING，达到目标瓶数进入 DONE
    localparam SETTING = 2'd0;
    localparam RUNNING = 2'd1;
    localparam DONE    = 2'd2;

    reg [1:0] state,next_state;

    assign target_valid = (target_pills1 || target_pills2 || target_pills3) && (target_bottles1 || target_bottles2);

    // =========================================================================
    // ALWAYS BLOCK 1: 状态寄存器时序逻辑（纯状态转移）
    // 功能：在时钟上升沿更新状态，异步复位
    // =========================================================================
    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            state <= SETTING;
        end else begin
            state <= next_state;
        end
    end

    // =========================================================================
    // ALWAYS BLOCK 2: 次态组合逻辑（纯组合）
    // 功能：根据当前状态和输入条件计算下一状态
    // 注意：组合逻辑中不能检测边沿，因此btn_pressed信号已在顶层定义
    // =========================================================================
    always @(*) begin
        // 默认保持当前状态
        next_state = state;
        
        case (state)
            SETTING: begin
                // SETTING状态下，btn3确认则转移到RUNNING
                if (btn_3 && target_valid) begin
                    next_state = RUNNING;
                end
            end
            
            RUNNING: begin
                // RUNNING状态下，当瓶数达到目标时转移到DONE
                // 原逻辑在btn2_pressed处理中判断，这里直接比较寄存器值
                // 注意：由于非阻塞赋值，比较的是上一周期的值，与原逻辑一致
                if (now_bottles2 == target_bottles2 && now_bottles1 == target_bottles1) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // DONE状态下，btn3按下返回RUNNING
                if (btn_3) begin
                    next_state = RUNNING;
                end
            end
            
            default: next_state = SETTING;
        endcase
    end

    // =========================================================================
    // ALWAYS BLOCK 3: 数据路径时序逻辑（纯数据更新）
    // 功能：更新所有数据寄存器（计数器、目标值、位置等）
    // 与原代码完全一致，仅移除了state赋值
    // =========================================================================
    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            // 异步复位所有数据寄存器
            now_pills1 <= 0; now_pills2 <= 0; now_pills3 <= 0;
            now_bottles1 <= 0; now_bottles2 <= 0;
            target_pills1 <= 1; target_pills2 <= 0; target_pills3 <= 0;
            target_bottles1 <= 1; target_bottles2 <= 0;
            position <= 0;
        end else begin
            // 数据更新逻辑与原代码完全一致
            if (state == SETTING) begin
                if (btn1_pressed) begin
                    if (position == 3'd4) position <= 3'd0;
                    else position <= position + 1'b1;
                end

                if (btn2_pressed) begin
                    case (position)
                        3'd0: target_pills1 <= (target_pills1 == 9) ? 0 : target_pills1 + 1'b1;
                        3'd1: target_pills2 <= (target_pills2 == 9) ? 0 : target_pills2 + 1'b1;
                        3'd2: target_pills3 <= (target_pills3 == 9) ? 0 : target_pills3 + 1'b1;
                        3'd3: target_bottles1 <= (target_bottles1 == 9) ? 0 : target_bottles1 + 1'b1;
                        3'd4: target_bottles2 <= (target_bottles2 == 9) ? 0 : target_bottles2 + 1'b1;
                        default: ;
                    endcase
                end

                // SETTING状态下的state转移已在块2中处理
            end
            else if (state == RUNNING) begin
                if (btn2_pressed) begin
                    // 使用临时变量计算，与原代码完全一致
                    np1 = now_pills1;
                    np2 = now_pills2;
                    np3 = now_pills3;
                    nb1 = now_bottles1;
                    nb2 = now_bottles2;

                    if (np1 == 4'd9) begin
                        np1 = 4'd0;
                        if (np2 == 4'd9) begin
                            np2 = 4'd0;
                            if (np3 == 4'd9) np3 = 4'd0;
                            else np3 = np3 + 1'b1;
                        end else np2 = np2 + 1'b1;
                    end else np1 = np1 + 1'b1;

                    if ((np3 == target_pills3) && (np2 == target_pills2) && (np1 == target_pills1)) begin
                        np1 = 4'd0; np2 = 4'd0; np3 = 4'd0;
                        if (nb1 == 4'd9) begin
                            nb1 = 4'd0;
                            nb2 = nb2 + 1'b1;
                        end else nb1 = nb1 + 1'b1;
                        // 达到目标瓶数的判断已移至块2
                    end

                    now_pills1 <= np1;
                    now_pills2 <= np2;
                    now_pills3 <= np3;
                    now_bottles1 <= nb1;
                    now_bottles2 <= nb2;
                end
            end
            else if (state == DONE) begin
                if (btn_3) begin
                    // 返回RUNNING状态并清零计数
                    now_pills1 <= 0; now_pills2 <= 0; now_pills3 <= 0;
                    now_bottles1 <= 0; now_bottles2 <= 0;
                    // DONE→RUNNING的转移在块2中处理
                end
            end
        end
    end

    
    // ==========================================
    // 显示译码
    // ==========================================
    // 修改 display_1 ~ display_6 的值即可修改显示内容
    // 修改 flicker_mask[0...5] 的值即可启动/关闭闪烁
  
    wire [3:0] display_2 = (state == SETTING) ? target_pills1   : now_pills1;
    wire [3:0] display_3 = (state == SETTING) ? target_pills2   : now_pills2;
    wire [3:0] display_4 = (state == SETTING) ? target_pills3   : now_pills3;
    wire [3:0] display_5 = (state == SETTING) ? target_bottles1 : now_bottles1;
    wire [3:0] display_6 = (state == SETTING) ? target_bottles2 : now_bottles2;


    reg [0:5] flicker_mask;

    assign LED7S2_out = (((~flicker_mask[1]) | clk_4hz) ? display_2 : 4'hf);
    assign LED7S3_out = (((~flicker_mask[2]) | clk_4hz) ? display_3 : 4'hf);
    assign LED7S4_out = (((~flicker_mask[3]) | clk_4hz) ? display_4 : 4'hf);
    assign LED7S5_out = (((~flicker_mask[4]) | clk_4hz) ? display_5 : 4'hf);
    assign LED7S6_out = (((~flicker_mask[5]) | clk_4hz) ? display_6 : 4'hf);


    assign LED7S_out =  (state == SETTING) ? (clk_2hz ? 7'b1001001 : 7'b0000000):
                        (state == RUNNING) ? (clk_4hz ? 7'b0110110 : (clk_2hz ? 7'b0101101 : 7'b0011011))  : 
                        (clk_2hz ? 7'b1011100 : 7'b0000000) ;

    always @(*) begin
        if (state == SETTING) begin
            case (position)
                3'd0 : flicker_mask = 6'b010000;
                3'd1 : flicker_mask = 6'b001000;
                3'd2 : flicker_mask = 6'b000100;
                3'd3 : flicker_mask = 6'b000010;
                3'd4 : flicker_mask = 6'b000001;
                default : flicker_mask = 6'b000000;
            endcase
        end
        else begin
            flicker_mask = 6'b000000;
        end
            
    end
    // ==========================================
    // 蜂鸣器部分（简化：DONE 时 2Hz 蜂鸣用于提示）
    // ==========================================
    assign beep = (state == DONE) ? clk_2hz : 1'b0;

endmodule

