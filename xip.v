            xip: begin
                read_array_en = 1'b1;
                if (por_xip) begin
                    case (vncr_0)
                        8'hfc : begin
                            sample_mode = sample_dual;
                            cm_cycle = 4;
                            addr_cycle = ads ? 16 : 12;
                            if (cnt == addr_cycle + cm_cycle)
                                drive_mode = drive_dual;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hfd : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_dual;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hfe : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_quad;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hfb : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = ads ? 4 : 3;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_quad;
                                if (!cs)
                                    next_state = idle;
                        end
                        default : next_state = idle;
                    endcase
                end
                else if (cmd_xip) begin
                    case(cmd_reg)
                        8'hbb : begin
                            sample_mode = sample_dual;
                            cm_cycle = 4;
                            addr_cycle = ads ? 16 : 12;
                            if (cnt == cm_cycle + addr_cycle)
                                drive_mode = drive_dual;
                                if (!cs)
                                    next_state = idle;
                        end
                        
                        8'hbc : begin
                            sample_mode = sample_dual;
                            cm_cycle = 4;
                            addr_cycle = 16;
                            if (cnt == cm_cycle + addr_cycle)
                                drive_mode = drive_dual;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hbd : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_dual;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hbe : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = 8;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_dual;
                                if (!cs)
                                    next_state = idle;
                        end
                        
                        8'heb : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_quad;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hec : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = 8;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_quad;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hed : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = ads ? 4 : 3;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_quad;
                                if (!cs)
                                    next_state = idle;
                        end

                        8'hee : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = 4;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_quad;
                                if (!cs)
                                    next_state = idle;
                        end

                        default : next_state = idle;
                    endcase
                end
            end