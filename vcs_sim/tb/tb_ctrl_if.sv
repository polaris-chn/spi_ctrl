`timescale 1ns/1ps
module tb_ctrl_if;

    reg         sclk = 1'b0;
    reg         rstn = 1'b0;
    reg         cs   = 1'b1;
    reg         pwd  = 1'b0;
    reg         por_xip = 1'b0;
    reg         ads  = 1'b0;
    reg  [7:0]  vncr_0 = 8'd0;
    reg  [7:0]  cmd  = 8'h00;
    reg  [7:0]  cm   = 8'h00;
    reg  [7:0]  spi_wrap_data = 8'h00;
    reg  [7:0]  qpi_read_param = 8'h00;

    wire        clear_por_xip;
    wire        write_SR_shadow_en;
    wire        write_SR_en;
    wire        write_array_en;
    wire        read_array_en;
    wire        read_SR_en;
    wire        set_wel;
    wire        clear_wel;
    wire        clear_FSR;
    wire        read_FSR_en;
    wire        erase_sector_en;
    wire        erase_block32_en;
    wire        erase_block64_en;
    wire        erase_chip_en;
    wire        pes_en;
    wire        per_en;
    wire        data_crc_en;
    wire        global_block_sector_lock_en;
    wire        global_block_sector_unlock_en;
    wire        write_VCR_en;
    wire        read_VCR_en;
    wire        write_NVCR_en;
    wire        read_NVCR_en;
    wire        read_manuid_devid_en;
    wire        rdid_en;
    wire        read_devid_en;
    wire        read_itcrcr_en;
    wire        write_EAR_en;
    wire        read_EAR_en;
    wire        write_VLR_en;
    wire        read_VLR_en;
    wire        read_NVLR_en;
    wire        set_NVLR_en;
    wire        clear_all_NVLR_en;
    wire        set_ads;
    wire        clear_ads;
    wire        write_sec_reg_en;
    wire        erase_sec_reg_en;
    wire        read_sec_reg_en;
    wire        read_uid_en;
    wire        rst_all;
    wire        exit_dpd_en;
    wire        enter_dpd_en;
    wire        write_pwd_en;
    wire        read_pwd_en;
    wire        pwd_lock_unlock_en;
    wire  [6:0] wrap_len;
    wire  [7:0] cm_cycle;
    wire  [7:0] cmd_cycle;
    wire  [7:0] dummy_cycle;
    wire  [7:0] data_cycle;
    wire  [7:0] addr_cycle;
    wire  [2:0] sample_cmd_mode;
    wire  [2:0] sample_mode;
    wire  [2:0] drive_mode;
    wire  [1:0] write_SR_addr;
    wire  [1:0] read_SR_addr;

    ctrl_if dut (
        .sclk                (sclk),
        .rstn                (rstn),
        .cs                  (cs),
        .pwd                 (pwd),
        .vncr_0              (vncr_0),
        .cmd                 (cmd),
        .cm                  (cm),
        .por_xip             (por_xip),
        .ads                 (ads),
        .spi_wrap_data       (spi_wrap_data),
        .qpi_read_param      (qpi_read_param),
        .clear_por_xip       (clear_por_xip),
        .write_SR_shadow_en  (write_SR_shadow_en),
        .write_SR_en         (write_SR_en),
        .write_array_en      (write_array_en),
        .read_array_en       (read_array_en),
        .read_SR_en          (read_SR_en),
        .set_wel             (set_wel),
        .clear_wel           (clear_wel),
        .clear_FSR           (clear_FSR),
        .read_FSR_en         (read_FSR_en),
        .erase_sector_en     (erase_sector_en),
        .erase_block32_en    (erase_block32_en),
        .erase_block64_en    (erase_block64_en),
        .erase_chip_en       (erase_chip_en),
        .pes_en              (pes_en),
        .per_en              (per_en),
        .data_crc_en         (data_crc_en),
        .global_block_sector_lock_en   (global_block_sector_lock_en),
        .global_block_sector_unlock_en (global_block_sector_unlock_en),
        .write_VCR_en        (write_VCR_en),
        .read_VCR_en         (read_VCR_en),
        .write_NVCR_en       (write_NVCR_en),
        .read_NVCR_en        (read_NVCR_en),
        .read_manuid_devid_en(read_manuid_devid_en),
        .rdid_en             (rdid_en),
        .read_devid_en       (read_devid_en),
        .read_itcrcr_en      (read_itcrcr_en),
        .write_EAR_en        (write_EAR_en),
        .read_EAR_en         (read_EAR_en),
        .write_VLR_en        (write_VLR_en),
        .read_VLR_en         (read_VLR_en),
        .read_NVLR_en        (read_NVLR_en),
        .set_NVLR_en         (set_NVLR_en),
        .clear_all_NVLR_en   (clear_all_NVLR_en),
        .set_ads             (set_ads),
        .clear_ads           (clear_ads),
        .write_sec_reg_en    (write_sec_reg_en),
        .erase_sec_reg_en    (erase_sec_reg_en),
        .read_sec_reg_en     (read_sec_reg_en),
        .read_uid_en         (read_uid_en),
        .rst_all             (rst_all),
        .exit_dpd_en         (exit_dpd_en),
        .enter_dpd_en        (enter_dpd_en),
        .write_pwd_en        (write_pwd_en),
        .read_pwd_en         (read_pwd_en),
        .pwd_lock_unlock_en  (pwd_lock_unlock_en),
        .wrap_len            (wrap_len),
        .cm_cycle            (cm_cycle),
        .cmd_cycle           (cmd_cycle),
        .dummy_cycle         (dummy_cycle),
        .data_cycle          (data_cycle),
        .addr_cycle          (addr_cycle),
        .sample_cmd_mode     (sample_cmd_mode),
        .sample_mode         (sample_mode),
        .drive_mode          (drive_mode),
        .write_SR_addr       (write_SR_addr),
        .read_SR_addr        (read_SR_addr)
    );

    always #10 sclk = ~sclk;

    task automatic do_spi_cmd(input [7:0] opcode, input int unsigned clocks);
        cs   <= 1'b0;
        cmd  <= opcode;
        repeat (clocks) @(posedge sclk);
        cs   <= 1'b1;
        cmd  <= 8'h00;
        @(posedge sclk);
    endtask

    initial begin
        $fsdbDumpfile("tb.fsdb");
        $fsdbDumpvars(0, tb_ctrl_if);
    end

    initial begin
        repeat (3) @(posedge sclk);
        rstn <= 1'b1;
        @(posedge sclk);

        $display("-- SPI WREN 06h --");
        do_spi_cmd(8'h06, 12);

        $display("-- SPI RDSR 05h --");
        do_spi_cmd(8'h05, 12);

        $display("-- SPI WRDI 04h --");
        do_spi_cmd(8'h04, 12);

        $display("-- Enter DPD B9h --");
        do_spi_cmd(8'hB9, 12);

        $display("-- 06h in DPD should be ignored --");
        do_spi_cmd(8'h06, 12);

        $display("-- Exit DPD ABh --");
        do_spi_cmd(8'hAB, 12);

        $display("-- Enable QPI 38h --");
        do_spi_cmd(8'h38, 12);

        $display("-- Disable QPI FFh --");
        do_spi_cmd(8'hFF, 6);

        repeat (10) @(posedge sclk);
        $finish;
    end

endmodule
