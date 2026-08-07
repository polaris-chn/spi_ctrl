decode_spi: begin
    sample_mode = sample_standard;
    case(cmd[7:4])
        4'h0: begin
            case(cmd[3:0])
            4'h1:begin
                    if (write_en_VSR_reg) begin
                        write_SR_shadow_signal = 1'b1;
                        write_SR_addr = SR1 & SR2;
                        write_en_VSR = 1'b0;
                        data_cycle = 16;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
                    else begin
                        write_SR_signal = 1'b1;
                        write_SR_addr = SR1 & SR2;
                        data_cycle = 16;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
            end 
            4'h2: begin
                write_array_signal = 1'b1;
                addr_cycle = ads ? 32 : 24;
                if (!cs)
                    next_state = idle;
            end
            4'h3: begin
                    read_array_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    if (cnt == addr_cycle)
                        next_state = drive_standard;
            end
            4'h4: begin
                clear_wel = 1'b1;
                next_state = idle;
            end
            4'h5: begin
                read_SR_signal = 1'b1;
                read_SR_addr = SR1;
                next_state = drive_standard;
            end
            4'h6: begin
                set_wel = 1'b1;
                next_state = idle;
            end
            4'hb: begin
                read_array_signal = 1'b1;
                addr_cycle = ads ? 32 : 24;
                dummy_cycle = 8;
                if (cnt == addr_cycle + dummy_cycle)
                    next_state = drive_standard;
            end
            4'hc: begin
                read_array_signal = 1'b1;
                addr_cycle = 32;
                dummy_cycle = 8;
                if (cnt == addr_cycle + dummy_cycle)
                    next_state = drive_standard;
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
                        data_cycle = 8;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
                    else begin
                        write_SR_signal = 1'b1;
                        write_SR_addr = SR3;
                        data_cycle = 8;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
                end 
                4'h2: begin
                    write_array_signal = 1'b1;
                    addr_cycle = 32;
                    if (!cs)
                        next_state = idle;
                end
                4'h3: begin
                    read_array_signal = 1'b1;
                    addr_cycle = 32;
                    if (cnt == addr_cycle)
                        next_state = drive_standard;
                end
                4'h5: begin
                    read_SR_signal = 1'b1;
                    read_SR_addr = SR3;
                    next_state = drive_standard;
                end
                default : next_state = idle;
            endcase
        end

        4'h2: begin
            case(cmd[3:0])
                4'h0: begin
                    erase_sector_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'h1: begin
                    erase_sector_signal = 1'b1;
                    addr_cycle = 32;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'h7: begin
                    if (pwd)
                        next_state = idle;
                    else 
                        next_state = drive_standard;
                end
                4'h8: begin 
                    if (pwd)
                        next_state = idle;
                    else begin
                        write_pwd_signal = 1'b1;
                        data_cycle = 64;
                        if (cnt == data_cycle)
                            next_state = idle;
                    end
                end
                4'h9: begin
                    if (!pwd)
                        next_state = idle;
                    else begin
                        pwd_lock_unlock_signal = 1'b1;
                        data_cycle = 64;
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
                4'h2: begin
                    write_array_signal = 1'b1;
                    sample_addr_mode = sample_standard;
                    addr_cycle = ads ? 32 : 24;
                    sample_data_mode = sample_quad;
                    if (!cs)
                        next_state = idle;
                end
                4'h4: begin
                    write_array_signal = 1'b1;
                    sample_addr_mode = sample_standard;
                    addr_cycle = 32;
                    sample_data_mode = sample_quad;
                    if (!cs)
                        next_state = idle;
                end
                4'h5: begin
                    read_SR_signal = 1'b1;
                    read_SR_addr = SR2;
                    next_state = drive_standard;
                end
                4'h8 : begin
                    set_qpi_mode = 1'b1;
                    next_state = idle;
                end
                4'hb: begin
                    addr_cycle = ads ? 32 : 24;
                    dummy_cycle = 8;
                    if(cnt == addr_cycle + dummy_cycle)
                        next_state = drive_dual;
                end
                4'hc: begin
                    addr_cycle = 32;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle+dummy_cycle)
                        next_state = drive_dual;
                end
                default : next_state = idle;
            endcase
        end

        4'h4: begin
            case (cmd[3:0])
                4'h2: begin
                    write_sec_reg_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    if (!cs)
                        next_state = idle;
                end
                4'h4: begin
                    erase_sec_reg_signale = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'h8: begin
                    read_sec_reg_signal = 1'b1;
                    dummy_cycle = 8;
                    addr_cycle = ads ? 32 : 24;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_standard;
                end
                4'hb: begin
                    read_uid_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_standard;
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
                    addr_cycle = ads ? 32 : 24;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'ha: begin
                    addr_cycle = 24;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_standard;
                end
                4'hb: begin
                    data_crc_signal = 1;
                    addr_cycle = 64;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'hc: begin
                    erase_block32_signal = 1'b1;
                    addr_cycle = 32;
                    if (cnt == addr_cycle)
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
                    addr_cycle = 32;
                    if (cnt == addr_cycle)
                        next_state = drive_standard;
                end 
                4'h6: begin
                    set_en_rst = 1'b1;
                    next_state = idle;
                end
                4'hb: begin
                    addr_cycle = ads ? 32 : 24;
                    dummy_cycle = 8;
                    if(cnt == addr_cycle+dummy_cycle)
                        next_state = drive_quad;
                end
                4'hc: begin
                    addr_cycle = 32;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                default : next_state = idle;
            endcase
        end

        4'h7: begin
            case(cmd[3:0])
                4'h0: begin
                    read_FSR_signal = 1'b1;
                    next_state = drive_standard;
                end
                4'h5: begin
                    pes_signal = 1'b1;
                    next_state = idle;                                
                end
                4'h7: begin
                        dummy_cycle = 6;
                        data_cycle = 2;
                        if (cnt == dummy_cycle + data_cycle) begin
                            wrap_reg_en = 1'b1;
                            next_state = idle;
                        end
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
                    addr_cycle = ads ? 32 : 24;
                    data_cycle = 8;
                    if (cnt == addr_cycle + data_cycle)
                        next_state = idle;
                end
                4'h5: begin
                    read_VCR_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_standard;
                end
                default : next_state = idle;
            endcase
        end

        4'h9: begin
            case(cmd[3:0])
                4'h0: begin
                    read_manuid_devid_signal = 1'b1;
                    addr_cycle = 24;
                    if (cnt == addr_cycle)
                        next_state = drive_standard;
                end
                4'h8: begin
                    global_block_sector_unlock_signal = 1'b1;
                    next_state = idle;
                end
                4'h9 : begin
                    if (en_rst) begin
                        rst_all = 1'b1;
                        next_state = idle;
                    end
                    else
                        next_state = idle;
                end
                4'hf: begin
                    rdid_signal = 1'b1;
                    next_state = drive_standard;
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
                        dummy_cycle = 24;
                        if (cnt == dummy_cycle)
                            next_state = drive_standard;
                    end
                end
                default : next_state = idle;
            endcase
        end

        4'hb: begin
            case(cmd[3:0])
                4'h1: begin
                    write_NVCR_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    data_cycle = 8;
                    if (cnt == addr_cycle + data_cycle)
                        next_state = idle;
                end
                4'h5: begin
                    read_NVCR_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    dummy_cycle = 8;
                    if (cnt == addr_cycle + dummy_cycle)
                        next_state = drive_standard;
                end
                4'h7: begin
                    set_ads = 1'b1;
                    next_state = idle;
                end
                4'h9: begin
                    enter_dpd_signal = 1'b1;
                    next_state = idle;
                end
                4'hb: begin
                    addr_cycle = ads ? 16 : 12;
                    cm_cycle = 4;
                    if(cnt == addr_cycle + cm_cycle)
                        next_state = drive_dual;
                end
                4'hc: begin
                    addr_cycle = 16;
                    cm_cycle = 4;
                    if(cnt == addr_cycle + cm_cycle)
                        next_state = drive_dual;
                end
                4'hd: begin
                    addr_cycle = ads ? 8 : 6;
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    if(cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_dtr_dual;
                end
                4'he: begin
                    addr_cycle = 8;
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    if(cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_dtr_dual;
                end
                default : next_state = idle;
            endcase
        end

        4'hc: begin
            case(cmd[3:0])
                4'h5: begin
                    write_EAR_signal = 1'b1;
                    data_cycle = 8;
                    if (cnt == data_cycle)
                        next_state = idle;
                end
                4'h7: begin
                    erase_chip_signal = 1'b1;
                    next_state = idle;
                end
                4'h8: begin
                    read_EAR_signal = 1'b1;
                    next_state = drive_standard;
                end
                default : next_state = idle;
            endcase
        end

        4'hd: begin
            case(cmd[3:0])
                4'h8: begin
                    erase_block64_signal = 1'b1;
                    addr_cycle = ads ? 32 : 24;
                    if (cnt == addr_cycle)
                        next_state = idle;
                end
                4'hc: begin
                    erase_block64_signal = 1'b1;
                    addr_cycle = 32;
                    if(cnt == addr_cycle)
                        next_state = idle;
                end
                default : next_state = idle;
            endcase
        end

        4'he: begin
            case(cmd[3:0])
                4'h0: begin
                    read_VLR_signal = 1'b1;
                    addr_cycle = 32;
                    if (cnt == addr_cycle)
                        next_state = drive_standard;
                end
                4'h1: begin
                    write_VLR_signal = 1'b1;
                    addr_cycle = 32;
                    data_cycle = 8;
                    if (cnt == addr_cycle + data_cycle)
                        next_state = idle;
                end
                4'h2: begin
                    read_NVLR_signal = 1'b1;
                    addr_cycle = 32;
                    if (cnt == addr_cycle)
                        next_state = drive_standard;
                end
                4'h3: begin
                    set_NVLR_signal = 1'b1;
                    addr_cycle = 32;
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
                    dummy_cycle = 4;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'hc: begin
                    addr_cycle = 8;
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_quad;
                end
                4'hd: begin
                    addr_cycle = ads ? 4 : 3;
                    cm_cycle = 1;
                    dummy_cycle = 7;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_dtr_quad;
                end
                4'he: begin
                    addr_cycle = 4;
                    cm_cycle = 1;
                    dummy_cycle = 7;
                    if (cnt == addr_cycle + cm_cycle + dummy_cycle)
                        next_state = drive_dtr_quad;
                end
                default : next_state = idle;
            endcase
        end
                
        default: next_state = idle;
    endcase
end