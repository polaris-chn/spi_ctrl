module ctrl_if(
    input sclk,
    input rstn,
    // cs#低电平有效
    input cs,
    input pwd,
    input [7:0] vncr_0,
    input [7:0] cmd,
    // continuous mode byte
    input [7:0] cm,
    // por或者reset后，是否进入xip模式，在osc fsm中用reg进行状态保持，作为此模块的输入
    input por_xip,
    input ads,
    // C0指令进来的p_data数据
    input [7:0] p_data,
    input [7:0] wrap_data,

    input qpi_read_param_en,
    input [7:0] qpi_read_param,
    input [7:0] cnt,
    input p_data_en,

    output wire clear_por_xip,

    output reg [2:0] sample_mode,
    output reg [2:0] sample_addr_mode,
    output reg [2:0] sample_data_mode,

    output reg write_SR_shadow_en,
    output reg write_SR_en,
    output reg write_array_en,
    output reg read_array_en,
    output reg read_SR_en,
    output reg set_wel,
    output reg clear_wel,
    output reg clear_FSR,
    output reg read_FSR_en,
    output reg erase_sector_en,
    output reg erase_block32_en,
    output reg erase_block64_en,
    output reg erase_chip_en,
    output reg pes_en,
    output reg per_en,
    output reg data_crc_en,
    output reg global_block_sector_lock_en,
    output reg global_block_sector_unlock_en,
    output reg write_VCR_en,
    output reg read_VCR_en,
    output reg write_NVCR_en,
    output reg read_NVCR_en,
    output reg read_manuid_devid_en,
    output reg rdid_en,
    output reg read_devid_en,
    output reg read_itcrcr_en,
    output reg write_EAR_en,
    output reg read_EAR_en,
    output reg write_VLR_en,
    output reg read_VLR_en,
    output reg read_NVLR_en,
    output reg set_NVLR_en,
    output reg clear_all_NVLR_en,
    output reg set_ads,
    output reg clear_ads,
    output reg write_sec_reg_en,
    output reg erase_sec_reg_en,
    output reg read_sec_reg_en,
    output reg read_uid_en,
    output reg rst_all,
    output reg exit_dpd_en,
    output reg enter_dpd_en,
    output reg write_pwd_en,
    output reg pwd_lock_unlock_en,
    output reg [6:0] wrap_len,
    output reg [7:0] cm_cycle,
    output reg [7:0] cmd_cycle,
    output reg [7:0] dummy_cycle,
    output reg [7:0] data_cycle,
    output reg [7:0] addr_cycle,
    output reg [7:0] sample_data_cycle

);                  
    parameter idle                  = 5'd0;
    parameter xip                   = 5'd1;
    parameter cmd_sample_qpi        = 5'd2;
    parameter cmd_sample_spi        = 5'd3;
    parameter decode_qpi            = 5'd4;
    parameter decode_spi            = 5'd5;
    parameter drive_standard        = 5'd6;
    parameter drive_dual            = 5'd7;
    parameter drive_quad            = 5'd8;
    parameter drive_dtr_dual        = 5'd9;
    parameter drive_dtr_quad        = 5'd10;

    parameter sample_standard       = 3'd0;
    parameter sample_dual           = 3'd1;
    parameter sample_quad           = 3'd2;
    parameter sample_dtr_dual       = 3'd3;
    parameter sample_dtr_quad       = 3'd4;

    reg [4:0] current_state;
    reg [4:0] next_state;

    reg set_en_rst;
    reg write_en_VSR;
    reg wrap_reg_en;
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
        else if (cm[5:4]==2'b10)
            cmd_xip <= 1'b1;
        else
            cmd_xip <= 1'b0;
    end
    
    // cm[5:4]不等于2'b10时，需要对por_xip进行清零
    assign clear_por_xip = (cm[5:4]==2'b10) ? 1'b0 : 1'b1;

    reg [7:0] cmd_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            cmd_reg <= 8'd0;
        else
            cmd_reg <= cmd;
    end

    reg qpi_mode_reg;
    reg set_qpi_mode;
    reg clear_qpi_mode;
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

    reg en_rst_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            en_rst_reg <= 1'b0;
        else if (set_en_rst)
            en_rst_reg <= 1'b1;
        else
            en_rst_reg <= 1'b0;
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
    always@(posedge sclk or negedge rstn) begin
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
        else if (enter_dpd_en)
            dpd_reg <= 1'b1;
        else if (exit_dpd_en)
            dpd_reg <= 1'b0;
        else
            dpd_reg <= dpd_reg;
    end

    always@(*) begin
        set_en_rst = 1'b0;
        case(current_state)
            idle : begin
                sample_mode                     = 3'd0;
                sample_addr_mode                = 3'd0;
                sample_data_mode                = 3'd0;
                write_SR_shadow_en              = 1'b0;
                write_SR_en                     = 1'b0;
                write_array_en                  = 1'b0;
                read_array_en                   = 1'b0;
                read_SR_en                      = 1'b0;
                set_wel                         = 1'b0;
                clear_wel                       = 1'b0;
                clear_FSR                       = 1'b0;
                read_FSR_en                     = 1'b0;
                erase_sector_en                 = 1'b0;
                erase_block32_en                = 1'b0;
                erase_block64_en                = 1'b0;
                erase_chip_en                   = 1'b0;
                pes_en                          = 1'b0;
                per_en                          = 1'b0;
                data_crc_en                     = 1'b0;
                global_block_sector_lock_en     = 1'b0;
                global_block_sector_unlock_en   = 1'b0;
                write_VCR_en                    = 1'b0;
                read_VCR_en                     = 1'b0;
                write_NVCR_en                   = 1'b0;
                read_NVCR_en                    = 1'b0;
                read_manuid_devid_en            = 1'b0;
                rdid_en                         = 1'b0;
                read_devid_en                   = 1'b0;
                read_itcrcr_en                  = 1'b0;
                write_EAR_en                    = 1'b0;
                read_EAR_en                     = 1'b0;
                write_VLR_en                    = 1'b0;
                read_VLR_en                     = 1'b0;
                read_NVLR_en                    = 1'b0;
                set_NVLR_en                     = 1'b0;
                clear_all_NVLR_en               = 1'b0;
                set_ads                         = 1'b0;
                clear_ads                       = 1'b0;
                write_sec_reg_en                = 1'b0;
                erase_sec_reg_en                = 1'b0;
                read_sec_reg_en                 = 1'b0;
                read_uid_en                     = 1'b0;
                rst_all                         = 1'b0;
                exit_dpd_en                     = 1'b0;
                enter_dpd_en                    = 1'b0;
                write_pwd_en                    = 1'b0;
                pwd_lock_unlock_en              = 1'b0;
                wrap_len                        = 7'd0;
                cm_cycle                        = 8'd0;
                cmd_cycle                       = 8'd0;
                dummy_cycle                     = 8'd0;
                data_cycle                      = 8'd0;
                addr_cycle                      = 8'd0;
                sample_data_cycle               = 8'd0;
                if (por_xip | cmd_xip)
                    next_state = xip;
                else if (qpi_mode_reg)
                    next_state = cmd_sample_qpi;
                else
                    next_state = cmd_sample_spi;
            end
            
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
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hfd : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_dual;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hfe : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_quad;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hfb : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = ads ? 4 : 3;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_quad;
                                if (~cs)
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
                                if (~cs)
                                    next_state = idle;
                        end
                        
                        8'hbc : begin
                            sample_mode = sample_dual;
                            cm_cycle = 4;
                            addr_cycle = 16;
                            if (cnt == cm_cycle + addr_cycle)
                                drive_mode = drive_dual;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hbd : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_dual;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hbe : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = 8;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_dual;
                                if (~cs)
                                    next_state = idle;
                        end
                        
                        8'heb : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_quad;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hec : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = 8;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_quad;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hed : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = ads ? 4 : 3;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_quad;
                                if (~cs)
                                    next_state = idle;
                        end

                        8'hee : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = 4;
                            if (cnt == cm_cycle + dummy_cycle + addr_cycle)
                                drive_mode = drive_dtr_quad;
                                if (~cs)
                                    next_state = idle;
                        end

                        default : next_state = idle;
                    endcase
                end
            end

            qpi : begin
                sample_mode = sample_quad;
                cmd_cycle = 2;
                case(cmd[7:4])
                    4'h0: begin
                        case(cmd[3:0])
                            4'h1:begin
                                if (write_en_VSR_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = SR1 & SR2;
                                    write_en_VSR = 1'b0;
                                    data_cycle = 4;
                                    if (cnt == data_cycle + cmd_cycle)
                                        next_state = idle;
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = SR1 & SR2;
                                    data_cycle = 4;
                                    if (cnt == data_cycle + cmd_cycle)
                                        next_state = idle;
                                end
                            end 
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if(!cs)
                                    next_state = idle;
                            end
                            4'h4: begin
                                clear_wel = 1'b1;
                                next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR1;
                                next_state = drive_quad;
                            end
                            4'h6: begin
                                set_wel = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = 6;
                                if (cnt == addr_cycle + dummy_cycle)
                                    next_state = drive_quad;
                            end
                            4'hc: begin 
                                read_array_en = 1'b1;
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
                                    next_state = drive_quad;
                                end
                            4'he: begin
                                sample_mode = sample_dtr_quad;
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 4 : 3;
                                dummy_cycle = 10;
                                case(qpi_read_param_reg[1:0])
                                    2'b00: wrap_len = 8;
                                    2'b01: wrap_len = 16;
                                    2'b10: wrap_len = 32;
                                    2'b11: wrap_len = 64;
                                    default: wrap_len = 0;
                                endcase
                                if(cnt == addr_cycle + dummy_cycle)
                                    next_state = drive_dtr_quad;
                            end
                            default: next_state = idle;
                        endcase
                    end

                    4'h1: begin
                        case(cmd[3:0])
                            4'h1 : begin
                                if (write_en_VSR_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = SR3;
                                    write_en_VSR = 1'b0;
                                    sample_data_cycle = 2;
                                    if (cnt == sample_data_cycle)
                                        next_state = idle;
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = SR3;
                                    sample_data_cycle = 2;
                                    if (cnt == sample_data_cycle)
                                        next_state = idle;
                                end 
                            end
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = 8;
                                if (!cs)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR3;
                                next_state = drive_quad;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h2: begin
                        case(cmd[3:0])
                            4'h0: begin
                                erase_sector_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'h1: begin
                                erase_sector_en = 1'b1;
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
                                    write_pwd_en = 1'b1;
                                    data_cycle = 16;
                                    if (cnt == data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h9: begin
                                if (!pwd)
                                    next_state = idle;
                                else begin
                                    pwd_lock_unlock_en = 1'b1;
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
                                read_SR_en = 1'b1;
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
                                erase_block32_en = 1'b1;
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
                                data_crc_en = 1;
                                addr_cycle = 16;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block32_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h6: begin
                        case(cmd[3:0])
                            4'h0: begin
                                erase_chip_en = 1'b1;
                                next_state = idle;
                            end
                            4'h4: begin
                                read_itcrcr_en = 1'b1;
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
                                read_FSR_en = 1'b1;
                                next_state = drive_quad;
                            end
                            4'h5: begin
                                pes_en = 1'b1;
                                next_state = idle;                                
                            end
                            4'ha: begin
                                per_en = 1'b1;
                                next_state = idle;
                            end
                            4'he: begin
                                global_block_sector_lock_en = 1'b1;
                                next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h8: begin
                        case(cmd[3:0])
                            4'h1: begin
                                write_VCR_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                data_cycle = 2;
                                if (cnt == addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_VCR_en = 1'b1;
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
                                read_manuid_devid_en = 1'b1;
                                addr_cycle = 6;
                                if (cnt == addr_cycle)
                                    next_state = drive_quad;
                            end
                            4'h8: begin
                                global_block_sector_unlock_en = 1'b1;
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
                                    rdid_en = 1'b1;
                                    next_state = drive_quad;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'ha: begin
                        case(cmd[3:0])
                            4'hb: begin
                                if (cs) begin
                                    exit_dpd_en = 1'b1;
                                    next_state = idle;
                                end
                                else begin
                                    read_devid_en = 1'b1;
                                    exit_dpd_en = 1'b1;
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
                                write_NVCR_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                data_cycle = 2;
                                if (cnt == addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_NVCR_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = 8;
                                if (cnt == addr_cycle + dummy_cycle)
                                    next_state = drive_quad;
                            end
                            4'h7: begin
                                set_ads = 1'b1;
                                next_state = idle;
                            end
                            4'h9: begin
                                enter_dpd_en = 1'b1;
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
                                write_EAR_en = 1'b1;
                                data_cycle = 2;
                                if (cnt == data_cycle)
                                    next_state = idle;
                            end
                            4'h7: begin
                                erase_chip_en = 1'b1;
                                next_state = idle;
                            end
                            4'h8: begin
                                read_EAR_en = 1'b1;
                                next_state = drive_quad;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hd: begin
                        case(cmd[3:0])
                            4'h8: begin
                                erase_block64_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin 
                                erase_block64_en = 1'b1;
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
                                read_VLR_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt == addr_cycle)
                                    next_state = drive_quad;
                            end
                            4'h1: begin
                                write_VLR_en = 1'b1;
                                addr_cycle = 8;
                                data_cycle = 2;
                                if (cnt == addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h2: begin
                                read_NVLR_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt == addr_cycle)
                                    next_state = drive_quad;
                            end
                            4'h3: begin
                                set_NVLR_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'h4: begin
                                clear_all_NVLR_en = 1'b1;
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

            spi: begin
                case(cmd[7:4])
                    4'h0: begin
                        case(cmd[3:0])
                            4'h1:begin
                                if (write_en_VSR_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = SR1 & SR2;
                                    write_en_VSR = 1'b0;
                                    data_cycle = 16;
                                    if (cnt == data_cycle)
                                        next_state = idle;
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = SR1 & SR2;
                                    data_cycle = 16;
                                    if (cnt == data_cycle)
                                        next_state = idle;
                                end
                            end 
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (!cs)
                                    next_state = idle;
                            end
                            4'h3: begin
                                    read_array_en = 1'b1;
                                    addr_cycle = ads ? 32 : 24;
                                    if (cnt == addr_cycle)
                                        next_state = drive_standard;
                            end
                            4'h4: begin
                                clear_wel = 1'b1;
                                next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR1;
                                next_state = drive_standard;
                            end
                            4'h6: begin
                                set_wel = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if (cnt == addr_cycle + dummy_cycle)
                                    next_state = drive_standard;
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if (cnt == addr_cycle + dummy_cycle)
                                    next_state = drive_standard;
                            end
                            default: next_state = idle;
                        endcase
                    end

                    4'h1: begin
                        case(cmd[3:0])
                            4'h1 : begin
                                if (write_en_VSR_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = SR3;
                                    write_en_VSR = 1'b0;
                                    data_cycle = 8;
                                    if (cnt == data_cycle)
                                        next_state = idle;
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = SR3;
                                    data_cycle = 8;
                                    if (cnt == data_cycle)
                                        next_state = idle;
                                end
                            end 
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = 32;
                                if (!cs)
                                    next_state = idle;
                            end
                            4'h3: begin
                                read_array_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt == addr_cycle)
                                    next_state = drive_standard;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR3;
                                next_state = drive_standard;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h2: begin
                        case(cmd[3:0])
                            4'h0: begin
                                erase_sector_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'h1: begin
                                erase_sector_en = 1'b1;
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
                                    write_pwd_en = 1'b1;
                                    data_cycle = 64;
                                    if (cnt == data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h9: begin
                                if (!pwd)
                                    next_state = idle;
                                else begin
                                    pwd_lock_unlock_en = 1'b1;
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
                                write_array_en = 1'b1;
                                sample_addr_mode = sample_standard;
                                addr_cycle = ads ? 32 : 24;
                                sample_data_mode = sample_quad;
                                if (!cs)
                                    next_state = idle;
                            end
                            4'h4: begin
                                write_array_en = 1'b1;
                                sample_addr_mode = sample_standard;
                                addr_cycle = 32;
                                sample_data_mode = sample_quad;
                                if (!cs)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
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
                                write_sec_reg_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (!cs)
                                    next_state = idle;
                            end
                            4'h4: begin
                                erase_sec_reg_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'h8: begin
                                read_sec_reg_en = 1'b1;
                                dummy_cycle = 8;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt == addr_cycle + dummy_cycle)
                                    next_state = drive_standard;
                            end
                            4'hb: begin
                                read_uid_en = 1'b1;
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
                                erase_block32_en = 1'b1;
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
                                data_crc_en = 1;
                                addr_cycle = 64;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block32_en = 1'b1;
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
                                erase_chip_en = 1'b1;
                                next_state = idle;
                            end
                            4'h4: begin
                                read_itcrcr_en = 1'b1;
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
                                read_FSR_en = 1'b1;
                                next_state = drive_standard;
                            end
                            4'h5: begin
                                pes_en = 1'b1;
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
                                per_en = 1'b1;
                                next_state = idle;
                            end
                            4'he: begin
                                global_block_sector_lock_en = 1'b1;
                                next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h8: begin
                        case(cmd[3:0])
                            4'h1: begin
                                write_VCR_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                data_cycle = 8;
                                if (cnt == addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_VCR_en = 1'b1;
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
                                read_manuid_devid_en = 1'b1;
                                addr_cycle = 24;
                                if (cnt == addr_cycle)
                                    next_state = drive_standard;
                            end
                            4'h8: begin
                                global_block_sector_unlock_en = 1'b1;
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
                                rdid_en = 1'b1;
                                next_state = drive_standard;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'ha: begin
                        case(cmd[3:0])
                            4'hb: begin
                                if (cs) begin
                                    exit_dpd_en = 1'b1;
                                    next_state = idle;
                                end
                                else begin
                                    read_devid_en = 1'b1;
                                    exit_dpd_en = 1'b1;
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
                                write_NVCR_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                data_cycle = 8;
                                if (cnt == addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_NVCR_en = 1'b1;
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
                                enter_dpd_en = 1'b1;
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
                                write_EAR_en = 1'b1;
                                data_cycle = 8;
                                if (cnt == data_cycle)
                                    next_state = idle;
                            end
                            4'h7: begin
                                erase_chip_en = 1'b1;
                                next_state = idle;
                            end
                            4'h8: begin
                                read_EAR_en = 1'b1;
                                next_state = drive_standard;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hd: begin
                        case(cmd[3:0])
                            4'h8: begin
                                erase_block64_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block64_en = 1'b1;
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
                                read_VLR_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt == addr_cycle)
                                    next_state = drive_standard;
                            end
                            4'h1: begin
                                write_VLR_en = 1'b1;
                                addr_cycle = 32;
                                data_cycle = 8;
                                if (cnt == addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h2: begin
                                read_NVLR_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt == addr_cycle)
                                    next_state = drive_standard;
                            end
                            4'h3: begin
                                set_NVLR_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt == addr_cycle)
                                    next_state = idle;
                            end
                            4'h4: begin
                                clear_all_NVLR_en = 1'b1;
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

            default: begin
                next_state = idle;
            end
        endcase
    end

endmodule
.