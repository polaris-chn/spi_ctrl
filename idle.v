idle: begin
        if (por_xip) 
            case (vncr_0)
                8'hfc : begin
                    cm_cycle = 4;
                    sample_mode = sample_dual;
                    addr_cycle = ads ? 16 : 12;
                    if (cnt == addr_cycle + cm_cycle)
                        next_state = drive_dual;
                end

                8'hfd : begin
                    cm_cycle = 2;
                    dummy_cycle = 4
                    sample_mode = sample_dtr_dual;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_dtr_dual;
                end

                8'hfe : begin
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    sample_mode = sample_quad;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_quad;
                end

                8'hfb : begin
                    cm_cycle = 1;
                    dummy_cycle = 9;
                    sample_mode = sample_dtr_quad;
                    addr_cycle = ads ? 4 : 3;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_dtr_quad;
                end
                default : next_state = idle;
            endcase 

        else if (cmd_xip) 
            case(cmd_reg)
                8'hbb : begin
                    cm_cycle = 4;
                    sample_mode = sample_dual;
                    addr_cycle = ads ? 16 : 12;
                    if (cnt == cm_cycle + addr_cycle)
                        next_state = drive_dual;
                end
                
                8'hbc : begin
                    cm_cycle = 4;
                    sample_moe = sample_dual;
                    addr_cycle = 16;
                    if (cnt == cm_cycle + addr_cycle)
                        next_state = drive_dual;
                end

                8'hbd : begin
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    sample_mode = sample_dtr_dual;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_dtr_dual;
                end

                8'hbe : begin
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    sample_mode = sample_dtr_dual;
                    addr_cycle = 8;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_dtr_dual;
                end
                
                8'heb : begin
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    sample_mode = sample_quad;
                    addr_cycle = ads ? 8 : 6;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_quad;
                end

                8'hec : begin
                    cm_cycle = 2;
                    dummy_cycle = 4;
                    sample_mode = sample_quad;
                    addr_cycle = 8;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_quad;
                end

                8'hed : begin
                    cm_cycle = 1;
                    dummy_cycle = 9;
                    sample_mode = sample_dtr_quad;
                    addr_cycle = ads ? 4 : 3;
                    if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_dtr_quad;
                end

                8'hee : begin
                    cm_cycle = 1;
                    dummy_cycle = 9;
                    sample_mode = sample_dtr_quad;
                    addr_cycle = 4;
                    if (cnt = cm_cycle + dummy_cycle + addr_cycle)
                        next_state = drive_dtr_quad;
                end
                default : next_state = idle;
            endcase
            
        else if (qpi_mode_reg) begin
            sample_mode = sample_quad;
            cmd_cycle = 2;
            if (cnt == cm_cycle)
                next_state = decode_qpi;
        end
                
        else begin
            sample_mode = sample_standard
            cmd_cycle = 8;
            if (cnt == cm_cycle)
                next_state = decode_spi;
        end
end