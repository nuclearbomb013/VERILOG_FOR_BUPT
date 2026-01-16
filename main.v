module main(
    input clk_1hz, 
    input clk_1khz,      // 假设输入是 1000Hz
    input btn_1, 
    input btn_2, 
    input btn_3_raw, 
    input emergncy_stop, 
    input switch_clr, 
    input simu_hopper_stop, 
    input simu_hopper_add, 
    input simu_conveyor_stop, 
    output [6:0] LED7S_out,
    output [3:0] LED7S2_out,
    output [3:0] LED7S3_out,
    output [3:0] LED7S4_out,
    output [3:0] LED7S5_out,
    output [3:0] LED7S6_out,
    output beep
);
    
    // 1. 输入消抖处理
    wire btn_3;
    assign btn_3 = ~btn_3_raw; 

    reg btn1_prev, btn2_prev, btn3_prev;
    wire btn1_pressed = btn_1 && !btn1_prev;
    wire btn2_pressed = btn_2 && !btn2_prev;
    wire btn3_pressed = btn_3 && !btn3_prev;
    
    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            btn1_prev <= 1'b0; btn2_prev <= 1'b0; btn3_prev <= 1'b0;
        end else begin
            btn1_prev <= btn_1; btn2_prev <= btn_2; btn3_prev <= btn_3;
        end
    end

    // ==========================================
    // 2. 终极省资源分频 (修复了复位，解决了频率快的问题)
    // ==========================================
    // 9位计数器 (0~511)
    // 资源消耗：仅 9 个寄存器，无比较逻辑
    reg [8:0] divider_cnt; 

    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) 
            divider_cnt <= 0; // 【关键】必须复位，否则计数器不走！
        else 
            divider_cnt <= divider_cnt + 1'b1; // 自然溢出，循环计数
    end

    // 直接取位作为时钟信号 (Wire直连，无需逻辑)
    // 1000Hz / 256 = 3.9Hz (用于闪烁)
    // 1000Hz / 512 = 1.95Hz (用于报警)
    wire clk_4hz = divider_cnt[7]; 
    wire clk_2hz = divider_cnt[8];

    // ==========================================
    // 3. 状态机与业务逻辑
    // ==========================================
    reg [3:0] target_pills1, target_pills2, target_pills3;
    reg [3:0] target_bottles1, target_bottles2;
    reg [2:0] position; // 3位宽
    reg [3:0] now_pills1, now_pills2, now_pills3;
    reg [3:0] now_bottles1, now_bottles2;

    localparam SETTING = 2'd0;
    localparam RUNNING = 2'd1;
    localparam DONE    = 2'd2;
    localparam ERROR   = 2'd3;
    reg [1:0] state;

    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            state <= SETTING;
            now_pills1 <= 0; now_pills2 <= 0; now_pills3 <= 0;
            now_bottles1 <= 0; now_bottles2 <= 0;
            target_pills1 <= 1; target_pills2 <= 0; target_pills3 <= 0;
            target_bottles1 <= 1; target_bottles2 <= 0;
            position <= 3'd0;
        end else begin
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
                if (btn3_pressed) begin
                    state <= RUNNING;
                    now_pills1 <= 0; now_pills2 <= 0; now_pills3 <= 0;
                    now_bottles1 <= 0; now_bottles2 <= 0;
                end
            end
            else if (state == RUNNING) begin
                if (btn2_pressed) begin
                    if (now_pills1 == 9) begin
                        now_pills1 <= 0;
                        if (now_pills2 == 9) begin
                            now_pills2 <= 0;
                            if (now_pills3 == 9) now_pills3 <= 0;
                            else now_pills3 <= now_pills3 + 1'b1;
                        end else now_pills2 <= now_pills2 + 1'b1;
                    end else now_pills1 <= now_pills1 + 1'b1;

                    if ((now_pills3 == target_pills3) && (now_pills2 == target_pills2) && (now_pills1 == target_pills1)) begin
                        now_pills1 <= 0; now_pills2 <= 0; now_pills3 <= 0;
                        if (now_bottles1 == 9) begin
                            now_bottles1 <= 0;
                            now_bottles2 <= now_bottles2 + 1'b1;
                        end else now_bottles1 <= now_bottles1 + 1'b1;

                        if ((now_bottles2 == target_bottles2) && (now_bottles1 == target_bottles1)) begin
                            state <= DONE;
                        end
                    end
                end
            end
            else if (state == DONE) begin
                if (btn3_pressed) begin
                    state <= SETTING;
                    now_pills1 <= 0; now_pills2 <= 0; now_pills3 <= 0;
                    now_bottles1 <= 0; now_bottles2 <= 0;
                end
            end
        end
    end

    // ==========================================
    // 4. 显示逻辑 (确保位宽匹配，无锁存器)
    // ==========================================
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
    assign LED7S_out = 7'b0000000;

    always @(*) begin
        if (state == SETTING) begin
            // 这里全部使用 3'd 匹配 position 的 3位宽
            case (position)
                3'd0 : flicker_mask = 6'b010000;
                3'd1 : flicker_mask = 6'b001000;
                3'd2 : flicker_mask = 6'b000100;
                3'd3 : flicker_mask = 6'b000010;
                3'd4 : flicker_mask = 6'b000001;
                default: flicker_mask = 6'b000000; // 必须加 default
            endcase
        end
        else begin
            flicker_mask = 6'b000000;
        end
    end

    assign beep = (state == DONE) ? clk_2hz : 1'b0;

endmodule