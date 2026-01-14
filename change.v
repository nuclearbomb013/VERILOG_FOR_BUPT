module change(
    input  key_to_change, 
    input  button_for_change,
    input  button_for_add, 
    input  clk,
    output [6:0] LED7S,
    output [3:0] LED7S2,
    output [3:0] LED7S3,
    output [3:0] LED7S4,
    output [3:0] LED7S5,
    output [3:0] LED7S6,
    output reg beep
);
    // 变量定义
    reg [1:0] hour_h;
    reg [3:0] hour_l;
    reg [2:0] min_h;
    reg [3:0] min_l;
    reg [1:0] position;
    reg [2:0] sec_h;
    reg [3:0] sec_l;
    
    // 边沿检测变量
    reg prev_change, prev_add;
    wire pulse_change, pulse_add;

    // 1. 生成脉冲
    // ==========================================
    // 1. 历史记录模块 (像照相机一样记录上一刻的状态)
    // ==========================================
    always @(posedge clk) begin
        // 单纯地记录当前按钮的状态，留给下一个时钟周期做比较
        prev_change <= button_for_change; 
        prev_add    <= button_for_add;    
    end
    
    // ==========================================
    // 2. 脉冲生成模块 (逻辑判断)
    // ==========================================
    
    // 逻辑 A: 检测 button_for_change 的下降沿 (1 -> 0)
    // 解读：现在是0 (按下去了) 并且 (!) 刚才还是1 (prev_change)
    assign pulse_change = (!button_for_change && prev_change); 
    
    // 逻辑 B: 检测 button_for_add 的上升沿 (0 -> 1)
    // 解读：现在是1 (按下去了) 并且 (&&) 刚才还是0 (!prev_add)
    assign pulse_add    = (button_for_add && !prev_add);
    
    // 2. 蜂鸣器
    always @(posedge clk) beep <= (pulse_change || pulse_add);
    
    // 3. 显示连接
    assign LED7S  = 7'b0111111; 
    assign LED7S2 = {1'b0, sec_h}; 
    assign LED7S3 = min_l;         
    assign LED7S4 = {1'b0, min_h}; 
    assign LED7S5 = hour_l;        
    assign LED7S6 = {2'b00, hour_h};
    
    // 4. 核心逻辑
    always @(posedge clk) begin
        if (key_to_change == 0) begin
            
            position <= 0;
            
        end 
        else begin // 
            sec_l <= 0;
            sec_h <= 0;
            
            
            if (pulse_change) begin 
                position <= position + 1;
            end
            
            
            if (pulse_add) begin
                case (position) // 【修正4】拼写 position
                    2'd0: min_l  <= (min_l == 9)  ? 0 : min_l + 1;
                    2'd1: min_h  <= (min_h == 5)  ? 0 : min_h + 1;
                    2'd2: hour_l <= (hour_l == 9) ? 0 : hour_l + 1;
                    2'd3: hour_h <= (hour_h == 2) ? 0 : hour_h + 1;
                endcase
            end
            
            // 非法时间修正
            if (hour_h == 2 && hour_l > 3) begin
                hour_l <= 0;
            end
            
        end 
    end 

endmodule