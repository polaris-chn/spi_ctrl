//=============================================================================
// tb_xm25q512f.sv
//
// Standalone simulation environment for the XTX XM25Q512F behavioral model
// (VerMdl_XM25Q512F_1.0.v). Focus: opcode 05h (RDSR1) and 06h (WREN).
//
// Model quirks that this TB is built around (verified against the model):
//   - Powers up with ADS=1 (4-byte address mode, model L2841). An E9h
//     (exit-4-byte) is issued first so 3-byte address ops behave (L10378).
//   - WEL (SR1[1]) is set ONLY by 06h at the CS# rising edge (L10282).
//   - WEL is auto-cleared by: WRDI, end of every program/erase/WRSR cycle
//     (success or fail), SW/HW reset.
//   - status_register[1:0] = {wel|wip, wip} (L6344): while busy, RDSR reads
//     back 2'b11, not 2'b01.
//   - Internal write-cycle delays: tW (WRSR) = 1ms, tPP = 250us. RDSR polling
//     is mandatory.
//   - DPD (B9h): opcodes are NOT decoded while dpd_enable; ABh + 3 dummy
//     bytes releases and shifts out electronic signature 0x19 (L13257).
//   - SPI mode 0: model samples SI on posedge SCLK, updates SO 1.5ns after
//     negedge SCLK (TCLQV). 50 MHz SCLK is safely within acdc_check limits.
//=============================================================================
`timescale 1ns/1ps

module tb_xm25q512f;

    //--------------------------------------------------------------------------
    // DUT interface
    //--------------------------------------------------------------------------
    reg  cs_n;
    reg  sclk;
    reg  si_drv;      // value driven onto SI when si_oe=1
    reg  si_oe;
    wire si;          // SI / IO0 (inout at DUT; model only drives it in x2/x4)
    wire wp;          // WP#/ IO2 - tied high (never enter quad modes here)
    wire hold;        // HOLD#/IO3 - tied high
    wire so;          // SO / IO1
    wire ecs;         // model status output, unused

    assign si   = si_oe ? si_drv : 1'bz;
    assign wp   = 1'b1;
    assign hold = 1'b1;

    xm25q512f dut (
        .cs   (cs_n),
        .sclk (sclk),
        .si   (si),
        .wp   (wp),
        .hold (hold),
        .so   (so),
        .ecs  (ecs)
    );

    //--------------------------------------------------------------------------
    // Bookkeeping
    //--------------------------------------------------------------------------
    integer errors = 0;
    integer checks = 0;

    // Global watchdog: total sim time is dominated by 2 WRSR cycles (~2ms).
    initial begin
        #50_000_000;
        $display("\n*** FATAL: global watchdog timeout (50 ms) - a polling loop is stuck");
        $finish;
    end

`ifdef DUMP_FSDB
    initial begin
        $fsdbDumpfile("tb.fsdb");
        $fsdbDumpvars(0, tb_xm25q512f);
    end
`endif

    //--------------------------------------------------------------------------
    // Low-level bus primitives (SPI mode 0, MSB first, SCLK idles low)
    //--------------------------------------------------------------------------
    task cs_low;
        begin
            sclk = 1'b0;
            cs_n = 1'b0;
            #10;                       // tSLCH: CS# low to first clock
        end
    endtask

    task cs_high;
        begin
            #10;                       // tCHDX: last clock to CS# high
            cs_n = 1'b1;
            #100;                      // tSHSL: deselect gap (>=100ns is safe)
        end
    endtask

    // Send one byte on SI. SCLK starts and ends low.
    task spi_tx_byte;
        input [7:0] data;
        integer i;
        begin
            si_oe = 1'b1;
            for (i = 7; i >= 0; i = i - 1) begin
                si_drv = data[i];
                #10;                   // data stable during low half (tDSU)
                sclk = 1'b1;           // DUT samples SI here
                #10;
                sclk = 1'b0;
            end
            si_oe = 1'b0;
        end
    endtask

    // Send only the n MSBs of data, then stop (for partial-command tests).
    task spi_tx_partial;
        input [7:0]   data;
        input integer nbits;
        integer k;
        begin
            si_oe = 1'b1;
            for (k = 0; k < nbits; k = k + 1) begin
                si_drv = data[7-k];
                #10;
                sclk = 1'b1;
                #10;
                sclk = 1'b0;
            end
            si_oe = 1'b0;
        end
    endtask

    // Receive one byte from SO. Model updates SO ~1.5ns after negedge SCLK,
    // so sampling just after the rising edge is the safe Mode-0 point.
    task spi_rx_byte;
        output [7:0] data;
        integer i;
        begin
            si_oe = 1'b0;              // release SI (irrelevant in x1, harmless)
            for (i = 7; i >= 0; i = i - 1) begin
                #10;
                sclk = 1'b1;
                #2;                    // past any residual TCLQV skew
                data[i] = so;
                #8;
                sclk = 1'b0;
            end
        end
    endtask

    task spi_tx_addr3;
        input [23:0] addr;
        begin
            spi_tx_byte(addr[23:16]);
            spi_tx_byte(addr[15:8]);
            spi_tx_byte(addr[7:0]);
        end
    endtask

    //--------------------------------------------------------------------------
    // Protocol helpers
    //--------------------------------------------------------------------------
    // 05h: read SR1
    task rdsr;
        output [7:0] sr;
        begin
            cs_low;
            spi_tx_byte(8'h05);
            spi_rx_byte(sr);
            cs_high;
        end
    endtask

    // 06h: write enable
    task wren;
        begin
            cs_low;
            spi_tx_byte(8'h06);
            cs_high;
        end
    endtask

    // 06h then 05h: verify WEL was written into SR1 (check bit1 only)
    task wren_check;
        output [7:0] sr;
        begin
            wren;
            rdsr(sr);
            check1("WEL bit after 06h+05h", sr[1], 1'b1);
        end
    endtask

    // 06h then 05h: verify WEL was NOT written (negative case)
    task wren_check_wel0;
        output [7:0] sr;
        begin
            wren;
            rdsr(sr);
            check1("WEL bit still 0 after 06h+05h", sr[1], 1'b0);
        end
    endtask

    // 04h: write disable
    task wrdi;
        begin
            cs_low;
            spi_tx_byte(8'h04);
            cs_high;
        end
    endtask

    // Poll WIP via RDSR until it clears or timeout_ns elapses.
    // busy_seen reports whether WIP=1 was ever observed.
    task poll_wip;
        input  integer timeout_ns;
        output busy_seen;
        output timed_out;
        reg [7:0] sr;
        integer   n;
        real      t0;
        reg       done;
        begin
            busy_seen = 1'b0;
            timed_out = 1'b0;
            done      = 1'b0;
            n         = 0;
            t0        = $realtime;
            while (!done) begin
                rdsr(sr);
                n = n + 1;
                if (sr[0] === 1'b1) busy_seen = 1'b1;
                if (sr[0] === 1'b0) done = 1'b1;
                if (($realtime - t0) > timeout_ns) begin
                    done      = 1'b1;
                    timed_out = 1'b1;
                end
            end
            $display("    poll_wip: %0d RDSR polls, %0.1f us elapsed, busy_seen=%0b",
                     n, ($realtime - t0)/1000.0, busy_seen);
        end
    endtask

    //--------------------------------------------------------------------------
    // Checkers
    //--------------------------------------------------------------------------
    task check8;
        input [8*40-1:0] name;
        input [7:0]      got;
        input [7:0]      exp;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  ** FAIL: %0s  got=0x%02h  exp=0x%02h", name, got, exp);
            end else begin
                $display("  PASS: %0s = 0x%02h", name, got);
            end
        end
    endtask

    task check1;
        input [8*40-1:0] name;
        input            got;
        input            exp;
        begin
            checks = checks + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  ** FAIL: %0s  got=%b  exp=%b", name, got, exp);
            end else begin
                $display("  PASS: %0s = %b", name, got);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------
    integer  i;
    reg [7:0] sr;
    reg [7:0] sr_a, sr_b, sr_c;
    reg [7:0] rdata;
    reg       busy_seen, timed_out;

    initial begin
        cs_n   = 1'b1;
        sclk   = 1'b0;
        si_drv = 1'b0;
        si_oe  = 1'b0;
        #1000;                          // let the model's initial block settle

        $display("\n======================================================");
        $display(" XM25Q512F model test - focus on 05h(RDSR) / 06h(WREN)");
        $display("======================================================");

        //---------------------------------------------------------------------
        // T0: E9h - exit 4-byte address mode (model powers up with ADS=1)
        //---------------------------------------------------------------------
        $display("\n[T0] E9h exit 4-byte address mode");
        cs_low;
        spi_tx_byte(8'hE9);
        cs_high;                        // ADS<=0 on this CS# rising edge

        //---------------------------------------------------------------------
        // T1: RDSR initial state -> SR1 must be 0x00 (WIP=0, WEL=0, BP=0)
        //---------------------------------------------------------------------
        $display("\n[T1] RDSR(05h) initial");
        rdsr(sr);
        check8("initial SR1", sr, 8'h00);

        //---------------------------------------------------------------------
        // T2: RDSR rollover - holding CS# and clocking repeats SR1 forever
        //     (model: 3-bit bit_register wraps naturally)
        //---------------------------------------------------------------------
        $display("\n[T2] RDSR continuous rollover (3 consecutive bytes)");
        cs_low;
        spi_tx_byte(8'h05);
        spi_rx_byte(sr_a);
        spi_rx_byte(sr_b);
        spi_rx_byte(sr_c);
        cs_high;
        check8("RDSR byte0", sr_a, 8'h00);
        check8("RDSR byte1 (rollover)", sr_b, sr_a);
        check8("RDSR byte2 (rollover)", sr_c, sr_a);

        //---------------------------------------------------------------------
        // T3: WREN -> RDSR must show WEL=1 (SR1=0x02)
        //     wel is set at the CS# rising edge of the 06h transaction
        //---------------------------------------------------------------------
        $display("\n[T3] WREN(06h) -> RDSR(05h) verify WEL");
        wren_check(sr);                 // 06h+05h: WEL=1
        check8("SR1 after 06h+05h (idle, no BP)", sr, 8'h02);

        //---------------------------------------------------------------------
        // T4: WREN again - idempotent, WEL stays 1
        //---------------------------------------------------------------------
        $display("\n[T4] WREN again (idempotent) -> RDSR(05h)");
        wren_check(sr);
        check8("SR1 after 2nd 06h+05h", sr, 8'h02);

        //---------------------------------------------------------------------
        // T5: WRDI(04h) -> RDSR must show WEL=0
        //---------------------------------------------------------------------
        $display("\n[T5] WRDI(04h) -> RDSR");
        wrdi;
        rdsr(sr);
        check8("SR1 after WRDI", sr, 8'h00);

        //---------------------------------------------------------------------
        // T6: partial WREN - raise CS# after only 4 clocks. The model decodes
        //     opcodes only on complete byte boundaries, so WEL must stay 0.
        //---------------------------------------------------------------------
        $display("\n[T6] partial WREN (4 clocks only) -> WEL must stay 0");
        cs_low;
        spi_tx_partial(8'h06, 4);
        cs_high;
        rdsr(sr);
        check1("WEL bit still 0 after partial 06h+05h", sr[1], 1'b0);
        check8("SR1 after partial WREN", sr, 8'h00);

        //---------------------------------------------------------------------
        // T7: PP(02h) WITHOUT WREN - model must reject it:
        //     wip never rises, memory untouched, WEL stays 0.
        //---------------------------------------------------------------------
        $display("\n[T7] PP(02h) without WREN -> must be rejected");
        cs_low;
        spi_tx_byte(8'h02);
        spi_tx_addr3(24'h00_0020);
        for (i = 0; i < 4; i = i + 1) spi_tx_byte(8'h55);
        cs_high;
        poll_wip(20_000, busy_seen, timed_out);   // short window is enough
        check1("PP w/o WREN: busy never seen", busy_seen, 1'b0);
        check1("PP w/o WREN: no timeout",        timed_out, 1'b0);
        rdsr(sr);
        check8("SR1 after rejected PP", sr, 8'h00);
        cs_low;
        spi_tx_byte(8'h03);
        spi_tx_addr3(24'h00_0020);
        spi_rx_byte(rdata);
        cs_high;
        check8("rejected PP left 0xFF", rdata, 8'hFF);

        //---------------------------------------------------------------------
        // T8: WREN -> PP 16 bytes @0x10. While busy, RDSR must read 0x03
        //     ({wel|wip,wip}=11). After tPP, WEL must be auto-cleared (0x00).
        //---------------------------------------------------------------------
        $display("\n[T8] WREN -> PP(02h) 16 bytes @0x000010, poll, verify");
        wren_check(sr);
        cs_low;
        spi_tx_byte(8'h02);
        spi_tx_addr3(24'h00_0010);
        for (i = 0; i < 16; i = i + 1) spi_tx_byte(8'hA0 + i[7:0]);
        cs_high;
        rdsr(sr);                       // first poll: model sets wip at deselect
        check1("WIP=1 during program",  sr[0], 1'b1);
        check1("RDSR bit1 = wel|wip = 1 during program", sr[1], 1'b1);
        poll_wip(1_000_000, busy_seen, timed_out);   // tPP = 250us
        check1("PP completed (no timeout)", timed_out, 1'b0);
        rdsr(sr);
        check8("SR1 after PP done (WEL auto-cleared)", sr, 8'h00);
        // readback
        cs_low;
        spi_tx_byte(8'h03);
        spi_tx_addr3(24'h00_0010);
        for (i = 0; i < 16; i = i + 1) begin
            spi_rx_byte(rdata);
            check8("PP readback", rdata, 8'hA0 + i[7:0]);
        end
        cs_high;

        //---------------------------------------------------------------------
        // T9: WREN -> WRSR(01h) SR1=0x1C. Non-volatile write takes tW=1ms
        //     (event wrsr_process #TW). Afterwards WEL must be cleared and
        //     SR1 must read back 0x1C. Then restore SR1=0x00 the same way.
        //---------------------------------------------------------------------
        $display("\n[T9] WREN -> WRSR(01h) SR1=0x1C, poll tW, verify, restore");
        wren_check(sr);
        cs_low;
        spi_tx_byte(8'h01);
        spi_tx_byte(8'h1C);
        cs_high;
        poll_wip(5_000_000, busy_seen, timed_out);   // tW = 1ms
        check1("WRSR busy seen",          busy_seen, 1'b1);
        check1("WRSR completed (no timeout)", timed_out, 1'b0);
        rdsr(sr);
        check8("SR1 after WRSR (BP bits set, WEL cleared)", sr, 8'h1C);
        wren_check(sr);
        cs_low;
        spi_tx_byte(8'h01);
        spi_tx_byte(8'h00);
        cs_high;
        poll_wip(5_000_000, busy_seen, timed_out);
        check1("restore WRSR done", timed_out, 1'b0);
        rdsr(sr);
        check8("SR1 restored", sr, 8'h00);

        //---------------------------------------------------------------------
        // T10: WREN then SW reset (66h/99h) - reset must clear WEL.
        //      Note: SW reset also restores ADS=ADP=1 (4-byte mode).
        //---------------------------------------------------------------------
        $display("\n[T10] WREN -> SW reset(66h/99h) -> WEL must be 0");
        wren_check(sr);
        cs_low; spi_tx_byte(8'h66); cs_high;
        cs_low; spi_tx_byte(8'h99); cs_high;
        #20_000;                        // tRST = 8us, margin
        rdsr(sr);
        check8("SR1 after SW reset", sr, 8'h00);
        // (addressing is back to 4-byte mode now; no more address ops below)

        //---------------------------------------------------------------------
        // T11: DPD(B9h) - 06h must NOT be decoded in deep power down.
        //      ABh + 3 dummy bytes releases and returns signature 0x19.
        //      After wakeup, WEL must still be 0.
        //---------------------------------------------------------------------
        $display("\n[T11] DPD(B9h) -> WREN ignored -> ABh wakeup -> WEL still 0");
        cs_low; spi_tx_byte(8'hB9); cs_high;
        #2000;                          // tDP = 1.5us
        wren;                           // 06h ignored in DPD (05h also blocked here)
        cs_low;
        spi_tx_byte(8'hAB);
        spi_rx_byte(rdata);             // dummy byte 1
        spi_rx_byte(rdata);             // dummy byte 2
        spi_rx_byte(rdata);             // dummy byte 3
        spi_rx_byte(rdata);             // electronic signature
        cs_high;
        check8("ABh electronic signature", rdata, 8'h19);
        #4000;                          // tRES1 = 3us
        rdsr(sr);
        check8("SR1 after DPD wakeup (WREN was ignored)", sr, 8'h00);

        //---------------------------------------------------------------------
        // T12: WEL is committed only on WREN CS# rising edge (model L10282).
        //      While CS# is still low after 06h, internal wel must stay 0.
        //---------------------------------------------------------------------
        $display("\n[T12] WEL commits on WREN CS# deassert only");
        wrdi;                           // ensure WEL=0
        cs_low;
        spi_tx_byte(8'h06);
        check1("wel=0 while WREN CS# still low", dut.spi_decoder.wel, 1'b0);
        cs_high;                        // wel<=1 here
        check1("wel=1 right after WREN CS# deassert", dut.spi_decoder.wel, 1'b1);
        rdsr(sr);
        check1("WEL bit after 06h+05h", sr[1], 1'b1);
        check8("RDSR reflects WEL=1", sr, 8'h02);

        //---------------------------------------------------------------------
        // T13: RDSR MSB-first bit order: SR1=0x02 -> first bit out is bit7=0
        //---------------------------------------------------------------------
        $display("\n[T13] RDSR MSB-first bit order (SR1=0x02)");
        cs_low;
        spi_tx_byte(8'h05);
        #10; sclk = 1'b1; #2;
        check1("SR1[7] first out (MSB)", so, 1'b0);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[6] second out", so, 1'b0);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[5] third out", so, 1'b0);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[4] fourth out", so, 1'b0);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[3] fifth out", so, 1'b0);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[2] sixth out", so, 1'b0);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[1]=WEL seventh out", so, 1'b1);
        #8; sclk = 1'b0;
        #10; sclk = 1'b1; #2;
        check1("SR1[0]=WIP eighth out", so, 1'b0);
        #8; sclk = 1'b0;
        cs_high;
        wrdi;

        //---------------------------------------------------------------------
        // Summary
        //---------------------------------------------------------------------
        $display("\n======================================================");
        $display(" checks=%0d  errors=%0d", checks, errors);
        if (errors == 0) $display(" *** TEST PASSED ***");
        else             $display(" *** TEST FAILED ***");
        $display("======================================================\n");
        $finish;
    end

endmodule
