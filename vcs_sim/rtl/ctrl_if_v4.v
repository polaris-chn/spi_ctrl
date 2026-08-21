/* verilator lint_off DECLFILENAME */
module ctrl_if(
    input sclk,
    input rstn,
    // cs#低电平有效
    input cs,
    input pwd,
    input [7:0] vncr_0,
    input [7:0] cmd,
    // continuous mode byte，是否持续连读模式
    /* verilator lint_off UNUSEDSIGNAL */
    input [7:0] cm,
    /* verilator lint_on UNUSEDSIGNAL */
    // por或者reset后，是否进入xip模式，在osc fsm中用reg进行状态保持，作为此模块的输入
    input por_xip,
    input ads,
    // 77指令进来的wrap数据
    input [7:0] spi_wrap_data,
    // C0指令进来的parameter数据，用于设置read freq, dummcy周期数， wrap length
    input [7:0] qpi_read_param,

    output wire clear_por_xip,
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
    output reg read_pwd_en,
    output reg pwd_lock_unlock_en,
    output reg [6:0] wrap_len,
    output reg [7:0] cm_cycle,
    output reg [7:0] cmd_cycle,
    output reg [7:0] dummy_cycle,
    output reg [7:0] data_cycle,
    output reg [7:0] addr_cycle,
    output reg [2:0] sample_cmd_mode,
    output reg [2:0] sample_mode,
    output reg [2:0] drive_mode,
    output reg [1:0] write_SR_addr,
    output reg [1:0] read_SR_addr
);
    parameter idle                  = 5'd0;
    parameter xip                   = 5'd1;
    parameter qpi                   = 5'd2;
    parameter spi                   = 5'd3;

    parameter sample_standard       = 3'd1;
    parameter sample_dual           = 3'd2;
    parameter sample_quad           = 3'd3;
    parameter sample_dtr_dual       = 3'd4;
    parameter sample_dtr_quad       = 3'd5;

    parameter drive_standard        = 3'd1;
    parameter drive_dual            = 3'd2;
    parameter drive_quad            = 3'd3;
    parameter drive_dtr_dual        = 3'd4;
    parameter drive_dtr_quad        = 3'd5;

    localparam SR1 = 2'd0;
    localparam SR2 = 2'd1;
    localparam SR3 = 2'd2;
    // read_SR_addr编码：0=SR1, 1=SR2, 2=SR3；
    // write_SR_addr编码：0=SR1&SR2, 2=SR3。
    localparam WR_SR1_SR2 = 2'd0;

    reg [4:0] current_state;
    reg [4:0] next_state;

    reg set_rst_en;
    reg set_volatile_sr_write;
    reg clear_volatile_sr_write;
    reg clear_rst_en;
    reg spi_wrap_data_en;
    reg qpi_read_param_en;
    reg qpi_read_param_valid;
    reg cs_prev;
    reg [7:0] cnt;

    wire cs_fall;
    wire cmd_boundary;

    assign cs_fall     = cs_prev & ~cs;
    assign cmd_boundary = ((current_state == qpi) || (current_state == spi)) && (cnt >= cmd_cycle);

    // C0h P5-P4 dummy-cycle lookup.
    // STR: 00=4, 01=6, 10=8, 11=10
    // DTR: 00=10, 01=8, 10=10, 11=10
    function [7:0] qpi_dummy_sel;
        input       dtr;
        input [1:0] p;
        begin
            if (dtr) begin
                case (p)
                    2'd0 : qpi_dummy_sel = 8'd10;
                    2'd1 : qpi_dummy_sel = 8'd8;
                    2'd2 : qpi_dummy_sel = 8'd10;
                    2'd3 : qpi_dummy_sel = 8'd10;
                    default : qpi_dummy_sel = 8'd10;
                endcase
            end
            else begin
                case (p)
                    2'd0 : qpi_dummy_sel = 8'd4;
                    2'd1 : qpi_dummy_sel = 8'd6;
                    2'd2 : qpi_dummy_sel = 8'd8;
                    2'd3 : qpi_dummy_sel = 8'd10;
                    default : qpi_dummy_sel = 8'd4;
                endcase
            end
        end
    endfunction


    // 内部SCLK计数器：
    // CS#=1时清零；CS#=0时在每个sclk上升沿递增；
    // 计数到8'hFF后饱和，避免长时间连续读时计数器回绕导致使能丢失。
    // CS#下降沿后的第一个sclk边沿把cnt置1，避免CS#拉高期间无sclk时残留旧计数值。
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            cnt <= 8'd0;
        else if (rst_all)
            cnt <= 8'd0;
        else if (cs)
            cnt <= 8'd0;
        else if (cs_fall)
            cnt <= 8'd1;
        else if (cnt == 8'hFF)
            cnt <= cnt;
        else
            cnt <= cnt + 1'b1;
    end

    always@(posedge sclk or negedge rstn) begin
        if (!rstn) begin
            current_state <= idle;
            cs_prev      <= 1'b1;
        end
        else if (rst_all) begin
            current_state <= idle;
            cs_prev      <= 1'b1;
        end
        else begin
            current_state <= next_state;
            cs_prev      <= cs;
        end
    end

    reg cmd_xip;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            cmd_xip <= 1'b0;
        else if (rst_all)
            cmd_xip <= 1'b0;
        else if (cm[5:4]==2'b10)
            cmd_xip <= 1'b1;
        else
            cmd_xip <= 1'b0;
    end

    // 仅在XIP模式下、mode byte采样完成后，若M5-4 != 10，才清除POR-XIP。
    // 避免复位/空闲期间cm无效时误清por_xip。
    wire xip_mode_sampled;
    assign xip_mode_sampled = (current_state == xip) && (cnt >= (addr_cycle + cm_cycle));
    assign clear_por_xip = xip_mode_sampled && (cm[5:4] != 2'b10);

    reg [7:0] cmd_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            cmd_reg <= 8'd0;
        else if (rst_all)
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
        else if (rst_all)
            qpi_mode_reg <= 1'b0;
        else if (set_qpi_mode)
            qpi_mode_reg <= 1'b1;
        else if (clear_qpi_mode)
            qpi_mode_reg <= 1'b0;
        else
            qpi_mode_reg <= qpi_mode_reg;
    end

    reg rst_en_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
         rst_en_reg <= 1'b0;
        else if (rst_all)
         rst_en_reg <= 1'b0;
        else if (set_rst_en)
         rst_en_reg <= 1'b1;
        else if (clear_rst_en)
         rst_en_reg <= 1'b0;
        else
         rst_en_reg <= rst_en_reg;
    end

    // 50h置位易失SR写使能；除WRSR(01h/11h)外，任意其他命令在命令边界处清除该使能。
    // WRSR写完成后由clear_volatile_sr_write清除。
    reg write_VSR_en_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            write_VSR_en_reg <= 1'b0;
        else if (rst_all)
            write_VSR_en_reg <= 1'b0;
        else if (clear_volatile_sr_write)
            write_VSR_en_reg <= 1'b0;
        else if (set_volatile_sr_write)
            write_VSR_en_reg <= 1'b1;
        else if (cmd_boundary && (cmd != 8'h50) && (cmd != 8'h01) && (cmd != 8'h11))
            write_VSR_en_reg <= 1'b0;
        else
            write_VSR_en_reg <= write_VSR_en_reg;
    end

    // spi下77指令进来的wrap配置。
    // 复位默认W4=1（不wrap），因此复位值为8'h10。
    reg [7:0] spi_wrap_data_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            spi_wrap_data_reg <= 8'h10;
        else if (rst_all)
            spi_wrap_data_reg <= 8'h10;
        else if (spi_wrap_data_en)
            spi_wrap_data_reg <= spi_wrap_data;
        else
            spi_wrap_data_reg <= spi_wrap_data_reg;
    end

    // qpi下c0指令进来的read parameter配置
    reg [7:0] qpi_read_param_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn) begin
            qpi_read_param_reg   <= 0;
            qpi_read_param_valid <= 1'b0;
        end
        else if (rst_all) begin
            qpi_read_param_reg   <= 0;
            qpi_read_param_valid <= 1'b0;
        end
        else if (qpi_read_param_en) begin
            qpi_read_param_reg   <= qpi_read_param;
            qpi_read_param_valid <= 1'b1;
        end
        else begin
            qpi_read_param_reg   <= qpi_read_param_reg;
            qpi_read_param_valid <= qpi_read_param_valid;
        end
    end

    reg dpd_reg;
    always@(posedge sclk or negedge rstn) begin
        if (!rstn)
            dpd_reg <= 1'b0;
        else if (rst_all)
            dpd_reg <= 1'b0;
        else if (enter_dpd_en)
            dpd_reg <= 1'b1;
        else if (exit_dpd_en)
            dpd_reg <= 1'b0;
        else
            dpd_reg <= dpd_reg;
    end

    always@(*) begin
        write_VCR_en                    = 1'b0;
        spi_wrap_data_en                = 1'b0;
        set_rst_en                      = 1'b0;
        set_volatile_sr_write           = 1'b0;
        clear_volatile_sr_write         = 1'b0;
        set_qpi_mode                    = 1'b0;
        clear_qpi_mode                  = 1'b0;
        clear_rst_en                    = 1'b0;
        qpi_read_param_en               = 1'b0;
        next_state                      = current_state;
        sample_mode                     = 3'd0;
        sample_cmd_mode                 = 3'd0;
        drive_mode                      = 3'd0;
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
        read_pwd_en                     = 1'b0;
        write_SR_addr                   = 2'd0;
        read_SR_addr                    = 2'd0;
        wrap_len                        = 7'd0;
        cm_cycle                        = 8'd0;
        cmd_cycle                       = 8'd0;
        dummy_cycle                     = 8'd0;
        data_cycle                      = 8'd0;
        addr_cycle                      = 8'd0;
        case(current_state)
            idle : begin
                if (cs_fall) begin
                    if (por_xip | cmd_xip)
                        next_state = xip;
                    else if (qpi_mode_reg)
                        next_state = qpi;
                    else
                        next_state = spi;
                end
                else begin
                    next_state = idle;
                end
            end

            xip: begin
                read_array_en = 1'b1;
                if (por_xip) begin
                    case (vncr_0)
                        8'hfc : begin
                            sample_mode = sample_dual;
                            cm_cycle = 4;
                            addr_cycle = ads ? 16 : 12;
                            if (cnt >= addr_cycle + cm_cycle) begin
                                drive_mode = drive_dual;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hfd : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_dtr_dual;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hfe : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_quad;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hfb : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = ads ? 4 : 3;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_dtr_quad;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
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
                            if (cnt >= cm_cycle + addr_cycle) begin
                                drive_mode = drive_dual;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hbc : begin
                            sample_mode = sample_dual;
                            cm_cycle = 4;
                            addr_cycle = 16;
                            if (cnt >= cm_cycle + addr_cycle) begin
                                drive_mode = drive_dual;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hbd : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_dtr_dual;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hbe : begin
                            sample_mode = sample_dtr_dual;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = 8;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_dtr_dual;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'heb : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = ads ? 8 : 6;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_quad;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hec : begin
                            sample_mode = sample_quad;
                            cm_cycle = 2;
                            dummy_cycle = 4;
                            addr_cycle = 8;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_quad;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hed : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = ads ? 4 : 3;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_dtr_quad;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        8'hee : begin
                            sample_mode = sample_dtr_quad;
                            cm_cycle = 1;
                            dummy_cycle = 9;
                            addr_cycle = 4;
                            if (cnt >= cm_cycle + dummy_cycle + addr_cycle) begin
                                drive_mode = drive_dtr_quad;
                            end
                            if (cs) begin
                                next_state = idle;
                            end
                        end

                        default : next_state = idle;
                    endcase
                end
                else begin
                    next_state = idle;
                end
            end

            qpi : begin
                // 指令采样模式
                sample_cmd_mode = sample_quad;
                cmd_cycle = 2;
                // 除指令外的采用模式，包括地址、数据、CM字节、dummy
                sample_mode = sample_quad;
                set_rst_en =  1'b0;
                if (cnt < cmd_cycle) begin
                    next_state = current_state;
                end
                else if (dpd_reg && (cmd != 8'hAB) && (cmd != 8'h66) && (cmd != 8'h99)) begin
                    next_state = idle;
                end
                else begin
                case(cmd[7:4])
                    4'h0: begin
                        case(cmd[3:0])
                            4'h1:begin
                                if (write_VSR_en_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = WR_SR1_SR2;
                                    data_cycle = 4;
                                    if (cnt >= cmd_cycle + data_cycle) begin
                                        clear_volatile_sr_write = 1'b1;
                                        next_state = idle;
                                    end
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = WR_SR1_SR2;
                                    data_cycle = 4;
                                    if (cnt >= cmd_cycle + data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h4: begin
                                clear_wel = 1'b1;
                                next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR1;
                                drive_mode = drive_quad;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h6: begin
                                set_wel = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b0, qpi_read_param_reg[5:4]) : 8'd6;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b0, qpi_read_param_reg[5:4]) : 8'd4;
                                case(qpi_read_param_reg[1:0])
                                    2'b00: wrap_len = 8;
                                    2'b01: wrap_len = 16;
                                    2'b10: wrap_len = 32;
                                    2'b11: wrap_len = 64;
                                    default: wrap_len = 0;
                                endcase
                                if(cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                                end
                            4'he: begin
                                sample_mode = sample_dtr_quad;
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 4 : 3;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b1, qpi_read_param_reg[5:4]) : 8'd10;
                                case(qpi_read_param_reg[1:0])
                                    2'b00: wrap_len = 8;
                                    2'b01: wrap_len = 16;
                                    2'b10: wrap_len = 32;
                                    2'b11: wrap_len = 64;
                                    default: wrap_len = 0;
                                endcase
                                if(cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default: next_state = idle;
                        endcase
                    end

                    4'h1: begin
                        case(cmd[3:0])
                            4'h1 : begin
                                if (write_VSR_en_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = SR3;
                                    data_cycle = 2;
                                    if (cnt >= cmd_cycle + data_cycle) begin
                                        clear_volatile_sr_write = 1'b1;
                                        next_state = idle;
                                    end
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = SR3;
                                    data_cycle = 2;
                                    if (cnt >= cmd_cycle + data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = 8;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR3;
                                drive_mode = drive_quad;
                                if (cs)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h2: begin
                        case(cmd[3:0])
                            4'h0: begin
                                erase_sector_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'h1: begin
                                erase_sector_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'h7: begin
                                if (pwd)
                                    next_state = idle;
                                else begin
                                    read_pwd_en = 1'b1;
                                    dummy_cycle = 8;
                                    if (cnt >= cmd_cycle + dummy_cycle) begin
                                        drive_mode = drive_quad;
                                    end
                                    if (cs) begin
                                        next_state = idle;
                                    end
                                end
                            end
                            4'h8: begin
                                if (pwd)
                                    next_state = idle;
                                else begin
                                    write_pwd_en = 1'b1;
                                    data_cycle = 16;
                                    if (cnt >= cmd_cycle + data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h9: begin
                                if (!pwd)
                                    next_state = idle;
                                else begin
                                    pwd_lock_unlock_en = 1'b1;
                                    data_cycle = 16;
                                    if (cnt >= cmd_cycle + data_cycle)
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
                                drive_mode = drive_quad;
                                if (cs)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h5: begin
                        case(cmd[3:0])
                            4'h0: begin
                                set_volatile_sr_write = 1'b1;
                                next_state = idle;
                            end
                            4'h2: begin
                                erase_block32_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'ha: begin
                                read_array_en = 1'b1;
                                addr_cycle = 6;
                                dummy_cycle = 8;
                                if(cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hb: begin
                                data_crc_en = 1;
                                addr_cycle = 16;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block32_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle)
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
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h6: begin
                                set_rst_en = 1'b1;
                                next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h7: begin
                        case(cmd[3:0])
                            4'h0: begin
                                read_FSR_en = 1'b1;
                                drive_mode = drive_quad;
                                if (cs)
                                    next_state = idle;
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
                                if (cnt >= cmd_cycle + addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_VCR_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h9: begin
                        case(cmd[3:0])
                            4'h0: begin
                                read_manuid_devid_en = 1'b1;
                                addr_cycle = 6;
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end

                            end
                            4'h8: begin
                                global_block_sector_unlock_en = 1'b1;
                                next_state = idle;
                            end
                            4'h9 : begin
                                if  (rst_en_reg) begin
                                    rst_all = 1'b1;
                                    clear_rst_en = 1'b1;
                                    next_state = idle;
                                end
                                else
                                    next_state = idle;
                            end
                            4'hf: begin
                                    rdid_en = 1'b1;
                                    drive_mode = drive_quad;
                                    if (cs)
                                        next_state = idle;
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
                                    if (cnt >= cmd_cycle + dummy_cycle) begin
                                        drive_mode = drive_quad;
                                    end
                                    if (cs) begin
                                        next_state = idle;
                                    end
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
                                if (cnt >= cmd_cycle + addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_NVCR_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
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
                                    // qpi_read_param_en信号由解码产生，并且延后两拍，可以和qpi_read_param信号同步
                                    // c0产生的wrap length给qpi的用
                                    // 77产生的wrap length给spi的用
                                    data_cycle = 2;
                                    if (cnt >= cmd_cycle + data_cycle) begin
                                        qpi_read_param_en = 1'b1;
                                        next_state = idle;
                                    end
                            end
                            4'h5: begin
                                write_EAR_en = 1'b1;
                                data_cycle = 2;
                                if (cnt >= cmd_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h7: begin
                                erase_chip_en = 1'b1;
                                next_state = idle;
                            end
                            4'h8: begin
                                read_EAR_en = 1'b1;
                                drive_mode = drive_quad;
                                if (cs)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hd: begin
                        case(cmd[3:0])
                            4'h8: begin
                                erase_block64_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block64_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle)
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
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h1: begin
                                write_VLR_en = 1'b1;
                                addr_cycle = 8;
                                data_cycle = 2;
                                if (cnt >= cmd_cycle + addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h2: begin
                                read_NVLR_en = 1'b1;
                                addr_cycle = 8;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h3: begin
                                set_NVLR_en = 1'b1;
                                addr_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle)
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
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 8 : 6;
                                cm_cycle = 2;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b0, qpi_read_param_reg[5:4]) : 8'd2;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                addr_cycle = 8;
                                cm_cycle = 2;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b0, qpi_read_param_reg[5:4]) : 8'd2;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hd: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dtr_quad;
                                addr_cycle = ads ? 4 : 3;
                                cm_cycle = 1;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b1, qpi_read_param_reg[5:4]) : 8'd9;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'he: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dtr_quad;
                                addr_cycle = 4;
                                cm_cycle = 1;
                                dummy_cycle = qpi_read_param_valid ? qpi_dummy_sel(1'b1, qpi_read_param_reg[5:4]) : 8'd9;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hf: begin
                        case (cmd[3:0])
                            4'hf : begin
                                clear_qpi_mode = 1'b1;
                                next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    default: next_state = idle;
                endcase
                end
            end

            spi: begin
                // 指令采样模式
                sample_cmd_mode = sample_standard;
                cmd_cycle = 8;
                // 除指令外的采样模式，包括地址、数据、CM字节、dummy
                sample_mode = sample_standard;
                set_rst_en =  1'b0;
                if (cnt < cmd_cycle) begin
                    next_state = current_state;
                end
                else if (dpd_reg && (cmd != 8'hAB) && (cmd != 8'h66) && (cmd != 8'h99)) begin
                    next_state = idle;
                end
                else begin
                case(cmd[7:4])
                    4'h0: begin
                        case(cmd[3:0])
                            4'h1:begin
                                if (write_VSR_en_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = WR_SR1_SR2;
                                    data_cycle = 16;
                                    if (cnt >= cmd_cycle + data_cycle) begin
                                        clear_volatile_sr_write = 1'b1;
                                        next_state = idle;
                                    end
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = WR_SR1_SR2;
                                    data_cycle = 16;
                                    if (cnt >= cmd_cycle + data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h3: begin
                                    read_array_en = 1'b1;
                                    addr_cycle = ads ? 32 : 24;
                                    if (cnt >= cmd_cycle + addr_cycle) begin
                                        drive_mode = drive_standard;
                                    end
                                    if(cs) begin
                                        next_state = idle;
                                    end
                            end
                            4'h4: begin
                                clear_wel = 1'b1;
                                next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR1;
                                drive_mode = drive_standard;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h6: begin
                                set_wel = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if(cs) begin
                                    next_state = idle;
                                end
                            end
                            default: next_state = idle;
                        endcase
                    end

                    4'h1: begin
                        case(cmd[3:0])
                            4'h1 : begin
                                if (write_VSR_en_reg) begin
                                    write_SR_shadow_en = 1'b1;
                                    write_SR_addr = SR3;
                                    data_cycle = 8;
                                    if (cnt >= cmd_cycle + data_cycle) begin
                                        clear_volatile_sr_write = 1'b1;
                                        next_state = idle;
                                    end
                                end
                                else begin
                                    write_SR_en = 1'b1;
                                    write_SR_addr = SR3;
                                    data_cycle = 8;
                                    if (cnt >= cmd_cycle + data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h2: begin
                                write_array_en = 1'b1;
                                addr_cycle = 32;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h3: begin
                                read_array_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if(cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR3;
                                drive_mode = drive_standard;
                                if (cs)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h2: begin
                        case(cmd[3:0])
                            4'h0: begin
                                erase_sector_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'h1: begin
                                erase_sector_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'h7: begin
                                if (pwd)
                                    next_state = idle;
                                else begin
                                    read_pwd_en = 1'b1;
                                    drive_mode = drive_standard;
                                    if (cs)
                                        next_state = idle;
                                end
                            end
                            4'h8: begin
                                if (pwd)
                                    next_state = idle;
                                else begin
                                    write_pwd_en = 1'b1;
                                    data_cycle = 64;
                                    if (cnt >= cmd_cycle + data_cycle)
                                        next_state = idle;
                                end
                            end
                            4'h9: begin
                                if (!pwd)
                                    next_state = idle;
                                else begin
                                    pwd_lock_unlock_en = 1'b1;
                                    data_cycle = 64;
                                    if (cnt >= cmd_cycle + data_cycle)
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
                                sample_mode = sample_standard;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    sample_mode = sample_quad;
                                    if (cs)
                                        next_state = idle;
                            end
                            4'h4: begin
                                write_array_en = 1'b1;
                                sample_mode = sample_standard;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    sample_mode = sample_quad;
                                    if (cs)
                                        next_state = idle;
                            end
                            4'h5: begin
                                read_SR_en = 1'b1;
                                read_SR_addr = SR2;
                                drive_mode = drive_standard;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h8 : begin
                                set_qpi_mode = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if(cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_dual;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_dual;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h4: begin
                        case (cmd[3:0])
                            4'h2: begin
                                write_sec_reg_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h4: begin
                                erase_sec_reg_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'h8: begin
                                read_sec_reg_en = 1'b1;
                                dummy_cycle = 8;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hb: begin
                                read_uid_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h5: begin
                        case(cmd[3:0])
                            4'h0: begin
                                set_volatile_sr_write = 1'b1;
                                next_state = idle;
                            end
                            4'h2: begin
                                erase_block32_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'ha: begin
                                read_array_en = 1'b1;
                                addr_cycle = 24;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hb: begin
                                data_crc_en = 1;
                                addr_cycle = 64;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block32_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle)
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
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h6: begin
                                set_rst_en = 1'b1;
                                next_state = idle;
                            end
                            4'hb: begin
                                read_array_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if(cnt >= cmd_cycle + addr_cycle+dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                addr_cycle = 32;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h7: begin
                        case(cmd[3:0])
                            4'h0: begin
                                read_FSR_en = 1'b1;
                                drive_mode = drive_standard;
                                if (cs)
                                    next_state = idle;
                            end
                            4'h5: begin
                                pes_en = 1'b1;
                                next_state = idle;
                            end
                            4'h7: begin
                                    sample_mode = sample_quad;
                                    data_cycle = 8;
                                    if (cnt >= cmd_cycle + data_cycle) begin
                                        spi_wrap_data_en = 1'b1;
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
                                if (cnt >= cmd_cycle + addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_VCR_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'h9: begin
                        case(cmd[3:0])
                            4'h0: begin
                                read_manuid_devid_en = 1'b1;
                                addr_cycle = 24;
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h8: begin
                                global_block_sector_unlock_en = 1'b1;
                                next_state = idle;
                            end
                            4'h9 : begin
                                if  (rst_en_reg) begin
                                    rst_all = 1'b1;
                                    clear_rst_en = 1'b1;
                                    next_state = idle;
                                end
                                else
                                    next_state = idle;
                            end
                            4'hf: begin
                                rdid_en = 1'b1;
                                drive_mode = drive_standard;
                                if (cs)
                                    next_state = idle;
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
                                    if (cnt >= cmd_cycle + dummy_cycle) begin
                                        drive_mode = drive_standard;
                                    end
                                    if (cs) begin
                                        next_state = idle;
                                    end
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
                                if (cnt >= cmd_cycle + addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h5: begin
                                read_NVCR_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                dummy_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + dummy_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
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
                                read_array_en = 1'b1;
                                sample_mode = sample_dual;
                                addr_cycle = ads ? 16 : 12;
                                cm_cycle = 4;
                                if(cnt >= cmd_cycle + addr_cycle + cm_cycle) begin
                                    drive_mode = drive_dual;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dual;
                                addr_cycle = 16;
                                cm_cycle = 4;
                                if(cnt >= cmd_cycle + addr_cycle + cm_cycle) begin
                                    drive_mode = drive_dual;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hd: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dtr_dual;
                                addr_cycle = ads ? 8 : 6;
                                cm_cycle = 2;
                                dummy_cycle = 4;
                                if(cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_dual;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'he: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dtr_dual;
                                addr_cycle = 8;
                                cm_cycle = 2;
                                dummy_cycle = 4;
                                if(cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_dual;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hc: begin
                        case(cmd[3:0])
                            4'h5: begin
                                write_EAR_en = 1'b1;
                                data_cycle = 8;
                                if (cnt >= cmd_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h7: begin
                                erase_chip_en = 1'b1;
                                next_state = idle;
                            end
                            4'h8: begin
                                read_EAR_en = 1'b1;
                                drive_mode = drive_standard;
                                if (cs)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'hd: begin
                        case(cmd[3:0])
                            4'h8: begin
                                erase_block64_en = 1'b1;
                                addr_cycle = ads ? 32 : 24;
                                if (cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            4'hc: begin
                                erase_block64_en = 1'b1;
                                addr_cycle = 32;
                                if(cnt >= cmd_cycle + addr_cycle)
                                    next_state = idle;
                            end
                            default : next_state = idle;
                        endcase
                    end

                    4'he: begin
                        // 77h W4=0时，SPI EB/EC/ED/EE使用W6-W5配置wrap长度。
                        if (!spi_wrap_data_reg[4]) begin
                            case (spi_wrap_data_reg[6:5])
                                2'b00 : wrap_len = 8;
                                2'b01 : wrap_len = 16;
                                2'b10 : wrap_len = 32;
                                2'b11 : wrap_len = 64;
                                default : wrap_len = 0;
                            endcase
                        end
                        case(cmd[3:0])
                            4'h0: begin
                                read_VLR_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h1: begin
                                write_VLR_en = 1'b1;
                                addr_cycle = 32;
                                data_cycle = 8;
                                if (cnt >= cmd_cycle + addr_cycle + data_cycle)
                                    next_state = idle;
                            end
                            4'h2: begin
                                read_NVLR_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle) begin
                                    drive_mode = drive_standard;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'h3: begin
                                set_NVLR_en = 1'b1;
                                addr_cycle = 32;
                                if (cnt >= cmd_cycle + addr_cycle)
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
                                read_array_en = 1'b1;
                                sample_mode = sample_quad;
                                addr_cycle = ads ? 8 : 6;
                                cm_cycle = 2;
                                dummy_cycle = 4;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hc: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_quad;
                                addr_cycle = 8;
                                cm_cycle = 2;
                                dummy_cycle = 4;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'hd: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dtr_quad;
                                addr_cycle = ads ? 4 : 3;
                                cm_cycle = 1;
                                dummy_cycle = 7;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            4'he: begin
                                read_array_en = 1'b1;
                                sample_mode = sample_dtr_quad;
                                addr_cycle = 4;
                                cm_cycle = 1;
                                dummy_cycle = 7;
                                if (cnt >= cmd_cycle + addr_cycle + cm_cycle + dummy_cycle) begin
                                    drive_mode = drive_dtr_quad;
                                end
                                if (cs) begin
                                    next_state = idle;
                                end
                            end
                            default : next_state = idle;
                        endcase
                    end

                    default: next_state = idle;
                endcase
                end
            end

            default: begin
                next_state = idle;
            end
        endcase
    end

endmodule
