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

    wire clear_wel;
    wire set_wel;

    always@(*) begin
        set_en_rst = 1'b0;

        case(current_state)
            idle: begin
                if (cs#) begin
                    // 是否是por之后的xip模式的判断
                    if (por_xip) 
                        case (vncr_0)
                            8'hfc : next_state = xip_dual;
                            8'hfd : next_state = xip_dtr_dual;
                            8'hfe : next_state = xip_quad;
                            8'hfb : next_state = xip_dtr_quad;
                            default : next_state = idle;
                        endcase 
                    else if (cmd_xip) 
                            case(cmd_reg)
                                8'hbb, 8'hbc : next_state = xip_dual;
                                8'hbd, 8'hbe : next_state = xip_dtr_dual;
                                8'heb, 8'hec : next_state = xip_quad;
                                8'hed, 8'hee : next_state = xip_dtr_quad;
                                default : next_state = idle;
                            endcase
                    else if (qpi_mode_reg)
                        next_state = cmd_cnt_qpi;
                    else
                        next_state = cmd_cnt_spi;
                end

                else 
                    next_state = idle;
            end

            xip_dual: begin
                // to do : 控制接口双线xip采样地址、continuous mode字节、dummy；
                if (cmd_reg == 8'hbc)
                    addr = 32bit;
                else if (ads==1'b1)
                    addr = 32bit;
                else   
                    addr = 24bit;
                    ...
            end

            xip_dtr_dual: begin
                // to do : 控制接口双线xip双边沿采样地址、continuous mode字节、dummy；
                if (cmd_reg == 8'hbe)
                    addr = 32bit;
                else if (ads==1'b1)
                    addr = 32bit;
                else
                    addr = 24bit;
                ...
            end

            xip_quad: begin
                // to do : 控制接口四线xip采样地址、continuous mode字节、dummy；
                if (cmd_reg == 8'hec)
                    addr = 32bit;
                else if (ads==1'b1)
                    addr = 32bit;
                else 
                    addr = 24bit;
                ...
            end

            xip_dtr_quad: begin
                // to do : 控制接口四线xip双边沿采样地址、continuous mode字节、dummy；
                if (cmd_reg == 8'hee)
                    addr = 32bit;
                else if (ads==1'b1)
                    addr = 32bit;
                else 
                    addr = 24bit;
                ...
            end

            cmd_cnt_spi: begin
                // to do : 接口spi模式下采样指令，需要8个计数周期；
                // 计数cnt放在组合电路之外，组合电路只使用这个cnt数值，计数完成，跳转到decode状态；
            end

            cmd_cnt_qpi: begin
                // to do : 接口qpi模式下采样指令，需要2个计数周期；
                // 计数cnt放在组合电路之外，组合电路只使用这个cnt数值，计数完成，跳转到decode状态；
            end


            // 需要在解码的时候就注明下一步采样的地址周期，
            decode: begin
                case(cmd[7:4])
                    4'h0: begin
                        4'h1:begin
                            if(qpi_mode_reg)
                                next_state = sample_if_quad;
                            else
                                next_state = sample_if_standard;
                        end 
                        4'h2: begin
                            write_array_signal = 1'b1;
                            if (qpi_mode_reg)
                            next_state = sample_if_quad;
                            else
                                next_state = sample_if_standard;
                        end
                        4'h3: next_state = sample_if_standard;
                        4'h4: begin 
                            clear_wel = 1'b1;
                            next_state = idle;
                        end
                        4'h5: begin
                            read_reg_signal = 1'b1;
                            read_reg_addr = SR1;
                            if (qpi_mode_reg)
                                next_state = drive_if_quad;
                            else
                                next_state = drive_if_standard;
                        end
                        4'h6: begin
                            set_wel = 1'b1;
                            next_state = idle;
                        end
                        4'hb: begin
                            if (qpi_mode_reg)
                                next_state = sample_if_quad;
                            else
                                next_state = sample_if_standard;
                        end
                        4'hc: begin
                            read_array_signal = 1'b1;
                            if (qpi_mode_reg)
                                case(p_reg[1:0])
                                    2'b00: wrap_len = 8;
                                    2'b01: wrap_len = 16;
                                    2'b10: wrap_len = 32;
                                    2'b11: wrap_len = 64;
                                    default: wrap_len = 0;
                                endcase
                                next_state = sample_if_quad;
                            else
                                next_state = sample_if_standard;

                        end
                        4'he: begin
                            read_array_signal = 1'b1;
                            next_state = sample_if_dtr_dual
                        end
                        default : next_state = idle;
                    end

                    4'h1: begin
                        case(cmd[3:0])
                            4'h1 : begin
                                if(qpi_mode_reg)
                                    next_state = sample_if_quad;
                                else
                                    next_state = sample_if_standard;
                            end
                            4'h2: begin
                                write_array_signal = 1'b1;
                                if (qpi_mode_reg)
                                    next_state = sample_if_quad;
                                else
                                    next_state = sample_if_standard;
                            end
                            4'h3: begin
                                read_array_signal = 1'b1;
                                next_state = sample_if_standard;

                            end
                            4'h5: begin
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
                            4'h0:
                            4'h1:
                            4'h7:
                            4'h8:
                            4'h9:
                            default : next_state = idle;
                        endcase
                    end

                    4'h3: begin
                        case (cmd[3:0])
                            4'h0:
                            4'h2:
                            4'h4:
                            4'h5: begin
                                read_reg_signal = 1'b1;
                                read_reg_addr = SR2;
                                if (qpi_mode_reg)
                                    next_state = drive_if_quad;
                                else
                                    next_state = drive_if_standard;
                            end
                            4'h8 : begin
                                set_qpi_mode = 1'b1;
                                next_state = idel;
                            end
                            4'hb:
                            4'hc:
                            default : next_state = idle
                        endcase
                    end

                    4'h4: begin
                        case(cmd[3:0])
                            4'h2:
                            4'h4:
                            4'h8:
                            4'hb:
                            default : next_state = idle;
                        endcase
                    end

                    4'h5: begin
                        case(cmd[3:0])
                            4'h0:
                            4'h2:
                            4'ha:
                            4'hb:
                            4'hc:
                            default : next_state = idle;
                        endcase
                    end

                    4'h6: begin
                        case(cmd[3:0])
                            4'h0:
                            4'h4:
                            4'h6 : begin
                                set_en_rst = 1'b1;
                                next_state = idle;
                            end
                            4'hb:
                            4'bc:
                            default : next_state = idle;
                        endcase
                    end

                    4'h7: begin
                        case(cmd[3:0])
                            4'h0:
                            4'h5:
                            4'h7:
                            4'ha:
                            4'he:
                            default : next_state = idel;
                        endcase
                    end

                    4'h8: begin
                        case(cmd[3:0])
                            4'h1:
                            4'h5:
                            default : next_state = idle;
                        endcase
                    end

                    4'h9: begin
                        case(cmd[3:0])
                            4'h0:
                            4'h8:
                            4'h9 : begin
                                if (en_rst) begin
                                    rst_all = 1'b1;
                                    next_state = idle;
                                end
                                else
                                    next_state = idle;
                            end
                            4'hf:
                            default : next_state = idle;
                        endcase
                    end

                    4'ha: begin
                        case(cmd[3:0])
                            4'hb:
                            default next_state = idle;
                        endcase
                    end

                    4'hb: begin
                        case(cmd[3:0])
                            4'h1:
                            4'h5:
                            4'h7:
                            4'h9:
                            4'hb:
                            4'hc:
                            4'hd:
                            4'he:
                            default : next_state = idle;
                        endcase
                    end

                    4'hc: begin
                        case(cmd[3:0])
                            4'h0: next_state = sample_if_dual;
                            4'h5:
                            4'h7:
                            4'h8:
                            default : next_state = idle;
                        endcase
                    end

                    4'hd: begin
                        case(cmd[3:0])
                            4'h8:
                            4'hc:
                            default : next_state = idle;
                        endcase
                    end

                    4'he: begin
                        case(cmd[3:0])
                            4'h0:
                            4'h1:
                            4'h2:
                            4'h3:
                            4'h4:
                            4'h9:
                            4'hb:
                            4'hc:
                            4'hd:
                            4'he:
                            default : next_state = idle;
                        endcase
                    end
            
                    4'hf: begin
                        clear_qpi_mode = 1'b1;
                        next_state = idle;
                    end
                    default: next_state = idle;
                endcase
            end

            sample_if_standard: begin
                case(cmd_reg)
                    // 8'h01 : 对采样数据计数，8/16才执行指令，否则跳转到idle；若是8，则SR2全为0
                    // write_reg_signal = 1'b1;
                    // wirte_reg_addr = SR1 & SR2; 

                    // 8'h11 : 对采样数据计数，8才执行指令，否则跳转到idle
                    // write_reg_signal = 1'b1;
                    // wirte_reg_addr = SR3;
                endcase
                // to do : 输出高速接口单线采样地址周期（32b or 24b）；采样dummy多少周期；
                // 内部计数地址、dummy，然后跳转到驱动输出状态；
            end

            sample_if_dual: begin
                // to do : 输出高速接口双线采样地址周期（32b or 24b）；采样continuous mode字节多少周期；采样dummy多少周期；
                // 内部计数地址、continus mode字节、dummy，然后跳转到驱动输出状态；
            end

            sample_if_quad: begin
                // to do : 输出高速接口四线采样地址周期（32b or 24b）；采样continuous mode字节多少周期；采样dummy多少周期；
                // 内部计数地址、continus mode字节、dummy，然后跳转到驱动输出状态；
            end

            sample_if_dtr_dual: begin
                // to do : 输出高速接口双线双边沿采样地址周期（32b or 24b）；采样continuous mode字节多少周期；采样dummy多少周期；
                // 内部计数地址、continus mode字节、dummy，然后跳转到驱动输出状态；
            end

            sample_if_dtr_quad: begin
                // to do : 输出高速接口四线双边沿采样地址周期（32b or 24b）；采样continuous mode字节多少周期；采样dummy多少周期；
                // 内部计数地址、continus mode字节、dummy，然后跳转到驱动输出状态；
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