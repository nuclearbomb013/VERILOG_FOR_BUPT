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

    // 分频器和节拍生成器
    // 从 1kHz 时钟分频出：
    // - clk_4hz: 4Hz 信号，用于闪烁显示
    // - rhythm: 蜂鸣器节拍信号 (每秒3声"嘀嘀嘀")    

    reg [9:0] cnt1000;  // 0~999 毫秒计数器
    reg clk_4hz;        // 4Hz 方波，用于闪烁效果
    reg rhythm;         // 蜂鸣器节拍

    always @(posedge clk_1khz or negedge switch_clr) begin
        if (!switch_clr) begin
            cnt1000 <= 10'd0;
        end
        else begin        
            // 毫秒计数器:0->999->0循环
            if (cnt1000 >= 10'd999) 
                cnt1000 <= 10'd0;
            else 
                cnt1000 <= cnt1000 + 1'b1;

            // 4Hz 分频: 每 250ms 翻转一次 
            if (cnt1000 == 10'd249 || cnt1000 == 10'd499 || cnt1000 == 10'd749 || cnt1000 == 10'd999)
            clk_4hz <= ~clk_4hz;

            // 蜂鸣器节拍: 每秒3声，每声100ms
            if (cnt1000 == 10'd0 || cnt1000 == 10'd200 || cnt1000 == 10'd400)
                rhythm <= 1'b1;
            
            if (cnt1000 == 10'd100 || cnt1000 == 10'd300 || cnt1000 == 10'd500)
                rhythm <= 1'b0;
        end

    end

    // 当前模式
    // 0: 电子钟模式
    // 1: 校时模式
    // 2: 闹钟模式
    // 3: 秒表模式
    wire [1:0] mode = switch_stopwatch ? 2'd3 :
                    switch_alarm    ? 2'd2 :
                    switch_setting  ? 2'd1 : 2'd0;       

    // 电子钟逻辑
    reg [3:0] clock_sec_l;
    reg [2:0] clock_sec_h;
    reg [3:0] clock_min_l;
    reg [2:0] clock_min_h;
    reg [3:0] clock_hour_l;
    reg [1:0] clock_hour_h;
    
    
    //alarm_beep_enable
    reg [1:0] alarm_beep_enable;
    
    //使能进位
    wire en_clock_sec_h, en_clock_min_l, en_clock_min_h, en_clock_hour_l;
    
    assign en_clock_sec_h  = (clock_sec_l == 4'd9);
    assign en_clock_min_l  = (clock_sec_h == 3'd5) && en_clock_sec_h;
    assign en_clock_min_h  = (clock_min_l == 4'd9) && en_clock_min_l;
    assign en_clock_hour_l = (clock_min_h == 3'd5) && en_clock_min_h;
    
    wire hour_reset; 
    assign hour_reset = (clock_hour_h == 2'd2 && clock_hour_l == 4'd3);

    // 时间走字逻辑 
    always @(posedge clk_1hz or negedge switch_clr) begin
        if (!switch_clr) 
            clock_sec_l <= 4'd0;
        else if (load_from_setting) 
            clock_sec_l <= 4'd0;
        else case (clock_sec_l)
            4'd9:    clock_sec_l <= 4'd0;
            default: clock_sec_l <= clock_sec_l + 1'b1;
        endcase
    end

    always @(posedge clk_1hz or negedge switch_clr) begin
        if (!switch_clr) 
            clock_sec_h <= 3'd0;
        else if (load_from_setting) 
            clock_sec_h <= 3'd0;
        else if (en_clock_sec_h) case (clock_sec_h)
            3'd5:    clock_sec_h <= 3'd0;
            default: clock_sec_h <= clock_sec_h + 1'b1;
        endcase
    end

    always @(posedge clk_1hz or negedge switch_clr) begin
        if (!switch_clr) 
            clock_min_l <= 4'd0;
        else if (load_from_setting) 
            clock_min_l <= setting_min_l;
        else if (en_clock_min_l) case (clock_min_l)
            4'd9:    clock_min_l <= 4'd0;
            default: clock_min_l <= clock_min_l + 1'b1;
        endcase
    end

    always @(posedge clk_1hz or negedge switch_clr) begin
        if (!switch_clr) 
            clock_min_h <= 3'd0;
        else if (load_from_setting) 
            clock_min_h <= setting_min_h;
        else if (en_clock_min_h) case (clock_min_h)
            3'd5:    clock_min_h <= 3'd0;
            default: clock_min_h <= clock_min_h + 1'b1;
        endcase
    end

    always @(posedge clk_1hz or negedge switch_clr) begin
        if (!switch_clr) 
            clock_hour_l <= 4'd0;
        else if (load_from_setting) 
            clock_hour_l <= setting_hour_l;
        else if (en_clock_hour_l) case (1'b1) 
            hour_reset:            clock_hour_l <= 4'd0; 
            (clock_hour_l == 4'd9): clock_hour_l <= 4'd0;
            default:               clock_hour_l <= clock_hour_l + 1'b1;
        endcase
    end

    always @(posedge clk_1hz or negedge switch_clr) begin
        if (!switch_clr) 
            clock_hour_h <= 2'd0;
        else if (load_from_setting) 
            clock_hour_h <= setting_hour_h;
        else if (en_clock_hour_l) case (1'b1)
            hour_reset:            clock_hour_h <= 2'd0;
            (clock_hour_l == 4'd9): clock_hour_h <= clock_hour_h + 1'b1;
            default:               clock_hour_h <= clock_hour_h;
        endcase
    end


    // 校时逻辑
    // 在校时模式下，可以通过按钮调整时间
    // button_1: 切换调整位置 (分低->分高->时低->时高)
    // button_2: 增加当前位的值
    // 退出校时模式时，将设定时间同步到主时钟

    //校时寄存器
    reg [3:0] setting_min_l;
    reg [2:0] setting_min_h;
    reg [3:0] setting_hour_l;
    reg [1:0] setting_hour_h;
    reg [1:0] position;         // 当前调整位置 (0:分低, 1:分高, 2:时低, 3:时高)
    reg switch_setting_prev;    // 校时开关前一状态 (用于边沿检测)

    //闹钟寄存器
    reg [3:0] alarm_min_l;
    reg [2:0] alarm_min_h;
    reg [3:0] alarm_hour_l;
    reg [1:0] alarm_hour_h;
    reg switch_alarm_prev;

    // 检测校时开关的下降沿
    always @(posedge clk_1hz) begin
        switch_setting_prev <= switch_setting;
    end

    // 同步信号: 退出校时模式时触发
    wire load_from_setting;
    assign load_from_setting = !switch_setting && switch_setting_prev;

    //检测开关的下降沿
    always @(posedge clk_1hz) begin
        switch_alarm_prev <= switch_alarm;
    end
    // alarm button  switch_alarm
    wire load_for_alarm;
    assign load_for_alarm = !switch_alarm && switch_alarm_prev;

    // 切换调整位置 (按下button_1)
    always @(posedge button_1) begin
        if (button_1)
            position <= position + 1;
    end
        
    always @(posedge button_2) begin
        if (button_2) begin
            if (mode == 2'd1) begin
                case (position) 
                    // 分低位: 0-9 循环
                    2'd0: setting_min_l <= (setting_min_l == 4'd9) ? 4'd0 : setting_min_l + 1'b1;
                    // 分高位: 0-5 循环
                    2'd1: setting_min_h <= (setting_min_h == 3'd5) ? 3'd0 : setting_min_h + 1'b1;
                    // 时低位: 需考虑24小时限制
                    2'd2: begin
                        if (setting_hour_h == 2'd2)
                            // 20-23时，时低位只能是0-3
                            setting_hour_l <= (setting_hour_l == 4'd3) ? 4'd0 : setting_hour_l + 1'b1;
                        else
                            // 0x-19时，时低位是0-9
                            setting_hour_l <= (setting_hour_l == 4'd9) ? 4'd0 : setting_hour_l + 1'b1;
                    end
                    
                    // 时高位: 0-2 循环，并自动修正时低位
                    2'd3: begin
                        // 如果即将变成2x时，且时低位>3，则修正为0
                        if (setting_hour_h == 2'd1 && setting_hour_l > 4'd3)
                            setting_hour_l <= 4'd0;
                        setting_hour_h <= (setting_hour_h == 2'd2) ? 2'd0 : setting_hour_h + 1'b1;
                    end
            endcase
            end
            if (mode == 2'd2) begin
                case (position) 
                    // 分低位: 0-9 循环
                    2'd0: alarm_min_l <= (alarm_min_l == 4'd9) ? 4'd0 : alarm_min_l + 1'b1;
                    // 分高位: 0-5 循环
                    2'd1: alarm_min_h <= (alarm_min_h == 3'd5) ? 3'd0 : alarm_min_h + 1'b1;
                    // 时低位: 需考虑24小时限制
                    2'd2: begin
                        if (alarm_hour_h == 2'd2)
                            // 20-23时，时低位只能是0-3
                            alarm_hour_l <= (alarm_hour_l == 4'd3) ? 4'd0 : alarm_hour_l + 1'b1;
                        else
                            // 0x-19时，时低位是0-9
                            alarm_hour_l <= (alarm_hour_l == 4'd9) ? 4'd0 : alarm_hour_l + 1'b1;
                    end
                    
                    // 时高位: 0-2 循环，并自动修正时低位
                    2'd3: begin
                        // 如果即将变成2x时，且时低位>3，则修正为0
                        if (alarm_hour_h == 2'd1 && alarm_hour_l > 4'd3)
                            alarm_hour_l <= 4'd0;
                        alarm_hour_h <= (alarm_hour_h == 2'd2) ? 2'd0 : alarm_hour_h + 1'b1;
                    end
            endcase
            end
        end
    end 

    // 闹钟匹配检测 (秒为00时触发)
	wire check_alarm_sec = (clock_sec_l == 4'd0) && (clock_sec_h == 3'd0);
	wire check_alarm_min_l = (alarm_min_l == clock_min_l);
	wire check_alarm_min_h = (alarm_min_h == clock_min_h);
	wire check_alarm_hour_l = (alarm_hour_l == clock_hour_l);
	wire check_alarm_hour_h = (alarm_hour_h == clock_hour_h);
	always @ (posedge clk_1hz) begin
		alarm_beep_enable= (check_alarm_sec)&(check_alarm_min_l)&(check_alarm_min_h)&(check_alarm_hour_l)&(check_alarm_hour_h);
	end



    // 显示译码
    // 修改 display_1 ~ display_6 的值即可修改显示内容
    // 修改 flicker_mask[0...5] 的值即可启动/关闭闪烁
    wire [3:0] display_1;
    wire [3:0] display_2;
    wire [3:0] display_3;
    wire [3:0] display_4;
    wire [3:0] display_5;
    wire [3:0] display_6;

    // 根据模式选择显示内容
    assign display_1 = (mode == 2'd0) ? clock_sec_l : setting_sec_l;
    assign display_2 = (mode == 2'd0) ? clock_sec_h : setting_sec_h;
    assign display_3 = (mode == 2'd0) ? clock_min_l : setting_min_l;
    assign display_4 = (mode == 2'd0) ? clock_min_h : setting_min_h;
    assign display_5 = (mode == 2'd0) ? clock_hour_l : setting_hour_l;
    assign display_6 = (mode == 2'd0) ? clock_hour_h : setting_hour_h;

    reg [0:5] flicker_mask;

    assign LED7S2_out = ~ flicker_mask[1] | clk_4hz ? display_2 : 4'hf;
    assign LED7S3_out = ~ flicker_mask[2] | clk_4hz ? display_3 : 4'hf;
    assign LED7S4_out = ~ flicker_mask[3] | clk_4hz ? display_4 : 4'hf;
    assign LED7S5_out = ~ flicker_mask[4] | clk_4hz ? display_5 : 4'hf;
    assign LED7S6_out = ~ flicker_mask[5] | clk_4hz ? display_6 : 4'hf;
    // 秒低位需要七段译码 (其他位由外部译码器处理)
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

    // 判定逻辑
    always @(*) begin
        if (mode == 2'd1) begin
            case (position)
                2'd0 : flicker_mask = 6'b001000;
                2'd1 : flicker_mask = 6'b000100;
                2'd2 : flicker_mask = 6'b000010;
                2'd3 : flicker_mask = 6'b000001;
            endcase
        end
        else if (mode == 2'd2) begin
            case (position)
                2'd0 : flicker_mask = 6'b001000;
                2'd1 : flicker_mask = 6'b000100;
                2'd2 : flicker_mask = 6'b000010;
                2'd3 : flicker_mask = 6'b000001;
            endcase
        end else begin
            flicker_mask = 6'b000000;
        end
            
    end

    // ==========================================
    // 蜂鸣器部分
    // ==========================================
    // beep_timer 为计时器，未归零时发声

    reg [3:0] beep_timer;
    assign beep_enable = (beep_timer != 4'd0) || switch_debug1;
    assign beep = beep_enable && rhythm && clk_1khz;

    always @(posedge clk_1hz) begin
        if (beep_timer > 0) 
            beep_timer <= beep_timer - 1;

        if (alarm_beep_enable || en_clock_hour_l)
			beep_timer <= 4'd5;
    end

endmodule