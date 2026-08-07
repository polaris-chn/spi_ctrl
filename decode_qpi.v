decode_qpi : begin
    sample_mode = sample_quad;
    case(cmd[7:4])
        4'h0: begin
            case(cmd[3:0])
                4'h1:begin
                    if (write_en_VSR_reg) begin
                        write_SR_shadow_signal = 1'b1;
                        write_SR_addr = SR1 & SR2;
                        write_en_VSR = 1'b0;
                        sample_data_cycle = 4;
                        if (cnt == sample_data_cycle)
                            next_state = idle;
                    end
                    else begin
                        write_SR_signal = 1'b1;
                        write_SR_addr = SR1 & SR2;
                        sample_data_cycle = 4;
                        if (cnt == sample_data_cycle)
                            next_state = idle;
                    end
                end 
                4'h2: begin
                    write_array_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    if(!cs)
                        next_state = idle;
                end
                4'h4: begin
                    clear_wel = 1'b1;
                    next_state = idle;
                end
                4'h5: begin
                    read_SR_signal = 1'b1;
                    read_SR_addr = SR1;
                    next_state = drive_quad;
                end
                4'h6: begin
                    set_wel = 1'b1;
                    next_state = idle;
                end
                4'hb: begin
                    read_array_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    dummy_cycle = 6;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'hc: begin 
                    read_array_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    dummy_cycle = 4;
                    case(p_reg[1:0])
                        2'b00: wrap_len = 8;
                        2'b01: wrap_len = 16;
                        2'b10: wrap_len = 32;
                        2'b11: wrap_len = 64;
                        default: wrap_len = 0;
                    endcase
                    if(cnt == addr_cycle + dummy_cycle)
                        next_state = drive_quad
                end
                4'he: begin
                    sample_mode = sample_dtr_quad;
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
                    if(cnt ==a ddr_cycle + dummy_cycle)
                        next_state = drive_dtr_quad;
                end
            endcase
        end

        4'h1: begin
            case(cmd[3:0])
                4'h1 : begin
                    if (write_en_VSR_reg) begin
                        write_SR_shadow_signal = 1'b1;
                        write_SR_addr = SR3;
                        write_en_VSR = 1'b0;
                        sample_data_cycle = 2;
                        if (cnt == sample_data_cycle)
                            next_state = idle;
                    end
                    else begin
                        write_SR_signal = 1'b1;
                        write_SR_addr = SR3;
                        sample_data_cycle = 2;
                        if (cnt == sample_data_cycle)
                            next_state = idle;
                    end 
                end
                4'h2: begin
                    write_array_signal = 1'b1;
                    addr_cycle = 8;
                    if (!cs)
                        next_state = idle;
                end
                4'h5: begin
                    read_SR_signal = 1'b1;
                    read_SR_addr = SR3;
                    next_state = drive_quad;
                end
                default : next_state = idle;
            endcase
        end

        4'h2: begin
            case(cmd[3:0])
                4'h0: begin
                    erase_sector_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'h1: begin
                    erase_sector_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'h7: begin
                    if (pwd)
                        next_state = idle;
                    else begin
                        dummy_cycle = 8;
                        if (cnt == dummy_cycle)
                            next_state = drive_quad;
                    end
                end
                4'h8: begin
                    if (pwd)
                        next_state = idle;
                    else begin
                        write_pwd_signal = 1'b1;
                        data_cycle = 16;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
                end
                4'h9: begin
                    if (!pwd)
                        next_state = idle;
                    else begin
                        pwd_lock_unlock_signal = 1'b1;
                        data_cycle = 16;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
                end
                default : next_state = idle;
            endcase
        end

        4'h3: begin
            case (cmd[3:0])
                4'h0: begin
                    clear_FSR = 1'b1;
                    next_state = idle;
                end
                4'h5: begin
                    read_SR_signal = 1'b1;
                    read_SR_addr = SR2;
                    next_state = drive_quad;
                end
                default : next_state = idle;
            endcase
        end

        4'h5: begin
            case(cmd[3:0])
                4'h0: begin
                    write_en_VSR = 1'b1;
                    next_state = idle;
                end
                4'h2: begin
                    erase_block32_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'ha: begin
                    addr_cycle = 6;
                    dummy_cycle = 8;
                    if(cnt == addr_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'hb: begin
                    data_crc_signal = 1;
                    addr_cycle = 16;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'hc: begin
                    erase_block32_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == 8)
                        next_state = idle;
                end
                default : next_state = idle;
            endcase
        end

        4'h6: begin
            case(cmd[3:0])
                4'h0: begin
                    erase_chip_signal = 1'b1;
                    next_state = idle;
                end
                4'h4: begin
                    read_itcrcr_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == addr_cycle)
                        next_state = drive_quad;
                end 
                4'h6: begin
                    set_en_rst = 1'b1;
                    next_state = idle;
                end
                default : next_state = idle;
            endcase
        end

        4'h7: begin
            case(cmd[3:0])
                4'h0: begin
                    read_FSR_signal = 1'b1;
                    next_state = drive_quad;
                end
                4'h5: begin
                    pes_signal = 1'b1;
                    next_state = idle;                                
                end
                4'ha: begin
                    per_signal = 1'b1;
                    next_state = idle;
                end
                4'he: begin
                    global_block_sector_lock_signal = 1'b1;
                    next_state = idle;
                end
                default : next_state = idle;
            endcase
        end

        4'h8: begin
            case(cmd[3:0])
                4'h1: begin
                    write_VCR_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    data_cycle = 2;
                    if (cnt == addr_cycle + data_cycle)
                        next_state = idle;
                end
                4'h5: begin
                    read_VCR_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                default : next_state = idle;
            endcase
        end

        4'h9: begin
            case(cmd[3:0])
                4'h0: begin
                    addr_cycle = 6;
                    if (cnt == addr_cycle)
                        next_state = drive_quad;
                end
                4'h8: begin
                    global_block_sector_unlock_signal = 1'b1;
                    next_state = idle;
                end
                4'h9 : begin 
                    if (en_rst_reg) begin
                        rst_all = 1'b1;
                        next_state = idle;
                    end
                    else
                        next_state = idle;
                end
                4'hf: begin
                        rdid_signal = 1'b1;
                        next_state = drive_quad;
                end
                default : next_state = idle;
            endcase
        end

        4'ha: begin
            case(cmd[3:0])
                4'hb: begin
                    if (!cs) begin
                        exit_dpd_signal = 1'b1;
                        next_state = idle;
                    end
                    else begin
                        read_devid_signal = 1'b1;
                        dummy_cycle = 6;
                        if (cnt ==  dummy_cycle)
                            next_state = drive_quad;
                        end
                    end
                default : next_state = idle;
            endcase
        end

        4'hb: begin
            case(cmd[3:0])
                4'h1: begin
                    write_NVCR_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    data_cycle = 2;
                    if (cnt == addr_cycle + data_cycle)
                        next_state = idle;
                end
                4'h5: begin
                    read_NVCR_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    dummy_cycle = 8;
                    if (cnt = addr_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'h7: begin
                    set_ads = 1'b1;
                    next_state = idle;
                end
                4'h9: begin
                    enter_dpd_signal = 1'b1;
                    next_state = idle;
                end
                default : next_state = idle;
            endcase
        end

        4'hc: begin
            case(cmd[3:0])
                4'h0: begin
                        // 这里的qpi_read_param_en和qpi_read_param信号都是从接口进来的，是input信号
                        data_cycle = 2;
                        if (cnt == data_cycle)
                            next_state = idle;
                end
                4'h5: begin
                    write_EAR_signal = 1'b1;
                    data_cycle = 2;
                    if (cnt == data_cycle)
                        next_state = idle;
                end
                4'h7: begin
                    erase_chip_signal = 1'b1;
                    next_state = idle;
                end
                4'h8: begin
                    read_EAR_signal = 1'b1;
                    next_state = drive_quad;
                end
                default : next_state = idle;
            endcase
        end

        4'hd: begin
            case(cmd[3:0])
                4'h8: begin
                    erase_block64_signal = 1'b1;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'hc: begin 
                    erase_block64_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                default : next_state = idle;
            endcase
        end

        4'he: begin
            case(cmd[3:0])
                4'h0: begin
                    read_VLR_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == addr_cycle)
                        next_state = drive_quad;
                end
                4'h1: begin
                    write_VLR_signal = 1'b1;
                    addr_cycle = 8;
                    data_cycle = 2;
                    if (cnt == addr_cycle + data_cycle)
                        next_state = idle;
                end
                4'h2: begin
                    read_NVLR_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == addr_cycle)
                        next_state = drive_quad;
                end
                4'h3: begin
                    set_NVLR_signal = 1'b1;
                    addr_cycle = 8;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'h4: begin
                    clear_all_NVLR_signal = 1'b1;
                    next_state = idle;
                end
                4'h9: begin
                    clear_ads = 1'b1;
                    next_state = idle;
                end
                4'hb: begin
                    addr_cycle = ads ? 8 : 6;
                    cm_cycle = 2;
                    dummy_cycle = 2;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'hc: begin
                    addr_cycle = 8;
                    cm_cycle = 2;
                    dummy_cycle = 2;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'hd: begin
                    addr_cycle = ads ? 4 : 3;
                    cm_cycle = 1;
                    dummy_cycle = 9;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_dtr_quad;
                end
                4'he: begin
                    addr_cycle = 4;
                    cm_cycle = 1;
                    dummy_cycle = 9;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_dtr_quad;
                end
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
