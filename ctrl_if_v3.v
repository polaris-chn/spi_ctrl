// 输出给interface的控制信号有
// xip模式是否有效，
// xip用那几条线采样
// xip采样是否用双边沿
// 采样地址的sclk周期数，
// 采样continuous mode的sclk周期数
// 采样dummy的sclk周期数
// 在idle和decode就直接输出这些信号
// 砍掉大部分的状态，只保留idle、decode、drive状态


module ctrl_if(
    input sclk,
    input rstn,
    // cs#低电平有效
    input cs#,
    input [7:0] vncr_0,
    input [7:0] cmd,
    input [7:0] continus_mode,
    // por或者reset后，是否进入xip模式，在osc fsm中用reg进行状态保持，作为此模块的输入
    input por_xip,
    input ads,
    // C0指令进来的p_data数据
    input [7:0] p_data,
    input [7:0] wrap_data,

    input qpi_read_param_en,
    input [7:0] qpi_read_param,
);                  
    parameter idle                  = 5'd0;
    parameter xip_dual              = 5'd1;
    parameter xip_dtr_dual          = 5'd2;
    parameter xip_quad              = 5'd3;
    parameter xip_dtr_quad          = 5'd4;
    parameter cmd_cnt_spi           = 5'd5;
    parameter cmd_cnt_qpi           = 5'd6;
    parameter decode                = 5'd7;
    parameter sample_if_standard    = 5'd8;
    parameter sample_if_dual        = 5'd9;
    parameter sample_if_quad        = 5'd10;
    parameter sample_if_dtr_dual    = 5'd11;
    parameter sample_if_dtr_quad    = 5'd12;
    parameter drive_if_standard     = 5'd13;
    parameter drive_if_dual         = 5'd14;
    parameter drive_if_quad         = 5'd15;
    parameter drive_if_dtr_dual     = 5'd16;
    parameter drive_if_dtr_quad     = 5'd17;

    reg [4:0] current_state;
    reg [4:0] next_state;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            current_state <= idle;
        else
            current_state <= next_state;
    end

    reg cmd_xip;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            cmd_xip <= 1'b0;
        else if (continus_mode[5:4]==2'b10)
            cmd_xip <= 1'b1;
        else
            cmd_xip <= 1'b0;
    end
    
    // continus_mode[5:4]不等于2'b10时，需要对por_xip进行清零
    assign clear_por_xip = (continus_mode[5:4]==2'b10) ? 1'b0 : 1'b1;

    reg [7:0] cmd_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            cmd_reg <= 8'd0;
        else
            cmd_reg <= cmd;
    end

    reg qpi_mode_reg;
    wire set_qpi_mode;
    wire clear_qpi_mode;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            qpi_mode_reg <= 1'b0;
        else if (set_qpi_mode)
            qpi_mode_reg <= 1'b1;
        else if (clear_qpi_mode)
            qpi_mode_reg <= 1'b0;
        else
            qpi_mode_reg <= qpi_mode_reg;
    end

    reg en_rst;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            en_rst <= 1'b0;
        else if (set_en_rst)
            en_rst <= 1'b1;
        else
            en_rst <= 1'b0;
    end

    reg [7:0] p_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            p_reg <= 8'd0;
        else if (p_data_en)
            p_reg <= p_data;
        else
            p_reg <= 8'd0;
    end

    // 只有50指令才能置位
    reg write_en_VSR_reg;
    always@(posedge clk or negedge rstn) begin
        if (!rstn)
            write_en_VSR_reg <= 1'b0;
        else if (write_en_VSR)
            write_en_VSR_reg <= 1'b1;
        else
            write_en_VSR_reg <= 1'b0;
    end

    reg [7:0] wrap_data_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            wrap_data_reg <= 8'd0;
        else if (wrap_reg_en)
            wrap_data_reg <= wrap_data;
        else
            wrap_data_reg <= 8'd0;
    end

    reg [7:0] qpi_read_param_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            qpi_read_param_reg <= 0;
        else if (qpi_read_param_en)
            qpi_read_param_reg <= qpi_read_param;
        else
            qpi_read_param_reg <= qpi_read_param_reg;
    end

    reg dpd_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            dpd_reg <= 1'b0;
        else if (enter_dpd_signal)
            dpd_reg <= 1'b1;
        else if (exit_dpd_signal)
            dpd_reg <= 1'b0;
        else
            dpd_reg <= dpd_reg;
    end

    wire clear_wel;
    wire set_wel;

    always@(*) begin
        set_en_rst = 1'b0;

        case(current_state)
            // 只要rstn有效，current_state就会进入到idle，不需要依赖sclk，那么此时是不是不需要判断cs#,直接进行下面的操作？会不会快一点？
            idle: begin
                if (!cs) begin
                    // 是否是por之后的xip模式的判断
                    if (por_xip) 
                        case (vncr_0)
                            8'hfc : begin
                                continus_mode_cycle = 4;
                                // 双线上升沿采样
                                xip_mode = 2'b00;
                                if (ads) begin
                                    addr_cycle = 16;
                                    if (cnt == 16+4)
                                        next_state = drive_if_dual;
                                end
                                else begin
                                    addr_cycle = 12;
                                    if (cnt == 12+4)
                                        next_state = drive_if_dual;
                                end
                            end

                            8'hfd : begin
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                // 双线双边沿采样
                                xip_mode = 2'b01;
                                if (ads) begin
                                    addr_cycle = 8;
                                    if (cnt == 2+4+8)
                                        next_state = drive_if_dtr_dual;
                                end
                                else begin
                                    addr_cycle = 6;
                                    if (cnt == 2+4+6)
                                        next_state = drive_if_dtr_dual;
                                end
                            end

                            8'hfe : begin
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                // 四线上升沿采样
                                xip_mode = 2'b10;
                                if (ads) begin
                                    addr_cycle = 8;
                                    if (cnt==2+4+8)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 6;
                                    if (cnt==2+4+6)
                                        next_state = drive_if_quad;
                                end
                            end

                            8'hfb : begin
                                continus_mode_cycle = 1;
                                dummy_cycle = 7;
                                // 四线双边沿采样
                                xip_mode = 2'b11;
                                if (ads) begin
                                    addr_cycle = 4;
                                    if (cnt==1+7+4)
                                        next_state = drive_if_dtr_quad;
                                end
                                else begin
                                    addr_cycle = 3;
                                    if (cnt==1+7+3)
                                        next_state = drive_if_dtr_quad;
                                end
                            end

                            default : next_state = idle;
                        endcase 

                    else if (cmd_xip) 
                        case(cmd_reg)
                            8'hbb : begin
                                continus_mode_cycle = 4;
                                // 双线上升沿采样
                                xip_mode = 2'b00;
                                if (ads) begin
                                    addr_cycle = 16;
                                    if (cnt == 16+4)
                                        next_state = drive_if_dual;
                                end
                                else begin
                                    addr_cycle = 12;
                                    if (cnt == 12+4)
                                        next_state = drive_if_dual;
                                end
                            end
                            
                            8'hbc : begin
                                continus_mode_cycle = 4;
                                xip_mode = 2'b00;
                                addr_cycle = 16;
                                if (cnt == 16+4)
                                    next_state = drive_if_dual;
                            end

                            8'hbd : begin
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                // 双线双边沿采样
                                xip_mode = 2'b01;
                                if (ads) begin
                                    addr_cycle = 8;
                                    if (cnt == 2+4+8)
                                        next_state = drive_if_dtr_dual;
                                end
                                else begin
                                    addr_cycle = 6;
                                    if (cnt == 2+4+6)
                                        next_state = drive_if_dtr_dual;
                                end
                            end

                            8'hbe : begin
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                xip_mode = 2'b01;
                                addr_cycle = 8;
                                if (cnt == 2+4+8)
                                    next_state = drive_if_dtr_dual;
                            end
                            
                            8'heb : begin
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                // 四线上升沿采样
                                xip_mode = 2'b10;
                                if (ads) begin
                                    addr_cycle = 8;
                                    if (cnt==2+4+8)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 6;
                                    if (cnt==2+4+6)
                                        next_state = drive_if_quad;
                                end
                            end

                            8'hed : begin
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                xip_mode = 2'b10;
                                addr_cycle = 8;
                                if (cnt==2+4+8)
                                    next_state = drive_if_quad;
                            end

                            8'hed : begin
                                continus_mode_cycle = 1;
                                dummy_cycle = 7;
                                // 四线双边沿采样
                                xip_mode = 2'b11;
                                if (ads) begin
                                    addr_cycle = 4;
                                    if (cnt==1+7+4)
                                        next_state = drive_if_dtr_quad;
                                end
                                else begin
                                    addr_cycle = 3;
                                    if (cnt==1+7+3)
                                        next_state = drive_if_dtr_quad;
                                end
                            end

                            8'hee : begin
                                continus_mode_cycle = 1;
                                dummy_cycle = 7;
                                xip_mode = 2'b11;
                                addr_cycle = 4;
                                if (cnt==1+7+4)
                                    next_state = drive_if_dtr_quad;
                            end

                            default : next_state = idle;
                        endcase
                        
                    else if (qpi_mode_reg)
                        cmd_cnt = 2;
                        if (cnt==2)
                            next_state = decode;
                            
                    else
                        cmd_cnt = 8;
                        if (cnt==8)
                            next_state = decode
                end

                else 
                    next_state = idle;
            end

          
            // 需要在解码的时候就注明下一步采样的地址周期，dummy周期，continuous mode周期，数据周期等   
            decode: begin
                case(cmd[7:4])
                    4'h0: begin
                        4'h1:begin (done)
                            if (write_en_VSR_reg)
                                write_sr_shadow_signal = 1'b1;
                                write_sr_addr = SR1 & SR2;
                                write_en_VSR = 1'b0;
                                if (qpi_mode_reg)
                                    to_if_cnt = 4;
                                else
                                    to_if_cnt = 16;
                                next_state = idle;
                            else
                                write_sr_signal = 1'b1;
                                write_sr_addr = SR1 & SR2;
                                if (qpi_mode_reg)
                                    to_if_cnt = 4;
                                else
                                    to_if_cnt = 16;
                                next_state = idle;
                        end 
                        4'h2: begin (done)
                            write_array_signal = 1'b1;
                            if (qpi_mode_reg)
                                if (ads)
                                    addr_cycle = 8
                                else
                                    addr_cycle = 6;
                            else
                                if (ads)
                                    addr_cycle = 32;
                                else
                                    addr_cycle = 24;
                            if(cs#)
                                next_state = idle;
                        end
                        4'h3: begin (done)
                            if (qpi_mode_reg)
                                next_state = idle;
                            else begin
                                read_array_signal = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if(cnt==addr_cycle)
                                    next_state = drive_if_standard;
                            end
                        end
                        4'h4: begin (done)
                            write_reg_signal = 1'b1;
                            clear_wel = 1'b1;
                            next_state = idle;
                        end
                        4'h5: begin (done)
                            read_reg_signal = 1'b1;
                            read_reg_addr = SR1;
                            if (qpi_mode_reg)
                                next_state = drive_if_quad;
                            else
                                next_state = drive_if_standard;
                        end
                        4'h6: begin (done)
                            write_reg_signal = 1'b1;
                            set_wel = 1'b1;
                            next_state = idle;
                        end
                        4'hb: begin (done)
                            read_array_signal = 1'b1;
                            if (qpi_mode_reg)
                                if(ads) begin
                                    addr_cycle = 8;
                                    dummy_cycle = 6;
                                    if(cnt==addr_cycle+dummy_cycle)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 6;
                                    dummy_cycle = 6;
                                    if(cnt==addr_cycle+dummy_cycle)
                                        next_state = drive_if_quad;
                                end
                            else 
                                if(ads) begin
                                    addr_cycle = 32;
                                    dummy_cycle = 8;
                                    if(cnt==addr_cycle+dummy_cycle)
                                        next_state = drive_if_standard;
                                end
                                else begin
                                    addr_cycle = 24;
                                    dummy_cycle = 8;
                                    if (cnt==addr_cycle+dummy_cycle)
                                        next_state  = drive_if_standard;
                                end
                        end
                        4'hc: begin (done)
                            read_array_signal = 1'b1;
                            if (qpi_mode_reg) begin
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = 4;
                                case(p_reg[1:0])
                                    2'b00: wrap_len = 8;
                                    2'b01: wrap_len = 16;
                                    2'b10: wrap_len = 32;
                                    2'b11: wrap_len = 64;
                                    default: wrap_len = 0;
                                endcase
                                if(cnt==addr_cycle+dummy_cycle)
                                    next_state = drive_if_quad
                            end
                            else begin
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if(cnt==addr_cycle+dummy_cycle)
                                    next_state = drive_if_standard;
                            end

                        end
                        4'he: begin (done)
                            read_array_signal = 1'b1;
                            addr_cycle = ads ? 4 : 3;
                            dummy_cycle = 10;
                            case(qpi_read_param_reg[1:0])
                                2'b00: wrap_len = 8;
                                2'b01: wrap_len = 16;
                                2'b10: wrap_len = 32;
                                2'b11: wrap_len = 64;
                                default: wrap_len = 0;
                            endcase
                            if(cnt==addr_cycle+dummy_cycle)
                                next_state = drive_if_dtr_quad;
                        end
                    end

                    4'h1: begin
                        case(cmd[3:0])
                            4'h1 : begin (done)
                                if (write_en_VSR_reg)
                                    write_sr_shadow_signal = 1'b1;
                                    write_sr_addr = SR3;
                                    write_en_VSR = 1'b0;
                                    if (qpi_mode_reg)
                                        to_if_cnt = 2;
                                    else
                                        to_if_cnt = 8;
                                    next_state = idle;
                                else
                                    write_sr_signal = 1'b1;
                                    write_sr_addr = SR3;
                                    if (qpi_mode_reg)
                                        to_if_cnt = 2;
                                    else
                                        to_if_cnt = 8;
                                    next_state = idle;
                            end 
                            4'h2: begin (done)
                                write_array_signal = 1'b1;
                                addr_cycle = qpi_mode_reg ? 8 : 6;
                                if (cs#)
                                    next_state = idle;
                            end
                            4'h3: begin (done)
                                read_array_signal = 1'b1;
                                addr_cycle = 32;
                                if(cnt==addr_cycle)
                                    next_state = drive_if_standard;
                            end
                            4'h5: begin (done)
                                read_reg_signal = 1'b1;
                                read_reg_addr = SR3;
                                if (qpi_mode_reg)
                                    next_state = drive_if_quad;
                                else
                                    next_state = drive_if_standard;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h2: begin
                        case(cmd[3:0])
                            4'h0: begin (done)
                                erase_sector_signal = 1'b1;
                                if (qpi_mode_reg)
                                    if(ads) begin
                                        addr_cycle = 8;
                                        if(cnt==8)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        if (cnt==6)
                                            next_state = idle;
                                    end
                                else 
                                    if(ads) begin
                                        addr_cycle = 32;
                                        if (cnt==32)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        if(cnt==24)
                                            next_state = idle;
                                    end
                            end
                            4'h1: begin (done)
                                erase_sector_signal = 1'b1;
                                if (qpi_mode_reg) begin
                                    addr_cycle = 8;
                                    if(cnt==8)
                                        next_state = idle;
                                end
                                else begin
                                    addr_cycle = 6;
                                    if (cnt==6)
                                        next_state = idle;
                                end
                            end
                            4'h7: begin (done)
                                if (pwd)
                                    next_state = idle;
                                else if (qpi_mode_reg) begin
                                    dummy_cycle = 8;
                                    if (cnt==8)
                                        next_state = drive_if_quad;
                                end
                                else 
                                    next_state = drive_if_standard;
                            end
                            4'h8: begin (done)
                                if (pwd)
                                    next_state = idle;
                                else begin
                                    write_pwd_signal = 1'b1;
                                    if (qpi_mode_reg) begin
                                        data_cycle = 16;
                                        if(cnt==16)
                                            next_state = idle
                                    end
                                    else begin
                                        data_cycle = 64;
                                        if (cnt==64)
                                            next_state = idle;
                                    end
                                end
                            end
                            4'h9: begin (done)
                                if (!pwd)
                                    next_state = idle;
                                else begin
                                    pwd_lock_unlock_signal = 1'b1;
                                    if (qpi_mode_reg) begin
                                        data_cycle = 16;
                                        if (cnt==16)
                                            next_state = idle;
                                    end
                                    else begin
                                        data_cycle = 64;
                                        if (cnt==64)
                                            next_state = idle;
                                    end
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h3: begin
                        write_en_VSR = 1'b0;
                        case (cmd[3:0])
                            4'h0: begin (done)
                                clear_FSR = 1'b1;
                                next_state = idle;
                            end
                            4'h2: begin (done)
                                write_array_signal = 1'b1;
                                if (qpi_mode_reg)
                                    next_state = idle;
                                else begin
                                    quad_sample_data = 1'b1;
                                    addr_cycle = ads ? 32 : 24;
                                    if (cs#)
                                        next_state = idle;
                                end
                            end
                            4'h4: begin (done)
                                write_array_signal = 1'b1;
                                if (qpi_mode_reg)
                                    next_state = idle;
                                else begin
                                    quad_sample_data = 1'b1;
                                    addr_cycle = 32;
                                    if (cs#)
                                        next_state = idle;
                                end
                            end
                            4'h5: begin (done)
                                read_reg_signal = 1'b1;
                                read_reg_addr = SR2;
                                if (qpi_mode_reg)
                                    next_state = drive_if_quad;
                                else
                                    next_state = drive_if_standard;
                            end
                            4'h8 : begin (done)
                                set_qpi_mode = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin (done)
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if(cnt==addr_cycle+dummy_cycle)
                                    next_state = drive_if_dual;
                            end
                            4'hc: begin (done)
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if (cnt==addr_cycle+dummy_cycle)
                                    next_state = drive_if_dual;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h4: begin
                        write_en_VSR = 1'b0;
                        case (cmd[3:0])
                            4'h2: begin (done)
                                write_sec_reg_signal = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cs#)
                                    next_state = idle;
                            end
                            4'h4: begin (done)
                                if (ads) begin
                                    addr_cycle = 32;
                                    if (cnt==32)
                                        next_state = idle;
                                end
                                else begin
                                    addr_cycle = 24;
                                    if(cnt==24)
                                        next_state = idle;
                                end
                            end
                            4'h8: begin (done)
                                read_sec_reg_signal = 1'b1;
                                dummy_cycle = 8;
                                if (ads) begin
                                    addr_cycle = 32;
                                    if (cnt==8+32)
                                        next_state = drive_if_standard;
                                end
                                else begin
                                    addr_cycle = 24;
                                    if (cnt==24+8)
                                        next_state = drive_if_standard;
                                end
                            end
                            4'hb: begin (done)
                                read_id_signal = 1'b1;
                                if (qpi_mode_reg)
                                    next_state = idle;
                                else begin
                                    if (ads)
                                        addr_cycle = 32;
                                    else
                                        addr_cycle = 24;
                                    dummy_cycle = 8;
                                    next_state = drive_if_standard;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h5: begin
                        case(cmd[3:0])
                            4'h0: begin (done)
                                write_en_VSR = 1'b1;
                                next_state = idle;
                            end
                            4'h2: begin (done)
                                erase_block32_signal = 1'b1;
                                if(qpi_mode_reg)
                                    if(ads) begin
                                        addr_cycle = 8;
                                        if(cnt==8)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        if (cnt==6)
                                            next_state = idle;
                                    end
                                else
                                    if(ads) begin
                                        addr_cycle = 32;
                                        if(cnt==32)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        if (cnt==24)
                                            next_state = idle;
                                    end
                            end
                            4'ha: begin (done)
                                if (qpi_mode_reg) begin
                                    addr_cycle = 6;
                                    dummy_cycle = 8;
                                    if (cnt==6+8)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 24;
                                    dummy_cycle = 8;
                                    if (cnt==24+8)
                                        next_state = drive_if_standard;
                                end
                            end
                            4'hb: begin (done)
                                data_crc_signal = 1;
                                if (qpi_mode_reg) begin
                                    addr_cycle = 16;
                                    if(cnt==16)
                                        next_state = idle;
                                end
                                else begin
                                    addr_cycle = 64;
                                    if (cnt==64)
                                        next_state = idle;
                                end
                            end
                            4'hc: begin (done)
                                erase_block32_signal = 1'b1;
                                if(qpi_mode_reg) begin
                                    addr_cycle = 8;
                                    if(cnt==8)
                                        next_state = idle;
                                end
                                else begin
                                    addr_cycle = 32;
                                    if(cnt==32)
                                        next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h6: begin
                        write_en_VSR = 1'b0;
                        case(cmd[3:0])
                            4'h0: begin (done)
                                erase_chip_signal = 1'b1;
                                next_state = idle;
                            end
                            4'h4: begin (done)
                                read_itcrcr_signal = 1'b1;
                                if (qpi_mode_reg) begin
                                    addr_cycle = 8;
                                    if(cnt==8)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 32;
                                    if (cnt==32)
                                        next_state = drive_if_standard;
                                end
                            end 
                            4'h6: begin (done)
                                set_en_rst = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin (done)
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if(cnt==addr_cycle+dummy_cycle)
                                    next_state = drive_if_quad;
                            end
                            4'hc: begin (done)
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if (cnt==addr_cycle+dummy_cycle)
                                    next_state = drive_if_quad;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h7: begin
                        write_en_VSR = 1'b0;
                        case(cmd[3:0])
                            4'h0: begin (done)
                                read_reg_signal = 1'b1;
                                read_reg_addr = FSR;
                                if (qpi_mode_reg)
                                    next_state = drive_if_quad;
                                else
                                    next_state = drive_if_standard;
                            end
                            4'h5: begin
                                pes_signal = 1'b1;
                                next_state = idle;                                
                            end
                            4'h7: begin (done)
                                if (qpi_mode_reg)
                                    next_state = idle;
                                else begin
                                    dummy_cycle = 6;
                                    data_cycle = 2;
                                    if (cnt==6+2) begin
                                        wrap_reg_en = 1'b1;
                                        next_state = idle;
                                    end
                                end
                            end
                            4'ha: begin
                                per_signal = 1'b1;
                                next_state = idle;
                            end
                            4'he: begin (done)
                                global_block_sector_lock_signal = 1'b1;
                                next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h8: begin
                        write_en_VSR = 1'b0;
                        case(cmd[3:0])
                            4'h1: begin (done)
                                write_VCR_signal = 1'b1;
                                if (qpi_mode_reg)
                                    if (ads) begin
                                        addr_cycle = 8;
                                        data_cycle = 2;
                                        if (cnt==8+2)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        data_cycle = 2;
                                        if (cnt==6+2)
                                            next_state = idle;
                                    end
                                else
                                    if (ads) begin
                                        addr_cycle = 32;
                                        data_cycle = 8;
                                        if (cnt==32+8)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        data_cycle = 8;
                                        if (cnt=24+8)
                                            next_state = idle;
                                    end
                            end
                            4'h5: begin (done)
                                read_VCR_signal = 1'b1;
                                if (qpi_mode_reg)
                                    if (ads) begin
                                        addr_cycle = 8;
                                        dummy_cycle = 8;
                                        if (cnt==8+8)
                                            next_state = drive_if_quad;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        dummy_cycle = 8;
                                        if (cnt==6+8)
                                            next_state = drive_if_quad;
                                    end
                                else
                                    if (ads) begin
                                        addr_cycle = 32;
                                        dummy_cycle = 8;
                                        if (cnt==32+8)
                                            next_state = drive_if_standard;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        dummy_cycle = 8;
                                        if (cnt==24+8)
                                            next_state = drive_if_standard;
                                    end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h9: begin
                        case(cmd[3:0])
                            4'h0: begin (done)
                                if (qpi_mode_reg) begin
                                    addr_cycle = 6;
                                    if (cnt==6)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 24;
                                    if (cnt==24)
                                        next_state = drive_if_standard;
                                end

                            end
                            4'h8: begin (done)
                                global_block_sector_unlock_signal = 1'b1;
                                next_state = idle;
                            end
                            4'h9 : begin (done)
                                if (en_rst) begin
                                    rst_all = 1'b1;
                                    next_state = idle;
                                end
                                else
                                    next_state = idle;
                            end
                            4'hf: begin (done)
                                if (qpi_mode_reg)
                                    next_state = drive_if_dtr_quad;
                                else
                                    next_state = drive_if_standard;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'ha: begin
                        case(cmd[3:0])
                            4'hb: begin (done)
                                if (cs#) begin
                                    exit_dpd_signal = 1'b1;
                                    next_state = idle;
                                end
                                else begin
                                    if (qpi_mode_reg) begin
                                        dummy_cycle = 7;
                                        if (cnt==7)
                                            next_state = drive_if_quad;
                                            // 输出数据之后再给退出dqd信号？
                                    end
                                    else begin
                                        dummy_cycle = 24;
                                        if (cnt==24)
                                            next_state = drive_if_standard;
                                            // 输出数据之后再给退出dqd信号？
                                    end
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hb: begin
                        write_en_VSR = 1'b0;
                        case(cmd[3:0])
                            4'h1: begin (done)
                                write_NVCR_signal = 1'b1;
                                if (qpi_mode_reg)
                                    if (ads) begin
                                        addr_cycle = 8;
                                        data_cycle = 2;
                                        if (cnt==8+2)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        data_cycle = 2;
                                        if (cnt==6+2)
                                            next_state = idle;
                                    end
                                else
                                    if (ads) begin
                                        addr_cycle = 32;
                                        data_cycle = 8;
                                        if (cnt==32+8)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        data_cycle = 8;
                                        if (cnt=24+8)
                                            next_state = idle;
                                    end
                            end
                            4'h5: begin (done)
                                read_NVCR_signal = 1'b1;
                                if (qpi_mode_reg)
                                    if (ads) begin
                                        addr_cycle = 8;
                                        dummy_cycle = 8;
                                        if (cnt==8+8)
                                            next_state = drive_if_quad;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        dummy_cycle = 8;
                                        if (cnt==6+8)
                                            next_state = drive_if_quad;
                                    end
                                else
                                    if (ads) begin
                                        addr_cycle = 32;
                                        dummy_cycle = 8;
                                        if (cnt==32+8)
                                            next_state = drive_if_standard;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        dummy_cycle = 8;
                                        if (cnt==24+8)
                                            next_state = drive_if_standard;
                                    end
                            end
                            4'h7: begin (done)
                                set_ads = 1'b1;
                                next_state = idle;
                            end
                            4'h9: begin (done)
                                enter_dpd_signal = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin (done)
                                addr_cycle = ads ? 16 : 12;
                                continus_mode_cycle = 4;
                                if(cnt==addr_cycle+continus_mode_cycle)
                                    next_state = drive_if_dual;
                            end
                            4'hc: begin (done)
                                addr_cycle = 32;
                                continus_mode_cycle = 4;
                                if(cnt==addr_cycle+continus_mode_cycle)
                                    next_state = drive_if_dual;
                            end
                            4'hd: begin (done)
                                addr_cycle = ads ? 8 : 6;
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                    next_state = drive_if_dtr_dual;
                            end
                            4'he: begin (done)
                                addr_cycle = 8;
                                continus_mode_cycle = 2;
                                dummy_cycle = 4;
                                if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                    next_state = drive_if_dtr_dual;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hc: begin
                        write_en_VSR = 1'b0;
                        case(cmd[3:0])
                            4'h0: begin (done)
                                if (!qpi_mode_reg)
                                    next_state = idle;
                                else begin
                                    // 这里的qpi_read_param_en和qpi_read_param信号都是从接口进来的，是input信号
                                    data_cycle = 2;
                                    if (cnt==2)
                                        next_state = idle;
                                end
                            end
                            4'h5: begin (done)
                                write_reg_signal = 1'b1;
                                wirte_reg_addr = EAR;
                                if (qpi_mode_reg)
                                    to_if_cnt = 2;
                                else
                                    to_if_cnt = 8;
                                next_state = idle;
                            end
                            4'h7: begin (done)
                                erase_chip_signal = 1'b1;
                                next_state = idle;
                            end
                            4'h8: begin (done)
                                read_reg_signal = 1'b1;
                                read_reg_addr = EAR;
                                if (qpi_mode_reg)
                                    next_state = drive_if_quad;
                                else
                                    next_state = drive_if_standard;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hd: begin
                        case(cmd[3:0])
                            4'h8: begin (done)
                                erase_block64_signal = 1'b1;
                                if(qpi_mode_reg)
                                    if(ads) begin
                                        addr_cycle = 8;
                                        if(cnt==8)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 6;
                                        if(cnt==6)
                                            next_state = idle;
                                    end
                                else 
                                    if(ads) begin
                                        addr_cycle = 32;
                                        if(cnt==32)
                                            next_state = idle;
                                    end
                                    else begin
                                        addr_cycle = 24;
                                        if(cnt==24)
                                            next_state = idle;
                                    end
                            end
                            4'hc: begin (done)
                                erase_block64_signal = 1'b1;
                                if(qpi_mode_reg) begin
                                    addr_cycle = 8;
                                    if(cnt==8)
                                        next_state = idle;
                                end
                                else begin
                                    addr_cycle = 32;
                                    if(cnt==32)
                                        next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'he: begin
                        case(cmd[3:0])
                            4'h0: begin (done)
                                read_VLR_signal = 1'b1;
                                if (qpi_mode_reg) begin
                                    addr_cycle = 8;
                                    if (cnt==8)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 32;
                                    if (cnt==32)
                                        next_state = drive_if_standard;
                                end
                            end
                            4'h1: begin (done)
                                write_VLR_signal = 1'b1;
                                addr_cycle = (qpi_mode_reg) ? 8 : 32;
                                data_cycle = (qpi_mode_reg) ? 2 : 8;
                                if (cnt==addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h2: begin (done)
                                read_NVLR_signal = 1'b1;
                                if (qpi_mode_reg) begin
                                    addr_cycle = 8;
                                    if (cnt==8)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = 32;
                                    if (cnt==32)
                                        next_state = drive_if_standard;
                                end
                            end
                            4'h3: begin (done)
                                set_NVLR_signal = 1'b1;
                                addr_cycle = (qpi_mode_reg) ? 8 : 32;
                                if(cnt==addr_cycle)
                                    next_state = idle;
                            end
                            4'h4: begin (done)
                                clear_all_NVLR_signal = 1'b1;
                                next_state = idle;
                            end
                            4'h9: begin (done)
                                clear_ads = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin (done)
                                if(qpi_mode_reg) begin
                                    addr_cycle = ads ? 8 : 6;
                                    continus_mode_cycle = 2;
                                    dummy_cycle = 2;
                                    if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                        next_state = drive_if_quad;
                                end
                                else begin
                                    addr_cycle = ads ? 8 : 6;
                                    continus_mode_cycle = 2;
                                    dummy_cycle = 4;
                                    if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                        next_state = drive_if_quad;
                                end
                            end
                            4'hc: begin (done)
                                addr_cycle = 8;
                                continus_mode_cycle = 2;
                                dummy_cycle = qpi_mode_reg ? 2 : 4;
                                if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                    next_state = drive_if_quad;
                            end
                            4'hd: begin (done)
                                addr_cycle = ads ? 4 : 3;
                                continus_mode_cycle = 1;
                                dummy_cycle = qpi_mode_reg ? 9 : 7;
                                if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                    next_state = drive_if_dtr_quad;
                            end
                            4'he: begin (done)
                                addr_cycle = 4;
                                continus_mode_cycle = 1;
                                dummy_cycle = qpi_mode_reg ? 9 : 7;
                                if(cnt==addr_cycle+continus_mode_cycle+dummy_cycle)
                                    next_state = drive_if_dtr_quad;
                            end
                            default : next_state = idle;
                        endcase
                    end
            
                    4'hf: begin (done)
                        clear_qpi_mode = 1'b1;
                        next_state = idle;
                    end
                    default: next_state = idle;
                endcase
            end



            drive_if_standard: begin
                // to do : 高速接口单线驱动下降沿输出；
            end

            drive_if_dual: begin
                // to do : 高速接口双线驱动下降沿输出；
            end

            drive_if_quad: begin
                // to do : 高速接口四线驱动下降沿输出；
            end

            drive_if_dtr_dual: begin
                // to do : 高速接口双线双边沿驱动输出；
            end

            drive_if_dtr_quad : begin
                // to do : 高速接口四线双边沿驱动输出；
            end

            default: begin
                next_state = idle;
            end
        endcase
    end

endmodule