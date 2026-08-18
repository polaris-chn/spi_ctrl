//////////////////////////////////////////////////////////////////////////////
//  File name : xm25q512f.v
//////////////////////////////////////////////////////////////////////////////
//---------------------------------------------------------------------------
// XT25q512 Verilog model
//
// These Verilog HDL models are provided "as is" without warranty
// of any kind, included but not limited to, implied warranty
// of merchantability and fitness for a particular purpose.
//
//
// Copyright (C) XTX Inc. http://www.xtxtech.com
//-----------------------------------------------------------------------------
//  MODIFICATION HISTORY:
//
//  version: |    author:      |  mod date: | changes made:
//  V1            dayen.yang      2020/06/01   
//                                           
// 
//                                           
//
//////////////////////////////////////////////////////////////////////////////
//  PART DESCRIPTION:
//
//  Library:     FLASH
//  Technology:  FLASH MEMORY
//  Part:        XT25F512B
//
//  Description: 512 Mbit 3.3V Uniform Sector Dual and Quad SPI Flash
//
//////////////////////////////////////////////////////////////////////////////
//  Comments :
//
//
//////////////////////////////////////////////////////////////////////////////
//  Known Bugs:
//
//////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////
// Parameter DECLARATION                                                       //
//////////////////////////////////////////////////////////////////////////////

 
`define SIZE               536870912 // 512Mbit 1024*1024*512     
`define BLOCK_NUM	   1024       //number of block 
`define PLENGTH            256           // page length 256 bytes
`define OTP_SIZE           3072 /*2048*/         // otp array size 2048+1024 bytes  3wl
`define OTP_SIZE_PAGE      256         // otp array size 1 pages
`define BSIZE_64           524288      // Block size 512 kbits(64k size blk)
`define BSIZE_32           262144     // Block size 256 kbits(32k size slk)
`define SSIZE              32768           // Sector size 32 kbits
`define SIGNATRUE          8'h19          // electronic signature   CMD=AB ID7-ID0               
`define manufacturerID     8'h0b         // Manufacturer ID
`define memtype            8'h60        // memorytype   ID15-ID8
`define density            8'h1a       // memory density 16Mbits  ID7-ID0                                
`define BIT_TO_CODE_MEM    26         // number of bit to code a 128Mbits memory                       
`define LSB_TO_CODE_PAGE   8         // number of bit to code a PLENGTH page

`define NB_BIT_ADD_MEM              32        //
`define NB_BIT_ADD                  8
`define NB_BIT_DATA                 8
`define TOP_MEM                     (`SIZE/`NB_BIT_DATA)-1
//`define OTP_ADD                     (`SIZE/`NB_BIT_DATA)-4096

`define MASK_BLK64          32'hFFFF0000     // anded with address to find first block adress to erase
`define MASK_BLK32          32'hFFFF8000    // anded with address to find first 32 block adress to erase
`define MASK_SECTOR         32'hFFFFF000   // anded with address to find first sector adress to erase
`define MASK_PAGE           32'hFFFFFF00  // anded with address to find first page adress to erase  /*************


`define   TRUE    1'b1
`define   FALSE   1'b0


`define TC     7.5             // Minimum Clock period 
`define TR     7.5           // Minimum Clock period for read instruction ns
`define TSLCH  3             // notS active setup time (relative to C)
`define TCHSL  3            // notS not active hold time
`define TCH    3           // Clock high time 
`define TCL    3         // Clock low time    
`define TDVCH  2          // Data in Setup Time
`define TCHDX  2          // Data in Hold Time
`define TCHSH  3          // notS active hold time (relative to C)
`define TSHCH  3          // notS not active setup  time (relative to C)
`define TSHSL  20            // /S deselect time
`define TSHQZ  6          // Output disable Time                        
//`define TCLQV  6.5          // clock low to output valid
`define TCLQV  1.5 
`define THLCH  5          // NotHold active setup time
`define TCHHH  5          // NotHold not active hold time
`define THHCH  5          // NotHold not active setup time
`define TCHHL  5          // NotHold active hold time
`define THHQX  6          // NotHold high to Output Low-Z
`define THLQZ  6          // NotHold low to Output High-Z
`define TWHSL  20          // Write protect setup time (SRWD=1)
`define TSHWL  100         // Write protect hold time (SRWD=1)

`define TRLRH  1000       //Reset pluse width (HOLD#/RESET) min 
`define TRHSL  40000      //Reset high tinme before read min 
`define TRB1   50000       //Reset recovery time(Fsuccessful or not busy mode)max 
`define TRB2   50000      //Reset recovery time(For busy mode)max 
`define TRS   135000        //Latency betewwn resume and next suspend


`define TSUS   40000       // notS high to next instruction after suspend (Max:20us),change small
`define TDP    1500        // notS high to deep power down mode(3us)
`define TRES1  3000        // notS high to Stand-By power mode w-o ID Read(3us)
`define TRES2  3000        // notS high to Stand-By power mode with ID Read(3us)


`define TW     1000000    // write status register cycle time typical

`define TRST    8000     // reset cycle time, change small

`define TPP    250000     // page program cycle time  typical
`define TPP_F  160000     // page program cycle time  factory mode

`define TSE    30      // sector erase cycle time (40ms)
`define TSE_F  18      // sector erase cycle time factory mode

`define TBE1    150      // block erase 32k cycle time 
`define TBE1_F  100      // block erase 32k cycle time factory mode

`define TBE2    200      // block erase 64k cycle time 
`define TBE2_F  200      // block erase 64k cycle time factory mode

`define TCE    100000     // chip erase cycle time 
`define TCE_F   50000     // chip erase cycle time factory mode no factory 5109

`define Tbase  1000000  // time base for chip and Block Sector ERASE, delay function limited to signed 32bits values (1ms)
//////////////////////////////////////////////////////////////////////////////
// MODULE DECLARATION                                                       //
//////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module xm25q512f(cs,sclk,si,wp,hold,so,ecs);
   input cs;
   input sclk;

   inout si;  
   inout wp;       
   inout hold;    
   inout so;   
   output ecs;

  // output wip;
  // output standby;
  // assign standby = ~wip;

   wire [(`NB_BIT_ADD_MEM-1):0] address;       
   wire [(`BIT_TO_CODE_MEM-1):0] suspend_add;  
   wire [(`BIT_TO_CODE_MEM-1):0] int_add;  
   wire [(`NB_BIT_DATA-1):0] data_to_read;     //7:0
   wire [(`NB_BIT_DATA-1):0] data_to_write; 
   wire [(`LSB_TO_CODE_PAGE-1):0] page_index;  //7:0 
   
   wire [(`BIT_TO_CODE_MEM-1):0] ers_add;      
   wire wr_op; 
   wire rd_op; 
   
   wire c_en;
   wire ser_enable; 
   wire ber32_enable; 
   wire ber64_enable; 

   wire add_pp_en; 
   wire pp_en; 
   wire read_enable; 
   wire rd_req;
   wire wd_req; 
   wire suspend_en;
   wire resume_en;
   wire suspend_pp;
   wire suspend_ber32;
   wire suspend_ber64;

   wire suspend_ser;
   
   ////////////////////////////////
   //////////////////////////////
   
   wire quadpgm_enable;  
   wire otpers_enable;
   wire otppgm_enable;
   wire wrap_enable;
   wire wrap_8byte;
   wire wrap_16byte;
   wire wrap_32byte;
   wire wrap_64byte;
   wire otppgm;
   wire otpers;
   wire suspend_quadpgm;
   wire suspend_otppgm;
   wire suspend_otpers;
   wire wip;
   wire qpim;
   wire quad_cmd;
   wire qpi_wrap_8byte;
   wire qpi_wrap_16byte;
   wire qpi_wrap_32byte;
   wire qpi_wrap_64byte;
   wire qpi_wrap_read;
  
  wire pp;
   wire quadpgm;

  wire ex_quadpgm;           //2008
  wire ex_quadpgm_enable;
  wire suspend_ex_quadpgm;


     memory_access  mem_access(address, suspend_add, suspend_en,     suspend_pp, suspend_ber32, suspend_ber64, suspend_ser, resume_en,     c_en,       ber32_enable,
         ber64_enable, ser_enable, add_pp_en,     pp_en,    wd_req,             read_enable, rd_req,            data_to_write, page_index,     data_to_read,
         dtr_read_data_req, DTR_single_read,qpim,
                               quadpgm_enable,ex_quadpgm_enable,otppgm_enable, otpers_enable, wrap_enable, wrap_8byte, wrap_16byte, wrap_32byte, wrap_64byte,qpi_wrap_8byte,
                                                                                 qpi_wrap_16byte, qpi_wrap_32byte, qpi_wrap_64byte, suspend_quadpgm, suspend_ex_quadpgm,
																				 suspend_otppgm, suspend_otpers, otppgm, otprd, otpers,thold_readquad,
																				 qpi_wrap_read,ers_add,SW_RST,HW_RST,pp,quadpgm, ex_quadpgm, int_add,ads); 



    acdc_check  acdc_watch(sclk, si, cs, hold, wr_op, rd_op,oen, thold_readquad,qpim,quad_cmd); 
   
    internal_logic  spi_decoder(sclk, si, wp, cs, hold, data_to_read, so, data_to_write, page_index,     address, suspend_add, suspend_en,     suspend_pp, suspend_ber32,  suspend_ber64,  suspend_ser, resume_en,     wr_op,    rd_op, qpi_wrap_read,  c_en,       ber32_enable, ber64_enable, ser_enable, add_pp_en,     pp_en,    wd_req,             read_enable, rd_req ,           oen, thold_readquad,  
                                 quadpgm_enable, ex_quadpgm_enable, otpers_enable, otppgm_enable, wrap_enable, wrap_8byte, wrap_16byte, wrap_32byte, wrap_64byte,qpi_wrap_8byte,
                                                                 dtr_read_data_req, DTR_single_read , qpi_wrap_16byte, qpi_wrap_32byte, qpi_wrap_64byte, suspend_quadpgm, suspend_ex_quadpgm,  suspend_otppgm,  suspend_otpers, otppgm, otprd,
                                                                 otpers,wip,standby_bak,qpim,quad_cmd,ers_add,SW_RST,HW_RST,pp,quadpgm, ex_quadpgm, int_add,ads); 
 
   assign ecs =1;
endmodule

//--------memory.v--------------

module memory_access (    add_mem, suspend_add, suspend_enable, suspend_pp, suspend_ber32, suspend_ber64, suspend_ser, resume_enable, cer_enable, ber32_enable,
ber64_enable, ser_enable, add_pp_enable, pp_enable,write_data_request, read_enable, read_data_request, data_to_write, page_add_index, data_to_read, dtr_read_data_req,
DTR_single_read,qpim,
                          quadpgm_enable, ex_quadpgm_enable, otppgm_enable, otpers_enable, wrap_enable, wrap_8byte, wrap_16byte, wrap_32byte,
						  wrap_64byte,qpi_wrap_8byte, qpi_wrap_16byte, qpi_wrap_32byte, qpi_wrap_64byte, suspend_quadpgm, suspend_ex_quadpgm, suspend_otppgm,
						  suspend_otpers, otppgm, otprd,otpers,thold_readquad,qpi_wrap_read,ers_add,SW_RST,HW_RST,pp,quadpgm, ex_quadpgm, int_add,ads);

   input[(`NB_BIT_ADD_MEM - 1):0] add_mem; 
   input[(`BIT_TO_CODE_MEM-1):0] suspend_add; 
   input cer_enable; 
   input ber32_enable;
   input ber64_enable;
   input ser_enable; 
   input add_pp_enable; 
   input pp_enable; 
   input pp; 
   input quadpgm; 
   input quadpgm_enable;   // new add cmd
    
   input ex_quadpgm;
   input ex_quadpgm_enable; //2008

   input otppgm_enable;
   input ads;

   input otpers_enable; 
   input wrap_enable;
   input wrap_8byte;  //Wrap Length
   input wrap_16byte;
   input wrap_32byte;
   input wrap_64byte;
   input qpi_wrap_8byte;
   input qpi_wrap_16byte;
   input qpi_wrap_32byte;
   input qpi_wrap_64byte;
   input otppgm;    
   input otprd; 
   input otpers;   
   input qpim;
   
   input read_enable; 
   input read_data_request;
   input dtr_read_data_req;
   input DTR_single_read;

   input write_data_request; 
   input suspend_enable;
   input resume_enable;
   input suspend_pp;
   input suspend_quadpgm;   // new add cmd suspend

   input suspend_ex_quadpgm;  //2008

   input suspend_otppgm;
   input suspend_otpers;
   
   input suspend_ber32;
   input suspend_ber64;

   input thold_readquad;
   input qpi_wrap_read;
   input suspend_ser;
   input SW_RST;//SW Reset
   input HW_RST;//HW Reset
   input[(`NB_BIT_DATA - 1):0] data_to_write;//[7:0] 
   input[(`LSB_TO_CODE_PAGE-1):0] page_add_index;  //data write latch address
   input [(`BIT_TO_CODE_MEM-1):0] ers_add;

   output[(`NB_BIT_DATA - 1):0] data_to_read; 
   reg[(`NB_BIT_DATA - 1):0] data_to_read;
   output [(`BIT_TO_CODE_MEM-1):0] int_add; 
   reg [(`BIT_TO_CODE_MEM-1):0] int_add; 

   reg[(`NB_BIT_DATA - 1):0] p_prog[0:(`PLENGTH-1)];  //page capacity 256byte 
   reg[(`NB_BIT_DATA - 1):0] content[0:`TOP_MEM];     //array capacity , how many  bytes
   reg[(`NB_BIT_DATA - 1):0] otp_content[0:`OTP_SIZE-1];     // otp array capacity 
   reg[`BIT_TO_CODE_MEM - 1:0] cut_add; 

   integer i; 
   integer int_add_ers;  // To find the first adress of the sector/block to be erased



initial
   begin
      cut_add = 0;
      int_add = 0;
      int_add_ers = 0;

      
      //-------------------------------
      // initialisation of memory array     write fff
      //-------------------------------
      
      for(i = 0; i <= (`PLENGTH-1); i = i + 1)  //page data initialization  1page
      begin
         p_prog[i] = 8'b11111111 ; 
      end
      
      for(i = 0; i <= (`TOP_MEM); i = i + 1)   //array data initialization 
      begin
         content[i] = 8'b11111111 ; 

      end
        
      for(i = 0; i <= (`OTP_SIZE-1); i = i + 1)   // otp array data initialization  
      begin
         otp_content[i] = 8'b11111111 ; 
      end



  end 

   //--------------------------------------------------
   //                PROCESS MEMORY
   //--------------------------------------------------

   always @(negedge pp_enable)
    begin
      if (!suspend_enable)
      begin

         for(i = 0; i <= (`PLENGTH-1); i = i + 1)
         begin
            p_prog[i] = 8'b11111111 ; 
         end

      end
   end

   always @(negedge pp)
    begin
      if (!suspend_enable)
      begin
        if((SW_RST==1) | (HW_RST==1'b1)) //
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            content[int_add + i] = 8'bxxxxxxxx;

         end
        end
        end
    end



   always @(negedge quadpgm_enable)
    begin
      if (!suspend_enable)
      begin

         for(i = 0; i <= (`PLENGTH-1); i = i + 1)
         begin
            p_prog[i] = 8'b11111111 ; 
         end


      end
   end

   always @(negedge quadpgm)
    begin
      if (!suspend_enable)
      begin

        if((SW_RST==1) | (HW_RST==1'b1))
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            content[int_add + i] = 8'bxxxxxxxx;
         end

        end

        end
    end

//2008
    always @(negedge ex_quadpgm_enable)
    begin
      if (!suspend_enable)
      begin

         for(i = 0; i <= (`PLENGTH-1); i = i + 1)
         begin
            p_prog[i] = 8'b11111111 ; 
         end


      end
   end

   always @(negedge ex_quadpgm)
    begin
      if (!suspend_enable)
      begin

        if((SW_RST==1) | (HW_RST==1'b1))
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            content[int_add + i] = 8'bxxxxxxxx;
         end

        end

        end
    end



   always @(negedge  otppgm)
    begin
      if (!suspend_enable)
      begin
        if((SW_RST==1) | (HW_RST==1'b1))
        begin

        if({int_add[13:12],int_add[9:8]} == 4'b0100)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000000 + i] = 8'bxxxxxxxx;

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b0101)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000100 + i] = 8'bxxxxxxxx;

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b0110)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000200 + i] = 8'bxxxxxxxx;

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b0111)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000300 + i] = 8'bxxxxxxxx;

         end
        end
        if({int_add[13:12],int_add[9:8]} == 4'b1000)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000400 + i] = 8'bxxxxxxxx;

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1001)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000500 + i] = 8'bxxxxxxxx;

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1010)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000600 + i] = 8'bxxxxxxxx;

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1011)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000700 + i] = 8'bxxxxxxxx;

         end
        end


        end

      end
   end


wire #1 delayed_otppgm = otppgm;
   always @(negedge  delayed_otppgm) // change otppgm_enable  --- otppgm
    begin
      if (!suspend_enable)
      begin
         for(i = 0; i <= (`PLENGTH-1); i = i + 1)
         begin
            p_prog[i] = 8'b11111111 ; 
         end

      end
   end



   
wire #1 delayed_write_data_request = write_data_request;

   always
   begin
      @(posedge delayed_write_data_request)
      if ($time != 0)
      begin
         if (page_add_index !== 8'bxxxxxxxx)
         begin
          if (add_pp_enable == 1'b1 && (pp_enable == 1'b0 || quadpgm_enable || otppgm_enable) )
            begin

                p_prog[page_add_index] <= data_to_write ;
                
            end
         end
      end
   end
   
 
wire otpcmd = (otpers | otppgm | otprd) ;  
   always 
      @(posedge ser_enable  or posedge otpers_enable or posedge read_enable or posedge add_pp_enable or posedge ber32_enable or posedge ber64_enable )   
      if ($time != 0)
      begin
        if(!otpcmd) 
         begin
         for(i = 0; i <= `BIT_TO_CODE_MEM - 1; i = i + 1)  //25-1
           begin
            cut_add[i] = add_mem[i]; //add_mem:24:0 
           end
         end 
         
       else if(otpcmd) 
         begin

         for(i = 0; i <=(`BIT_TO_CODE_MEM -1); i = i + 1)   //otp array only 4 page
               begin                   
                  cut_add[i] = add_mem[i]; 
               end
         end  
         
      end
      
   wire #1 delayed_read_data_request = (read_data_request && !(DTR_single_read && !qpim))  ;
   wire #1 delayed_dtr_read_data_request = dtr_read_data_req;
   always 
      @(posedge delayed_read_data_request)
      if ($time != 0)
      begin
        if (read_enable) begin 
            int_add = cut_add; 
            //---------------------------------------------------------
            // Read instruction
            //---------------------------------------------------------
            if(!otprd)
              begin 
              if (int_add > `TOP_MEM)                                  
              begin                                                      
                 for(i = 0; i <= `BIT_TO_CODE_MEM - 1; i = i + 1)        
                 begin                                                   
                    cut_add[i] = 1'b0;                                   
                 end                                                     
                 int_add = 0; // roll over at the end of mem array      
              end                                                        
              data_to_read <= content[int_add] ; 
              //$display("content[%h]=%h",int_add,content[int_add]);
              end 
             
             else if(otprd)
              begin 
                if({int_add[13:12],int_add[9:8]}==4'b0100)
                begin
                        data_to_read <= otp_content[{16'h0000,int_add[7:0] & 8'hff}] ; 
                $display("R_otp_content[%h]=%h",{16'h0000,int_add[7:0] & 8'hff},otp_content[{16'h0000,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b0101)
                begin
                        data_to_read <= otp_content[{16'h0001,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0001,int_add[7:0] & 8'hff},otp_content[{16'h0001,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b0110)
                begin
                        data_to_read <= otp_content[{16'h0002,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0002,int_add[7:0] & 8'hff},otp_content[{16'h0002,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b0111)
                begin
                        data_to_read <= otp_content[{16'h0003,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0003,int_add[7:0] & 8'hff},otp_content[{16'h0003,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1000)
                begin
                        data_to_read <= otp_content[{16'h0004,int_add[7:0] & 8'hff}] ; 
                $display("R_otp_content[%h]=%h",{16'h0004,int_add[7:0] & 8'hff},otp_content[{16'h0004,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1001)
                begin
                        data_to_read <= otp_content[{16'h0005,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0005,int_add[7:0] & 8'hff},otp_content[{16'h0005,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1010)
                begin
                        data_to_read <= otp_content[{16'h0006,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0006,int_add[7:0] & 8'hff},otp_content[{16'h0006,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1011)
                begin
                        data_to_read <= otp_content[{16'h0007,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0007,int_add[7:0] & 8'hff},otp_content[{16'h0007,int_add[7:0] & 8'hff}]);
                end



				if({int_add[13:12],int_add[9:8]}==4'b1100)
                begin
                        data_to_read <= otp_content[{16'h0008,int_add[7:0] & 8'hff}] ; 
                $display("R_otp_content[%h]=%h",{16'h0008,int_add[7:0] & 8'hff},otp_content[{16'h0008,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1101)
                begin
                        data_to_read <= otp_content[{16'h0009,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h0009,int_add[7:0] & 8'hff},otp_content[{16'h0009,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1110)
                begin
                        data_to_read <= otp_content[{16'h000a,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h000a,int_add[7:0] & 8'hff},otp_content[{16'h000a,int_add[7:0] & 8'hff}]);
                end

                if({int_add[13:12],int_add[9:8]}==4'b1111)
                begin
                        data_to_read <= otp_content[{16'h000b,int_add[7:0] & 8'hff}] ; 
                $display("otp_content[%h]=%h",{16'h000b,int_add[7:0] & 8'hff},otp_content[{16'h000b,int_add[7:0] & 8'hff}]);
                end
                
              end  
              
      end   
   end

   always 
      @(posedge delayed_dtr_read_data_request)
      if ($time != 0)
      begin
         if (read_enable &&  DTR_single_read && !qpim)
         begin
           // int_add = cut_add; 
		   if(!ads && !spi_decoder.cmd_4byte)begin
		    	int_add[25:24] = cut_add[25:24];
            	int_add[23:0] = cut_add[23:0] - 1; 
		  end
		  else begin
			int_add = cut_add - 1;
		  end
            //---------------------------------------------------------
            // Read instruction
            //---------------------------------------------------------
            if(!otprd)
              begin 
              if (int_add > `TOP_MEM)                                  
              begin                                                      
                 for(i = 0; i <= `BIT_TO_CODE_MEM - 1; i = i + 1)        
                 begin                                                   
                    cut_add[i] = 1'b0;                                   
                 end                                                     
                 int_add = 0; // roll over at the end of mem array      
              end                                                        
              data_to_read <= content[int_add] ; 
              //$display("content[%h]=%h",int_add,content[int_add]);
              end 
             
         end
      end   
   


reg [15:0] crc_cnt;
initial crc_cnt = 0;

wire crmr_flag;
assign crmr_flag = spi_decoder.crmr_flag;

always@( posedge read_enable ,crmr_flag )begin 
	crc_cnt = 0;
end

  always    
      @(negedge read_data_request)
        begin
                if ($time != 0)
                begin
                        if(wrap_8byte && wrap_enable && thold_readquad)
                        begin
                                cut_add[2:0] <= cut_add[2:0]+1;
                        end

                        else if(wrap_16byte && wrap_enable && thold_readquad)
                        begin
							case({spi_decoder.CRC1  ,spi_decoder.CRC0})	
                            	2'b11  :  cut_add[3:0] <= cut_add[3:0]+1;
								default:  begin											
										  	cut_add[3:0] <= (crc_cnt%16==0 ) && crc_cnt>0 ?  cut_add[3:0] :  cut_add[3:0]+1;
											crc_cnt  <= (crc_cnt%16==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
										  end
							endcase
                        end

                        else if(wrap_32byte && wrap_enable && thold_readquad)
                        begin	
							case({spi_decoder.CRC1  ,spi_decoder.CRC0})	
                            	2'b11  :  cut_add[4:0] <= cut_add[4:0]+1;
								default:  begin											
										  	cut_add[4:0] <= (crc_cnt%32==0 ) && crc_cnt>0  ?  cut_add[4:0] :  cut_add[4:0]+1;
											crc_cnt  <=  (crc_cnt%32==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
										  end
							endcase
                           //     cut_add[4:0] <= cut_add[4:0]+1;
                        end

                        else if(wrap_64byte && wrap_enable && thold_readquad)
                        begin
							case({spi_decoder.CRC1  ,spi_decoder.CRC0})	
                            	2'b11  :  cut_add[5:0] <= cut_add[5:0]+1;
								default:  begin											
										  	cut_add[5:0] <= (crc_cnt%64==0 ) && crc_cnt>0 ?  cut_add[5:0] :  cut_add[5:0]+1;
											crc_cnt  <= (crc_cnt%64==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;

										  end
							endcase
                              //  cut_add[5:0] <= cut_add[5:0]+1;
                        end

                        else if(qpi_wrap_8byte &&  qpi_wrap_read)
                        begin
                                cut_add[2:0] <= cut_add[2:0]+1;
                        end

                        else if(qpi_wrap_16byte &&  qpi_wrap_read)
                        begin
							case({spi_decoder.CRC1  ,spi_decoder.CRC0})	
                            	2'b11  :  cut_add[3:0] <= cut_add[3:0]+1;
								default:  begin											
										  	cut_add[3:0] <= (crc_cnt%16==0 ) && crc_cnt>0 ?  cut_add[3:0] :  cut_add[3:0]+1;
											crc_cnt  <= (crc_cnt%16==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
										  end
							endcase
                               // cut_add[3:0] <= cut_add[3:0]+1;
                        end

                        else if(qpi_wrap_32byte &&  qpi_wrap_read)
                        begin
							case({spi_decoder.CRC1  ,spi_decoder.CRC0})	
                            	2'b11  :  cut_add[4:0] <= cut_add[4:0]+1;
								default:  begin											
										  	cut_add[4:0] <= (crc_cnt%32==0 ) && crc_cnt>0 ?  cut_add[4:0] :  cut_add[4:0]+1;
											crc_cnt  <= (crc_cnt%32==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
										  end
							endcase
                             //   cut_add[4:0] <= cut_add[4:0]+1;
                        end

                        else if(qpi_wrap_64byte &&  qpi_wrap_read)
                        begin
							case({spi_decoder.CRC1  ,spi_decoder.CRC0})	
                            	2'b11  :  cut_add[5:0] <= cut_add[5:0]+1;
								default:  begin											
										  	cut_add[5:0] <= (crc_cnt%64==0 ) && crc_cnt>0 ?  cut_add[5:0] :  cut_add[5:0]+1;
											crc_cnt  <= (crc_cnt%64==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
										  end
							endcase
                               // cut_add[5:0] <= cut_add[5:0]+1;
                        end

			else if(otprd)
			begin
				cut_add[9:0] <= cut_add[9:0] + 1;
			end

            else begin   
					if(!ads && !spi_decoder.cmd_4byte )begin
						case({spi_decoder.CRC1  ,spi_decoder.CRC0,spi_decoder.DTR_quad_read_enable})	
                        3'b110  : cut_add[23:0] <= cut_add[23:0]+1;
						3'b101  : begin
							cut_add[23:0] <= (crc_cnt%16==0 ) && crc_cnt>0 ?  cut_add[23:0] :  cut_add[23:0]+1;
							crc_cnt  <= (crc_cnt%16==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
						end
						3'b011  : begin
							cut_add[23:0] <= (crc_cnt%32==0 ) && crc_cnt>0 ?  cut_add[23:0] :  cut_add[23:0]+1;
							crc_cnt  <= (crc_cnt%32==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
						end
						3'b001  : begin
							cut_add[23:0] <= (crc_cnt%64==0 ) && crc_cnt>0 ?  cut_add[23:0] :  cut_add[23:0]+1;
							crc_cnt  <= (crc_cnt%64==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
						end
						default : cut_add[23:0] <= cut_add[23:0]+1;
						endcase
					end
					else begin
						case({spi_decoder.CRC1  ,spi_decoder.CRC0,spi_decoder.DTR_quad_read_enable})	
                        3'b110  : cut_add <= cut_add+1;
						3'b101  : begin
							cut_add <= (crc_cnt%16==0 ) && crc_cnt>0 ?  cut_add :  cut_add+1;
							crc_cnt  <= (crc_cnt%16==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
						end
						3'b011  : begin
							cut_add <= (crc_cnt%32==0 ) && crc_cnt>0 ?  cut_add :  cut_add+1;
							crc_cnt  <= (crc_cnt%32==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
						end
						3'b001  : begin
							cut_add <= (crc_cnt%64==0 ) && crc_cnt>0 ?  cut_add :  cut_add+1;
							crc_cnt  <= (crc_cnt%64==0 ) && crc_cnt>0 ? 0 : crc_cnt +1;
						end
						default : cut_add <= cut_add+1;
						endcase
					end
				end
            end
        end
            
            
   always 
      @(negedge read_enable)
      if ($time != 0)
      begin
         for(i = 0; i <= `NB_BIT_DATA - 1; i = i + 1)
         begin
            data_to_read[i] <= 1'b0 ; 
         end
      end

   //--------------------------------------------------------
   // Page program instruction
   // To find the first adress of the memory to be programmed
   //--------------------------------------------------------
wire #1 delayed_add_pp_enable = add_pp_enable;  //added int_add_pp(int_add)
   always 
      @(delayed_add_pp_enable)
       begin
         if (delayed_add_pp_enable == 1'b1)
           if(!otppgm)
             begin
                int_add = {cut_add[(`BIT_TO_CODE_MEM-1):8],8'h00}; 
             end
           else if(otppgm)
             begin
                int_add = {{(`BIT_TO_CODE_MEM-1){1'b0}},cut_add[13:12],2'b00,cut_add[9:8], cut_add[7:0]};   //find the first add for otppg
             end 
       end      
             
             

 always                               // suspend address latch
      @(posedge resume_enable)
      if ($time != 0)
      begin
                if(suspend_otpers || suspend_ber32 || suspend_ber64 || suspend_ser)
                begin
                        if(suspend_pp || suspend_quadpgm || suspend_ex_quadpgm || suspend_otppgm)
                        begin
                                if (suspend_pp || suspend_quadpgm ||suspend_ex_quadpgm)
                                begin
                                        int_add = {suspend_add[`BIT_TO_CODE_MEM -1 : 8],8'h00}; 
                                        cut_add = {suspend_add[`BIT_TO_CODE_MEM -1 : 8],8'h00}; 
                                end
                                if (suspend_otppgm)
                                begin
                                        int_add = {{(`BIT_TO_CODE_MEM-1){1'b0}},suspend_add[13:12],2'h0,suspend_add[9:8],8'h00};       //***** 13'h0000 to 14'h0000 *****//
                                        cut_add = {{(`BIT_TO_CODE_MEM-1){1'b0}},suspend_add[13:12],2'h0,suspend_add[9:8],8'h00};       //***** 13'h0000 to 14'h0000 *****//
                                end

                        end
                        else
                        begin
                                if (suspend_otpers)
                                begin
                                        int_add = ers_add & `MASK_PAGE;                 
                                        cut_add = ers_add & `MASK_PAGE;                 
                                end
                                if (suspend_ber32)
                                begin
                                        int_add = ers_add & `MASK_BLK32 ;
                                        cut_add = ers_add & `MASK_BLK32 ;
                                end
                                if (suspend_ber64)
                                begin
                                        int_add = ers_add & `MASK_BLK64 ;
                                        cut_add = ers_add & `MASK_BLK64 ;
                                end
                                if (suspend_ser)
                                begin
                                        int_add = ers_add & `MASK_SECTOR ;
                                        cut_add = ers_add & `MASK_SECTOR ;
                                end

                        end

                end
                else if(suspend_pp || suspend_quadpgm || suspend_ex_quadpgm || suspend_otppgm)
                begin
                        if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)
                        begin
                                int_add = {suspend_add[`BIT_TO_CODE_MEM -1 : 8],8'h00}; 
                                cut_add = {suspend_add[`BIT_TO_CODE_MEM -1 : 8],8'h00}; 
                        end
                        if (suspend_otppgm)
                        begin
                                int_add = {{(`BIT_TO_CODE_MEM-1){1'b0}},suspend_add[13:12],2'h0,suspend_add[9:8],8'h00};       //***** 13'h0000 to 14'h0000 *****//
                                cut_add = {{(`BIT_TO_CODE_MEM-1){1'b0}},suspend_add[13:12],2'h0,suspend_add[9:8],8'h00};       //***** 13'h0000 to 14'h0000 *****//
                        end

                end
      end

      //----------------------------------------------------
      // Sector erase instruction
      // To find the first adress of the sector to be erased
      //----------------------------------------------------
wire #1 delayed_ser_enable = ser_enable;
   always 
      @(posedge delayed_ser_enable)
      
         begin
            int_add_ers = ers_add & `MASK_SECTOR ;
         end
         
 
      //----------------------------------------------------
      // Block erase instruction
      // To find the first adress of the block to be erased
      //----------------------------------------------------
wire #1 delayed_ber32_enable = ber32_enable;

 always 
      @(posedge delayed_ber32_enable)
         begin
            int_add_ers = ers_add & `MASK_BLK32 ;
         end
         
wire #1 delayed_ber64_enable = ber64_enable;
   always 
      @(posedge delayed_ber64_enable)
         begin
            int_add_ers = ers_add & `MASK_BLK64 ;
         end
         
                  
   //----------------------------------------------------
   // Write or erase cycle execution
   //----------------------------------------------------
     
   always 
      @(posedge pp_enable or posedge quadpgm_enable or posedge ex_quadpgm_enable)
      if ($time != 0)            // to avoid any corruption at initialization of variables
          begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
             content[int_add + i] = p_prog[i]& content[int_add + i];
         //$display("%t,p_prog[%h]=%h,content[%h]=%h",$time,i,p_prog[i],int_add + i,content[int_add + i]);
         end
      end
      
 always 
      @(posedge otppgm_enable)
      if ($time != 0)            // to avoid any corruption at initialization of variables
      begin

        if({int_add[13:12],int_add[9:8]} == 4'b0100)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000000 + i] = p_prog[i] & otp_content[24'h000000 + i];
          $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000000 +i,otp_content[24'h000000 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b0101)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000100 + i] = p_prog[i] & otp_content[24'h000100 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000100 +i,otp_content[24'h000100 + i]);

         end
        end


        if({int_add[13:12],int_add[9:8]} == 4'b0110)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000200 + i] = p_prog[i] & otp_content[24'h000200 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000200 +i,otp_content[24'h000200 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b0111)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000300 + i] = p_prog[i] & otp_content[24'h000300 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000300 +i,otp_content[24'h000300 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1000)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000400 + i] = p_prog[i] & otp_content[24'h000400 + i];
          $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000400 +i,otp_content[24'h000400 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1001)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000500 + i] = p_prog[i] & otp_content[24'h000500 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000500 +i,otp_content[24'h000500 + i]);

         end
        end


        if({int_add[13:12],int_add[9:8]} == 4'b1010)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000600 + i] = p_prog[i] & otp_content[24'h000600 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000600 +i,otp_content[24'h000600 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1011)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000700 + i] = p_prog[i] & otp_content[24'h000700 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000700 +i,otp_content[24'h000700 + i]);

         end
        end




		if({int_add[13:12],int_add[9:8]} == 4'b1100)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000800 + i] = p_prog[i] & otp_content[24'h000800 + i];
          $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000800 +i,otp_content[24'h000800 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1101)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000900 + i] = p_prog[i] & otp_content[24'h000900 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000900 +i,otp_content[24'h000900 + i]);

         end
        end


        if({int_add[13:12],int_add[9:8]} == 4'b1110)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000a00 + i] = p_prog[i] & otp_content[24'h000a00 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000a00 +i,otp_content[24'h000a00 + i]);

         end
        end

        if({int_add[13:12],int_add[9:8]} == 4'b1111)
        begin
         for(i = 0; i <= (`PLENGTH - 1); i = i + 1)
         begin
            otp_content[24'h000b00 + i] = p_prog[i] & otp_content[24'h000b00 + i];
            $display("%t,p_prog[%h]=%h,otp_content[%h]=%h",$time,i,p_prog[i],24'h000b00 +i,otp_content[24'h000b00 + i]);

         end
        end






      end      
      

   always 
      @(negedge cer_enable)
      if ($time != 0)            // to avoid any corruption at initialization of variables
      begin
   if((SW_RST==1) | (HW_RST==1'b1))
        begin
         for(i = 0; i <= `TOP_MEM; i = i + 1)
         begin
            content[i] = 8'bxxxxxxxx; 
         end
        end
        else
        begin
         for(i = 0; i <= `TOP_MEM; i = i + 1)
         begin
            content[i] = 8'b11111111; 
         end

        end


      end

   always 
      @(negedge ser_enable)

      if ($time != 0)            // to avoid any corruption at initialization of variables
      begin
    if((SW_RST==1) | (HW_RST==1'b1))
        begin
         for(i = int_add_ers; i <= (int_add_ers + (`SSIZE / `NB_BIT_DATA) - 1); i = i + 1)
         begin
            content[i] = 8'bxxxxxxxx; 
         end
        end

        else
        begin
         for(i = int_add_ers; i <= (int_add_ers + (`SSIZE / `NB_BIT_DATA) - 1); i = i + 1)
         begin
            content[i] = 8'b11111111;
	    
	    //$display("content[%h]=%h",int_add_ers,content[int_add_ers]);

         end
                
        end
      end
      
 always 
      @(negedge otpers_enable)
     
      if ($time != 0)            // to avoid any corruption at initialization of variables
      begin
        if((SW_RST==1) | (HW_RST==1'b1))
        begin
            for(i = 0; i <= (`OTP_SIZE - 1); i = i + 1)
            begin
                otp_content[i + 24'h000000] = 8'bxxxxxxxx; 
	    end

        end     
        else
        begin
	    	if (ers_add[13:12] == 2'b01)
        	begin
        	    for(i = 0; i <= (`OTP_SIZE/2 - 1); i = i + 1)
				begin
			    	otp_content[24'h000000 + i] = 8'b11111111;
        	    end
        	end

        	if (ers_add[13:12] == 2'b10)
        	begin
        	    for(i = 0; i <= (`OTP_SIZE/2 - 1); i = i + 1)
				begin
			    	otp_content[24'h000400 + i] = 8'b11111111;
        	    end
        	end

			if (ers_add[13:12] == 2'b11)
        	begin
        	    for(i = 0; i <= (`OTP_SIZE/2 - 1); i = i + 1)
				begin
			    	otp_content[24'h000800 + i] = 8'b11111111;
        	    end
        	end

        end

      end
      
  always 
      @(negedge ber32_enable)
     
      if ($time != 0)            // to avoid any corruption at initialization of variables
      begin
                if((SW_RST==1) | (HW_RST==1'b1))
        begin
         for(i = int_add_ers; i <= (int_add_ers + (`BSIZE_32 / `NB_BIT_DATA) - 1); i = i + 1)
         begin
            content[i] = 8'bxxxxxxxx; 
         end
        end

        else
        begin
         for(i = int_add_ers; i <= (int_add_ers + (`BSIZE_32 / `NB_BIT_DATA) - 1); i = i + 1)
         begin
            content[i] = 8'b11111111; 
         end
        end
      end
    
      
always 
      @(negedge ber64_enable)
      
      if ($time != 0)            // to avoid any corruption at initialization of variables
      begin
                if((SW_RST==1) | (HW_RST==1'b1))
        begin
         for(i = int_add_ers; i <= (int_add_ers + (`BSIZE_64 / `NB_BIT_DATA) - 1); i = i + 1)
         begin
            content[i] = 8'bxxxxxxxx; 
         end
        end
        else
        begin
         for(i = int_add_ers; i <= (int_add_ers + (`BSIZE_64 / `NB_BIT_DATA) - 1); i = i + 1)
         begin
            content[i] = 8'b11111111; 
         end
        end
      end
         

endmodule

//--------acdc_check.v---------------------
module acdc_check (c, d, s, hold, write_op, read_op,oen,thold_readquad,qpim,quad_cmd);

   input c; //clk
   input d; //si
   input s; //cs
   input hold; 
   input write_op; 
   input read_op; 
   input oen;                     //***** output enable *****//
   input thold_readquad;
   input qpim;
   input quad_cmd;
   
   ////////////////
   // TIMING VALUES
   ////////////////
   time t_C_rise;
   time t_C_fall;
   time t_H_rise;
   time t_H_fall;
   time t_S_rise;
   time t_S_fall;
   time t_D_change;
   time high_time;
   time low_time;
  

   ////////////////
   
   
   initial
   begin
      high_time = 100000;
      low_time = 100000;
   end

   //--------------------------------------------
   // This process checks pulses length on pin /S
   //--------------------------------------------
   always 
   begin : shsl_watch
      @(posedge s); 
      begin
         if ($time != 0) 
         begin
            t_S_rise = $time; 
            @(negedge s); 
            t_S_fall = $time; 
            if ((t_S_fall - t_S_rise) < `TSHSL)
            begin
               $display("%t : ERROR : tSHSL condition violated",$realtime); 
            end 
         end
      end 
   end 

   //----------------------------------------------------
   // This process checks select setup and hold timings 
   //----------------------------------------------------
   always 
   begin : s_watch1  
      @(s); 
      if ((s == 1'b0) && (hold != 1'b0))
      begin
      if(!oen)
      begin
         if ($time != 0) 
         begin
            t_S_fall = $time;
            if ( ($time - t_C_rise) < `TCHSL)
                begin
                $display("%t : ERROR :tCHSL condition violated",$realtime); 
            if (c ==1'b1)
                begin
                @(c);
                @(c);
                if (($time - t_S_fall) < `TSLCH)
                      begin 
                      $display("%t : ERROR :tSLCH condition violated",$realtime);  
                      end
                end 
                end
            else if (c == 1'b0)
                begin
                @(c);
                if (($time - t_S_fall) < `TSLCH)
                    begin 
                    $display("%t : ERROR :tSLCH condition violated",$realtime);  
                    end
                end 
                end
      end 
      end
   end
   
   //----------------------------------------------------
   // This process checks deselect setup and hold timings 
   //----------------------------------------------------
   always
   begin : s_watch2 
   @(s);
      if ((s == 1'b1) && (hold != 1'b0))
      begin
      if(!oen)
      begin
         if ($time != 0) 
         begin
            t_S_rise = $time;
            if ( ($time - t_C_rise) < `TCHSH)
                begin
                $display("%t : ERROR :tCHSH condition violated",$realtime); 
                end 
            if (c == 1'b1)
                begin
                @(c);
                @(c);
                if ( ($time - t_S_rise) < `TSHCH )
                    begin
                    $display("%t : ERROR :tSHCH condition violated",$realtime);
                    end
                end
            else if (c == 1'b0)
                begin
                @(c);
                if ( ($time - t_S_rise) < `TSHCH )
                    begin
                    $display("%t : ERROR :tSHCH condition violated",$realtime);
                    end
                end 
          end
          end
      end 
   end

   //---------------------------------
   // This process checks hold timings
   //---------------------------------
   always 
   begin : hold_watch
      @(hold); 
      if ((hold == 1'b0) && (s == 1'b0) && (qpim == 0) && !quad_cmd)
      begin
      if((!oen) & (!thold_readquad))
      begin
         if ($time != 0) 
         begin
            t_H_fall = $time ;
            if ( (t_H_fall - t_C_rise) < `TCHHL)
            begin
               $display("%t : ERROR : tCHHL condition violated",$realtime); 
            end 
         
            @(posedge c);
            if( ($time - t_H_fall) < `THLCH)
            begin
               $display("%t : ERROR : tHLCH condition violated",$realtime);
            end
         end
         end
      end 


      if ((hold == 1'b1) && (s == 1'b0) && (qpim == 0) && !quad_cmd)
      begin
       if((!oen) & (!thold_readquad))
       begin
         if ($time != 0) 
         begin
            t_H_rise = $time ;
            if ( (t_H_rise - t_C_rise) < `TCHHH)
            begin
               $display("%t : ERROR : tCHHH condition violated",$realtime); 
            end 
            @(posedge c);
            if( ($time - t_H_rise) < `THHCH)
            begin
               $display("%t : ERROR : tHHCH condition violated",$realtime);
            end
         end
         end
      end 
   end 

   //--------------------------------------------------
   // This process checks data hold and setup timings
   //--------------------------------------------------
   always 
   begin : d_watch
      @(d);
      if(!oen)
      begin
      if ((s ==1'b0)  && (hold == 1'b1))  
      begin
      if ($time != 0) 
      begin
         t_D_change = $time;
         if (c == 1'b1)
         begin
            if ( ($time - t_C_rise) < `TCHDX)
            begin
               $display("%t : ERROR : tCHDX condition violated",$realtime); 
            end 
         end
         else if (c == 1'b0)
         begin
            @(c);
            if ( ($time - t_D_change) < `TDVCH) 
            begin
               $display("%t : ERROR : tDVCH condition violated",$realtime);
            end
         end 
      end
      end
      end
   end 

   //-------------------------------------
   // This process checks clock high time
   //-------------------------------------
   always 
   begin : c_high_watch
      @(c); 
      if ($time != 0) 
         begin
         if (c == 1'b1)
            begin
            if (s==1'b1) high_time=100; 
            if (s==1'b0)  
                begin 
                t_C_rise = $time; 
                @(negedge c); 
                t_C_fall = $time; 
                high_time = t_C_fall - t_C_rise;
                if ((t_C_fall - t_C_rise) < `TCH)
                    begin
                    if ((s == 1'b0) && (hold == 1'b1)) 
                         begin
                         if ($time != 0) $display("%t : ERROR : tCH condition violated",$realtime); 
                         end 
                    end 
                 end
      end
   end 
 end
   //-------------------------------------
   // This process checks clock low time
   //-------------------------------------
   always 
   begin : c_low_watch
      @(c); 
      if ($time != 0)
          begin
          if (s==1'b1) low_time=100;  
          if (s==1'b0)  
              begin  
              if (c == 1'b0)
                  begin
                  t_C_fall = $time; 
                  @(posedge c); 
                  t_C_rise = $time; 
                  low_time = t_C_rise - t_C_fall;
                  if ((t_C_rise - t_C_fall) < `TCL)
                     begin
                     if ((s == 1'b0) && (hold == 1'b1)) 
                         begin
                         if ($time != 0) $display("%t : ERROR : tCL condition violated",$realtime); 
                        end 
                     end 
                  end
              end
        end 
   end
   
   //-----------------------------------------------
   // This process checks clock frequency
   //-----------------------------------------------
   always @(high_time or low_time or read_op or write_op)

   begin : freq_watch
      if ($time != 0) 
      begin
         if ((s == 1'b0) && (hold == 1'b1)) 
         begin
            if (read_op)
            begin
               if ((high_time + low_time) < `TR)
               begin
                  if ($time !=0) $display("%t : ERROR : Clock frequency condition violated for READ instruction: fR>120MHz",$realtime); 
               end 
            end
            if (write_op)
            begin
               if ((high_time + low_time) < `TC)
               begin
                  if ($time !=0) $display("%t : ERROR : Clock frequency condition violated: fC>120MHz",$realtime); 
               end 
            end 
         end
      end
   end 
  
 
endmodule

//------------internal_logic.v----------

module internal_logic (       c,   d,      w, s, hold, data_to_read, q,        data_to_write, page_add_index, add_mem, suspend_add, suspend_enable, suspend_pp, suspend_ber32 , suspend_ber64 , suspend_ser, resume_enable, write_op, read_op, qpi_wrap_read, cer_enable, ber32_enable, ber64_enable, ser_enable, add_pp_enable, pp_enable,write_data_request, read_enable, read_data_request, oen, thold_readquad,  
                              quadpgm_enable, ex_quadpgm_enable,  otpers_enable, otppgm_enable, wrap_enable, wrap_8byte, wrap_16byte, wrap_32byte, wrap_64byte, qpi_wrap_8byte,
                                                          dtr_read_data_req, DTR_single_read, qpi_wrap_16byte, qpi_wrap_32byte, qpi_wrap_64byte, suspend_quadpgm, suspend_ex_quadpgm, suspend_otppgm,  suspend_otpers, otppgm, otprd,
                                                                                otpers,wip,standby_bak,qpim,quad_cmd,ers_add,SW_RST,HW_RST,pp,quadpgm, ex_quadpgm,
																				int_add,ADS);
   ////////////////////////////////
   // declaration of the parameters
   ////////////////////////////////
    
   input c;   //clk
   inout d;   //si
   inout w;   //wp
   input s;  //cs
   inout hold; 
   inout q;  
   input[(`NB_BIT_DATA - 1):0] data_to_read;

   reg     [(`NB_BIT_DATA - 1):0] iddata_to_read;
   input [(`BIT_TO_CODE_MEM-1):0]   int_add; 
  
   wire d,q,w,hold;
 
   output thold_readquad;
	output ADS;//5109 
   output[(`NB_BIT_DATA - 1):0] data_to_write;
   reg[(`NB_BIT_DATA - 1):0] data_to_write;
   
   output[(`LSB_TO_CODE_PAGE - 1):0] page_add_index;    // position to write data_to_write inside the page
   reg[(`LSB_TO_CODE_PAGE - 1):0] page_add_index;

   output[(`NB_BIT_ADD_MEM - 1):0] add_mem; 
   reg[(`NB_BIT_ADD_MEM - 1):0] add_mem;
   
   output [(`BIT_TO_CODE_MEM-1):0]   suspend_add; 
   reg [(`BIT_TO_CODE_MEM-1):0]      suspend_add; 
    

   output write_op; 
   reg write_op;

   output read_op; 
   reg read_op;

   
   output cer_enable; 
   reg cer_enable;

   output ber32_enable; 
   reg ber32_enable;
   
   output ber64_enable; 
   reg ber64_enable;
   
   output ser_enable; 
   reg ser_enable;
   
   output otpers_enable;  //otp erase 
   reg otpers_enable;
   
   
   output add_pp_enable; 
   reg add_pp_enable;
   
   output pp_enable; 
   reg pp_enable;
   
   output quadpgm_enable;  //quad pgm
   reg quadpgm_enable;

   output ex_quadpgm_enable;
   reg ex_quadpgm_enable;
   
   output otppgm_enable;  //otp pgm
   reg otppgm_enable;
   
   output read_enable; 
   reg read_enable;

   output read_data_request; 
   reg read_data_request;
  
   output DTR_single_read;
   output dtr_read_data_req;

   output write_data_request; 
   reg write_data_request;
   
   output resume_enable;
   reg resume_enable;
   
   output suspend_enable;
   reg suspend_enable;

   output wrap_enable;
   reg wrap_enable;

   output wrap_8byte;
   reg wrap_8byte;

   output wrap_16byte;
   reg wrap_16byte;

   output wrap_32byte;
   reg wrap_32byte;

   output wrap_64byte;
   reg wrap_64byte;

   output qpi_wrap_8byte;
   reg qpi_wrap_8byte;

   output qpi_wrap_16byte;
   reg qpi_wrap_16byte;

   output qpi_wrap_32byte;
   reg qpi_wrap_32byte;

   output qpi_wrap_64byte;
   reg qpi_wrap_64byte;


   output suspend_pp;
   reg suspend_pp;
   
   output suspend_quadpgm;  //quadpgm suspend
   reg suspend_quadpgm;

   output suspend_ex_quadpgm;
   reg suspend_ex_quadpgm;
   
   output suspend_otppgm;  //otppgm suspend
   reg suspend_otppgm;
   
   output suspend_otpers;  //otpers suspend
   reg suspend_otpers;
         
   output suspend_ser;
   reg suspend_ser;
   
   output suspend_ber32;
   reg suspend_ber32;
   
   output suspend_ber64;
   reg suspend_ber64;
   
   output oen;
   reg oen;
    
   output otppgm;    // new add cmd
   reg    otppgm;
    
   output otprd;
   reg    otprd; 
   
   output otpers;
   reg    otpers;
  
   output qpim;
   reg    qpim;

   output quad_cmd; 
        
   output wip;
   reg wip;
   
   output standby_bak;
   reg standby_bak;
   output [(`BIT_TO_CODE_MEM-1):0] ers_add;
   reg [(`BIT_TO_CODE_MEM-1):0]     ers_add; 
   output SW_RST;
   reg SW_RST;

   output HW_RST;
   reg HW_RST;


      
   ///////////////////////////////////////////////
   // declaration of internal variables
   ///////////////////////////////////////////////
   reg only_rdsr;
   reg only_suspend;
   reg select_ok;
   reg raz;
   reg byte_ok;
   reg byte_ok_rst;
   reg wren;
   reg reset_66h;
   reg reset_99h;
   reg reset_enable;
   reg vwsr_enable;
   reg vwsr;
   reg wrdi;  //write disable
   reg rdsr_l; 
   reg rdsr_m;
   reg rdsr_h;     
   reg rd_ex_addr;  //2008
   reg rd_configuration_reg;  //5109 cmlin

   reg read_data_3byte;  
   reg read_data_4byte;  
   assign read_data = read_data_3byte || read_data_4byte; 
   
   reg fast_read_3byte;
   reg fast_read_4byte;
    assign fast_read = fast_read_3byte || fast_read_4byte ;


   reg DTR_single_read;
   reg DTR_dual_read;
   reg DTR_quad_read_3byte;
   reg DTR_quad_read_4byte;
   assign DTR_quad_read = DTR_quad_read_3byte || DTR_quad_read_4byte;

   reg read_sfdp,rd_sfdp_3byte;//2005 added
   reg read_uid;
   
   reg dofr_3byte;    //dual output fast read 3bh
   reg dofr_4byte;
   assign dofr = dofr_3byte || dofr_4byte;

   reg diofr_3byte;   //dual I/O fast read  bbh
   reg diofr_4byte;   //dual I/O fast read  bbh
   assign diofr = diofr_3byte || diofr_4byte;
   
   reg qofr_3byte;    //quad output fast read 6bh
   reg qofr_4byte;    //quad output fast read 6bh
    assign qofr = qofr_3byte || qofr_4byte;

   reg qiofr_3byte;   //quad I/O fast read  ebh
   reg qiofr_4byte;   //quad I/O fast read  ebh
   assign qiofr = qiofr_3byte || qiofr_4byte;

   reg qiowfr;  //quad I/O word read  e7h
   
   reg manu_device_id_dual;   //Manufacturer/Device ID  92h
   reg manu_device_id_quad;   //Manufacturer/Device ID  94h
   reg crmr;
   reg reset_crmr;
   reg crmr_flag;
   reg DTR_dual_read_crm_read ;
   reg DTR_quad_read_crm_read ;
  
   reg diofr_crm_flag ; 
   reg qiofr_crm_flag ; 
   reg DTR_dual_read_crm_flag ;
   reg DTR_quad_read_crm_flag ;
   reg qiowfr_crm_flag ; 
   reg manu_device_id_dual_crm_flag ; 
   reg manu_device_id_quad_crm_flag ; 
   reg ers_suspend_flag ; 
   reg pgm_suspend_flag ;
   reg [7:0] qpi_para_bit;
   


   reg wrsr_l;  
   reg wrsr_m; 
   reg wrsr_h;
   reg wrsr_enable;  
   reg wr_ex_addr;   //2008
   reg wr_ex_addr_enable;

   reg wr_configuration_reg;//5109 cmlin
   reg wr_config_reg_enable;//5109 cmlin
   
   reg  dpd;
   reg  rfdp;
   reg  rfdpid;
   reg  dpd_enable;
   reg  bpbit_reg;  // new add register for bp
 
    reg pp_3byte;
    reg pp_4byte;
   
    output pp;
    assign pp = pp_3byte | pp_4byte;

    
    reg quadpgm_3byte;
    reg quadpgm_4byte;

   output quadpgm;  
   assign quadpgm = quadpgm_3byte | quadpgm_4byte;  
    

    reg ex_quadpgm_3byte;
    reg ex_quadpgm_4byte;

    output ex_quadpgm;
    assign ex_quadpgm = ex_quadpgm_3byte | ex_quadpgm_4byte;


    output qpi_wrap_read;
    assign qpi_wrap_read = (qiofr || DTR_quad_read) && (!qpi_para_bit[2]);

   reg ser_3byte;
   reg ser_4byte;
   assign ser = ser_3byte || ser_4byte;

   reg ber32_3byte;
   reg ber32_4byte;
   assign ber32 = ber32_3byte || ber32_4byte;

   reg ber64_3byte;   
   reg ber64_4byte;   
   assign ber64 = ber64_3byte || ber64_4byte;
   
   reg cer;
   reg rdid;
   reg q_bis;
   reg d_bis;
   reg wp_bis;
   reg hold_bis;
   
  wire tmp_do;  
 
  wire tmp_di;
  wire tmp_wp;
  wire tmp_hold;
  wire bpbit;
 

   
   reg dq_do;
   reg dq_di;
   reg dq_wp;
   reg dq_hold;
   
   reg hold_cond;
   reg inhib_wren;
   reg inhib_reset_66h;
   reg inhib_reset_99h;
   reg inhib_wrdi;
   reg inhib_rdsr;
   reg inhib_read;
   reg inhib_crmr;
   reg inhib_wrap;
   reg inhib_set_read_para;

   reg inhib_rd_ex_addr;   //2008
   reg inhib_wr_ex_addr;
   reg rd_ex_addr_enable;

   reg inhib_pp;
   reg inhib_quadpgm;  //inhib nea add cmd
   reg inhib_ex_quadpgm;
   reg inhib_otppgm;   
   reg inhib_otpers;
   reg inhib_ser;
   reg inhib_ber32;
   reg inhib_ber64;   
 
   reg inhib_wrsr;  

   reg inhib_cer;
   reg inhib_rdid;
   reg inhib_mid;  
   reg inhib_uniqueid;  
   reg inhib_rfdpid;  
   reg inhib_manu_device_id_dual;  
   reg inhib_manu_device_id_quad;  
   reg inhib_suspend;
   reg inhib_resume;
  
  
   reg inhib_rfdp;  
   reg inhib_dpd; 


   reg clear_sr_flags;       //2008
   reg inhib_clear_sr_flags;


   reg enable_4byte_mode;
   reg inhib_enable_4byte_mode;

    
   reg disable_4byte_mode;
   reg inhib_disable_4byte_mode;

         
   reg suspend;
   reg resume;

   reg reset_wel;
   reg wel;
   reg c_int;
   
   reg rdsr_enable;
   reg rdid_enable;

   reg [4:0] bit_id;
   reg [23:0]  id;      //9fh
   reg [15:0] did0;     //90h 
   reg [15:0] did1;     //90h 
   reg [7:0] resdid;    //abh 
   
   reg [7:0] crm_bit;
   reg [7:0] wrap_bit;
   reg wrapset;
   reg set_read_para;
   reg  QE;  
   reg  LB1;    
   reg  LB2;    
   reg  LB3;//add cmlin    
   reg  T_B;
   reg  mid;      
   reg  uniqueid;      
   reg  qpi_dummy_4clk;
   reg  qpi_dummy_6clk;
   reg  qpi_dummy_8clk;
   reg  qpi_dummy_12clk;//5109 cmlin
   reg  qpi_dummy_16clk;//5109 cmlin


   wire dtr_dummy_6clk;
   wire dtr_dummy_8clk;
   wire dtr_dummy_12clk;
   wire dtr_dummy_16clk;

   wire lc_dummy_8clk;
   wire lc_dummy_6clk;
   wire lc_dummy_12clk;
   wire lc_dummy_16clk;

   reg [2:0]   cpt; 
   reg [2:0]   cpt_rst;
   reg [31:0]  cpt_rst_delay;
   reg [2:0]   bit_index;       // to allow shift inside a byte 
   reg [2:0]   bit_register;    // to allow shift inside status register


   reg [7:0]   data; 
   reg [7:0]   data_rst; 
   reg [7:0]   adress_1; 
   reg [7:0]   adress_2; 
   reg [7:0]   adress_3; 
   reg [7:0]   adress_4;
   reg [7:0]   extended_addr;
   reg [7:0]   manufacturerID;
   reg [7:0]   memtype;
   reg [7:0]   density; 
   reg [7:0]   electronic_signature;  
   reg [4:0]   bp;  // blk protected
   reg srp; // statue register protected
   reg srp1; //5109 cmlin
   reg wrsr_protect;
   reg HOLD_reset;  //new added
   reg inhib_HOLD_reset;  //new added
   reg WPS;                       //new added
   reg SUS1; //2104
   reg SUS2; //2104
   reg [1:0]   DRV; //2104
   reg LC0;   //2104
   reg LC1;

   reg ADP; //2008
   reg ADS;
      
   reg EE;  //erase error
   reg PE;  //program error
   reg CRC1,CRC0,ECC;//5109 cmlin
   reg [(`NB_BIT_DATA-1):0]   data_latch;
   reg [(`NB_BIT_DATA*3-1):0]   register_bis_latch;   
   reg [(`NB_BIT_DATA*3-1):0]   status_register; 

   reg [(`NB_BIT_DATA-1):0] ex_addr_latch;
   reg [(`NB_BIT_DATA-1):0] extended_addr_reg;

   reg [(`NB_BIT_DATA-1):0] configuration_latch;//add cmlin
   reg [(`NB_BIT_DATA-1):0] configuration_reg;  //add cmlin
   
   reg [(`NB_BIT_ADD_MEM-1):0]      adress; 
   reg [(`BIT_TO_CODE_MEM-1):0]     cut_add; 
   reg [(`LSB_TO_CODE_PAGE -1) :0]  lsb_adress; 

        reg inhib_IB_lock;     
        reg IB_lock;           
        reg IB_lock_enable;    

        reg inhib_IB_unlock;   
        reg IB_unlock;         
        reg IB_unlock_enable;  

        reg inhib_IB_read;     
        reg IB_read;           
        reg IB_read_enable;    

        reg inhib_GB_lock;     
        reg GB_lock;           
        reg GB_lock_enable;    

        reg inhib_GB_unlock;   
        reg GB_unlock;         
        reg GB_unlock_enable;  

	reg [9:0] address_IB_lock;
        reg [9:0] address_IB_read;

        //reg [(`BIT_TO_CODE_MEM-17):0] address_IB_lock;
        //reg [(`BIT_TO_CODE_MEM-17):0] address_IB_read;
	//
        reg [4:0] address_IS_lock;
        reg [4:0] address_IS_read;

        reg [3:0] address_otp;

        reg [7:0] data_lock_en;
        
        
        wire IS_lock_top;
        wire IS_lock_bottom;
        wire wps_protect_ber32_bottom_sel;
        wire wps_protect_ber32_top_sel;
        wire wps_protect_ber32_bottom;
        wire wps_protect_ber32_top;
        wire wps_protect_ber64_bottom;
        wire wps_protect_ber64_top;
        reg  wps_protect_bottom_sel;
        reg  wps_protect_top_sel;

        reg [15:0] IS_bottom_sel;
        reg [15:0] IS_top_sel;


	reg [(`BLOCK_NUM-1):0] lock_sel;

        reg [(`BLOCK_NUM-1):0] lock_enable;

        wire wps_lock_sel;
        reg  wps_protect_sel;
        wire wps_protect;

	reg factory_mode;

	reg [2:0] bit_index_dlp;
	reg dlp_done;

	wire [7:0] dlp_bit = 8'b00110100;
	reg dlp_read_enable;

	reg erase_enable;

	
	reg [7:0] SFDP_ARRAY [255:0];
	reg write_enable;


   reg [31:0]  byte_cpt;
   integer     byte_cpt_rst;
   integer     i,j;
   integer     count_enable; 
   
   time         pps_time;
   time         otppgms_time;  //new add cmd suspend 
   time         otperss_time;
   time         quadpgms_time;
   time		ex_quadpgms_time; 

   time         ser_time;
   time         ber32_time;
   time         ber64_time;
   
   time         ppi_time;
   time         quadpgmi_time; //new add cmd interrupt 
   time		ex_quadpgmi_time;

   time         otppgmi_time;
   time         otpersi_time;  
   time         seri_time;
   time         beri32_time;
   time         beri64_time;

   time         pps_time_add;
   time         otppgms_time_add;   
   time         otperss_time_add;
   time         quadpgms_time_add;         
   time		ex_quadpgms_time_add;

   time         ser_time_add;
   time         ber32_time_add;
   time         ber64_time_add;

   integer tSE;
    integer tBE1;
    integer tBE2 ;
    integer tCE;
    integer tPP;


   assign  tmp_do = q;    
   assign  tmp_di = d;
   assign  tmp_wp = w;
   assign  tmp_hold = hold;

   assign dtr_dummy_8clk = {LC1,LC0}==0 ;
   assign dtr_dummy_6clk = {LC1,LC0}==1 ;
   assign dtr_dummy_12clk = {LC1,LC0}==2 ;
   assign dtr_dummy_16clk = {LC1,LC0}==3 ;

   assign lc_dummy_8clk = {LC1,LC0}==0 ;
   assign lc_dummy_6clk = {LC1,LC0}==1 ;
   assign lc_dummy_12clk = {LC1,LC0}==2 ;
   assign lc_dummy_16clk = {LC1,LC0}==3 ;

	wire crc_16byte,crc_32byte,crc_64byte;
	assign crc_16byte  = {CRC1,CRC0}==2 ? 1 : 0 ;
	assign crc_32byte  = {CRC1,CRC0}==1 ? 1 : 0 ;
	assign crc_64byte  = {CRC1,CRC0}==0 ? 1 : 0 ;



   assign cmd_4byte = pp_4byte || quadpgm_4byte || ex_quadpgm_4byte || read_data_4byte || fast_read_4byte || dofr_4byte || diofr_4byte || qofr_4byte || qiofr_4byte || ser_4byte || ber32_4byte || ber64_4byte || DTR_quad_read_4byte;
    
    wire [2:0] pgm_addr_byte_num;
    assign pgm_addr_byte_num = (ADS || cmd_4byte) ? 4 : 3;
    assign {A27,A26, A25, A24} = extended_addr_reg[3:0]; 
    assign DLP = extended_addr_reg[4];
    
  
    assign d = (oen && ((fast_read && qpim) || (DTR_single_read && qpim) || DTR_dual_read || DTR_quad_read  || (read_sfdp && qpim) || qofr || qiofr || manu_device_id_quad || qiowfr || (rdsr_enable && qpim) || (rdid_enable && qpim) || (rfdp && qpim) || dofr || diofr || manu_device_id_dual || (IB_read_enable && qpim) || (rd_ex_addr_enable && qpim) || (otprd && qpim))) ? dq_di : 1'bz;
   assign q = (oen) ? dq_do : 1'bz;
   assign w = (oen && ((fast_read && qpim) || (DTR_single_read && qpim)|| DTR_quad_read  || (read_sfdp && qpim) || qofr || qiofr || manu_device_id_quad || qiowfr || (rdsr_enable && qpim) || (rdid_enable && qpim) || (rfdp && qpim) || (IB_read_enable && qpim) || (rd_ex_addr_enable && qpim) || (otprd && qpim))) ? dq_wp : 1'bz;
   assign hold = (oen && ((fast_read && qpim) || (DTR_single_read && qpim)|| DTR_quad_read || (read_sfdp && qpim)|| qofr || qiofr || manu_device_id_quad || qiowfr || (rdsr_enable && qpim) || (rdid_enable && qpim) || (rfdp && qpim) || (IB_read_enable && qpim) || (rd_ex_addr_enable && qpim) || (otprd && qpim))) ? dq_hold : 1'bz; 

   assign thold_readquad = (qiofr & !qpim) || qiowfr || (DTR_quad_read & !qpim);        //ebh e7h

   assign quad_cmd = quadpgm || ex_quadpgm || qofr || qiofr || manu_device_id_quad || qiowfr || wrapset || qpim;
   wire pgmsp = suspend_pp  || suspend_quadpgm  || suspend_ex_quadpgm  ; 
   wire ersp = suspend_ser  || suspend_ber32  || suspend_ber64  ;
   wire pgm_er_sp = pgmsp || ersp;
   


    //////////////////////////write command,address,first data byte enable
    assign pp_cmd_addr_enable = ((byte_cpt >= 4) && pp_3byte && (!ADS))
				|| ((byte_cpt >= 5) && (pp_4byte || (pp_3byte && ADS)));
    
    assign quadpgm_cmd_addr_enable = ((byte_cpt >= 4) && quadpgm_3byte && (!ADS))
				|| ((byte_cpt >= 5) && (quadpgm_4byte || (quadpgm_3byte && ADS)));

    assign ex_quadpgm_cmd_addr_enable = ((byte_cpt >= 4) && ex_quadpgm_3byte && (!ADS))
				|| ((byte_cpt >= 5) && (ex_quadpgm_4byte || (ex_quadpgm_3byte && ADS)));

    assign otppgm_cmd_addr_enable = ((byte_cpt >= 4) && otppgm && (!ADS))
				|| ((byte_cpt >= 5) && otppgm && ADS);



    ////////////////////read command,address,dummy enable
    assign read_data_enable = (read_data_3byte && (byte_cpt >= 3) && (!ADS)) || ((read_data_4byte || (read_data_3byte && ADS)) && (byte_cpt >= 4)); 
    assign fast_read_enable = (fast_read_3byte && (!ADS) && (byte_cpt >= 4) && !qpim)        //3yte mode and !qpi 
	 			|| (fast_read_3byte && (!ADS) && ( ((byte_cpt >= 9) && qpi_dummy_12clk) || ((byte_cpt >= 11) && qpi_dummy_16clk) || ((byte_cpt >= 6) && qpi_dummy_6clk) || ((byte_cpt >= 7) && qpi_dummy_8clk)) && qpim)  //3byte mode and qpi 
	 			|| ((fast_read_4byte || (fast_read_3byte && ADS)) && (byte_cpt >= 5) && !qpim)   //4byte mode and !qpi
	 			|| ((fast_read_4byte || (fast_read_3byte && ADS)) && (  ((byte_cpt >= 12) && qpi_dummy_16clk) ||  ((byte_cpt >= 10) && qpi_dummy_12clk) || ((byte_cpt >= 7) && qpi_dummy_6clk) || ((byte_cpt >= 8) && qpi_dummy_8clk)) && qpim);      //4byte mode and qpi

    assign dofr_enable = (dofr_3byte && (byte_cpt >= 4) && (!ADS)) ||  ((dofr_4byte || (dofr_3byte && ADS)) && (byte_cpt >= 5)); 
    assign diofr_enable = ((  (diofr_3byte  && (!ADS) &&  (((byte_cpt >= 7) && lc_dummy_16clk) ||  ((byte_cpt >= 6) && lc_dummy_12clk) || ((byte_cpt >= 4) && lc_dummy_6clk) ||	((byte_cpt >= 5) && lc_dummy_8clk))  )     ||  ((diofr_4byte || (diofr_3byte && ADS)) &&  (((byte_cpt >= 8) && lc_dummy_16clk) ||  ((byte_cpt >= 7) && lc_dummy_12clk) || ((byte_cpt >= 5) && lc_dummy_6clk) ||	((byte_cpt >= 6) && lc_dummy_8clk))   )) && (!crmr_flag))   //not continue read mode
	 		    || (((diofr_3byte &&  (((byte_cpt >= 6) && lc_dummy_16clk) ||  ((byte_cpt >= 5) && lc_dummy_12clk) || ((byte_cpt >= 3) && lc_dummy_6clk) ||	((byte_cpt >= 4) && lc_dummy_8clk))  && (!ADS)) || ((diofr_4byte || (diofr_3byte && ADS)) &&        (((byte_cpt >= 7) && lc_dummy_16clk) ||  ((byte_cpt >= 6) && lc_dummy_12clk) || ((byte_cpt >= 4) && lc_dummy_6clk) ||	((byte_cpt >= 5) && lc_dummy_8clk)) )) && crmr_flag);  //continue read mode

    assign qofr_enable = (qofr_3byte && (byte_cpt >= 4) && (!ADS)) ||  ((qofr_4byte || (qofr_3byte && ADS)) && (byte_cpt >= 5));

    assign qiofr_enable = (((qiofr_3byte && (!ADS) &&  (((byte_cpt >= 11) && lc_dummy_16clk) ||  ((byte_cpt >= 9) && lc_dummy_12clk) || ((byte_cpt >= 6) && lc_dummy_6clk) ||	((byte_cpt >= 7) && lc_dummy_8clk))  && !qpim)        //3yte mode and !qpi and !crmr
	 		  || (qiofr_3byte && (!ADS) && (((byte_cpt >= 11) && qpi_dummy_16clk) ||  ((byte_cpt >= 9) && qpi_dummy_12clk) || ((byte_cpt >= 6) && qpi_dummy_6clk) || ((byte_cpt >= 7) && qpi_dummy_8clk)) && qpim)  //3byte mode and qpi and !crmr
	 		  || ((qiofr_4byte || (qiofr_3byte && ADS)) &&  (((byte_cpt >= 12) && lc_dummy_16clk) ||  ((byte_cpt >= 10) && lc_dummy_12clk) || ((byte_cpt >= 7) && lc_dummy_6clk) ||	((byte_cpt >= 8) && lc_dummy_8clk))  && !qpim)   //4byte mode and !qpi and !crmr
	 		  || ((qiofr_4byte || (qiofr_3byte && ADS)) && (((byte_cpt >= 12) && qpi_dummy_16clk) || ((byte_cpt >= 10) && qpi_dummy_12clk) || ((byte_cpt >= 7) && qpi_dummy_6clk) || ((byte_cpt >= 8) && qpi_dummy_8clk)) && qpim)) && (!crmr_flag))     //4byte mode and qpi and !crmr
	 		  || (((qiofr_3byte && (!ADS) &&  (((byte_cpt >= 10) && lc_dummy_16clk) ||  ((byte_cpt >= 8) && lc_dummy_12clk) || ((byte_cpt >= 5) && lc_dummy_6clk) ||	((byte_cpt >= 6) && lc_dummy_8clk))  && !qpim)        //3yte mode and !qpi and crmr
	 		  || (qiofr_3byte && (!ADS) && (((byte_cpt >= 10) && qpi_dummy_16clk) || ((byte_cpt >= 8) && qpi_dummy_12clk) || ((byte_cpt >= 5) && qpi_dummy_6clk) || ((byte_cpt >= 6) && qpi_dummy_8clk)) && qpim)  //3byte mode and qpi and crmr
	 		  || ((qiofr_4byte || (qiofr_3byte && ADS)) &&  (((byte_cpt >= 11) && lc_dummy_16clk) ||  ((byte_cpt >= 9) && lc_dummy_12clk) || ((byte_cpt >= 6) && lc_dummy_6clk) ||	((byte_cpt >= 7) && lc_dummy_8clk))  && !qpim)   //4byte mode and !qpi and crmr
	 		  || ((qiofr_4byte || (qiofr_3byte && ADS)) && (((byte_cpt >= 11) && qpi_dummy_16clk) ||((byte_cpt >= 9) && qpi_dummy_12clk) || ((byte_cpt >= 6) && qpi_dummy_6clk) || ((byte_cpt >= 7) && qpi_dummy_8clk)) && qpim)) && crmr_flag) ;     //4byte mode and qpi and crmr
    assign qiowfr_enable = ((((byte_cpt >= 5) && (!crmr_flag)) || ((byte_cpt >= 4) && (crmr_flag))) && qiowfr && (!ADS))   //3byte mode 
				    || ((((byte_cpt >= 6) && (!crmr_flag)) || ((byte_cpt >= 5) && (crmr_flag))) && qiowfr && ADS); //4byte mode
    
    assign otprd_enable = (otprd && (byte_cpt >= 4) && (!ADS) && (!qpim))   //3byte and !qpi
			|| (otprd && (byte_cpt >= 5) && ADS && (!qpim))    //4byte and !qpi
			|| (otprd && (((byte_cpt >= 11) && qpi_dummy_16clk) || ((byte_cpt >= 9) && qpi_dummy_12clk) || ((byte_cpt >= 6) && qpi_dummy_6clk) || ((byte_cpt >= 7) && qpi_dummy_8clk)) && (!ADS) && qpim)	    //3byte and qpi 
			|| (otprd && (((byte_cpt >= 12) && qpi_dummy_16clk) || ((byte_cpt >= 10) && qpi_dummy_12clk) || ((byte_cpt >= 7) && qpi_dummy_6clk) || ((byte_cpt >= 8) && qpi_dummy_8clk)) && ADS && qpim);       //4byte and qpi


    assign DTR_single_read_enable = (DTR_single_read && (!ADS) && ( ((byte_cpt >= 15) && dtr_dummy_12clk) ||  ((byte_cpt >= 19) && dtr_dummy_16clk) ||  ((byte_cpt >= 11) && dtr_dummy_8clk) || ((byte_cpt >= 9) && dtr_dummy_6clk))  && qpim)     //3byte and qpim
				    || (DTR_single_read && (!ADS) && DTR_single_read && (byte_cpt >= 4) && (!qpim))    //3byte and !qpim
				    || (DTR_single_read && ADS && ( ((byte_cpt >= 16) && dtr_dummy_12clk) ||  ((byte_cpt >= 20) && dtr_dummy_16clk) || ((byte_cpt >= 12) && dtr_dummy_8clk) || ((byte_cpt >= 10) && dtr_dummy_6clk))  && qpim)   //4byte and qpim 
				    || (DTR_single_read && ADS && DTR_single_read && (byte_cpt >= 5) && (!qpim));   //4byte and !qpim

    assign DTR_dual_read_enable = (DTR_dual_read && (!ADS) &&  (((byte_cpt >= 11) && lc_dummy_16clk) ||  ((byte_cpt >= 9) && lc_dummy_12clk) || ((byte_cpt >= 6) && lc_dummy_6clk) ||	((byte_cpt >= 7) && lc_dummy_8clk))  && (!crmr_flag))    //3byte and !crmr 
				    || (DTR_dual_read && (!ADS) &&  (((byte_cpt >= 10) && lc_dummy_16clk) ||  ((byte_cpt >= 8) && lc_dummy_12clk) || ((byte_cpt >= 5) && lc_dummy_6clk) ||	((byte_cpt >= 6) && lc_dummy_8clk))  && crmr_flag)     //3byte and crmr
				    || (DTR_dual_read && ADS &&  (((byte_cpt >= 12) && lc_dummy_16clk) ||  ((byte_cpt >= 10) && lc_dummy_12clk) || ((byte_cpt >= 7) && lc_dummy_6clk) ||	((byte_cpt >= 8) && lc_dummy_8clk))  && (!crmr_flag))    //4byte and !crmr 
				    || (DTR_dual_read && ADS &&  (((byte_cpt >= 11) && lc_dummy_16clk) ||  ((byte_cpt >= 9) && lc_dummy_12clk) || ((byte_cpt >= 6) && lc_dummy_6clk) ||	((byte_cpt >= 7) && lc_dummy_8clk))  && crmr_flag);	      //4byte and crmr
				    
    assign DTR_quad_read_enable = ((DTR_quad_read_3byte && (!ADS) && ( ((byte_cpt >= 15) && dtr_dummy_12clk) ||  ((byte_cpt >= 19) && dtr_dummy_16clk) || ((byte_cpt >= 11) && dtr_dummy_8clk) || ((byte_cpt >=9) && dtr_dummy_6clk)) && (!crmr_flag))      //3byte and !crmr 
				|| (DTR_quad_read_3byte && (!ADS) && (((byte_cpt >= 14) && dtr_dummy_12clk) ||  ((byte_cpt >= 18) && dtr_dummy_16clk) || ((byte_cpt >= 10) && dtr_dummy_8clk) || ((byte_cpt >= 8) && dtr_dummy_6clk)) && crmr_flag)	    //3byte and crmr 
				|| (((DTR_quad_read_3byte && ADS) || DTR_quad_read_4byte) && ( ((byte_cpt >= 16) && dtr_dummy_12clk) ||  ((byte_cpt >= 20) && dtr_dummy_16clk) ||((byte_cpt >= 12) && dtr_dummy_8clk) || ((byte_cpt >=10) && dtr_dummy_6clk)) && (!crmr_flag))   //4byte and !crmr 
				|| (((DTR_quad_read_3byte && ADS) || DTR_quad_read_4byte) && ( ((byte_cpt >= 15) && dtr_dummy_12clk) ||  ((byte_cpt >= 19) && dtr_dummy_16clk) ||((byte_cpt >= 11) && dtr_dummy_8clk) || ((byte_cpt >= 9) && dtr_dummy_6clk)) && crmr_flag));	   //4byte and crm
    
    
    assign DTR_quad_read_with_dlp = ((DTR_quad_read_3byte && (!ADS) && ( ((byte_cpt >= 11) && dtr_dummy_12clk) ||  ((byte_cpt >= 15) && dtr_dummy_16clk) || ((byte_cpt	>= 7) && dtr_dummy_8clk) || ((byte_cpt >= 5) && dtr_dummy_6clk)) && (!crmr_flag))      //3byte and !crm and DLP 
				|| (DTR_quad_read_3byte && (!ADS) && ( ((byte_cpt >= 10) && dtr_dummy_12clk) ||  ((byte_cpt >= 14) && dtr_dummy_16clk) || ((byte_cpt >= 6) && dtr_dummy_8clk) || ((byte_cpt >= 4) && dtr_dummy_6clk)) && crmr_flag)	    //3byte and crmr and DLP 
				|| (((DTR_quad_read_3byte && ADS) || DTR_quad_read_4byte) && ( ((byte_cpt >= 12) && dtr_dummy_12clk) ||  ((byte_cpt >= 16) && dtr_dummy_16clk) ||((byte_cpt >= 8) && dtr_dummy_8clk) || ((byte_cpt >= 6) && dtr_dummy_6clk)) && (!crmr_flag))   //4byte and !crmr and DLP 
				|| (((DTR_quad_read_3byte && ADS) || DTR_quad_read_4byte) && ( ((byte_cpt >= 11) && dtr_dummy_12clk) ||  ((byte_cpt >= 15) && dtr_dummy_16clk) ||((byte_cpt >= 7) && dtr_dummy_8clk) || ((byte_cpt >= 5) && dtr_dummy_6clk)) && crmr_flag)) && DLP;	   //4byte and crmr and DLP 

   //5109 0DH NO DLP assign DTR_single_read_with_dlp = ((DTR_single_read && (!ADS) && (((byte_cpt >= 12) && dtr_dummy_12clk) ||  ((byte_cpt >= 15) && dtr_dummy_16clk) || ((byte_cpt >= 7) && dtr_dummy_8clk) || ((byte_cpt >= 5) && dtr_dummy_6clk))  && qpim)     //3byte and qpim and DLP
   //5109 0DH NO DLP				    || (DTR_single_read && ADS && ( ((byte_cpt >= 12) && dtr_dummy_12clk) ||  ((byte_cpt >= 15) && dtr_dummy_16clk) || ((byte_cpt >= 8) && dtr_dummy_8clk) || ((byte_cpt >= 6) && dtr_dummy_6clk))  && qpim)) && DLP;  //4byte and qpim and DLP 
				   
	assign DTR_single_read_with_dlp = 0;


    //////////////////////erase command,address enable
    assign ser_cmd_addr_enable =  ((byte_cpt == 3) && ser_3byte && (!ADS))
				    || ((byte_cpt == 4) && ((ser_3byte && ADS) || ser_4byte));

    assign ber32_cmd_addr_enable =  ((byte_cpt == 3) && ber32_3byte && (!ADS))
				    || ((byte_cpt == 4) && ((ber32_3byte && ADS) || ber32_4byte));

    assign ber64_cmd_addr_enable =  ((byte_cpt == 3) && ber64_3byte && (!ADS))
				    || ((byte_cpt == 4) && ((ber64_3byte && ADS) || ber64_4byte));

    assign otpers_cmd_addr_enable =  ((byte_cpt == 3) && otpers && (!ADS))
				    || ((byte_cpt == 4) && otpers && ADS);
    



    ///////////////////////individual protect command,address enable
    assign IB_lock_cmd_addr_enable =  (((byte_cpt == 4) || ((byte_cpt == 3) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)) && byte_ok)) && IB_lock && (!ADS))
				    || (((byte_cpt == 5) || ((byte_cpt == 4) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)) && byte_ok)) && IB_lock && ADS);

    assign IB_unlock_cmd_addr_enable =  (((byte_cpt == 4) || ((byte_cpt == 3) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)) && byte_ok)) && IB_unlock && (!ADS))
				    || (((byte_cpt == 5) || ((byte_cpt == 4) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)) && byte_ok)) && IB_unlock && ADS);

    assign IB_read_cmd_addr_enable =  ((byte_cpt == 3) && IB_read && (!ADS))
				    || ((byte_cpt == 4) && IB_read && ADS);
    
    ///////////id read enable
    assign manu_device_id_dual_enable = (manu_device_id_dual && (((byte_cpt >= 4) && (!crmr_flag)) || ((byte_cpt >= 3) && (crmr_flag))));
    assign manu_device_id_quad_enable = (manu_device_id_quad && (((byte_cpt >= 6) && (!crmr_flag)) || ((byte_cpt >= 5) && (crmr_flag))) && !qpim); 


	assign read_sfdp_enable = ( rd_sfdp_3byte && (read_sfdp) && (byte_cpt >= 4) && (!qpim)) || ( !rd_sfdp_3byte &&  !ADS && (read_sfdp) && (byte_cpt >= 4) && (!qpim))|| ( !rd_sfdp_3byte &&  ADS && (read_sfdp) && (byte_cpt >= 5) && (!qpim))||    (!rd_sfdp_3byte && read_sfdp && (((((byte_cpt >= 12) && qpi_dummy_16clk) || ((byte_cpt >= 10) &&	qpi_dummy_12clk) || ((byte_cpt >= 7) && qpi_dummy_6clk))) || (((byte_cpt >= 8) && qpi_dummy_8clk) )) && qpim) ||    ( rd_sfdp_3byte && read_sfdp && (((((byte_cpt >= 11) && qpi_dummy_16clk) || ((byte_cpt >= 9) &&	qpi_dummy_12clk) || ((byte_cpt >= 6) && qpi_dummy_6clk))) || (((byte_cpt >= 7) && qpi_dummy_8clk) )) && qpim)     ;


    initial
   begin
      ////////////////////////////////////////////
      // Initialization of the internal variables
      ////////////////////////////////////////////
     
    SFDP_ARRAY[8'h00] = 8'h53;
    SFDP_ARRAY[8'h01] = 8'h46;
    SFDP_ARRAY[8'h02] = 8'h44;
    SFDP_ARRAY[8'h03] = 8'h50;
    SFDP_ARRAY[8'h04] = 8'h06;
    SFDP_ARRAY[8'h05] = 8'h01;
    SFDP_ARRAY[8'h06] = 8'h02;
    SFDP_ARRAY[8'h07] = 8'hFF;
    SFDP_ARRAY[8'h08] = 8'h00;
    SFDP_ARRAY[8'h09] = 8'h06;
    SFDP_ARRAY[8'h0A] = 8'h01;
    SFDP_ARRAY[8'h0B] = 8'h10;
    SFDP_ARRAY[8'h0C] = 8'h30;
    SFDP_ARRAY[8'h0D] = 8'h00;
    SFDP_ARRAY[8'h0E] = 8'h00;
    SFDP_ARRAY[8'h0F] = 8'hFF;
    
    SFDP_ARRAY[8'h10] = 8'h0B;
    SFDP_ARRAY[8'h11] = 8'h00;
    SFDP_ARRAY[8'h12] = 8'h01;
    SFDP_ARRAY[8'h13] = 8'h03;
    SFDP_ARRAY[8'h14] = 8'h90;
    SFDP_ARRAY[8'h15] = 8'h00;
    SFDP_ARRAY[8'h16] = 8'h00;
    SFDP_ARRAY[8'h17] = 8'hFF;
    SFDP_ARRAY[8'h18] = 8'h84;
    SFDP_ARRAY[8'h19] = 8'h00;
    SFDP_ARRAY[8'h1A] = 8'h01;
    SFDP_ARRAY[8'h1B] = 8'h02;
    SFDP_ARRAY[8'h1C] = 8'hC0;
    SFDP_ARRAY[8'h1D] = 8'h00;
    SFDP_ARRAY[8'h1E] = 8'h00;
    SFDP_ARRAY[8'h1F] = 8'hFF;
                     
    SFDP_ARRAY[8'h20] = 8'hFF;
    SFDP_ARRAY[8'h21] = 8'hFF;
    SFDP_ARRAY[8'h22] = 8'hFF;
    SFDP_ARRAY[8'h23] = 8'hFF;
    SFDP_ARRAY[8'h24] = 8'hFF;
    SFDP_ARRAY[8'h25] = 8'hFF;
    SFDP_ARRAY[8'h26] = 8'hFF;
    SFDP_ARRAY[8'h27] = 8'hFF;
    SFDP_ARRAY[8'h28] = 8'hFF;
    SFDP_ARRAY[8'h29] = 8'hFF;
    SFDP_ARRAY[8'h2A] = 8'hFF;
    SFDP_ARRAY[8'h2B] = 8'hFF;
    SFDP_ARRAY[8'h2C] = 8'hFF;
    SFDP_ARRAY[8'h2D] = 8'hFF;
    SFDP_ARRAY[8'h2E] = 8'hFF;
    SFDP_ARRAY[8'h2F] = 8'hFF;
                     
    SFDP_ARRAY[8'h30] = 8'hE5;
    SFDP_ARRAY[8'h31] = 8'h20;
    SFDP_ARRAY[8'h32] = 8'hFB;
    SFDP_ARRAY[8'h33] = 8'hFF;
    SFDP_ARRAY[8'h34] = 8'hFF;
    SFDP_ARRAY[8'h35] = 8'hFF;
    SFDP_ARRAY[8'h36] = 8'hFF;
    SFDP_ARRAY[8'h37] = 8'h1F;
    SFDP_ARRAY[8'h38] = 8'h46;
    SFDP_ARRAY[8'h39] = 8'hEB;
    SFDP_ARRAY[8'h3A] = 8'h08;
    SFDP_ARRAY[8'h3B] = 8'h6B;
    SFDP_ARRAY[8'h3C] = 8'h08;
    SFDP_ARRAY[8'h3D] = 8'h3B;
    SFDP_ARRAY[8'h3E] = 8'h84;
    SFDP_ARRAY[8'h3F] = 8'hBB;
                      
    SFDP_ARRAY[8'h40] = 8'hFE;
    SFDP_ARRAY[8'h41] = 8'hFF;
    SFDP_ARRAY[8'h42] = 8'hFF;
    SFDP_ARRAY[8'h43] = 8'hFF;
    SFDP_ARRAY[8'h44] = 8'hFF;
    SFDP_ARRAY[8'h45] = 8'hFF;
    SFDP_ARRAY[8'h46] = 8'h00;
    SFDP_ARRAY[8'h47] = 8'hFF;
    SFDP_ARRAY[8'h48] = 8'hFF;
    SFDP_ARRAY[8'h49] = 8'hFF;
    SFDP_ARRAY[8'h4A] = 8'h46;
    SFDP_ARRAY[8'h4B] = 8'hEB;
    SFDP_ARRAY[8'h4C] = 8'h0C;
    SFDP_ARRAY[8'h4D] = 8'h20;
    SFDP_ARRAY[8'h4E] = 8'h0F;
    SFDP_ARRAY[8'h4F] = 8'h52;
                      
    SFDP_ARRAY[8'h50] = 8'h10;
    SFDP_ARRAY[8'h51] = 8'hD8;
    SFDP_ARRAY[8'h52] = 8'h00;
    SFDP_ARRAY[8'h53] = 8'hFF;
    SFDP_ARRAY[8'h54] = 8'h1f;
    SFDP_ARRAY[8'h55] = 8'h4a;
    SFDP_ARRAY[8'h56] = 8'hb5;
    SFDP_ARRAY[8'h57] = 8'hFe;
    SFDP_ARRAY[8'h58] = 8'h84;
    SFDP_ARRAY[8'h59] = 8'he3;
    SFDP_ARRAY[8'h5A] = 8'h15;
    SFDP_ARRAY[8'h5B] = 8'h5a;
    SFDP_ARRAY[8'h5C] = 8'ha8;
    SFDP_ARRAY[8'h5D] = 8'h86;
    SFDP_ARRAY[8'h5E] = 8'h38;
    SFDP_ARRAY[8'h5F] = 8'h44;
                      
    SFDP_ARRAY[8'h60] = 8'h7A;
    SFDP_ARRAY[8'h61] = 8'h75;
    SFDP_ARRAY[8'h62] = 8'h7A;
    SFDP_ARRAY[8'h63] = 8'h75;
    SFDP_ARRAY[8'h64] = 8'hf7;
    SFDP_ARRAY[8'h65] = 8'hbd;
    SFDP_ARRAY[8'h66] = 8'hD5;
    SFDP_ARRAY[8'h67] = 8'h5C;
    SFDP_ARRAY[8'h68] = 8'h19;
    SFDP_ARRAY[8'h69] = 8'hb6;
    SFDP_ARRAY[8'h6A] = 8'h4d;
    SFDP_ARRAY[8'h6B] = 8'hff;
    SFDP_ARRAY[8'h6C] = 8'he8;
    SFDP_ARRAY[8'h6D] = 8'h50;
    SFDP_ARRAY[8'h6E] = 8'hf9;
    SFDP_ARRAY[8'h6F] = 8'ha5;
                      
    SFDP_ARRAY[8'h70] = 8'hFF;
    SFDP_ARRAY[8'h71] = 8'hFF;
    SFDP_ARRAY[8'h72] = 8'hFF;
    SFDP_ARRAY[8'h73] = 8'hFF;
    SFDP_ARRAY[8'h74] = 8'hFF;
    SFDP_ARRAY[8'h75] = 8'hFF;
    SFDP_ARRAY[8'h76] = 8'hFF;
    SFDP_ARRAY[8'h77] = 8'hFF;
    SFDP_ARRAY[8'h78] = 8'hFF;
    SFDP_ARRAY[8'h79] = 8'hFF;
    SFDP_ARRAY[8'h7A] = 8'hFF;
    SFDP_ARRAY[8'h7B] = 8'hFF;
    SFDP_ARRAY[8'h7C] = 8'hFF;
    SFDP_ARRAY[8'h7D] = 8'hFF;
    SFDP_ARRAY[8'h7E] = 8'hFF;
    SFDP_ARRAY[8'h7F] = 8'hFF;
                      
    SFDP_ARRAY[8'h80] = 8'hFF;
    SFDP_ARRAY[8'h81] = 8'hFF;
    SFDP_ARRAY[8'h82] = 8'hFF;
    SFDP_ARRAY[8'h83] = 8'hFF;
    SFDP_ARRAY[8'h84] = 8'hFF;
    SFDP_ARRAY[8'h85] = 8'hFF;
    SFDP_ARRAY[8'h86] = 8'hFF;
    SFDP_ARRAY[8'h87] = 8'hFF;
    SFDP_ARRAY[8'h88] = 8'hFF;
    SFDP_ARRAY[8'h89] = 8'hFF;
    SFDP_ARRAY[8'h8A] = 8'hFF;
    SFDP_ARRAY[8'h8B] = 8'hFF;
    SFDP_ARRAY[8'h8C] = 8'hFF;
    SFDP_ARRAY[8'h8D] = 8'hFF;
    SFDP_ARRAY[8'h8E] = 8'hFF;
    SFDP_ARRAY[8'h8F] = 8'hFF;
                      
    SFDP_ARRAY[8'h90] = 8'h00;
    SFDP_ARRAY[8'h91] = 8'h20;
    SFDP_ARRAY[8'h92] = 8'h50;
    SFDP_ARRAY[8'h93] = 8'h16;
    SFDP_ARRAY[8'h94] = 8'h9F;
    SFDP_ARRAY[8'h95] = 8'hF9;
    SFDP_ARRAY[8'h96] = 8'h77;
    SFDP_ARRAY[8'h97] = 8'h64;
    SFDP_ARRAY[8'h98] = 8'hD9;
    SFDP_ARRAY[8'h99] = 8'hE8;
    SFDP_ARRAY[8'h9A] = 8'hFF;
    SFDP_ARRAY[8'h9B] = 8'hFF;
    SFDP_ARRAY[8'h9C] = 8'hFF;
    SFDP_ARRAY[8'h9D] = 8'hFF;
    SFDP_ARRAY[8'h9E] = 8'hFF;
    SFDP_ARRAY[8'h9F] = 8'hFF;
                      
    SFDP_ARRAY[8'hA0] = 8'hFF;
    SFDP_ARRAY[8'hA1] = 8'hFF;
    SFDP_ARRAY[8'hA2] = 8'hFF;
    SFDP_ARRAY[8'hA3] = 8'hFF;
    SFDP_ARRAY[8'hA4] = 8'hFF;
    SFDP_ARRAY[8'hA5] = 8'hFF;
    SFDP_ARRAY[8'hA6] = 8'hFF;
    SFDP_ARRAY[8'hA7] = 8'hFF;
    SFDP_ARRAY[8'hA8] = 8'hFF;
    SFDP_ARRAY[8'hA9] = 8'hFF;
    SFDP_ARRAY[8'hAA] = 8'hFF;
    SFDP_ARRAY[8'hAB] = 8'hFF;
    SFDP_ARRAY[8'hAC] = 8'hFF;
    SFDP_ARRAY[8'hAD] = 8'hFF;
    SFDP_ARRAY[8'hAE] = 8'hFF;
    SFDP_ARRAY[8'hAF] = 8'hFF;
                      
    SFDP_ARRAY[8'hB0] = 8'hFF;
    SFDP_ARRAY[8'hB1] = 8'hFF;
    SFDP_ARRAY[8'hB2] = 8'hFF;
    SFDP_ARRAY[8'hB3] = 8'hFF;
    SFDP_ARRAY[8'hB4] = 8'hFF;
    SFDP_ARRAY[8'hB5] = 8'hFF;
    SFDP_ARRAY[8'hB6] = 8'hFF;
    SFDP_ARRAY[8'hB7] = 8'hFF;
    SFDP_ARRAY[8'hB8] = 8'hFF;
    SFDP_ARRAY[8'hB9] = 8'hFF;
    SFDP_ARRAY[8'hBA] = 8'hFF;
    SFDP_ARRAY[8'hBB] = 8'hFF;
    SFDP_ARRAY[8'hBC] = 8'hFF;
    SFDP_ARRAY[8'hBD] = 8'hFF;
    SFDP_ARRAY[8'hBE] = 8'hFF;
    SFDP_ARRAY[8'hBF] = 8'hFF;
                      
    SFDP_ARRAY[8'hC0] = 8'hFF;
    SFDP_ARRAY[8'hC1] = 8'h8F;
    SFDP_ARRAY[8'hC2] = 8'hF0;
    SFDP_ARRAY[8'hC3] = 8'hFF;
    SFDP_ARRAY[8'hC4] = 8'h21;
    SFDP_ARRAY[8'hC5] = 8'h5C;
    SFDP_ARRAY[8'hC6] = 8'hDC;
    SFDP_ARRAY[8'hC7] = 8'hFF;
    SFDP_ARRAY[8'hC8] = 8'hFF;
    SFDP_ARRAY[8'hC9] = 8'hFF;
    SFDP_ARRAY[8'hCA] = 8'hFF;
    SFDP_ARRAY[8'hCB] = 8'hFF;
    SFDP_ARRAY[8'hCC] = 8'hFF;
    SFDP_ARRAY[8'hCD] = 8'hFF;
    SFDP_ARRAY[8'hCE] = 8'hFF;
    SFDP_ARRAY[8'hCF] = 8'hFF;

    SFDP_ARRAY[8'hD0] = 8'hFF;
    SFDP_ARRAY[8'hD1] = 8'hFF;
    SFDP_ARRAY[8'hD2] = 8'hFF;
    SFDP_ARRAY[8'hD3] = 8'hFF;
    SFDP_ARRAY[8'hD4] = 8'hFF;
    SFDP_ARRAY[8'hD5] = 8'hFF;
    SFDP_ARRAY[8'hD6] = 8'hFF;
    SFDP_ARRAY[8'hD7] = 8'hFF;
    SFDP_ARRAY[8'hD8] = 8'hFF;
    SFDP_ARRAY[8'hD9] = 8'hFF;
    SFDP_ARRAY[8'hDA] = 8'hFF;
    SFDP_ARRAY[8'hDB] = 8'hFF;
    SFDP_ARRAY[8'hDC] = 8'hFF;
    SFDP_ARRAY[8'hDD] = 8'hFF;
    SFDP_ARRAY[8'hDE] = 8'hFF;
    SFDP_ARRAY[8'hDF] = 8'hFF;

    SFDP_ARRAY[8'hE0] = 8'hFF;
    SFDP_ARRAY[8'hE1] = 8'hFF;
    SFDP_ARRAY[8'hE2] = 8'hFF;
    SFDP_ARRAY[8'hE3] = 8'hFF;
    SFDP_ARRAY[8'hE4] = 8'hFF;
    SFDP_ARRAY[8'hE5] = 8'hFF;
    SFDP_ARRAY[8'hE6] = 8'hFF;
    SFDP_ARRAY[8'hE7] = 8'hFF;
    SFDP_ARRAY[8'hE8] = 8'hFF;
    SFDP_ARRAY[8'hE9] = 8'hFF;
    SFDP_ARRAY[8'hEA] = 8'hFF;
    SFDP_ARRAY[8'hEB] = 8'hFF;
    SFDP_ARRAY[8'hEC] = 8'hFF;
    SFDP_ARRAY[8'hED] = 8'hFF;
    SFDP_ARRAY[8'hEE] = 8'hFF;
    SFDP_ARRAY[8'hEF] = 8'hFF;

    SFDP_ARRAY[8'hF0] = 8'hFF;
    SFDP_ARRAY[8'hF1] = 8'hFF;
    SFDP_ARRAY[8'hF2] = 8'hFF;
    SFDP_ARRAY[8'hF3] = 8'hFF;
    SFDP_ARRAY[8'hF4] = 8'hFF;
    SFDP_ARRAY[8'hF5] = 8'hFF;
    SFDP_ARRAY[8'hF6] = 8'hFF;
    SFDP_ARRAY[8'hF7] = 8'hFF;
    SFDP_ARRAY[8'hF8] = 8'hFF;
    SFDP_ARRAY[8'hF9] = 8'hFF;
    SFDP_ARRAY[8'hFA] = 8'hFF;
    SFDP_ARRAY[8'hFB] = 8'hFF;
    SFDP_ARRAY[8'hFC] = 8'hFF;
    SFDP_ARRAY[8'hFD] = 8'hFF;
    SFDP_ARRAY[8'hFE] = 8'hFF;
    SFDP_ARRAY[8'hFF] = 8'hFF;

                          
                         
    
      address_IB_lock = 0;
      crm_bit        = 8'h00;
      only_rdsr      = `FALSE;
      only_suspend   = `FALSE;
      select_ok      = `FALSE;
      raz            = `TRUE;
      byte_ok        = `FALSE;
      byte_ok_rst        = `FALSE;
      
      cpt         = 0;
      cpt_rst         = 0;
      cpt_rst_delay = 0;
      byte_cpt    = 0;
      byte_cpt_rst    = 0;

      data_to_write  = 8'bxxxxxxxx;
      data_latch     = 8'bxxxxxxxx;

      read_data_request <= `FALSE;
      write_data_request <= `FALSE;
      
      wren          = `FALSE;
      reset_66h          = `FALSE;
      reset_99h          = `FALSE;
      reset_enable    = `FALSE;
      SW_RST          = `FALSE;
      HW_RST          = `FALSE;
      vwsr_enable     = `FALSE;
      vwsr          = `FALSE;
      wrdi          = `FALSE;
      rdsr_l        = `FALSE; 
      rdsr_m        = `FALSE;
      rdsr_h        = `FALSE;  
      rd_ex_addr    = `FALSE;   //2008
      wr_ex_addr    = `FALSE;  
      rd_configuration_reg = `FALSE;//5109 cmlin
	  wr_configuration_reg = `FALSE;//5109 cmlin

	  
      read_data_3byte   = `FALSE;
      read_data_4byte   = `FALSE;

      fast_read_3byte   = `FALSE;
      fast_read_4byte   = `FALSE;

      DTR_single_read = `FALSE;
      DTR_dual_read = `FALSE;
      DTR_quad_read_3byte = `FALSE;
      DTR_quad_read_4byte = `FALSE;

      read_sfdp     = `FALSE;
      read_uid     = `FALSE;
      
      dofr_3byte        = `FALSE;   
      dofr_4byte        = `FALSE;   
      
      diofr_3byte       = `FALSE;
      diofr_4byte       = `FALSE;
      
      qofr_3byte        = `FALSE;
      qofr_4byte        = `FALSE;

      qiofr_3byte       = `FALSE;
      qiofr_4byte       = `FALSE;

      qiowfr      = `FALSE;
      otprd       = `FALSE;  
      manu_device_id_dual       = `FALSE;
      manu_device_id_quad       = `FALSE;
      
      DTR_dual_read_crm_read  = `FALSE;
      DTR_quad_read_crm_read  = `FALSE;
      
      diofr_crm_flag  = `FALSE;
      qiofr_crm_flag  = `FALSE;
      DTR_dual_read_crm_flag  = `FALSE;
      DTR_quad_read_crm_flag  = `FALSE;
      qiowfr_crm_flag = `FALSE;
      manu_device_id_dual_crm_flag  = `FALSE;
      manu_device_id_quad_crm_flag  = `FALSE;
      crmr        = `FALSE;
      crmr_flag   = `FALSE;
      ers_suspend_flag   = `FALSE;
      pgm_suspend_flag   = `FALSE;


      qpim        = `FALSE;
      wrapset     = `FALSE;
      wrap_8byte  = `FALSE; 
      wrap_16byte  = `TRUE ; 
      wrap_32byte  = `FALSE; 
      wrap_64byte  = `FALSE; 

      set_read_para       = `FALSE;
      qpi_wrap_8byte  = `FALSE; 
      qpi_wrap_16byte  = `FALSE ; 
      qpi_wrap_32byte  = `FALSE; 
      qpi_wrap_64byte  = `FALSE; 
      qpi_dummy_4clk   = `FALSE;
      qpi_dummy_6clk   = `FALSE;
      qpi_dummy_8clk   = `TRUE;
      qpi_dummy_12clk   = `FALSE;
      qpi_dummy_16clk   = `FALSE;
      pp_3byte              = `FALSE;
      pp_4byte	    = `FALSE;
      quadpgm_3byte         = `FALSE;   
      quadpgm_4byte         = `FALSE;   
      
      ex_quadpgm_3byte     =	`FALSE;
      ex_quadpgm_4byte     =	`FALSE;

      otppgm          = `FALSE;
      otpers          = `FALSE;      
      ser_3byte            = `FALSE;
      ser_4byte            = `FALSE;

      ber32_3byte         = `FALSE;
      ber32_4byte         = `FALSE;

      ber64_3byte         = `FALSE;
      ber64_4byte         = `FALSE;
        
      cer         = `FALSE;
      suspend_pp  = `FALSE;
      suspend_quadpgm  = `FALSE;  //new add cmd suspend 
      suspend_ex_quadpgm	=   `FALSE;
      suspend_otppgm  = `FALSE;      
      suspend_otpers  = `FALSE;      
            
      suspend_ser = `FALSE;
      suspend_ber32 = `FALSE;
      suspend_ber64 = `FALSE;

      rdid        = `FALSE;
      mid         = `FALSE;       
      uniqueid         = `FALSE;       
      suspend     = `FALSE;
      resume      = `FALSE;
      rfdp        = `FALSE;   
      rfdpid      = `FALSE;  
      dpd         = `FALSE;  
      dpd_enable  = `FALSE;  
      
      q_bis          = 1'bz;
      d_bis          = 1'b1;
      wp_bis         = 1'b1;
      hold_bis       = 1'b1;


     

      ex_addr_latch = 8'h0;
      extended_addr_reg = 8'h0;  //2008

	  configuration_latch= 8'hc1;//5109 cmlin 
	  configuration_reg= 8'hc1;//5109 cmlin

      hold_cond   = `FALSE;
      write_op    = `FALSE;
      read_op     = `FALSE;

      clear_sr_flags = `FALSE;           //2008
      inhib_clear_sr_flags = `FALSE;
     
    enable_4byte_mode = `FALSE;
    inhib_enable_4byte_mode = `FALSE;

    disable_4byte_mode = `FALSE;
    inhib_disable_4byte_mode = `FALSE;

      inhib_wren  = `FALSE;
      inhib_reset_66h  = `FALSE;
      inhib_reset_99h  = `FALSE;
      inhib_wrdi  = `FALSE;
      inhib_rdsr  = `FALSE;
    
    inhib_rd_ex_addr	=   `FALSE;   //2008
    inhib_wr_ex_addr	=   `FALSE;

      inhib_read  = `FALSE;
      
      inhib_crmr  = `FALSE;
      inhib_wrap  = `FALSE;
      inhib_set_read_para  = `FALSE;
      
      inhib_pp    = `FALSE;
      inhib_ber32    = `FALSE;
      inhib_ber64    = `FALSE;

      inhib_cer    = `FALSE;
      
      inhib_quadpgm   = `FALSE;        //new add cmd inhib
      inhib_ex_quadpgm = `FALSE;

      inhib_otppgm    = `FALSE;      
      inhib_otpers    = `FALSE;      
      inhib_ser     = `FALSE;
      inhib_wrsr    = `FALSE;  
      QE            = `FALSE;  
      LC0           = `FALSE; 
      LC1	    = `FALSE;
	  CRC0    = `FALSE;
	  CRC1    = `FALSE;
      LB1           = `FALSE;   //qpi added
      LB2           = `FALSE;   //qpi added
      LB3           = `FALSE;   //qpi added
      T_B           = `FALSE;
      HOLD_reset    = `FALSE;   //new added
      inhib_HOLD_reset    = `FALSE;   //new added
      WPS                       = `FALSE;   //new added
      SUS1      = `FALSE;
      SUS2      = `FALSE;

      ADP	=   1'b1;  //2008 initialize with ADP = 1
      
      ADS	=    1'b1;

      register_bis_latch    = 24'b00010000_00000001_00000000; 
      status_register  = 24'b00010000_00000001_00000000;

	  configuration_latch  = 8'hc1;
	  configuration_reg  = 8'hc1;
      EE        =   `FALSE;
      PE	=   `FALSE;

      inhib_rdid  = `FALSE;
      inhib_mid   = `FALSE;    
      inhib_uniqueid   = `FALSE;    
      inhib_rfdpid  = `FALSE;  
      inhib_manu_device_id_dual   = `FALSE;    
      inhib_manu_device_id_quad   = `FALSE;    
      
      inhib_dpd   = `FALSE;    
      inhib_rfdp  = `FALSE;  
      
      inhib_suspend  = `FALSE;
      inhib_resume   = `FALSE;
    add_pp_enable  = `FALSE;

      read_enable    = `FALSE;
      erase_enable    = `FALSE;
      write_enable    = `FALSE;

      dlp_read_enable = `FALSE;


      pp_enable      = `FALSE;
      quadpgm_enable     = `FALSE;  //new add cmd enable 
      ex_quadpgm_enable = `FALSE;

      otppgm_enable      = `FALSE;      
      
      cer_enable         = `FALSE;
      ber32_enable       = `FALSE;
      ber64_enable       = `FALSE;

      
      ser_enable      = `FALSE;
      otpers_enable   = `FALSE;     
      suspend_enable  = `FALSE;
      resume_enable   = `FALSE;
      rdsr_enable     = `FALSE;
      wrsr_l          = `FALSE;
      wrsr_m          = `FALSE;
      wrsr_h          = `FALSE;
      wrsr_enable     = `FALSE;

      rd_ex_addr_enable = `FALSE;
      wr_ex_addr_enable = `FALSE; 
      wr_ex_addr    =	`FALSE;  
	  wr_configuration_reg = `FALSE;//5109 cmlin
	  wr_config_reg_enable = `FALSE;//5109 cmlin

      rdid_enable     = `FALSE;
      oen             = `FALSE; 
      bpbit_reg       = `FALSE;  // bpbit_reg
      wrsr_protect    = `FALSE;
      wrap_enable     = `FALSE;

      count_enable   = `FALSE;
      data           = 8'b00000000;
      data_rst           = 8'b00000000;

      // decode process
      bit_index      = 8'b00000000;
      bit_register   = 8'b00000000;


      wrap_bit    = 8'b0001_0000;        //W4=1
      qpi_para_bit        = 8'b0000_0100;      // P2=1,default
      reset_crmr  = 1'b0;
      reset_wel   = 1'b0;
      wel         = 1'b0;
      wip         = 1'b0;
      //cnt_clk     = 1'b0;

      
      dq_di = 1'bz ;
      dq_do = 1'bz ;
      dq_wp = 1'bz ;
      dq_hold = 1'bz ;
      manufacturerID = `manufacturerID;
      memtype = `memtype;
      density = `density;
      electronic_signature = `SIGNATRUE; 
      
      /////////////////////////////////////////////////////////
      id = {manufacturerID,memtype,density};            //9fh
      did0 = { manufacturerID, electronic_signature };  //90h
      did1 = { electronic_signature, manufacturerID };  //90h
      resdid = electronic_signature;    //abh
      bit_id = 5'b00000;
      //////////////////////////////////////////////////////////

   pps_time_add         =0;
   otppgms_time_add     =0;   
   otperss_time_add     =0;
   quadpgms_time_add    =0;         
   ex_quadpgms_time_add =0;

   ser_time_add         =0;
   ber32_time_add       =0;
   ber64_time_add       =0;

        inhib_IB_lock = `FALSE;    //new added
        IB_lock = `FALSE;          //new added

        inhib_IB_unlock = `FALSE;    //new added
        IB_unlock = `FALSE;          //new added

        inhib_IB_read = `FALSE;    //new added
        IB_read = `FALSE;          //new added
        
        inhib_GB_lock = `FALSE;    //new added
        GB_lock = `FALSE;          //new added

        inhib_GB_unlock = `FALSE;    //new added
        GB_unlock = `FALSE;          //new added

        IB_lock_enable   = `FALSE;
        IB_unlock_enable = `FALSE;
        IB_read_enable   = `FALSE;
        GB_lock_enable   = `FALSE;
        GB_unlock_enable = `FALSE;

        //IB_lock_reg = `TRUE;

        IS_bottom_sel = 16'hffff;
        IS_top_sel    = 16'hffff;
 
        lock_sel      = {(`BLOCK_NUM-1){1'b1}};
        lock_enable   = {(`BLOCK_NUM-1){1'b0}};
        data_lock_en = 8'b0;

        wps_protect_sel = 1'b1;

        wps_protect_bottom_sel = 1'b1;
        wps_protect_top_sel = 1'b1;

	factory_mode = `FALSE;

	tSE = 40;
	tBE1 = 150;
	tBE2 = 220;
	tCE = 70000;
	tPP = 250000;

	
	bit_index_dlp = 3'b0;
	dlp_done = `FALSE;

	
  end // initial
   
 
	always @(negedge wrsr_enable)     
   	begin
		if($time != 0) 
		begin
	    	status_register[(`NB_BIT_DATA*3-1):0] =  register_bis_latch;
		end
   	end 

	always @(negedge wr_config_reg_enable)     
   	begin
		if($time != 0) 
		begin
	    	configuration_reg[(`NB_BIT_DATA-1):0] =  configuration_latch  ;
		end
   	end


	always@(select_ok)
	begin
 		if(!select_ok & vwsr_enable)                       //***** volatile write status register*****//
		begin
			if (((((byte_cpt == 3) && (cpt == 0)) || ((byte_cpt == 2) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)))) && byte_ok && wrsr_l) 
    			|| ((((byte_cpt == 2) && (cpt == 0)) || ((byte_cpt == 1) && (((cpt == 7) && !qpim) || ((cpt ==1) && qpim)))) && byte_ok && (wrsr_l || wrsr_m || wrsr_h))) 
			begin
    			if($time != 0) 
    			begin
					status_register[(`NB_BIT_DATA*3-1):2] =  register_bis_latch[(`NB_BIT_DATA*3-1):2];
    			end
			end
			else if(wr_configuration_reg) begin//cmlin vol wr configuration register
				if($time != 0) 
    			begin
					configuration_reg[(`NB_BIT_DATA-1):0] =  configuration_latch[(`NB_BIT_DATA-1):0];
    			end

			end
			wel <= 1'b0;
 		end 
	end

    always @(posedge wr_ex_addr_enable)     
    begin
        extended_addr_reg[(`NB_BIT_DATA-1):0] =  {3'h0,ex_addr_latch[4:0]};
    end

   //-----------------------------------------------------------
   // This process generates the Hold condition when it is valid
   always 
   begin : hold_com
      @(hold or s); 
      begin
      if ((hold == 1'b0) && (s == 1'b0 ) && (!QE))
      begin
         if (c == 1'b0)
         begin
            hold_cond <= `TRUE;
            if ($time != 0) $display("%t:  NOTE: COMMUNICATION PAUSED",$realtime); 
         end
         else
         begin
            @(c or hold); 
            if (c == 1'b0)
            begin
               hold_cond <= `TRUE;
               if ($time != 0) $display("%t:  NOTE: COMMUNICATION PAUSED",$realtime); 
            end 
         end 
      end
      else if (hold == 1'b1 &&  (!QE) )
      begin
         if (c == 1'b0)
         begin
            hold_cond <= `FALSE;
         //   if ($time != 0) $display("%t:  NOTE: COMMUNICATION (RE)STARTED",$realtime); 
         end
         else
         begin
            @(c or hold); 
            if (c == 1'b0)
            begin
               hold_cond <= `FALSE;
          //     if ($time != 0) $display("%t:  NOTE: COMMUNICATION (RE)STARTED",$realtime); 
            end 
         end 
      end
        if(s==1'b1)
        begin
                 hold_cond <= `FALSE;
        end
      end
   end 

   //----------------------------------------------------------------------
   // This process inhibits the internal clock when hold condition is valid
   always 
   begin : horloge
      @(c); 
      begin
      if (!hold_cond)
      begin
         c_int <= c ; 
      end
      else
      begin
         c_int <= 1'b0 ; 
      end 
      end
   end 

   //---------------------------------------------------------------
   // This process inhibits data output when hold condition is valid
   always @(posedge hold_cond) dq_do <= #`THLQZ 1'bz ;
   
   always @(negedge hold_cond) dq_do <= #`THHQX q_bis ; 
   
   always @ (q_bis or s)
      if (!hold_cond)
      begin
         dq_do <= q_bis ; 
      end

  always @ (d_bis or s)    
      if (!hold_cond)
      begin
         dq_di <= d_bis ; 
      end
        
 always @ (wp_bis or s)
      if (!hold_cond)
      begin
         dq_wp <= wp_bis ; 
      end
      
always @ (hold_bis or s)
      if (!hold_cond)
      begin
         dq_hold <= hold_bis ; 
      end
      
 
   //----------------------------------------------------------
   // This process increments 2 counters:  one bit counter (cpt)
   // one byte counter (byte_cpt)
   always 
   begin : count_bit_raz
         @(raz); 
         begin
            if (raz || !select_ok)
            begin
               cpt <= 0 ; 
               cpt_rst <= 0 ;
               byte_cpt <= 0 ; 
               byte_cpt_rst <= 0 ; 
               count_enable <= `FALSE; 
            end
         end
   end 


   always @(posedge select_ok) 
   begin : count_bit_raz_delay
         begin
            cpt_rst_delay <= 0;
         end
   end

 
  always @(negedge s) begin
        if((DTR_quad_read || DTR_dual_read)&c_int) begin
                @(negedge c_int);
                #1;
                count_enable = `TRUE;
        end
        else
                count_enable = `TRUE;
  end

   always 
   begin : count_bit
      @(negedge c_int);
      begin
         if (!raz && select_ok && !(DTR_single_read || DTR_dual_read || DTR_quad_read ))
         begin
            if (count_enable) 
            begin
                if(~(((diofr || (dofr && read_enable) || manu_device_id_dual) && (cpt ==3) && ~qpim)  || ((qiofr || (qofr && read_enable) || manu_device_id_quad || qiowfr || wrapset) && (cpt ==1) && ~qpim) 
		|| (quadpgm_3byte && (!ADS) && (byte_cpt >= 4 ) && (cpt ==1) && ~qpim)                        //3byte mode  
		|| (((quadpgm_3byte && ADS) || quadpgm_4byte) && (byte_cpt >= 5 ) && (cpt ==1) && ~qpim)   //4byte mode
		|| (ex_quadpgm_3byte && (!ADS) && (byte_cpt >= 1) && (cpt == 1) && ~qpim) 
		|| (((ex_quadpgm_3byte && ADS) || ex_quadpgm_4byte) && (byte_cpt >= 1) && (cpt == 1) && ~qpim)
		|| (qpim && (cpt ==1)))  	|| ( (cmd_4byte  ||  ADS) && diofr && lc_dummy_6clk && byte_cpt==5&& (!crmr_flag)    ||   (cmd_4byte  ||  ADS) &&diofr &&
		lc_dummy_6clk && byte_cpt==4 &&crmr_flag) 	||  (!cmd_4byte  &&  !ADS) && diofr && lc_dummy_6clk && byte_cpt==4 && (!crmr_flag)    ||   (!cmd_4byte  &&  !ADS)
		&&diofr && lc_dummy_6clk && byte_cpt==3 && crmr_flag)
               cpt <= cpt + 1 ;

            end 
         end
          
      end
   end 

always 
   begin : DTR_single_count_bit_initial
      @(negedge c_int);//2104 DTR
      begin
         if (!raz && select_ok && !qpim)
         begin
            if (count_enable) 
            begin
                if((DTR_single_read || DTR_dual_read || DTR_quad_read )&& (byte_cpt_rst == 1))
                        begin
              cpt <= 7 ;  
                        end
            end 
         end          
      end
          end



   always 
   begin : DTR_count_bit
      @( c_int );//2104 DTR
      begin
         if (select_ok &&(DTR_single_read  || DTR_dual_read || DTR_quad_read) )
         begin
            if (count_enable) 
            begin
            if(~((DTR_dual_read && (cpt ==3) && ~qpim)  || ((DTR_quad_read) && (cpt ==1) && ~qpim) || (qpim && (cpt==1))))
            begin
               cpt <= cpt + 1 ;
            end

            if(DTR_single_read && (byte_cpt_rst >0)&& qpim)
            begin
               cpt <= cpt + 1 ;
            end
            end 
         end
      end
   end 

   always @(negedge c_int)
   begin
      if (!(DTR_single_read || DTR_dual_read || DTR_quad_read))
          begin
      if (byte_ok) 
         byte_cpt <= (byte_cpt + 1) ; 
      if (byte_ok_rst) 
         byte_cpt_rst <= (byte_cpt_rst + 1) ; 
          end 
   end 

   always @(posedge c_int or negedge c_int) //2104 DTR added
   begin
      if ((DTR_single_read || DTR_dual_read || DTR_quad_read) &&!qpim)
          begin
          #1;
      if (byte_ok) 
         byte_cpt <= (byte_cpt + 1) ; 
      if (byte_ok_rst) 
         byte_cpt_rst <= (byte_cpt_rst + 1) ; 
          end 
   end

   always @(posedge c_int or negedge c_int) //2104 DTR added
   begin
      if ((DTR_single_read || DTR_quad_read) && qpim)
          begin
          #1;
      if (byte_ok) 
         byte_cpt <= (byte_cpt + 1) ; 
      if (byte_ok_rst) 
         byte_cpt_rst <= (byte_cpt_rst + 1) ; 
          end 
   end

   always @(negedge c_int or posedge c_int) //2104 DTR added
   begin
      if (DTR_single_read || DTR_dual_read || DTR_quad_read)
          begin
         if (byte_ok_rst) 
                 begin
         byte_cpt_rst <= (byte_cpt_rst + 1) ; 
                 end
          end 
   end




   //---------------------------------------------------------------------
   // This process latches every byte of data received and returns byte_ok 
   always 
   begin : data_in_reset

      @(select_ok); 
      begin
         if (!select_ok)
         begin
                raz <= `TRUE ; 
                byte_ok <=  `FALSE ; 
                byte_ok_rst <=  `FALSE ; 
                data_latch <= 8'b00000000 ; 
                data = 8'b00000000;
                vwsr <= `FALSE ; 
         end
      end
   end
   
//-------------reset data input-------------------------


always @(posedge c_int) 
begin
        if (select_ok && (!qpim))     //CS=0  spi mode
        begin
          if(byte_cpt_rst == 0)
           begin
                raz <= `FALSE ;
                if (cpt_rst == 0)
                begin
                   byte_ok_rst <= `FALSE ; 
                end 
                data_rst[7 - cpt_rst] = tmp_di; 
                if (cpt_rst == 7)
                begin
                   byte_ok_rst <= `TRUE ; 
                end 
            end
	end

        if (select_ok && qpim )   //CS=0          qpi mode
        begin
          if(byte_cpt_rst==0)
           begin
                raz <= `FALSE ;
                if (cpt_rst == 0)
                begin
                   byte_ok_rst <= `FALSE ; 
                end 
                data_rst[7 - cpt_rst * 4 ] = tmp_hold; 
                data_rst[6 - cpt_rst * 4 ] = tmp_wp; 
                data_rst[5 - cpt_rst * 4 ] = tmp_do; 
                data_rst[4 - cpt_rst * 4 ] = tmp_di; 
                if (cpt_rst == 1)
                begin
                   byte_ok_rst <= `TRUE ; 
                end 
           end
        end
end

///////////////////////////////////////
   always 
   begin : data_in     

      @(posedge c_int); 
      begin
      if (select_ok && (!(DTR_single_read || DTR_dual_read || DTR_quad_read) )) //CS=0
      begin
         
         if((byte_cpt==0) && (crm_bit[5:4] !== 2'h2) && (qpim==0))    //cmd data input
         begin
                raz <= `FALSE ;
                if (cpt == 0)
                begin
                   byte_ok <= `FALSE ; 
                end 
                data[7 - cpt] = tmp_di; 
                if (cpt == 7)
                begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data; 
                end 
                else data_latch <= 8'bxxxxxxxx ;
         end 
 
         else if((byte_cpt==0) && (crm_bit[5:4] !== 2'h2) && (qpim==1))    //qpi cmd data input
         begin
                raz <= `FALSE ;
                if (cpt == 0)
                begin
                   byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 4 ] = tmp_hold; 
                data[6 - cpt * 4 ] = tmp_wp; 
                data[5 - cpt * 4 ] = tmp_do; 
                data[4 - cpt * 4 ] = tmp_di; 

                if (cpt == 1)
                begin
                 byte_ok <= `TRUE ; 
                data_latch <= data ; 
                end 
                else data_latch <= 8'bxxxxxxxx;

         end 

         else if ((byte_cpt==0) && (crm_bit[5:4] == 2'h2) && (diofr || manu_device_id_dual ) && (qpim==0))    //continuous read mode
         begin
                raz <= `FALSE ;
                if (cpt == 0)
                 begin
                byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 2] = tmp_do; 
                data[6 - cpt * 2] = tmp_di; 
                
         
                if (cpt == 3)
                begin
                byte_ok <= `TRUE ; 
                data_latch <= data ; 
                end 
                
                else data_latch <= 8'bxxxxxxxx ;
         end 

         else if ((byte_cpt==0) && (crm_bit[5:4] == 2'h2) && (qiofr || qiowfr || manu_device_id_quad) && (qpim==0))    //continuous read mode
         begin
                raz <= `FALSE ;
                if (cpt == 0)
                begin
                byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 4 ] = tmp_hold; 
                data[6 - cpt * 4 ] = tmp_wp; 
                data[5 - cpt * 4 ] = tmp_do; 
                data[4 - cpt * 4 ] = tmp_di; 
                
                
                if (cpt == 1)
                begin
                    byte_ok <= `TRUE ; 
                data_latch <= data ; 
                end 
                
                else data_latch <= 8'bxxxxxxxx ;
                
         end
       
         else if ((byte_cpt==0) && (crm_bit[5:4] == 2'h2) && qiofr && (qpim==1))    //qpi continuous read mode
         begin
                raz <= `FALSE ;
                if (cpt == 0)
                begin
                byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 4 ] = tmp_hold; 
                data[6 - cpt * 4 ] = tmp_wp; 
                data[5 - cpt * 4 ] = tmp_do; 
                data[4 - cpt * 4 ] = tmp_di; 
                                
                if (cpt == 1)
                begin
                 byte_ok <= `TRUE ; 
                data_latch <= data ; 
                end 
                
                else data_latch <= 8'bxxxxxxxx;
                
         end


       else if (byte_cpt >= 1)      //adress data input
       begin
           raz <= `FALSE ;

         if((read_data || fast_read  || dofr || qofr ||otprd || read_sfdp) & ~qpim)
         begin
                if (cpt == 0)
                   begin
                   byte_ok <= `FALSE ; 
                   end 
                data[7 - cpt] = tmp_di; 
                  if (cpt == 7)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                   end 
                else data_latch <= 8'bxxxxxxxx;
         end 
                  
         else if ((diofr || manu_device_id_dual) & ~qpim)
         begin
		
		 		
                if (cpt == 0)
                   begin
                   byte_ok <= `FALSE ; 
                   end 


                data[7 - cpt * 2] = tmp_do; 
                data[6 - cpt * 2] = tmp_di; 
               
			   if(  (cmd_4byte  ||  ADS) && lc_dummy_6clk&&byte_cpt==5 && !crmr_flag )
				begin
					if(cpt==5)begin
                   		byte_ok <= `TRUE ; 
                   		data_latch <= data ; 
					end
                end

			  else if(  ( !cmd_4byte && !ADS) && lc_dummy_6clk&&byte_cpt==4 && !crmr_flag )
				begin
					if(cpt==5)begin
                   		byte_ok <= `TRUE ; 
                   		data_latch <= data ; 
					end
                end

			   else if( (cmd_4byte  ||  ADS) && lc_dummy_6clk&&byte_cpt==4 && crmr_flag )
				begin
					if(cpt==5)begin
                   		byte_ok <= `TRUE ; 
                   		data_latch <= data ; 
					end
                end
			    else if( (!cmd_4byte &&  !ADS) && lc_dummy_6clk&&byte_cpt==3 && crmr_flag )
				begin
					if(cpt==5)begin
                   		byte_ok <= `TRUE ; 
                   		data_latch <= data ; 
					end
                end


                else if ((cmd_4byte  ||  ADS) && cpt == 3 &&  lc_dummy_6clk && byte_cpt!==5 && !crmr_flag)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                end

				else if ((!cmd_4byte &&  !ADS) && cpt == 3 &&  lc_dummy_6clk && byte_cpt!==4 && !crmr_flag)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                end


				else if ( (cmd_4byte  ||  ADS) &&  cpt == 3 &&  lc_dummy_6clk && byte_cpt!==4 && crmr_flag)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                end
				else if ( (!cmd_4byte  &&  !ADS) &&  cpt == 3 &&  lc_dummy_6clk && byte_cpt!==3 && crmr_flag)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                end



				else if (cpt == 3)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                    end
				

                else data_latch <= 8'bxxxxxxxx;
         end 
        
         else if ((qiofr || qiowfr || manu_device_id_quad ||wrapset) & ~qpim)
         begin
                if (cpt == 0)
                begin
                   byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 4 ] = tmp_hold; 
                data[6 - cpt * 4 ] = tmp_wp; 
                data[5 - cpt * 4 ] = tmp_do; 
                data[4 - cpt * 4 ] = tmp_di; 
                
                if (cpt == 1)
                begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                end
		else data_latch <= 8'bxxxxxxxx;
        end 
        
         else if (quadpgm & ~qpim)
         begin  
            if(((byte_cpt >=1) && (byte_cpt <=3) && quadpgm_3byte && (!ADS))        //3byte mode
		|| ((byte_cpt >=1) && (byte_cpt <=4) && ((quadpgm_3byte && ADS) || quadpgm_4byte)))   //4byte mode
            begin
                if (cpt == 0)
                begin
                byte_ok <= `FALSE ; 
                end 
                data[7 - cpt] = tmp_di; 
                if (cpt == 7)
                begin
                byte_ok <= `TRUE ; 
                data_latch <= data ; 
                end 
                else data_latch <= 8'bxxxxxxxx;
            end
           
            else if(((byte_cpt > 3) && quadpgm_3byte && (!ADS))     //3byte mode
		    || ((byte_cpt > 4) && ((quadpgm_3byte && ADS) || quadpgm_4byte)))   //4byte mode
            begin
                if (cpt == 0)
                begin
                   data_latch <= 8'bxxxxxxxx;
                   byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 4 ] = tmp_hold; 
                data[6 - cpt * 4 ] = tmp_wp; 
                data[5 - cpt * 4 ] = tmp_do; 
                data[4 - cpt * 4 ] = tmp_di; 
                
                if (cpt == 1)
                begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                end 
            end        
        end 
	

	else if (ex_quadpgm)
         begin  

           if (cpt == 0)
           begin
              data_latch <= 8'bxxxxxxxx;
              byte_ok <= `FALSE ; 
           end 
           data[7 - cpt * 4 ] = tmp_hold; 
           data[6 - cpt * 4 ] = tmp_wp; 
           data[5 - cpt * 4 ] = tmp_do; 
           data[4 - cpt * 4 ] = tmp_di; 
           
           if (cpt == 1)
           begin
              byte_ok <= `TRUE ; 
              data_latch <= data ; 
           end 
        end 
               
        else
        begin
                if(~qpim)
                begin
                        raz <= `FALSE ;
                        if (cpt == 0)
                           begin
                           byte_ok <= `FALSE ; 
                           end 
                        data[7 - cpt] = tmp_di; 
                         if (cpt == 7)
                           begin
                           byte_ok <= `TRUE ; 
                           data_latch <= data ; 
                           end 
                        else data_latch <= 8'bxxxxxxxx;
                end

                else    //qpi mode
                begin
                        raz <= `FALSE ;
                        if (cpt == 0)
                        begin
                           byte_ok <= `FALSE ; 
                        end 

                        data[7 - cpt * 4 ] = tmp_hold; 
                        data[6 - cpt * 4 ] = tmp_wp; 
                        data[5 - cpt * 4 ] = tmp_do; 
                        data[4 - cpt * 4 ] = tmp_di; 
                        
                        if (cpt == 1)
                        begin
                           byte_ok <= `TRUE ; 
                           data_latch <= data ; 
                        end 
                        else data_latch <= 8'bxxxxxxxx;
                end

        end 
        
      end 
     

        
      end 
      end
   end 


always 
   begin : DTR_data_in     

      @(posedge c_int or negedge c_int); 
      begin
      if (select_ok && DTR_single_read )        //CS=0
      begin
          if (qpim==0)//2104 DTR added
         begin
                        raz <= `FALSE ;
                if (cpt == 0)
                   begin
                   byte_ok <= `FALSE ; 
                   end 
                   data[7 - cpt] = tmp_di; 
                  if (cpt == 7)
                   begin
                   byte_ok <= `TRUE ; 
                   data_latch <= data ; 
                   end 
                else data_latch <= 8'bxxxxxxxx;
         end
          end

          if (select_ok && DTR_dual_read )      //CS=0
      begin
          if (qpim==0)//2104 DTR added
         begin
                        raz <= `FALSE ;
                if (cpt == 0)
                   begin
                   byte_ok <= `FALSE ; 
                   end 
                   data[7 - 2*cpt] = tmp_do; 
                           data[6 - 2*cpt] = tmp_di;
                  if (cpt == 3)
                   begin
                                data_latch <= data ;
                        byte_ok <= `TRUE ; 
                   end 
                else data_latch <= 8'bxxxxxxxx;
         end
          end

          if (select_ok && DTR_quad_read )      //CS=0
      begin
                        raz <= `FALSE ;
                if (cpt == 0)
                   begin
                   byte_ok <= `FALSE ; 
                   end 
                    data[7 - cpt * 4 ] = tmp_hold; 
                        data[6 - cpt * 4 ] = tmp_wp; 
                        data[5 - cpt * 4 ] = tmp_do; 
                        data[4 - cpt * 4 ] = tmp_di;
                        if (cpt == 1)
                   begin
                                data_latch <= data ;
                        byte_ok <= `TRUE ; 
                   end 
                else data_latch <= 8'bxxxxxxxx;

          end
          
          end
          
end

always 
        begin :DTR_dual_read_cptchange
        @(posedge c_int or negedge c_int);
        begin
                if(select_ok && DTR_dual_read && (cpt==3))
                begin
                cpt <= 0;
                end
        end
        end

always 
        begin :DTR_quad_read_cptchange
        @(posedge c_int or negedge c_int);
        begin
                if(select_ok && DTR_quad_read && (cpt==1))
                begin
                cpt <= 0;
                end
        end
        end

always 
   begin : DTR_data_in_qpi     

      @(posedge c_int or negedge c_int); 
      begin
      if (select_ok && DTR_single_read )        //CS=0
      begin
                  if (qpim && (byte_cpt_rst >=1))    //qpi cmd data input
            begin
                raz <= `FALSE ;
                if (cpt == 0)
                begin
                   byte_ok <= `FALSE ; 
                end 
                data[7 - cpt * 4 ] = tmp_hold; 
                data[6 - cpt * 4 ] = tmp_wp; 
                data[5 - cpt * 4 ] = tmp_do; 
                data[4 - cpt * 4 ] = tmp_di; 

                if (cpt == 1)
                begin
                    byte_ok <= `TRUE ; 
                data_latch <= data ; 
                end 
            else data_latch <= 8'bxxxxxxxx;
                 end

          end
          end
end


//cpt set to 0   
always @(negedge c_int) 
 begin
      if (select_ok && (diofr || manu_device_id_dual) && ~qpim)
      begin
	    if( (cmd_4byte  ||  ADS) && lc_dummy_6clk&&byte_cpt==5 && !crmr_flag)begin
			if( cpt==5)
				cpt<=0;
		end

		else if( (!cmd_4byte  && !ADS) && lc_dummy_6clk&&byte_cpt==4 && !crmr_flag)begin
			if( cpt==5)
				cpt<=0;
		end



		else if(  (cmd_4byte  ||  ADS) && lc_dummy_6clk&&byte_cpt==4 && crmr_flag)begin
			if( cpt==5)
				cpt<=0;
		end

		else if(  (!cmd_4byte  && !ADS) && lc_dummy_6clk&&byte_cpt==3 && crmr_flag)begin
			if( cpt==5)
				cpt<=0;
		end


        else if(  (cmd_4byte  ||  ADS) && cpt ==3 && lc_dummy_6clk &&byte_cpt !==5 && !crmr_flag)
        	cpt<=0;

		else if(  (!cmd_4byte &&  !ADS) && cpt ==3 && lc_dummy_6clk &&byte_cpt !==4 && !crmr_flag)
        	cpt<=0;

		else if(  (cmd_4byte  ||  ADS) && cpt ==3 && lc_dummy_6clk &&byte_cpt !==4 && crmr_flag)
        	cpt<=0;

		else if(  (!cmd_4byte &&  !ADS) && cpt ==3 && lc_dummy_6clk &&byte_cpt !==3 && crmr_flag)
        	cpt<=0;

		else if(cpt ==3 )begin
        	cpt<=0;
		end
      end
      
      else if (select_ok && ( qiofr || manu_device_id_quad || qiowfr || wrapset ) && ~qpim )
      begin
        if(cpt ==1)
        cpt<=0;     
      end 
      
      else if (select_ok && quadpgm_3byte && (!ADS) && ~qpim)    //3byte mode
      begin
        if(byte_cpt >= 4)
         begin
                if(cpt ==1)
                cpt<=0;     
         end 
      end

      else if (select_ok && ((quadpgm_3byte && ADS) || quadpgm_4byte) && ~qpim)    //4byte mode
      begin
        if(byte_cpt >= 5)
         begin
                if(cpt ==1)
                cpt<=0;     
         end 
      end


      else if(select_ok && ex_quadpgm && ~qpim)
      begin
	if(byte_cpt >= 1)
	begin
	    if(cpt == 1)
	     cpt <=0;
	end
      end

      else if (select_ok && qpim )//qpi added
      begin
        if(cpt ==1)
        cpt<=0;     
      end 
 end
       

//-------------------------------------------------------------
//--------------- ASYNCHRONOUS DECODE PROCESS -----------------
//-------------------------------------------------------------
//-------reset decode-------------------
always 
   begin : reset_decode
      @(byte_ok_rst); 
   begin 
      if (byte_ok_rst == 1'b1)
      begin  
         if (byte_cpt_rst == 0)
         begin
            if (data_rst == 8'b01100110)//66h
            begin

               if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  6699 This Opcode is  decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  reset_66h <= `TRUE ; 
               end 
            end


            else if (data_rst == 8'b10011001)//99h
            begin
               if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  6699 This Opcode is  decoded during deep power down cycle. Cycle",$realtime); 
				  rfdp <= `TRUE ;
				  reset_99h <= `TRUE ;
               end
               else
               begin

                        if(reset_enable)                reset_99h <= `TRUE ;
                        else                    reset_99h <= `FALSE ;
               end 
            end         

        end
        end
        end
end

/////////////////////////////////
//////////////////////////////
//////////////2005 changed ffh//////////
//
always @(posedge select_ok)
begin
    data_rst <= 8'b0000_0000;
end

always @(posedge c_int)
begin
    if(count_enable)
    begin
	cpt_rst <= cpt_rst + 1;
	cpt_rst_delay <= cpt_rst_delay + 1;

    end

end


always @(negedge select_ok) 
begin
        if((((cpt_rst_delay==32'h7) || (cpt_rst_delay==32'h8)) && (!qpim))  ||  (((cpt_rst_delay==32'h1) || (cpt_rst_delay==32'h2)) && (qpim)) )
   begin
               if (data_rst == 8'b11111111)
               begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
                else if ((qpim!=1) && (crmr_flag))
                                 begin
                                  //5109      DTR_dual_read_crm_read = `FALSE;
                                  //5109      DTR_quad_read_crm_read = `FALSE;
                
                                  //5109      diofr_crm_flag  = `FALSE;
                                  //5109      qiofr_crm_flag  = `FALSE;
                                  //5109      DTR_dual_read_crm_flag = `FALSE;
                                  //5109      DTR_quad_read_crm_flag = `FALSE;
                                  //5109      qiowfr_crm_flag = `FALSE;
                                  //5109      manu_device_id_dual_crm_flag  = `FALSE;
                                  //5109      manu_device_id_quad_crm_flag  = `FALSE;
                                  //5109      crmr        = `FALSE;
                                  //5109      crmr_flag   = `FALSE;
                                  //5109      inhib_crmr  = `TRUE;
                                  //5109      crm_bit         = 8'b00000000;
                                  //5109      reset_crmr  = 1'b0;
								  ;
               end 

                                        else if ((qpim==1) && (crmr_flag))
                                                        begin

                
                                    //5109    diofr_crm_flag  = `FALSE;
                                    //5109    qiofr_crm_flag  = `FALSE;
                                    //5109            DTR_dual_read_crm_flag = `FALSE;
                                  //5109      DTR_quad_read_crm_flag = `FALSE;
                                   //5109             qiowfr_crm_flag = `FALSE;
                                   //5109     manu_device_id_dual_crm_flag  = `FALSE;
                                   //5109     manu_device_id_quad_crm_flag  = `FALSE;
                                   //5109     crmr        = `FALSE;
                                   //5109     crmr_flag   = `FALSE;
                                   //5109     inhib_crmr  = `TRUE;
                                   //5109             crm_bit         = 8'b00000000;
                                   //5109     reset_crmr  = 1'b0;
								   ;
               end
                                        else if ((qpim==1) && (QE))
                                                        qpim <= `FALSE ;
            end
                end
        end
                

always @( posedge byte_ok)
   begin : decode
     
    //  @(byte_ok); 
    //  if (byte_ok == 1'b1)
      begin         
         //-----------------------------------------------------------
         //-- op_code decode
         //-----------------------------------------------------------
         
         if ((byte_cpt == 0) || (byte_cpt_rst ==0))
         begin
           if ((data_latch == 8'b00000110) && (!crmr_flag))//06h
            begin
                if(!pgmsp)
                begin
                        if (only_rdsr)
                        begin
                           if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle",$realtime); 
                        end
                        else if ( dpd_enable)
                        begin
                           if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
                        end
                        else
                        begin
                           wren <= `TRUE ; 
                        end 
                end
                else
                begin
                           if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during Program Suspend",$realtime); 
                end
            end

            else if ((data_latch == 8'b01010000) && (!crmr_flag))//50h
            begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  vwsr <= `TRUE ; 
               end 
            end

            else if ((data_latch == 8'b00000100) && (!crmr_flag))//04h
            begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  wrdi <= `TRUE ; 
               end 
            end
            
            else if ((data_latch == 8'b00000101) && (!crmr_flag))//05h 
            begin
              if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  rdsr_l <= `TRUE ; 
               end
            end

            else if ((data_latch == 8'b00110101) && (!crmr_flag)) //35h
            begin
            if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  rdsr_m <= `TRUE ; 
               end
            end

                         else if ((data_latch == 8'b00010101) && (!crmr_flag)) //15h
            begin
            if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  rdsr_h <= `TRUE ; 
               end
            end

           
           
            else if ((data_latch == 8'b00000011) && (qpim==0) && (!crmr_flag))//03h
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  read_data_3byte <= `TRUE ; 
                  read_op <= `TRUE ; 
               end 
            end
           
	    else if ((data_latch == 8'b0001_0011) && (qpim==0) && (!crmr_flag))//13h
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  read_data_4byte <= `TRUE ; 

                  read_op <= `TRUE ; 
               end 
            end



            else if ((data_latch == 8'b0000_1011) && (!crmr_flag))//0bh
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  fast_read_3byte <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
                  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;

               end 
            end


	    else if ((data_latch == 8'b0000_1100) && (!crmr_flag))//0ch
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  fast_read_4byte <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
                //  if(qpim & qpi_dummy_4clk)     read_op <= `TRUE;
				  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;

               end 
            end



            else if ((data_latch == 8'b00001101) && (!crmr_flag))//0dh 2104 add
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  DTR_single_read <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
                       
                          // if(qpim & qpi_dummy_4clk)    
                      	//	 read_op <= `TRUE;
				  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;

               end 
            end

            else if ((data_latch == 8'b10111101) && (qpim==0) && (!crmr_flag))//bdh 2104 add
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  DTR_dual_read <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
                       
               end 
            end


            else if ((data_latch == 8'b1110_1101) &&(!crmr_flag))//edh quad read under DTR 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else if(QE)
               
               begin
                  DTR_quad_read_3byte <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
                       
                  //if(qpim & qpi_dummy_4clk)       
                  //    read_op <= `TRUE;
				  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;

               end 
                  else begin
                      DTR_quad_read_3byte <= `FALSE; 
			write_op <= `FALSE ;
                end
            end

    
	    else if ((data_latch == 8'b1110_1110) &&(!crmr_flag))   //eeh quad read under DTR  4byte
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else if(QE)
               
               begin
                  DTR_quad_read_4byte  <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
                       
                //  if(qpim & qpi_dummy_4clk)       
                //      read_op <= `TRUE;
				  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;

               end 
                  else begin
                      DTR_quad_read_4byte <= `FALSE; 
			write_op <= `FALSE ;
                end
            end



            else if ((data_latch == 8'b01011010) && (!crmr_flag))//2005 added 5a
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  read_sfdp     <= `TRUE ; 
                  rd_sfdp_3byte <= `TRUE ; 
                  write_op      <= `TRUE ;   //for frequency check
               end 

            end 
                            else if ((data_latch == 8'b01001011) && (!crmr_flag))//2104 added 4bh
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  read_sfdp <= `TRUE ; 
                  read_uid <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
				  rd_sfdp_3byte <= `FALSE ;
               end 
            end

            
           
            else if ((data_latch == 8'b01001000) && (!crmr_flag))//48h
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               
               begin
                  otprd <= `TRUE ; 
                  write_op <= `TRUE ;   //for frequency check
               end 
            end
            
            
            else if ((data_latch == 8'b0011_1011) && (qpim==0) && (!crmr_flag))  // for 3bh 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
                begin
                  dofr_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end
           

	    else if ((data_latch == 8'b0011_1100) && (qpim==0) && (!crmr_flag))  // for 3ch 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
                begin
                  dofr_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end



            else if ((data_latch == 8'b1011_1011) && (qpim==0) && (!crmr_flag))  // for bbh 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else 
               begin
                  diofr_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end

	    
	    else if ((data_latch == 8'b1011_1100) && (qpim==0) && (!crmr_flag))  // for bch 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else 
               begin
                  diofr_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end


            
          //5109 no 92h	 cmlin   else if ((data_latch == 8'b10010010) && (qpim==0) && (!crmr_flag))  // for 92h 
          //5109 no 92h	 cmlin   begin
          //5109 no 92h	 cmlin      if (only_rdsr && (~suspend_enable))
          //5109 no 92h	 cmlin      begin
          //5109 no 92h	 cmlin         if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
          //5109 no 92h	 cmlin      end
          //5109 no 92h	 cmlin      else if ( dpd_enable)
          //5109 no 92h	 cmlin      begin
          //5109 no 92h	 cmlin         if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
          //5109 no 92h	 cmlin      end
          //5109 no 92h	 cmlin      else 
          //5109 no 92h	 cmlin      begin
          //5109 no 92h	 cmlin         manu_device_id_dual <= `TRUE ; 
          //5109 no 92h	 cmlin         write_op <= `TRUE ; 
          //5109 no 92h	 cmlin      end 
          //5109 no 92h	 cmlin   end


            else if ((data_latch == 8'b0110_1011) && (qpim==0) && (!crmr_flag))  // for 6bh 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               
               else if (QE)
               begin
                  qofr_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
               else 
                begin
                  qofr_3byte <= `FALSE ; 
                  write_op <= `FALSE ; 
                 
               end 
            end
           

	    else if ((data_latch == 8'b0110_1100) && (qpim==0) && (!crmr_flag))  // for 6ch 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               
               else if (QE)
               begin
                  qofr_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
               else 
                begin
                  qofr_4byte <= `FALSE ; 
                  write_op <= `FALSE ; 
                 
               end 
            end



            else if ((data_latch == 8'b1110_1011) && (!crmr_flag))  // for ebh 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
                else if (QE)
               begin
                  qiofr_3byte <= `TRUE ;
                  write_op <= `TRUE ; 
                 // if(qpim & qpi_dummy_4clk)     read_op <= `TRUE;
				  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;
               end 
               else
                begin
                
                  qiofr_3byte <= `FALSE ;
                  write_op <= `FALSE ; 
                  
               end 
            end
           

	    else if ((data_latch == 8'b1110_1100) && (!crmr_flag))  // for ech 
            begin
               if (only_rdsr && (~suspend_enable))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
                else if (QE)
               begin
                  qiofr_4byte <= `TRUE ;
                  write_op <= `TRUE ; 
                  //if(qpim & qpi_dummy_4clk)     read_op <= `TRUE;
				  if(qpim & qpi_dummy_6clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_8clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_12clk)     read_op <= `TRUE;
                  if(qpim & qpi_dummy_16clk)     read_op <= `TRUE;
               end 
               else
                begin
                
                  qiofr_4byte <= `FALSE ;
                  write_op <= `FALSE ; 
                  
               end 
            end


        //5109 no 94h cmlin    else if ((data_latch == 8'b10010100) && (!crmr_flag)) // for 94h 
        //5109 no 94h cmlin    begin
        //5109 no 94h cmlin       if (only_rdsr && (~suspend_enable))
        //5109 no 94h cmlin       begin
        //5109 no 94h cmlin          if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
        //5109 no 94h cmlin       end
        //5109 no 94h cmlin       
        //5109 no 94h cmlin       else if ( dpd_enable)
        //5109 no 94h cmlin       begin
        //5109 no 94h cmlin          if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
        //5109 no 94h cmlin       end
        //5109 no 94h cmlin        else if (QE)
        //5109 no 94h cmlin       begin
        //5109 no 94h cmlin          manu_device_id_quad <= `TRUE ;
        //5109 no 94h cmlin          write_op <= `TRUE ; 
        //5109 no 94h cmlin       end 
        //5109 no 94h cmlin       else
        //5109 no 94h cmlin        begin
        //5109 no 94h cmlin        
        //5109 no 94h cmlin          manu_device_id_quad <= `FALSE ;
        //5109 no 94h cmlin          write_op <= `FALSE ; 
        //5109 no 94h cmlin          
        //5109 no 94h cmlin       end 
        //5109 no 94h cmlin    end


        //5109 no e7h cmlin    else if ((data_latch == 8'b11100111) && (qpim==0) && (!crmr_flag))  //for e7h 
        //5109 no e7h cmlin    begin
        //5109 no e7h cmlin       if (only_rdsr && (~suspend_enable))
        //5109 no e7h cmlin       begin
        //5109 no e7h cmlin          if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
        //5109 no e7h cmlin       end
        //5109 no e7h cmlin       else if ( dpd_enable)
        //5109 no e7h cmlin       begin
        //5109 no e7h cmlin          if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
        //5109 no e7h cmlin       end
        //5109 no e7h cmlin       
        //5109 no e7h cmlin        else if  (QE)
        //5109 no e7h cmlin       begin
        //5109 no e7h cmlin          qiowfr <= `TRUE ; 
        //5109 no e7h cmlin          write_op <= `TRUE ; 
        //5109 no e7h cmlin       end 
        //5109 no e7h cmlin       else 
        //5109 no e7h cmlin        begin
        //5109 no e7h cmlin          qiowfr <= `FALSE ;
        //5109 no e7h cmlin          write_op <= `FALSE ; 
        //5109 no e7h cmlin          
        //5109 no e7h cmlin       end 
        //5109 no e7h cmlin    end
            
           else if ((data_latch == 8'b00000001) && (!crmr_flag))  // 01h(wrsr)
            begin
               if (only_rdsr || suspend_enable)   //wip == 1 or in suspend state
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
	       else if (wrsr_protect) 
	       begin
		    wrsr_l <= `FALSE;
		    wel <= 1'b0;
		    if ($time != 0) $display("%t:  NOTE : this wrsr op protected,wrsr operation is inhibted",$realtime);

	       end
               else
               begin
                        wrsr_l <= `TRUE ;
                        write_op <= `TRUE ;
               end 
            end

            else if ((data_latch == 8'b00110001) && (!crmr_flag))  // 31h(wrsr)
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
              else if (wrsr_protect) 
	       begin
		    wrsr_m <= `FALSE;
		    wel <= 1'b0;
		    if ($time != 0) $display("%t:  NOTE : this wrsr op protected,wrsr operation is inhibted",$realtime);

	       end 
               else
               begin
                        wrsr_m <= `TRUE ;

                        write_op <= `TRUE ; 
               end 
            end

            else if ((data_latch == 8'b00010001) && (!crmr_flag))  // 11h(wrsr)
            begin
               	if (only_rdsr || suspend_enable)
               	begin
                  	if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               	end
               	else if ( dpd_enable)
               	begin
                  	if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               	end
              	else if (wrsr_protect) 
	       		begin
		    		wrsr_h <= `FALSE;
		    		wel <= 1'b0;
		    		if ($time != 0) $display("%t:  NOTE : this wrsr op protected,wrsr operation is inhibted",$realtime);

	       		end 
               	else
               	begin
                  	wrsr_h <= `TRUE ;
                   	write_op <= `TRUE ; 
               end 
            end
            
            else if ((data_latch == 8'b0000_0010) && (!crmr_flag))//02h
            begin
               if (only_rdsr || (suspend_enable && !ersp)) //2104
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  pp_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end


	    else if ((data_latch == 8'b0001_0010) && (!crmr_flag))//12h
            begin
               if (only_rdsr || (suspend_enable && !ersp)) 
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  pp_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end
	    
            
             else if ((data_latch == 8'b0011_0010) && (qpim==0) && (!crmr_flag))//32h
            begin
               if (only_rdsr || (suspend_enable && !ersp))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else if (QE)
               begin
                  quadpgm_3byte <= `TRUE ;
                  write_op <= `TRUE ; 
               end 
               else
                begin
                
                  quadpgm_3byte <= `FALSE ;
                  write_op <= `FALSE ; 
                  if ($time != 0) $display("%t:  ERROR : This Opcode need to set QE first. Cycle",$realtime); 
               end 
            end
            

	    else if ((data_latch == 8'b0011_0100) && (qpim==0) && (!crmr_flag))//34h
            begin
               if (only_rdsr || (suspend_enable && !ersp))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else if (QE)
               begin
                  quadpgm_4byte <= `TRUE ;
                  write_op <= `TRUE ; 
               end 
               else
                begin
                
                  quadpgm_4byte <= `FALSE ;
                  write_op <= `FALSE ; 
                  if ($time != 0) $display("%t:  ERROR : This Opcode need to set QE first. Cycle",$realtime); 
               end 
            end


             else if ((data_latch == 8'b01000010) && (!crmr_flag))//42h
            begin
               if (only_rdsr || (suspend_enable && !ersp))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  otppgm <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end 
                               
            
            else if ((data_latch == 8'b0010_0000) && (!crmr_flag))//20h
            begin
               if (only_rdsr || suspend_enable)    //wip == 1 or suspend_enable == 1, cannot take erase operation
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  ser_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end

	    else if ((data_latch == 8'b0010_0001) && (!crmr_flag))//21h
            begin
               if (only_rdsr || suspend_enable)    //wip == 1 or suspend_enable == 1, cannot take erase operation
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  ser_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end




            
             else if ((data_latch == 8'b01000100) && (!crmr_flag))//44h
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  otpers <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end
            
            
            else if (( data_latch == 8'b0101_0010 ) && (!crmr_flag))//52h
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  ber32_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end

	    else if (( data_latch == 8'b0101_1100 ) && (!crmr_flag))//5ch
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  ber32_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end


             else if (( data_latch == 8'b1101_1000 ) && (!crmr_flag))//d8h
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  ber64_3byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end

	    else if (( data_latch == 8'b1101_1100 ) && (!crmr_flag))//dch
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  ber64_4byte <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end




           
            else if (((data_latch == 8'b11000111) || (data_latch == 8'b01100000)) && (!crmr_flag))//c7h & 60h
            begin
               if (only_rdsr || suspend_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  cer <= `TRUE ; 
                  write_op <= `TRUE ; 
               end 
            end
            else if ((data_latch == 8'b10011111 || (data_latch == 8'b10011110) ) && (!crmr_flag))  // 9fh 9eh
            begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime);
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                  rdid <= `TRUE ;
               end
            end
            
            else if ((data_latch == 8'b10010000) && (!crmr_flag))  //90h 
            begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime);
               end
               else if ( dpd_enable)
               begin
                 // if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
                                 // rfdp <= `TRUE ;
                                  dpd <= `FALSE;
                                  dpd_enable <= `FALSE ;
                                  mid <= `TRUE ;


               end
               else
               begin
                  mid <= `TRUE ;
               end
            end
            
   
           else if ((data_latch == 8'b10101011) && (!crmr_flag)) // abh 
            begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime);
               end
                           else
               begin   

                                  rfdp <= `TRUE ;                        
               end
            end
            
             else if ((data_latch == 8'b10111001) && (!crmr_flag))  // b9h 
            begin
               if (only_rdsr)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime);
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else 
               begin
                  dpd <= `TRUE ;
               end
            end
            

            
            else if ((data_latch == 8'b01110101) && (!crmr_flag))//75h
            begin
              if (cer || (wrsr_l || wrsr_m || wrsr_h) || (!only_rdsr) || factory_mode || otppgm || otpers)  //modified for suspend can't decode during wrsr
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during wip=0",$realtime);
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end

              else 
              begin
                 
                  suspend <= `TRUE ;
                                  
                  if(pp)
                  begin
                        suspend_pp <= `TRUE;
                disable page_pgm_process;
                  end                  
                  if(quadpgm)
                  begin
                        suspend_quadpgm <= `TRUE;
                        disable quad_pgm_process;
                  end                 
		  if(ex_quadpgm)
                  begin
                        suspend_ex_quadpgm <= `TRUE;
                        disable ex_quad_pgm_process;
                  end    		    
                  if(otppgm)
                  begin
                        suspend_otppgm <= `FALSE ;
                        disable otp_pgm_process;
                  end
                  if(otpers)
                  begin
                        suspend_otpers <= `FALSE;
                        disable otp_ers_process;
                  end                                                      
                 if(ser)
                  begin
                        suspend_ser <= `TRUE;
                        disable ser_process;
                  end
                 if(ber32)
                  begin
                        suspend_ber32 <= `TRUE;
                        disable ber32_process;
                  end
                 if(ber64)
                  begin
                        suspend_ber64 <= `TRUE;
                        disable ber64_process;
                  end 
              end
            end
            else if ((data_latch == 8'b01111010) && (!crmr_flag))//7ah
            begin
               if ((only_rdsr & !suspend_enable) || factory_mode)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime);
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else
               begin
                resume <= `TRUE;
                                
                                
                resume_enable <= `TRUE;
                        if((!ersp && pgmsp) || (ersp && pgmsp))
                        begin

                    if(suspend_pp)
                                begin
                                    if(!cmd_4byte) pp_3byte <= `TRUE;   //3byte cmd 
				    else    pp_4byte <= `TRUE;    //4byte cmd 
                                end
                                if(suspend_quadpgm)
                                begin
                                    if(!cmd_4byte) quadpgm_3byte <= `TRUE;
				    else    quadpgm_4byte <= `TRUE;
                                end
				if(suspend_ex_quadpgm)
                                begin
                                    if(!cmd_4byte) ex_quadpgm_3byte <= `TRUE;
				    else    ex_quadpgm_4byte  <= `TRUE;
                                end

                                if(suspend_otppgm)
                                begin
                                        otppgm <= `TRUE;
                                end

                        end
                        if(ersp && !pgmsp)
                        begin
                                if(suspend_otpers)
                                begin
                                        otpers <= `TRUE;
                                end                                                     
                                if(suspend_ser)
                                begin
                                    if(!cmd_4byte) ser_3byte <= `TRUE;
				    else      ser_4byte <= `TRUE;
                                end
                                if(suspend_ber32)
                                begin
                                    if(!cmd_4byte)   ber32_3byte <= `TRUE;
				    else      ber32_4byte <= `TRUE;
                                end
                                if(suspend_ber64)
                                begin
                                    if(!cmd_4byte) ber64_3byte <= `TRUE;
				    else      ber64_4byte  <= `TRUE;
                                end

                        end


             end
            end   


            else if ((data_latch == 8'b00111000)&& (qpim==0) && (!crmr_flag))  // for 38h enter qpi mode
             begin
                if (only_rdsr && (~suspend_enable))
                begin
                   if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
                end
                
                else if ( dpd_enable)
                begin
                   if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
                end
                 else if (QE)
                begin
                   qpim <= `TRUE ;
                end 
                else
                 begin
                 
                   qpim <= `FALSE ;
                   
                end 
             end
                         
                         

            else if ((data_latch == 8'b11000000)&& (qpim==1) && (!crmr_flag))  // for c0h set read parameters in qpi mode
             begin
                if (only_rdsr && (~suspend_enable))
                begin
                   if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
                end
                
                else if ( dpd_enable)
                begin
                   if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
                end
                 else if (QE)
                begin
                   set_read_para <= `TRUE ;
                end 
                else
                 begin
                 
                   set_read_para <= `FALSE ;
                   
                end 
             end


            else if ((data_latch == 8'b01110111)&& (qpim==0) && (!crmr_flag))  // for 77h 
                 begin
                if (only_rdsr && (~suspend_enable))
                begin
                   if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
                end
                
                else if ( dpd_enable)
                begin
                   if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
                end

                else if (QE)
                begin
                   wrapset <= `TRUE ;
                end 
                else
                begin
                 
                   wrapset <= `FALSE ;
                   
                end 

              end
                                 
            else if((data_latch == 8'b0011_0110) && (!crmr_flag))   //36h individual block lock  new added
	         begin
                    if(only_rdsr || (suspend_enable && !ersp))
                    begin
                            if($time != 0) $display("%t: ERROE: This Opcode is not decoded during a Prog. Cycle ", $realtime);
                    end

                    else if(dpd_enable)
                    begin
                            if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
                    end

                    else 
                    begin
                            IB_lock <= `TRUE;
                    end
	         end

            else if((data_latch == 8'b0011_1001) && (!crmr_flag))   //39h individual block unlock  new added
	         begin
                    if(only_rdsr || (suspend_enable && !ersp))
                    begin
                            if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
                    end

                    else if(dpd_enable)
                    begin
                            if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
                    end
                    
                    else
                    begin
                            IB_unlock <= `TRUE;
                    end
	         end

            
            else if((data_latch == 8'b0011_1101) && (!crmr_flag))   //3dh read block lock  new added
	         begin
                    if(only_rdsr || (suspend_enable && !ersp))
                    begin
                            if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
                    end

                    else if(dpd_enable)
                    begin
                            if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
                    end
                    
                    else
                    begin
                            IB_read <= `TRUE;
                    end
	         end

            else if((data_latch == 8'b0111_1110) && (!crmr_flag))   //7eh global block lock  new added
	         begin
                    if(only_rdsr || (suspend_enable && !ersp))
                    begin
                            if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
                    end

                    else if(dpd_enable)
                    begin
                            if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
                    end
                    
                    else
                    begin
                            GB_lock <= `TRUE;
                    end
	         end

            else if((data_latch == 8'b1001_1000) && (!crmr_flag))   //98h global block unlock  new added
	         begin
                    if(only_rdsr || (suspend_enable && !ersp))
                   begin
                           if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
                   end

                   else if(dpd_enable)
                   begin
                           if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
                   end
                   
                   else
                   begin
                           GB_unlock <= `TRUE;
                   end
		end


		///////2008////
	    else if((data_latch == 8'b0011_0000) && (!crmr_flag))   //30h clear status register S18 and S19 flags
		begin
		    if (only_rdsr || suspend_enable)
			begin
			    if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
			end

		    else if(dpd_enable)
			begin
                           if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
			end
                   
		    else
			begin
                           clear_sr_flags = `TRUE;
			end
		end

	    
	    else if((data_latch == 8'b1011_0111) && (!crmr_flag))   //b7h enable 4-byte mode
		begin
		    if (only_rdsr || suspend_enable)
			begin
			    if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
			end

		    else if(dpd_enable)
			begin
                           if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
			end
                   
		    else
			begin
			   enable_4byte_mode = `TRUE; 
			end
		end

	    else if((data_latch == 8'b1110_1001) && (!crmr_flag))   //e9h disable 4-byte mode
		begin
		    if (only_rdsr || suspend_enable)
			begin
			    if($time != 0) $display("%t: ERROR: This Opcode is not decoded during a Prog. Cycle", $realtime);
			end

		    else if(dpd_enable)
			begin
                           if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
			end
                   
		    else
			begin
			   disable_4byte_mode = `TRUE; 
			end
		end


	    else if((data_latch == 8'b1100_1000) && (!crmr_flag))   //c8h read extended address register
		begin
		    if(dpd_enable)
			begin
                           if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
			end
                   
		    else
			begin
			   rd_ex_addr = `TRUE;
			    write_op = `TRUE;
			end
		end
	
	    else if ((data_latch == 8'b1100_0101) && (!crmr_flag))  //c5h write extended address register
	    begin
			if (only_rdsr || suspend_enable)
			begin
		    	if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
			end
			else if ( dpd_enable)
			begin
		    	if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
			end
               
			else
			begin
		    	wr_ex_addr <= `TRUE ; 
		    	write_op <=	`TRUE;
			end 
       	end




	    else if((data_latch == 8'b10110101) && (!crmr_flag))   //5109 cmlin b5h read configuration register
		begin
		    if(dpd_enable)
			begin
               if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
			end
                   
		    else
			begin
			   rd_configuration_reg  = `TRUE;
			   write_op = `TRUE;
			end
		end
	
	    else if ((data_latch == 8'b10110001) && (!crmr_flag))  //5109 cmlin b1h write configuration register
	    begin
			if (only_rdsr || suspend_enable)
			begin
		    	if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
			end
			else if ( dpd_enable)
			begin
		    	if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
			end
               
			else
			begin
		    	wr_configuration_reg  <= `TRUE ; 
		    	write_op <=	`TRUE;
			end 
       	end


	    else if ((data_latch == 8'b1100_0010) && (!crmr_flag))//c2h extend quad page program
            begin
               if (only_rdsr || (suspend_enable && !ersp))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else if (QE)
               begin
                  ex_quadpgm_3byte <= `TRUE ;
                  write_op <= `TRUE ; 
               end 
               else
                begin
                
                  ex_quadpgm_3byte <= `FALSE ;
                  write_op <= `FALSE ; 
                  if ($time != 0) $display("%t:  ERROR : This Opcode need to set QE first. Cycle",$realtime); 
               end 
            end



	    else if ((data_latch == 8'b0011_1110) && (!crmr_flag))//3eh extend quad page program
            begin
               if (only_rdsr || (suspend_enable && !ersp))
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during a Prog. Cycle ",$realtime); 
               end
               else if ( dpd_enable)
               begin
                  if ($time != 0) $display("%t:  ERROR : This Opcode is not decoded during deep power down cycle. Cycle",$realtime); 
               end
               else if (QE)
               begin
                  ex_quadpgm_4byte <= `TRUE ;
                  write_op <= `TRUE ; 
               end 
               else
                begin
                
                  ex_quadpgm_4byte <= `FALSE ;
                  write_op <= `FALSE ; 
                  if ($time != 0) $display("%t:  ERROR : This Opcode need to set QE first. Cycle",$realtime); 
               end 
            end 
	    

	    else if ((data_latch == 8'b0000_0000) && (!crmr_flag))//00h no operation command
            begin
	    
	    end

	    else if ((data_latch == 8'b0110_0010) && (!crmr_flag))//62h 
            begin
		
	    end 


	  //5109 no 41h cmlin  else if((data_latch == 8'b0100_0001) && (!crmr_flag))   //41h factory mode
	  //5109 no 41h cmlin       begin
      //5109 no 41h cmlin              if(only_rdsr || suspend_enable)
      //5109 no 41h cmlin              begin
      //5109 no 41h cmlin                      if($time != 0) $display("%t: ERROE: This Opcode is not decoded during a Prog. Cycle ", $realtime);
      //5109 no 41h cmlin              end

      //5109 no 41h cmlin              else if(dpd_enable)
      //5109 no 41h cmlin              begin
      //5109 no 41h cmlin                      if($time != 0) $display("%t: ERROE: This Opcode is not decoded during deep power down cycle. Cycle ", $realtime);
      //5109 no 41h cmlin              end

      //5109 no 41h cmlin              else 
      //5109 no 41h cmlin              begin
      //5109 no 41h cmlin                      factory_mode <= `TRUE;
      //5109 no 41h cmlin              end
	  //5109 no 41h cmlin       end






         end            

         //---------------------------------------------------------------------
         // addresses and data reception and treatment
         //---------------------------------------------------------------------
	
	//////first address byte
         if ( (byte_cpt == 1) && (!only_rdsr) && (crm_bit[5:4] !==2'h2))
         begin
            if (( (otppgm) || (quadpgm) || (ex_quadpgm) || (otpers) || (otprd)  || (read_data) || (fast_read) || DTR_single_read || DTR_dual_read || DTR_quad_read|| read_sfdp || (mid) || (uniqueid) || (dofr) || (diofr) ||
                                (manu_device_id_dual) || (qofr) || (qiofr) || (manu_device_id_quad) || (qiowfr)  || (ser) || (ber32)|| (ber64) || (pp) || (IB_lock) || (IB_unlock) ||
                                (IB_read) ) && (qpim==0) )      
            begin
               adress_1 = data_latch;   // address change        
            end

            if (((fast_read) || DTR_single_read|| DTR_quad_read  ||(mid) || (read_sfdp) || (qiofr) || (ser) || (ber32)|| (ber64) || (pp) || (IB_lock) || (IB_unlock) || (IB_read) || (ex_quadpgm) || otppgm || otpers || otprd) && (qpim==1))//qpi added   
            begin
               adress_1 = data_latch;   // address change 
            end

            if(set_read_para && qpim)
            begin
                qpi_para_bit = data_latch;

            end

         end 

         
         if ( (byte_cpt == 0) && (!only_rdsr) && (crm_bit[5:4] == 2'h2))
         begin
            if (((diofr) || (manu_device_id_dual) || (qiofr) || (manu_device_id_quad)|| DTR_dual_read|| DTR_quad_read || (qiowfr)) && (qpim==0) )
            begin
               adress_1 = data_latch;   // address change 
            end

            if ((qiofr|| DTR_quad_read || read_sfdp) && qpim)   //qpi
            begin
               adress_1 = data_latch;   // address change 
            end

         end 


	////////////second address byte
         if ((byte_cpt == 2) && (!only_rdsr) && (crm_bit[5:4] !==2'h2))
         begin
            if (( (otppgm) || (quadpgm) || (ex_quadpgm) || (otpers) || (otprd)  ||(read_data) || (fast_read) || DTR_single_read || DTR_dual_read|| DTR_quad_read || (read_sfdp) ||(mid) || (uniqueid) || (dofr) || (diofr) ||
                                (manu_device_id_dual) || (qofr) || (qiofr) || (manu_device_id_quad) || (qiowfr) || (ser) || (ber32)|| (ber64) || (pp_3byte) || (pp_4byte) || (IB_lock) || (IB_unlock) ||
                                (IB_read) ) && (qpim==0) )    
            begin
               adress_2 = data_latch; 
            end 

            if (( (fast_read) || DTR_single_read|| DTR_quad_read  ||(mid) || (read_sfdp) || (qiofr) || (ser) || (ber32)|| (ber64) || (pp) || (IB_lock) || (IB_unlock) || (IB_read) || (ex_quadpgm) || otppgm || otpers || otprd ) && (qpim==1) )//qpi added 
            begin
               adress_2 = data_latch; 
            end 

         end 
         
         if ((byte_cpt == 1) && (!only_rdsr) && (crm_bit[5:4] == 2'h2))
         begin
            if (((diofr) || (manu_device_id_dual) || (qiofr) || (manu_device_id_quad)|| DTR_dual_read|| DTR_quad_read || (qiowfr)) && (qpim==0))  
            begin
               adress_2 = data_latch; 
            end 

            if( (qiofr|| DTR_quad_read) && (qpim==1))  
            begin
               adress_2 = data_latch; 
            end 

         end 
         
////////////////////////////
///////////////////////////
	 //////////////third address byte
         if ((byte_cpt == 3) && (!only_rdsr) && (crm_bit[5:4] !==2'h2))
         begin
            if (( (otppgm) || (quadpgm) || (ex_quadpgm) || (otpers) || (otprd)  || (read_data) || (fast_read) || DTR_single_read || DTR_dual_read|| DTR_quad_read ||(read_sfdp) || (mid) || (uniqueid) || (dofr) || (diofr) ||
                                (manu_device_id_dual) || (qofr) || (qiofr) || (manu_device_id_quad) || (ser) || (ber32)|| (ber64) || (pp) || (IB_lock) || (IB_unlock) || (IB_read) ) &&
                                (qpim==0))    
            begin
               adress_3 = data_latch;
            end 
            
            if (( ser || ber32|| ber64 || pp || IB_lock || IB_unlock || IB_read || qiofr || read_sfdp || fast_read || DTR_single_read|| DTR_quad_read || mid || ex_quadpgm || otppgm || otpers || otprd) && (qpim==1) ) 
            begin
               adress_3 = data_latch;
            end 
                        
           if (qiowfr && (!qpim))
            begin
              if(!ADS)    //3byte mode 
	      begin
		adress_3 = {data_latch[7:1],1'b0}; 
	      end else if(ADS)  //4byte mode 
	      begin
		adress_3 = data_latch;
	      end
            end  
		
		//if only need 3byte address
		extended_addr = {6'b0, A25, A24};
		adress = {extended_addr, adress_1, adress_2, adress_3};
		add_mem <= adress;
		lsb_adress = adress;

	    if(!ADS)   //3byte mode 
	    begin
		  if (ser || ber32 || ber64 || otpers)  
            	  begin
            	     //-----------------------------------------
            	     // To ignore don't care MSB of the adress
            	     //----------------------------------------- 

            	      for(i = 0; i <= `BIT_TO_CODE_MEM -1; i = i + 1)
            	      begin
            	         cut_add[i] = adress[i]; 
            	      end
            	      ers_add = cut_add; 
            	  end 

            	 if (pp || otppgm || quadpgm || ex_quadpgm)  
            	  begin
            	     //-----------------------------------------
            	     // To ignore don't care MSB of the adress
            	     //----------------------------------------- 

            	      for(i = 0; i <= `BIT_TO_CODE_MEM -1; i = i + 1)
            	      begin
            	         cut_add[i] = adress[i]; 
            	      end

            	  end 


            	 if(IB_lock || IB_unlock)
            	 begin
            	         address_IB_lock <= adress[(`BIT_TO_CODE_MEM -1):16];
            	         address_IS_lock <= adress[15:12];
            	 end

            	 if(IB_read)
            	 begin
            	         address_IB_read <= adress[(`BIT_TO_CODE_MEM -1):16];
            	         address_IS_read <= adress[15:12];
            	 end

            	 if(otppgm || otpers)
            	 begin
            	         address_otp <= {adress[13:12],adress[9:8]};
            	 end
	    end
	 end  


       
         if ((byte_cpt == 2) && (!only_rdsr) && (crm_bit[5:4] == 2'h2))
         begin
            if ((diofr || manu_device_id_dual || qiofr || manu_device_id_quad|| DTR_dual_read|| DTR_quad_read) && !qpim)
            begin
               adress_3 = data_latch;
            end 
            
           if ((qiofr || DTR_quad_read) && qpim)        //qpi added  qpi EBH
            begin
               adress_3 = data_latch;
            end
	    
	    if (qiowfr && (!qpim))   //e7h need to ensure last address bit equal 0
            begin
              if(!ADS)    //3byte mode 
	      begin
		adress_3 = {data_latch[7:1],1'b0}; 
	      end else if(ADS)  //4byte mode 
	      begin
		adress_3 = data_latch;
	      end
            end 

		//if only need 3byte address
		extended_addr = {6'b0,A25, A24};
		adress = {extended_addr, adress_1, adress_2, adress_3};
		add_mem <= adress;
		lsb_adress = adress;
       end


       //////////////forth address byte
	if (ADS || cmd_4byte)    //4byte mode
	begin
	    if ((byte_cpt == 4) && (!only_rdsr) && (crm_bit[5:4] !==2'h2))
	    begin
		if ((  (otppgm) || (quadpgm) || (ex_quadpgm)  || (otpers) || (otprd)  || (read_data) || (fast_read) || DTR_single_read || DTR_dual_read|| DTR_quad_read ||(read_sfdp) || (mid) || (uniqueid) || (dofr) || (diofr) ||
                            (manu_device_id_dual) || (qofr) || (qiofr) || (manu_device_id_quad) || (ser) || (ber32)|| (ber64) || (pp) || (IB_lock) || (IB_unlock) || (IB_read) ) &&
                            (qpim==0))    
		begin
		    adress_4 = data_latch;
		end 
            
		if (( ser || ber32|| ber64 || pp || IB_lock || IB_unlock || IB_read || qiofr || read_sfdp || fast_read || DTR_single_read|| DTR_quad_read || mid || ex_quadpgm || otppgm || otpers || otprd) && (qpim==1)) 
		begin
		    adress_4 = data_latch;
		end 

		if (qiowfr && (!qpim))
		begin
		    adress_4 = {data_latch[7:1],1'b0}; 
		end 

		if(read_sfdp&& !read_uid)
			adress = {adress_1, adress_2, adress_3};
		else
			adress = {adress_1, adress_2, adress_3, adress_4};
		add_mem <= adress;
		lsb_adress = adress;

		 if (ser || ber32 || ber64 || otpers)  
            	  begin
            	     //-----------------------------------------
            	     // To ignore don't care MSB of the adress
            	     //----------------------------------------- 

            	      for(i = 0; i <= `BIT_TO_CODE_MEM -1; i = i + 1)
            	      begin
            	         cut_add[i] = adress[i]; 
            	      end
            	      ers_add = cut_add; 
            	  end 

            	 if (pp || otppgm || quadpgm || ex_quadpgm)  
            	  begin
            	     //-----------------------------------------
            	     // To ignore don't care MSB of the adress
            	     //----------------------------------------- 

            	      for(i = 0; i <= `BIT_TO_CODE_MEM -1; i = i + 1)
            	      begin
            	         cut_add[i] = adress[i]; 
            	      end

            	  end 


            	 if(IB_lock || IB_unlock)
            	 begin
            	         address_IB_lock <= adress[(`BIT_TO_CODE_MEM -1):16];
            	         address_IS_lock <= adress[15:12];
            	 end

            	 if(IB_read)
            	 begin
            	         address_IB_read <= adress[(`BIT_TO_CODE_MEM -1):16];
            	         address_IS_read <= adress[15:12];
            	 end

            	 if(otppgm || otpers)
            	 begin
            	         address_otp <= {adress[13:12],adress[9:8]};
            	 end   
	    end

       
	    if ((byte_cpt == 3) && (!only_rdsr) && (crm_bit[5:4] == 2'h2))
	    begin
		if ((diofr || manu_device_id_dual || qiofr || manu_device_id_quad|| DTR_dual_read|| DTR_quad_read) && !qpim && (ADS || cmd_4byte) )
		begin
		    adress_4 = data_latch;
		end
            
		if ((qiofr || DTR_quad_read) && qpim)        //qpi added  qpi EBH
		begin
		    adress_4 = data_latch;
		end
		
		if (qiowfr && (!qpim))
		begin
		    adress_4 = {data_latch[7:1],1'b0}; 
		end 

		adress = {adress_1, adress_2, adress_3, adress_4};
		add_mem <= adress;
		lsb_adress = adress;
                  
	    end
	    
	end
    
         
	if ((((byte_cpt == 4) && (!cmd_4byte) && (!ADS))       //3byte mode 
	    || ((byte_cpt == 5) && (cmd_4byte || ((!cmd_4byte) && ADS))))  //4byte mode
	    && (!only_rdsr) && (crm_bit[5:4] !==2'h2) && (!diofr_crm_flag) && (!manu_device_id_dual_crm_flag) && (!qiofr_crm_flag) &&
           (!DTR_dual_read_crm_flag) && (!DTR_quad_read_crm_flag) && (!manu_device_id_quad_crm_flag) && (!qiowfr_crm_flag))
	begin
           if ((diofr || qiofr || qiowfr || DTR_dual_read || DTR_quad_read) && !qpim)
           begin
                crm_bit = data_latch;
                
           end


           if ((qiofr|| DTR_quad_read) && qpim)
           begin
                crm_bit = data_latch;
                
           end

       end

      
	if ((((byte_cpt == 3) && (!cmd_4byte) && (!ADS))    //3byte mode 
	    || ((byte_cpt == 4) && (cmd_4byte || ((!cmd_4byte) && ADS))))   //4byte mode
	    && (!only_rdsr) && (crm_bit[5:4] ==2'h2))
	begin
           if ((diofr || qiofr || qiowfr || DTR_dual_read || DTR_quad_read) && !qpim)
           begin
                crm_bit = data_latch;
           end

           if ((qiofr|| DTR_quad_read) && qpim)
           begin
                crm_bit = data_latch;
           end

       end 

	if ((byte_cpt == 4) && (!only_rdsr) && (crm_bit[5:4] !==2'h2) && (!diofr_crm_flag) && (!manu_device_id_dual_crm_flag) && (!qiofr_crm_flag) &&
	   (!DTR_dual_read_crm_flag) && (!DTR_quad_read_crm_flag) && (!manu_device_id_quad_crm_flag) && (!qiowfr_crm_flag))
	begin

       	   if (wrapset && !qpim)
       	   begin
       	   	wrap_bit = data_latch;
       	   	
       	   end
	   
	end




                
         //---------------------------------------------------------------------------
         // PAGE PROGRAM
         // The adress's LSBs necessary to code a whole page are converted to a natural
         // and used to fullfill the page buffer p_prog the same way as the memory page
         // will be fullfilled.
         //--------------------------------------------------------------------------
	 //
	 //3byte mode

         if ( (byte_cpt >= 4) && (pp_3byte || quadpgm_3byte || ex_quadpgm_3byte ||otppgm ) && (!ADS) && (!only_rdsr) && (wel==1'b1) && (qpim==0) )  
         begin
            data_to_write =   data_latch ; 
            page_add_index = (byte_cpt - 1 -  pgm_addr_byte_num + lsb_adress); 
         end 

         else if ( (byte_cpt >= 4) && (pp_3byte || ex_quadpgm_3byte || otppgm) && (!ADS) && (!only_rdsr) && (wel==1'b1) && (qpim==1) )  
         begin
            data_to_write =   data_latch ;
            page_add_index = (byte_cpt - 1 -  pgm_addr_byte_num + lsb_adress); 
         end
	 

	//4byte mode 
	 else if ( (byte_cpt >= 5) && ((pp_4byte || quadpgm_4byte || ex_quadpgm_4byte) || ((pp_3byte || quadpgm_3byte || ex_quadpgm_3byte || otppgm) && ADS)) && (!only_rdsr) && (wel==1'b1) && (qpim==0) )  
         begin
            data_to_write =  data_latch ; 
            page_add_index = (byte_cpt - 1 -  pgm_addr_byte_num + lsb_adress); 
         end 

         else if ( (byte_cpt >= 5) && ((pp_4byte) || ((pp_3byte || ex_quadpgm_3byte || otppgm) && ADS)) && (!only_rdsr) && (wel==1'b1) && (qpim==1) )  
         begin
            data_to_write =  data_latch ;
            page_add_index = (byte_cpt - 1 -  pgm_addr_byte_num + lsb_adress); 
         end 

         else
         begin
            data_to_write  = 8'bxxxxxxxx; 
            page_add_index = 8'bxxxxxxxx; 
         end

         // to launch adress treatment in memory access
	if (	
		read_data_enable 
		|| fast_read_enable
		|| dofr_enable
		|| diofr_enable
		|| qofr_enable
		|| qiofr_enable
		|| qiowfr_enable
		|| otprd_enable
		|| DTR_single_read_enable
		|| DTR_dual_read_enable
		|| DTR_quad_read_enable
		|| manu_device_id_dual_enable 
		|| manu_device_id_quad_enable
		|| read_sfdp_enable
		|| IB_read_cmd_addr_enable
		|| (rd_ex_addr && byte_cpt == 0)
		)

         begin
                        
                        read_enable <=  `TRUE ; 
			read_data_request <= `TRUE ; 
         end 


	if (	
	    ser_cmd_addr_enable
	    || ber32_cmd_addr_enable
	    || ber64_cmd_addr_enable
	    || otpers_cmd_addr_enable
	    )
         begin
                        
                        erase_enable <=  `TRUE ; 
         end 

         if(
	     pp_cmd_addr_enable
	     || quadpgm_cmd_addr_enable
	     || ex_quadpgm_cmd_addr_enable
	     || otppgm_cmd_addr_enable
	    )
         begin
	    write_enable <= `TRUE; 
            write_data_request <= `TRUE ; 
         end 



	//---------------------------------------------------------------------------
         // write extended address register data treatment
         //--------------------------------------------------------------------------
      
        if ( (byte_cpt == 1) && ((cpt==7) && !qpim || (cpt==1) && qpim) && wr_ex_addr  && (!only_rdsr) &&  (wel == 1'b1)) 
        begin
            ex_addr_latch[`NB_BIT_DATA-1:0] = {3'b0,data_latch[4:0]} ;
			wel = 1'b0;
        end 

		if ( (byte_cpt == 1) && ((cpt==7) && !qpim || (cpt==1) && qpim) && wr_configuration_reg   && (!only_rdsr)) 
        begin
			if(vwsr_enable || (wel == 1'b1))
            	configuration_latch[`NB_BIT_DATA-1:0] = {data_latch[7:6],5'b0,data_latch[0]};
        end



          //---------------------------------------------------------------------------
         // WRSR data treatment
         // write status register 
         //--------------------------------------------------------------------------
      
        if ( (byte_cpt == 1) && ((cpt==7) && !qpim || (cpt==1) && qpim) && wrsr_l  && (!only_rdsr) ) 
         begin
                if(vwsr_enable || (wel == 1'b1))
                begin
                    register_bis_latch[`NB_BIT_DATA-1:0] = {data_latch[7:2],wip|wel,wip} ;

                end
        end 

        else if ( (byte_cpt == 2) && (((cpt==7) && !qpim) || ((cpt==1) && qpim)) && wrsr_l && (!only_rdsr) )  
        begin
	    if(vwsr_enable || (wel == 1'b1))
		begin
                    register_bis_latch[`NB_BIT_DATA-1:0] = register_bis_latch[`NB_BIT_DATA-1:0] ;
                    register_bis_latch[`NB_BIT_DATA*2-1:8] = vwsr_enable ?  {SUS1 ,data_latch[6], LB3 , LB2 ,LB1 , SUS2 ,(!qpim&data_latch[1])||qpim, ADS } : 
																			{SUS1 ,data_latch[6] ,(data_latch[5] | LB3)  ,  (data_latch[4] | LB2) ,  (data_latch[3] |LB1),SUS2 ,(!qpim&data_latch[1])||qpim, ADS }  ;
                end

        end
        
        else if ( (byte_cpt == 1) && ((cpt==7) && !qpim || (cpt==1) && qpim) && wrsr_m && (!only_rdsr) )  
        begin
                if(vwsr_enable || (wel == 1'b1))
                begin
                    register_bis_latch[`NB_BIT_DATA*2-1:8] = vwsr_enable ?  {SUS1 ,data_latch[6], LB3 , LB2 ,LB1  , SUS2 ,(!qpim&data_latch[1])||qpim, ADS } :
															{SUS1 ,data_latch[6],(data_latch[5] | LB3), (data_latch[4] | LB2),(data_latch[3] | LB1), SUS2 ,(!qpim&data_latch[1])||qpim, ADS } ;
                end

        end
                
                else if ( (byte_cpt == 1) && ((cpt==7) && !qpim || (cpt==1) && qpim) && wrsr_h && (!only_rdsr) )  
        begin
                if(vwsr_enable || (wel == 1'b1))
                begin
                    register_bis_latch[`NB_BIT_DATA*3-1:16] = {data_latch[7:4], EE, PE, data_latch[1:0]} ;  
                end
        end

                  
	end   



end   //end @(posedge byte_ok)
  



   //-----------------------------------------
   // adresses initialization and reset
   //-----------------------------------------
   

   always @(negedge byte_ok)
   begin


     if (	
		read_data_enable 
		|| fast_read_enable
		|| dofr_enable
		|| diofr_enable
		|| qofr_enable
		|| qiofr_enable
		|| qiowfr_enable
		|| DTR_single_read_enable
		|| DTR_dual_read_enable
		|| DTR_quad_read_enable
		|| otprd_enable
		|| manu_device_id_dual_enable
		|| read_sfdp_enable
		|| IB_read_cmd_addr_enable
		|| (rd_ex_addr && byte_cpt == 0)
		)

         begin
                        
			read_data_request <= `FALSE ; 
         end 



    if( 
	pp_cmd_addr_enable
	|| quadpgm_cmd_addr_enable
	|| ex_quadpgm_cmd_addr_enable
	|| otppgm_cmd_addr_enable
    )  
         begin
            write_data_request <= `FALSE; 
         end 
     	
   

    end






   always @(posedge select_ok) 
   begin
      for(i = 0; i <= (`NB_BIT_ADD - 1); i = i + 1)
      begin
         adress_1[i] = 1'b0; 
         adress_2[i] = 1'b0; 
         adress_3[i] = 1'b0; 
      end
      for(i = 0; i <= (`NB_BIT_ADD_MEM - 1); i = i + 1)
      begin
         adress[i] = 1'b0; 
      end
      add_mem <= adress ; 
     
      if (crm_bit[5:4] !== 2'h2)
      begin
         diofr_crm_flag <= `FALSE;
         manu_device_id_dual_crm_flag <= `FALSE;
         manu_device_id_quad_crm_flag <= `FALSE;
         qiofr_crm_flag <= `FALSE;
                 DTR_dual_read_crm_flag <= `FALSE;
                 DTR_quad_read_crm_flag <= `FALSE;
         qiowfr_crm_flag <= `FALSE;
         crmr_flag <= `FALSE;
                 DTR_dual_read_crm_flag <= `FALSE;
                 DTR_quad_read_crm_flag <= `FALSE;
      end
      if (diofr || manu_device_id_dual || qiofr || DTR_dual_read || DTR_quad_read || (read_sfdp && qpim) || manu_device_id_quad || qiowfr)//2104 add rfdp
        crmr_flag <= `TRUE;
      
        reset_crmr <= 1'b0;

      if (wrap_bit[4] !== 1'h0)
      begin
         wrap_enable <= `FALSE;
      end


   end
          
   always @(negedge select_ok) 
   begin
        if (crm_bit[5:4] !== 2'h2)
        begin
         diofr_3byte <= `FALSE ; 
         diofr_4byte <= `FALSE ; 

         manu_device_id_dual <= `FALSE ; 
         manu_device_id_quad <= `FALSE ; 
         qiofr_3byte <= `FALSE ; 
         qiofr_4byte <= `FALSE ; 

                 DTR_dual_read <= `FALSE ;
                 DTR_quad_read_3byte <= `FALSE ;
                 DTR_quad_read_4byte <= `FALSE ;
                 read_sfdp <= `FALSE ;
                 read_uid <= `FALSE ;
         qiowfr <= `FALSE ; 
         read_enable <= `FALSE;
         

	 dlp_read_enable <= `FALSE;
         read_data_request <= `FALSE ; 
        end
   end  
        
      
   always @(posedge inhib_read)
   begin
         read_op <= `FALSE ; 
         read_data_3byte <= `FALSE ; 
         read_data_4byte <= `FALSE ; 
         fast_read_3byte <= `FALSE ;
         fast_read_4byte <= `FALSE ;

                 DTR_single_read <= `FALSE ;
                 DTR_dual_read <= `FALSE ;
                 DTR_quad_read_3byte <= `FALSE ;
                 DTR_quad_read_4byte <= `FALSE ;
             read_sfdp <= `FALSE;
             read_uid <= `FALSE;
         otprd  <= `FALSE ;  
         read_enable <=  `FALSE ; 

         read_data_request <= `FALSE ; 
         dofr_3byte <= `FALSE ;    
         dofr_4byte <= `FALSE ;    

         qofr_3byte <= `FALSE ; 
         qofr_4byte <= `FALSE ; 

         if(!manu_device_id_dual_crm_flag) manu_device_id_dual <= `FALSE ;
         if(!manu_device_id_quad_crm_flag) manu_device_id_quad <= `FALSE ; 
         if(!diofr_crm_flag) begin
	    diofr_3byte <= `FALSE ; 
	    diofr_4byte <= `FALSE ; 
	end

         if(!qiofr_crm_flag) begin
	    qiofr_3byte <= `FALSE ; 
	    qiofr_4byte <= `FALSE ; 
	end

         if(!qiowfr_crm_flag) qiowfr <= `FALSE ; 
                 if(!DTR_dual_read_crm_flag) DTR_dual_read <= `FALSE;
                 if(!DTR_quad_read_crm_flag) DTR_dual_read <= `FALSE;
   end
   
   always @(posedge c_int)

   begin
        if (crm_bit[5:4] == 2'h2)
         begin
                if (diofr)
                diofr_crm_flag <= `TRUE;

                if (qiofr) begin
		    qiofr_crm_flag <= `TRUE;
		end 

                if (DTR_dual_read) 
                DTR_dual_read_crm_flag <= `TRUE;
                if (DTR_quad_read) 
                DTR_quad_read_crm_flag <= `TRUE;
                if (qiowfr)
                qiowfr_crm_flag <= `TRUE;
                if (manu_device_id_dual)
                manu_device_id_dual_crm_flag <= `TRUE;
                if (manu_device_id_quad && (byte_cpt==6))
                manu_device_id_quad_crm_flag <= `TRUE;

         end



  end           
   
   //------------------------------------------------------
   // STATUS REGISTER INSTRUCTIONS
   //------------------------------------------------------
   // WREN instructions
   //-----------------------      

   always @(posedge inhib_wren) 
   begin
      wren <= `FALSE ; 
   end 
   
    always @(posedge inhib_wrdi) 
   begin
      wrdi <= `FALSE ; 
   end 
   
   //----------------------
   // RESET ENABLE instruction 66h
   //----------------------
   always @(posedge inhib_reset_66h) 
   begin
      reset_66h <= `FALSE ; 
   end 

   //----------------------
   // RESET instruction 99h
   //----------------------
   always @(posedge inhib_reset_99h) 
   begin
      reset_99h <= `FALSE ; 
   end 

   //----------------------
   // RESET WEL instruction
   //----------------------
     
   always @(posedge reset_wel)
   begin
      wel <= `FALSE ; 
   end

   //----------------------
   // RESET clear_sr_flags instruction 30h
   //----------------------
   always @(posedge inhib_clear_sr_flags)
   begin
      clear_sr_flags <= `FALSE ; 
   end

    
    //----------------------
   // RESET enable_4byte_mode instruction b7h
   //----------------------
   always @(posedge inhib_enable_4byte_mode)
   begin
      enable_4byte_mode <= `FALSE ; 
   end

     //----------------------
   // RESET disable_4byte_mode instruction e9h
   //----------------------
   always @(posedge inhib_disable_4byte_mode)
   begin
      disable_4byte_mode <= `FALSE ; 
   end


 
   //-----------------------------
   // CONTINUOUS READ MODE RESET
   //-----------------------------
 
  always @(posedge inhib_crmr) 
   begin
      crmr <= `FALSE ; 
      crmr_flag <= `FALSE ; 
   end 
   
  always @(posedge reset_crmr)
  begin
        diofr_crm_flag <= `FALSE ; 
        manu_device_id_dual_crm_flag <= `FALSE ; 
        manu_device_id_quad_crm_flag <= `FALSE ; 
        qiofr_crm_flag <= `FALSE ; 
                DTR_dual_read_crm_flag <= `FALSE ;
                DTR_quad_read_crm_flag <= `FALSE ;
        qiowfr_crm_flag <= `FALSE ; 
        crm_bit <= 8'h00;
  end   
 
   //------
   // PROG
   //------
   
   //always @(wip or wel or pgmsp or ersp or pgm_er_sp)
   always @(*)
   begin

        status_register[1:0] = {wel|wip,wip} ; 
        status_register[10] = SUS2 ; 
        status_register[15] = SUS1 ; 
	
		status_register[8]  =	ADS;   //2008
		register_bis_latch[8] = ADS;
	
		status_register[18]  =	PE;
		status_register[19]  =	EE;

   end 
   
   
   //------------------
   // rdsr instruction
   //------------------
   always @(posedge inhib_rdsr) 
   begin
        rdsr_l <= `FALSE ;  
        rdsr_m <= `FALSE ; 
        rdsr_h <= `FALSE ;   
        read_op <= `FALSE ;
        rdsr_enable <= `FALSE ;  
        rd_configuration_reg <= `FALSE ;  
   end


   //------------------
   // read extended address register instruction
   //------------------
   always @(posedge inhib_rd_ex_addr) 
   begin
        rd_ex_addr <= `FALSE ; 
	rd_ex_addr_enable <= `FALSE;
   end

    
    //------------------
   // write extended address register instruction
   //------------------
   always @(posedge inhib_wr_ex_addr) 
   begin
        wr_ex_addr <= `FALSE ;  
   end


   //----------------------------------------------------------
   // CHIP/BLOCK/SECTOR ERASE INSTRUCTIONS
   //----------------------------------------------------------
   always @(posedge inhib_cer)
   begin
      cer <= `FALSE ; 
   end 
     
   always @(posedge inhib_ber32)
   begin
      ber32_3byte <= `FALSE ; 
      ber32_4byte <= `FALSE ; 

      ber32_enable <= `FALSE; 
      ber32_time_add <=0;
   end 
   
   always @(posedge inhib_ber64)
   begin
      ber64_3byte <= `FALSE ; 
      ber64_4byte <= `FALSE ; 

      ber64_enable <= `FALSE; 
      ber64_time_add <=0;
   end 
 
   always @(posedge inhib_ser)
   begin
      ser_3byte <= `FALSE ;
      ser_4byte <= `FALSE ;
      ser_enable <= `FALSE;
      ser_time_add <=0;
   end 
   
   always @(posedge inhib_otpers)    // otpers inhibt operation
   begin
      otpers <= `FALSE ;
      otpers_enable <= `FALSE;
      otperss_time_add <=0;
   end 
   
   
   
 //----------------------------------------------------------
   //WRSR INSTRUCTIONS
   //---------------------------------------------------------
  
   always @(posedge inhib_wrsr)
   begin
      wrsr_l <= `FALSE ;
          wrsr_m <= `FALSE ;
          wrsr_h <= `FALSE ;
          wr_configuration_reg <= `FALSE ;

     // wel   <= `FALSE ;
   end 
   
   
   //----------------------------------------------------------
   //PAGE PROGRAM INSTRUCTIONS
   //---------------------------------------------------------
   
   always @(posedge inhib_pp)
   begin
      pp_3byte <= `FALSE ;
      pp_4byte <=   `FALSE;
      write_data_request <= `FALSE ;
      pps_time_add <=0;

      #1;
      for(i = 0; i <= (`PLENGTH-1); i = i + 1)  //page data initialization  1page
        mem_access.p_prog[i] = 8'b11111111 ;
   end 

 always @(posedge inhib_quadpgm)
   begin
      quadpgm_3byte <= `FALSE;
      quadpgm_4byte <= `FALSE;
      write_data_request <= `FALSE ;
      quadpgms_time_add <=0;         
   end 

always @(posedge inhib_ex_quadpgm)
begin
   ex_quadpgm_3byte <= `FALSE ;
   ex_quadpgm_4byte <= `FALSE ;
   write_data_request <= `FALSE ;
   ex_quadpgms_time_add <=0;         
end 

   always @(posedge inhib_otppgm)
   begin
      otppgm <= `FALSE ;  // inhibt otp pgm 
      write_data_request <= `FALSE ;
      otppgms_time_add  <=0;   
   end 



   //--------------------------------------
   // READ JEDEC ID
   //--------------------------------------
   always @(posedge inhib_rdid)         //9fh
   begin
        rdid <= `FALSE;
        read_op <= `FALSE;
        rdid_enable  <= `FALSE;
   end
   
    always @(posedge inhib_mid)         //90h
   begin
        mid <= `FALSE;
        read_op <= `FALSE;
        rdid_enable  <= `FALSE;
   end


    always @(posedge inhib_uniqueid)    //4bh
   begin
        uniqueid <= `FALSE;
        read_op <= `FALSE;
        rdid_enable  <= `FALSE;
   end
   
    always @(posedge inhib_manu_device_id_dual)         //92h
   begin
        manu_device_id_dual <= `FALSE;
        read_op <= `FALSE;
        rdid_enable  <= `FALSE;
   end

    always @(posedge inhib_manu_device_id_quad)         //94h
   begin
        manu_device_id_quad <= `FALSE;
        read_op <= `FALSE;
        rdid_enable  <= `FALSE;
   end

//    always @(posedge inhib_rfdpid) 
//   begin
//      rfdpid <= `FALSE;
//      rfdp <= `FALSE;
//      read_op <= `FALSE;
//      rdid_enable  <= `FALSE;
//      dpd_enable <= `FALSE;
//   end
   
    
   //--------------------------------------
   // DEEP POWER DOWN
   //--------------------------------------
   always @(posedge inhib_dpd) 
   begin
        dpd <= `FALSE;
        read_op <= `FALSE;
   end
   
   //--------------------------------------
   // SET BURST WITH WRAP
   //--------------------------------------
   always @(posedge inhib_wrap) 
   begin
        wrapset <= `FALSE;
        //wrap_enable <= `FALSE;
   end

   //--------------------------------------
   // SET READ PARAMETERS
   //--------------------------------------
   always @(posedge inhib_set_read_para) 
   begin
        set_read_para <= `FALSE;
   end
    //--------------------------------------
   // RELEASE FORM DEEP POWER DOWN
   //--------------------------------------
   always @(posedge inhib_rfdp) 
   begin
        rfdp <= `FALSE;
        read_op <= `FALSE;
        dpd_enable <= `FALSE;
        rdid_enable <= `FALSE;
   end 
   
   
   //----------------------------------------------------------
   //  ERASE/PROGRAM SUSPEND INSTRUCTIONS
   //----------------------------------------------------------
   always @(posedge inhib_suspend)
   begin
      suspend <= `FALSE ;
   end 
   
   always @(posedge pgmsp)
   begin
      if(pgmsp)
        begin
        	pp_3byte <= `FALSE;
			pp_4byte <= `FALSE;
        	quadpgm_3byte <= `FALSE; 
			quadpgm_4byte <= `FALSE;
        	ex_quadpgm_3byte <= `FALSE;  
        	ex_quadpgm_4byte <= `FALSE;  
        	otppgm <= `FALSE;
        	if(suspend_pp)  
        	begin
                ppi_time = $time;
                pps_time_add <= pps_time_add+(ppi_time - pps_time);
        	end

        	if(suspend_quadpgm)     
        	begin
                quadpgmi_time = $time; 
                quadpgms_time_add <= quadpgms_time_add+(quadpgmi_time - quadpgms_time);
        	end

        	if(suspend_ex_quadpgm)     
        	begin
                ex_quadpgmi_time = $time; 
                ex_quadpgms_time_add <= ex_quadpgms_time_add+(ex_quadpgmi_time - ex_quadpgms_time);
			end

        	if(suspend_otppgm)      
        	begin
                otppgmi_time = $time;
                otppgms_time_add <= otppgms_time_add+(otppgmi_time - otppgms_time);
        	end
       	 	suspend_add <= cut_add;
        end

   end
  
   always @(posedge ersp)
   begin
      if(ersp)
        begin
        otpers <= `FALSE;
        ser_3byte <= `FALSE;
        ser_4byte <= `FALSE;
        ber32_3byte <= `FALSE;
        ber32_4byte <= `FALSE;

        ber64_3byte <= `FALSE;
        ber64_4byte <= `FALSE;
        if(suspend_otpers)

        begin
                otpersi_time = $time;
                otperss_time_add <= otperss_time_add+(otpersi_time - otperss_time);
        end
          

          
        if(suspend_ser) 
        begin
                seri_time = $time;
                ser_time_add <= ser_time_add+(seri_time - ser_time);

        end


        if(suspend_ber32)       
        begin   
                beri32_time = $time;
                ber32_time_add <= ber32_time_add+(beri32_time - ber32_time);

        end

        if(suspend_ber64)       
        begin
                beri64_time = $time;
                ber64_time_add <= ber64_time_add+(beri64_time - ber64_time);

        end
        suspend_add <= ers_add;
        end
         

   end



    always @(posedge suspend_enable)
    begin
        pp_enable <= `FALSE;
        quadpgm_enable <= `FALSE;  // new add 3 writed cmd
	ex_quadpgm_enable <= `FALSE;
        otppgm_enable <= `FALSE;

    end
   //----------------------------------------------------------
   //  ERASE/PROGRAM RESUME INSTRUCTIONS
   //----------------------------------------------------------
   always @(posedge inhib_resume)
   begin
      resume <= `FALSE ; 
      resume_enable <= `FALSE;
   end 


        //--------------------------------------------------------
        //BLOCK LOCK OR UNLOCK OR READ INSTRUCTIONS
        //--------------------------------------------------------
        always@(posedge inhib_IB_lock)    //new added
        begin
                IB_lock <= `FALSE; 
        end

        always@(posedge inhib_IB_unlock)    //new added
        begin
                IB_unlock <= `FALSE;
        end

        always@(posedge inhib_IB_read)    //new added
        begin
                IB_read <= `FALSE; 
                IB_read_enable <= `FALSE;
        end
        
        always@(posedge inhib_GB_lock)    //new added
        begin
                GB_lock <= `FALSE; 
        end

        always@(posedge inhib_GB_unlock)    //new added
        begin
                GB_unlock <= `FALSE;
        end


 
   //--------------------------------------------------------
   //--------------- SYNCHRONOUS PROCESS  ----------------
   //--------------------------------------------------------
      //-------------------------------------------
      // READ_data
      //-------------------------------------------
   always 
      @(select_ok)
      begin
         if ((!read_data) && (!fast_read) &&(!read_sfdp) && (!(DTR_single_read || DTR_dual_read || DTR_quad_read )) && (!otprd)  && (!dofr)  && (!diofr) && (!manu_device_id_dual) && (!qofr) && (!qiofr) && (!manu_device_id_quad) && (!qiowfr)  )
         begin
            inhib_read <= `FALSE ; 
         end 

	if ((byte_cpt == 0) && (!byte_ok) && (!select_ok)) 
	begin
	    if ($time != 0) $display("%t:  WARNING : Instruction canceled because the chip is deselected at byte_cpt==0",$realtime); 
	    inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000;
	end


         if (read_data && (!read_enable) && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : read_data Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
	 
         if (read_data && read_enable && (!select_ok))
	 begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000;            
               q_bis <= #`TSHQZ 1'bz ; 
         end
         
     end
  
   always 
   @(negedge c_int )
   begin
	if (read_data && read_enable && (!suspend_enable) && select_ok)
      begin
         if (select_ok)
         begin
            d_bis <= #`TSHQZ 1'bz ;
            q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
            wp_bis <= #`TSHQZ 1'bz ;
            hold_bis <= #`TSHQZ 1'bz ;
            bit_index <= bit_index + 1; 
         end 
      end
	
	else if (read_data && read_enable && (suspend_enable) && select_ok)
      begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])) 
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                   d_bis <= #`TSHQZ 1'bz ;
                                   q_bis <= #`TCLQV data_to_read[7 - bit_index] ;
                                   wp_bis <= #`TSHQZ 1'bz ;
                                   hold_bis <= #`TSHQZ 1'bz ; 
                                   bit_index <= bit_index + 1; 
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                        d_bis <= #`TSHQZ 1'bz ;
                                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ;
                                        wp_bis <= #`TSHQZ 1'bz ;
                                        hold_bis <= #`TSHQZ 1'bz ; 
                                        bit_index <= bit_index + 1; 
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                d_bis <= #`TSHQZ 1'bz ;
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <= bit_index + 1; 
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                   d_bis <= #`TSHQZ 1'bz ;
                                   q_bis <= #`TCLQV data_to_read[7 - bit_index] ;
                                   wp_bis <= #`TSHQZ 1'bz ;
                                   hold_bis <= #`TSHQZ 1'bz ; 
                                   bit_index <= bit_index + 1; 
                                end 
                end
          end

end

//////*************************************************************************

//**********************************************************************************

      //------------------------------------------------------------------
      // Fast_Read
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         if (fast_read && (!read_enable) && (!select_ok) && !qpim)
         begin
            if ($time != 0) $display("%t:  WARNING : fast read Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end

	if (fast_read && read_enable && (!qpim) && (!select_ok))
         begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000;            
               q_bis <= #`TSHQZ 1'bz ; 
         end 


	if (fast_read && (!read_enable) && (!select_ok) && qpim)  //qpi added
         begin
            if ($time != 0) $display("%t:  WARNING : fast_read Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 



         if (fast_read && read_enable && qpim && (!select_ok))
         begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
                hold_bis<= #`TSHQZ 1'bz ; 
                wp_bis<= #`TSHQZ 1'bz ; 
                q_bis <= #`TSHQZ 1'bz ; 
                d_bis <= #`TSHQZ 1'bz ;
         end

      end


   always 
      @(negedge c_int)
      begin
	if (fast_read && read_enable && (!suspend_enable) && !qpim)
         begin
            if (select_ok)
            begin
               d_bis <= #`TSHQZ 1'bz ;
               q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               bit_index <= bit_index + 1 ;
            end 
         end

    	else if (fast_read && read_enable && (suspend_enable) && (select_ok) && !qpim)
        begin
                                if (pgmsp)
                                begin
                                        if(ersp)
                                        begin
                                                if (suspend_ser) 
                                                begin
                                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                                        begin
                                                                bit_index <= 8'b00000000; 
                                                                d_bis <= #`TSHQZ 1'bx ;
                                                                q_bis <=  #`TSHQZ 1'bx;
                                                                wp_bis <= #`TSHQZ 1'bx ;
                                                                hold_bis <= #`TSHQZ 1'bx ;   
                                                        end
                                                        else
                                                        begin
                                                                d_bis <= #`TSHQZ 1'bz ;
                                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                                wp_bis <= #`TSHQZ 1'bz ;
                                                                hold_bis <= #`TSHQZ 1'bz ;
                                                                bit_index <= bit_index + 1; 
                                                        end
                                                end

                                                if (suspend_ber32) 
                                                begin
                                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                                        begin
                                                                bit_index <= 8'b00000000; 
                                                                d_bis <= #`TSHQZ 1'bx ;
                                                                q_bis <=  #`TSHQZ 1'bx;
                                                                wp_bis <= #`TSHQZ 1'bx ;
                                                                hold_bis <= #`TSHQZ 1'bx ;   
                                                        end
                                                        else
                                                        begin
                                                                d_bis <= #`TSHQZ 1'bz ;
                                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                                wp_bis <= #`TSHQZ 1'bz ;
                                                                hold_bis <= #`TSHQZ 1'bz ;
                                                                bit_index <= bit_index + 1; 
                                                        end
                                                end

                                                if (suspend_ber64) 
                                                begin
                                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                                        begin
                                                                bit_index <= 8'b00000000; 
                                                                d_bis <= #`TSHQZ 1'bx ;
                                                                q_bis <=  #`TSHQZ 1'bx;
                                                                wp_bis <= #`TSHQZ 1'bx ;
                                                                hold_bis <= #`TSHQZ 1'bx ;   
                                                        end
                                                        else
                                                        begin
                                                                d_bis <= #`TSHQZ 1'bz ;
                                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                                wp_bis <= #`TSHQZ 1'bz ;
                                                                hold_bis <= #`TSHQZ 1'bz ;
                                                                bit_index <= bit_index + 1; 
                                                        end
                                                end

                        if (suspend_otpers)
                        begin
                                d_bis <= #`TSHQZ 1'bz ;
                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ;
                                wp_bis <= #`TSHQZ 1'bz ;
                        hold_bis <= #`TSHQZ 1'bz ; 
                                bit_index <= bit_index + 1; 
                        end 
                                        end

                                        else
                                        begin
                                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                                        begin
                                        bit_index <= 8'b00000000; 
                                        d_bis <= #`TSHQZ 1'bx ;
                                        q_bis <=  #`TSHQZ 1'bx;
                                        wp_bis <= #`TSHQZ 1'bx ;
                                        hold_bis <= #`TSHQZ 1'bx ;  
                                                        end
                                                        else
                                                        begin
                                                                d_bis <= #`TSHQZ 1'bz ;
                                                                q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                                wp_bis <= #`TSHQZ 1'bz ;
                                                                hold_bis <= #`TSHQZ 1'bz ;
                                                                bit_index <= bit_index + 1; 
                                                        end
                        end

                                                if (suspend_otppgm )
                                begin
                                   d_bis <= #`TSHQZ 1'bz ;
                                   q_bis <= #`TCLQV data_to_read[7 - bit_index] ;
                                   wp_bis <= #`TSHQZ 1'bz ;
                                   hold_bis <= #`TSHQZ 1'bz ; 
                                   bit_index <= bit_index + 1; 
                                end  
                                        end
                                end

                                else if(ersp)   
                                begin

                                        if (suspend_ser) 
                                        begin
                                                if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                                begin
                                                        bit_index <= 8'b00000000; 
                                                        d_bis <= #`TSHQZ 1'bx ;
                                                        q_bis <=  #`TSHQZ 1'bx;
                                                        wp_bis <= #`TSHQZ 1'bx ;
                                                        hold_bis <= #`TSHQZ 1'bx ;   
                                                end
                                                else
                                                begin
                                                        d_bis <= #`TSHQZ 1'bz ;
                                                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                        wp_bis <= #`TSHQZ 1'bz ;
                                                        hold_bis <= #`TSHQZ 1'bz ;
                                                        bit_index <= bit_index + 1; 
                                                end
                                        end

                                        if (suspend_ber32) 
                                        begin
                                                if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                                begin
                                                        bit_index <= 8'b00000000; 
                                                        d_bis <= #`TSHQZ 1'bx ;
                                                        q_bis <=  #`TSHQZ 1'bx;
                                                        wp_bis <= #`TSHQZ 1'bx ;
                                                        hold_bis <= #`TSHQZ 1'bx ;   
                                                end
                                                else
                                                begin
                                                        d_bis <= #`TSHQZ 1'bz ;
                                                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                        wp_bis <= #`TSHQZ 1'bz ;
                                                        hold_bis <= #`TSHQZ 1'bz ;
                                                        bit_index <= bit_index + 1; 
                                                end
                                        end

                                        if (suspend_ber64) 
                                        begin
                                                if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                                begin
                                                        bit_index <= 8'b00000000; 
                                                        d_bis <= #`TSHQZ 1'bx ;
                                                        q_bis <=  #`TSHQZ 1'bx;
                                                        wp_bis <= #`TSHQZ 1'bx ;
                                                        hold_bis <= #`TSHQZ 1'bx ;   
                                                end
                                                else
                                                begin
                                                        d_bis <= #`TSHQZ 1'bz ;
                                                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                                                        wp_bis <= #`TSHQZ 1'bz ;
                                                        hold_bis <= #`TSHQZ 1'bz ;
                                                        bit_index <= bit_index + 1; 
                                                end
                                        end

               if (suspend_otpers)
               begin
                d_bis <= #`TSHQZ 1'bz ;
                q_bis <= #`TCLQV data_to_read[7 - bit_index] ;
                wp_bis <= #`TSHQZ 1'bz ;
                hold_bis <= #`TSHQZ 1'bz ; 
                bit_index <= bit_index + 1; 
               end 
                                end
                        end


//----------- qpi mode fast read ------------------------- 

         if (fast_read && read_enable && (!suspend_enable) && qpim && select_ok)
         begin
               hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
               wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
               q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
               d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
               bit_index <= bit_index + 1 ;
               if (bit_index == 1)
               begin
               bit_index <= 0;
               end
         end

	 else if (fast_read && read_enable && (suspend_enable) && (select_ok) && qpim)
         begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end

                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                end
          end
     end
        
                //------------------------------------------------------------------
                //single read under DTR  0d
                //------------------------------------------------------------------
reg [2:0] read_data_request_dly;
wire      dtr_read_data_req;
always @ (c_int ) begin
    read_data_request_dly  <= { read_data_request_dly[1:0],read_data_request};
end
assign dtr_read_data_req = read_data_request_dly[2];

always 
      @(select_ok)

      begin
         if ((!read_enable) && DTR_single_read && (!select_ok) && !qpim)
         begin
            if ($time != 0) $display("%t:  WARNING :read_data_request_dly Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
         if (DTR_single_read && read_enable && !qpim && (!select_ok))
         begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
         end

  
         if (DTR_single_read && (!read_enable) && (!select_ok) && qpim)    //qpi added
         begin
            if ($time != 0) $display("%t:  WARNING : read_data_request_dly Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 



         if (DTR_single_read && read_enable && (!select_ok) && qpim)
         begin
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
            hold_bis<= #`TSHQZ 1'bz ; 
            wp_bis<= #`TSHQZ 1'bz ; 
            q_bis <= #`TSHQZ 1'bz ; 
            d_bis <= #`TSHQZ 1'bz ;
         end

      end


   always 
      @( c_int )
      begin
             #0.5;
         if ((((((byte_cpt == 5) && ((cpt == 0) || (cpt>=4))) || (byte_cpt >= 6)) && (!ADS))     //3byte mode 
	    || ((((byte_cpt == 6) && ((cpt == 0) || (cpt>=4))) || (byte_cpt >= 7)) && ADS))    //4byte mode 
	    && DTR_single_read && (!suspend_enable) && !qpim)
         begin
            if (select_ok)
            begin
               d_bis <= #`TSHQZ 1'bz ;
               q_bis <= data_to_read[7 - bit_index] ; 
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               bit_index = bit_index + 1 ;
            end 
         end
          end



//----------- qpi mode DTR fast read ------------------------- 
 always 
      @( c_int)
      begin
         #0.5;
         if (DTR_single_read && read_enable && (!suspend_enable) && qpim)
         begin
            if (select_ok )
            begin
               if((((byte_cpt == 11 && cpt ==0) || byte_cpt>=12) && dtr_dummy_8clk ) || (((byte_cpt == 9 && cpt ==0) || byte_cpt>=10)&& dtr_dummy_6clk )  || (((byte_cpt  == 9 && cpt ==0) || byte_cpt>=10)&& dtr_dummy_12clk )  || (((byte_cpt == 20 && cpt ==0) || byte_cpt>=18)&& dtr_dummy_16clk )     )
               begin
               #1;
               hold_bis <= data_to_read[7- bit_index *4] ;
               wp_bis <= data_to_read[6 -bit_index *4] ;
               q_bis <=  data_to_read[5 -bit_index *4] ; 
               d_bis <=  data_to_read[4 -bit_index *4] ;
               end
            end
         end
      end


  always 
      @( c_int )
      begin
         if (DTR_single_read && read_enable && (!suspend_enable)&&qpim)
         begin
            if (select_ok)
            begin
               bit_index <=  bit_index + 1 ;
               if (bit_index == 1)
               begin
               bit_index <=  0 ;
               end              
            end
             
         end
          end


       //------------------------------------------------------------------
                // dual read under DTR      bd                 
		// //------------------------------------------------------------------
 always 
      @(select_ok)
      begin
         if ((!read_enable) && DTR_dual_read && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : DTR_dual_read Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
	 
         if (DTR_dual_read && read_enable && (byte_cpt >= 7) && (!select_ok))
         begin
            if (!DTR_dual_read_crm_flag)
            begin
              
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               DTR_dual_read_crm_read <=`FALSE; 
            end

            if (DTR_dual_read_crm_flag)
            begin
               read_enable <= `FALSE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               DTR_dual_read_crm_read <=`FALSE;
            end
         end
      end

always 
      @(c_int)
      begin
         if (DTR_dual_read && read_enable && DTR_dual_read_crm_read && (!suspend_enable))
         begin
            if (select_ok)
            begin
               bit_index <=  bit_index + 1 ;
               if (bit_index == 3)
               begin
               bit_index <=  0 ;
               end              
            end
             
         end
          end

   always 
      @( c_int )
      begin
                #0.5;
         if (DTR_dual_read && read_enable && DTR_dual_read_crm_read && (!suspend_enable))
         begin
            if (select_ok)
            begin
                if(crmr_flag) 
                begin
                    if((byte_cpt == 5 && cpt ==0) || byte_cpt>=6) 
                    begin
                        #1;
                        q_bis <=  data_to_read[7 - bit_index *2 ] ; 
			d_bis <=  data_to_read[6 - bit_index *2 ] ;
                    end
                end
                else begin
                    if((byte_cpt == 6 && cpt ==0) || byte_cpt>=7) 
                    begin
                        #1;
                        q_bis <=  data_to_read[7 - bit_index *2 ] ; 
			d_bis <=  data_to_read[6 - bit_index *2 ] ;
                    end
                end
                    wp_bis <= #`TSHQZ 1'bz ;
		    hold_bis <= #`TSHQZ 1'bz ;
            end
             
         end
      end
     

      always 
      @(posedge byte_ok)
      begin
         if(DTR_dual_read  && (((byte_cpt == 6) && (cpt == 0)) || (byte_cpt >= 7)) && (!crmr_flag) )
            DTR_dual_read_crm_read <= `TRUE;
         else
         if (DTR_dual_read && (((byte_cpt == 5) && (cpt == 3)) || (byte_cpt >= 5)) && (crmr_flag) )
            DTR_dual_read_crm_read <= `TRUE;
         else 
            DTR_dual_read_crm_read <= `FALSE;
          
       end                      


     //------------------------------------------------------------------
      //quad read  under DTR		 edh
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         if ((!read_enable) && DTR_quad_read && (!select_ok))
         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : DTR_quad_read Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 

         if (DTR_quad_read && read_enable && (!select_ok))
         begin
            if (!DTR_quad_read_crm_flag)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               DTR_quad_read_crm_read <=`FALSE;
               
            end
            if (DTR_quad_read_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               DTR_quad_read_crm_read <=`FALSE;
               
            end
         end

      end    



reg [16:0] r_cnt  ;
reg crc_si, crc_so,crc_wp, crc_hold,neg_flag ;
initial  begin
		r_cnt	=0  ;
		crc_si 	=0  ;
		crc_so 	=0  ;
		crc_wp 	=0  ;
		crc_hold=0  ;
		neg_flag=0  ;
end 

always@( posedge read_enable )begin
	r_cnt=0;
	crc_si 	=0  ;
	crc_so 	=0  ;
	crc_wp 	=0  ;
	crc_hold=0  ;
	neg_flag =0  ;
end


//output data
   always 
      @( c_int)
      begin
	 	 
         #0.5;
         if (DTR_quad_read && read_enable && (!suspend_enable) && select_ok)
         begin
                #1;
				casex({CRC1,CRC0,wrap_enable,wrap_16byte,wrap_32byte,wrap_64byte})

				6'b11???? : begin//no crc
                		hold_bis <= data_to_read[7- bit_index *4] ;
						wp_bis <= data_to_read[6 -bit_index *4] ;
                		q_bis <=  data_to_read[5 -bit_index *4] ; 
						d_bis <=  data_to_read[4 -bit_index *4] ;
				end
				6'b001100 ,6'b011100,6'b101100 ,   6'b100000 ,   6'b100001,6'b100010, 6'b100011, 6'b100100,6'b100101,6'b100110, 6'b100111  : begin//crc with wrap 16byte and not wrap
						r_cnt <=   (r_cnt%16 ==0 && r_cnt>0)   ?   r_cnt :  ( c_int  ?   r_cnt+1 :r_cnt );
						if(r_cnt%16 ==0 && r_cnt>0  && !c_int     )begin
							hold_bis <=   crc_hold ;
							wp_bis  <=    crc_wp;
							q_bis   <=   crc_so;
							d_bis   <=   crc_si;
						end
						else if (r_cnt%16 ==0 && r_cnt>0  && c_int     )begin
							hold_bis <=   crc_hold ;
							wp_bis  <=    crc_wp;
							q_bis   <=   crc_so;
							d_bis   <=   crc_si;

							#0.1;
							crc_hold <=0;
							crc_wp<=0;
							crc_so<=0;
							crc_si<=0;
							r_cnt  <=0;
						end
						else begin
							hold_bis <= data_to_read[7- bit_index *4] ;
							wp_bis <= data_to_read[6 -bit_index *4] ;
                			q_bis <=  data_to_read[5 -bit_index *4] ; 
							d_bis <=  data_to_read[4 -bit_index *4] ;
							#0.1;
							crc_si <= d_bis^crc_si;
							crc_so <= q_bis^crc_so;
							crc_wp <= wp_bis^crc_wp;
							crc_hold <= hold_bis^crc_hold;
						end
				end
				6'b001010 ,6'b011010,6'b101010    ,6'b010000 ,6'b010001, 6'b010010,6'b010011,6'b010100,6'b010101, 6'b010110,6'b010111 : begin//crc	with wrap 32byte and not wrap
						r_cnt <=   (r_cnt%32 ==0 && r_cnt>0)   ?   r_cnt :  ( c_int  ?   r_cnt+1 :r_cnt );
						if(r_cnt%32 ==0 && r_cnt>0  && !c_int     )begin
							hold_bis <=   crc_hold ;
							wp_bis  <=    crc_wp;
							q_bis   <=   crc_so;
							d_bis   <=   crc_si;
						end
						else if (r_cnt%32 ==0 && r_cnt>0  && c_int     )begin
							hold_bis <=   crc_hold ;
							wp_bis  <=    crc_wp;
							q_bis   <=   crc_so;
							d_bis   <=   crc_si;

							#0.1;
							crc_hold <=0;
							crc_wp<=0;
							crc_so<=0;
							crc_si<=0;
							r_cnt  <=0;
						end
						else begin
							hold_bis <= data_to_read[7- bit_index *4] ;
							wp_bis <= data_to_read[6 -bit_index *4] ;
                			q_bis <=  data_to_read[5 -bit_index *4] ; 
							d_bis <=  data_to_read[4 -bit_index *4] ;
							#0.1;
							crc_si <= d_bis^crc_si;
							crc_so <= q_bis^crc_so;
							crc_wp <= wp_bis^crc_wp;
							crc_hold <= hold_bis^crc_hold;
						end
				end
				6'b001001 ,6'b011001,6'b101001     ,6'b000000 ,6'b000001, 6'b000010,6'b000011,6'b000100,6'b000101, 6'b000110,6'b000111  : begin//crc with wrap 64byte and not wrap
						r_cnt <=   (r_cnt%64 ==0 && r_cnt>0)   ?   r_cnt :  ( c_int  ?   r_cnt+1 :r_cnt );
						if(r_cnt%64 ==0 && r_cnt>0  && !c_int     )begin//crc high 4bit
							hold_bis <=   crc_hold ;
							wp_bis  <=    crc_wp;
							q_bis   <=   crc_so;
							d_bis   <=   crc_si;
						end
						else if (r_cnt%64 ==0 && r_cnt>0  && c_int     )begin//crc low 4bit
							hold_bis <=   crc_hold ;
							wp_bis  <=    crc_wp;
							q_bis   <=   crc_so;
							d_bis   <=   crc_si;

							#0.1;
							crc_hold <=0;
							crc_wp<=0;
							crc_so<=0;
							crc_si<=0;
							r_cnt  <=0;
						end
						else begin  //main data
							hold_bis <= data_to_read[7- bit_index *4] ;
							wp_bis <= data_to_read[6 -bit_index *4] ;
                			q_bis <=  data_to_read[5 -bit_index *4] ; 
							d_bis <=  data_to_read[4 -bit_index *4] ;
							#0.1;
							crc_si <= d_bis^crc_si;
							crc_so <= q_bis^crc_so;
							crc_wp <= wp_bis^crc_wp;
							crc_hold <= hold_bis^crc_hold;
						end
				end

				endcase
	  	 end              
           
      end
     
     
  always 
      @( c_int )
      begin
         if (DTR_quad_read && read_enable && (!suspend_enable))
         begin
            if (select_ok)
            begin
               bit_index <=  bit_index + 1 ;
               if (bit_index == 1)
               begin
               bit_index <=  0 ;
               end              
            end
             
         end
          end
     
 always 
      @(negedge c_int)
      begin
         if (DTR_quad_read && (read_enable))
         begin
            if (cpt==1)
            begin
             cpt<= 0 ;
             end
           end
       end
       

                //------------------------------------------------------------------
                //read serial flash discoverable        parameter 5a 
                //------------------------------------------------------------------
        always 
      @(select_ok)
      begin
         if ((!read_enable) && read_sfdp && (!select_ok) && !qpim)
         begin
            if ($time != 0) $display("%t:  WARNING : read_sfdp Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
         if (read_sfdp && read_enable && !qpim)
         begin
            if (!select_ok)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               
            end
         end

         if ((!read_enable) && read_sfdp && (!select_ok) && qpim)  
         begin
            if ($time != 0) $display("%t:  WARNING : read_sfdp Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 0; 
         end 



        if (read_sfdp && read_enable && qpim) 
         begin  
         if (!select_ok)
             begin
                bit_index <= 1'b0;
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TSHQZ 1'bz;
                wp_bis <= #`TSHQZ 1'bz;
                hold_bis <= #`TSHQZ 1'bz;
                        inhib_read <= `TRUE;

      end

end
end



   always 
      @(negedge c_int)
      begin
        if (read_sfdp && read_enable  && select_ok)
        begin
	    if(int_add[7:0] == 8'h00) iddata_to_read = SFDP_ARRAY[8'h00];
	    if(int_add[7:0] == 8'h01) iddata_to_read = SFDP_ARRAY[8'h01];
	    if(int_add[7:0] == 8'h02) iddata_to_read = SFDP_ARRAY[8'h02];
	    if(int_add[7:0] == 8'h03) iddata_to_read = SFDP_ARRAY[8'h03];
	    if(int_add[7:0] == 8'h04) iddata_to_read = SFDP_ARRAY[8'h04];
	    if(int_add[7:0] == 8'h05) iddata_to_read = SFDP_ARRAY[8'h05];
	    if(int_add[7:0] == 8'h06) iddata_to_read = SFDP_ARRAY[8'h06];
	    if(int_add[7:0] == 8'h07) iddata_to_read = SFDP_ARRAY[8'h07];
	    if(int_add[7:0] == 8'h08) iddata_to_read = SFDP_ARRAY[8'h08];
	    if(int_add[7:0] == 8'h09) iddata_to_read = SFDP_ARRAY[8'h09];
	    if(int_add[7:0] == 8'h0A) iddata_to_read = SFDP_ARRAY[8'h0A];
	    if(int_add[7:0] == 8'h0B) iddata_to_read = SFDP_ARRAY[8'h0B];
	    if(int_add[7:0] == 8'h0C) iddata_to_read = SFDP_ARRAY[8'h0C];
	    if(int_add[7:0] == 8'h0D) iddata_to_read = SFDP_ARRAY[8'h0D];
	    if(int_add[7:0] == 8'h0E) iddata_to_read = SFDP_ARRAY[8'h0E];
	    if(int_add[7:0] == 8'h0F) iddata_to_read = SFDP_ARRAY[8'h0F];

	    if(int_add[7:0] == 8'h10) iddata_to_read = SFDP_ARRAY[8'h10];
	    if(int_add[7:0] == 8'h11) iddata_to_read = SFDP_ARRAY[8'h11];
	    if(int_add[7:0] == 8'h12) iddata_to_read = SFDP_ARRAY[8'h12];
	    if(int_add[7:0] == 8'h13) iddata_to_read = SFDP_ARRAY[8'h13];
	    if(int_add[7:0] == 8'h14) iddata_to_read = SFDP_ARRAY[8'h14];
	    if(int_add[7:0] == 8'h15) iddata_to_read = SFDP_ARRAY[8'h15];
	    if(int_add[7:0] == 8'h16) iddata_to_read = SFDP_ARRAY[8'h16];
	    if(int_add[7:0] == 8'h17) iddata_to_read = SFDP_ARRAY[8'h17];
	    if(int_add[7:0] == 8'h18) iddata_to_read = SFDP_ARRAY[8'h18];
	    if(int_add[7:0] == 8'h19) iddata_to_read = SFDP_ARRAY[8'h19];
	    if(int_add[7:0] == 8'h1A) iddata_to_read = SFDP_ARRAY[8'h1A];
	    if(int_add[7:0] == 8'h1B) iddata_to_read = SFDP_ARRAY[8'h1B];
	    if(int_add[7:0] == 8'h1C) iddata_to_read = SFDP_ARRAY[8'h1C];
	    if(int_add[7:0] == 8'h1D) iddata_to_read = SFDP_ARRAY[8'h1D];
	    if(int_add[7:0] == 8'h1E) iddata_to_read = SFDP_ARRAY[8'h1E];
	    if(int_add[7:0] == 8'h1F) iddata_to_read = SFDP_ARRAY[8'h1F];

	    if(int_add[7:0] == 8'h20) iddata_to_read = SFDP_ARRAY[8'h20];
	    if(int_add[7:0] == 8'h21) iddata_to_read = SFDP_ARRAY[8'h21];
	    if(int_add[7:0] == 8'h22) iddata_to_read = SFDP_ARRAY[8'h22];
	    if(int_add[7:0] == 8'h23) iddata_to_read = SFDP_ARRAY[8'h23];
	    if(int_add[7:0] == 8'h24) iddata_to_read = SFDP_ARRAY[8'h24];
	    if(int_add[7:0] == 8'h25) iddata_to_read = SFDP_ARRAY[8'h25];
	    if(int_add[7:0] == 8'h26) iddata_to_read = SFDP_ARRAY[8'h26];
	    if(int_add[7:0] == 8'h27) iddata_to_read = SFDP_ARRAY[8'h27];
	    if(int_add[7:0] == 8'h28) iddata_to_read = SFDP_ARRAY[8'h28];
	    if(int_add[7:0] == 8'h29) iddata_to_read = SFDP_ARRAY[8'h29];
	    if(int_add[7:0] == 8'h2A) iddata_to_read = SFDP_ARRAY[8'h2A];
	    if(int_add[7:0] == 8'h2B) iddata_to_read = SFDP_ARRAY[8'h2B];
	    if(int_add[7:0] == 8'h2C) iddata_to_read = SFDP_ARRAY[8'h2C];
	    if(int_add[7:0] == 8'h2D) iddata_to_read = SFDP_ARRAY[8'h2D];
	    if(int_add[7:0] == 8'h2E) iddata_to_read = SFDP_ARRAY[8'h2E];
	    if(int_add[7:0] == 8'h2F) iddata_to_read = SFDP_ARRAY[8'h2F];

	    if(int_add[7:0] == 8'h30) iddata_to_read = SFDP_ARRAY[8'h30];
	    if(int_add[7:0] == 8'h31) iddata_to_read = SFDP_ARRAY[8'h31];
	    if(int_add[7:0] == 8'h32) iddata_to_read = SFDP_ARRAY[8'h32];
	    if(int_add[7:0] == 8'h33) iddata_to_read = SFDP_ARRAY[8'h33];
	    if(int_add[7:0] == 8'h34) iddata_to_read = SFDP_ARRAY[8'h34];
	    if(int_add[7:0] == 8'h35) iddata_to_read = SFDP_ARRAY[8'h35];
	    if(int_add[7:0] == 8'h36) iddata_to_read = SFDP_ARRAY[8'h36];
	    if(int_add[7:0] == 8'h37) iddata_to_read = SFDP_ARRAY[8'h37];
	    if(int_add[7:0] == 8'h38) iddata_to_read = SFDP_ARRAY[8'h38];
	    if(int_add[7:0] == 8'h39) iddata_to_read = SFDP_ARRAY[8'h39];
	    if(int_add[7:0] == 8'h3A) iddata_to_read = SFDP_ARRAY[8'h3A];
	    if(int_add[7:0] == 8'h3B) iddata_to_read = SFDP_ARRAY[8'h3B];
	    if(int_add[7:0] == 8'h3C) iddata_to_read = SFDP_ARRAY[8'h3C];
	    if(int_add[7:0] == 8'h3D) iddata_to_read = SFDP_ARRAY[8'h3D];
	    if(int_add[7:0] == 8'h3E) iddata_to_read = SFDP_ARRAY[8'h3E];
	    if(int_add[7:0] == 8'h3F) iddata_to_read = SFDP_ARRAY[8'h3F];
	    
	    if(int_add[7:0] == 8'h40) iddata_to_read = SFDP_ARRAY[8'h40];
	    if(int_add[7:0] == 8'h41) iddata_to_read = SFDP_ARRAY[8'h41];
	    if(int_add[7:0] == 8'h42) iddata_to_read = SFDP_ARRAY[8'h42];
	    if(int_add[7:0] == 8'h43) iddata_to_read = SFDP_ARRAY[8'h43];
	    if(int_add[7:0] == 8'h44) iddata_to_read = SFDP_ARRAY[8'h44];
	    if(int_add[7:0] == 8'h45) iddata_to_read = SFDP_ARRAY[8'h45];
	    if(int_add[7:0] == 8'h46) iddata_to_read = SFDP_ARRAY[8'h46];
	    if(int_add[7:0] == 8'h47) iddata_to_read = SFDP_ARRAY[8'h47];
	    if(int_add[7:0] == 8'h48) iddata_to_read = SFDP_ARRAY[8'h48];
	    if(int_add[7:0] == 8'h49) iddata_to_read = SFDP_ARRAY[8'h49];
	    if(int_add[7:0] == 8'h4A) iddata_to_read = SFDP_ARRAY[8'h4A];
	    if(int_add[7:0] == 8'h4B) iddata_to_read = SFDP_ARRAY[8'h4B];
	    if(int_add[7:0] == 8'h4C) iddata_to_read = SFDP_ARRAY[8'h4C];
	    if(int_add[7:0] == 8'h4D) iddata_to_read = SFDP_ARRAY[8'h4D];
	    if(int_add[7:0] == 8'h4E) iddata_to_read = SFDP_ARRAY[8'h4E];
	    if(int_add[7:0] == 8'h4F) iddata_to_read = SFDP_ARRAY[8'h4F];

	    if(int_add[7:0] == 8'h50) iddata_to_read = SFDP_ARRAY[8'h50];
	    if(int_add[7:0] == 8'h51) iddata_to_read = SFDP_ARRAY[8'h51];
	    if(int_add[7:0] == 8'h52) iddata_to_read = SFDP_ARRAY[8'h52];
	    if(int_add[7:0] == 8'h53) iddata_to_read = SFDP_ARRAY[8'h53];
	    if(int_add[7:0] == 8'h54) iddata_to_read = SFDP_ARRAY[8'h54];
	    if(int_add[7:0] == 8'h55) iddata_to_read = SFDP_ARRAY[8'h55];
	    if(int_add[7:0] == 8'h56) iddata_to_read = SFDP_ARRAY[8'h56];
	    if(int_add[7:0] == 8'h57) iddata_to_read = SFDP_ARRAY[8'h57];
	    if(int_add[7:0] == 8'h58) iddata_to_read = SFDP_ARRAY[8'h58];
	    if(int_add[7:0] == 8'h59) iddata_to_read = SFDP_ARRAY[8'h59];
	    if(int_add[7:0] == 8'h5A) iddata_to_read = SFDP_ARRAY[8'h5A];
	    if(int_add[7:0] == 8'h5B) iddata_to_read = SFDP_ARRAY[8'h5B];
	    if(int_add[7:0] == 8'h5C) iddata_to_read = SFDP_ARRAY[8'h5C];
	    if(int_add[7:0] == 8'h5D) iddata_to_read = SFDP_ARRAY[8'h5D];
	    if(int_add[7:0] == 8'h5E) iddata_to_read = SFDP_ARRAY[8'h5E];
	    if(int_add[7:0] == 8'h5F) iddata_to_read = SFDP_ARRAY[8'h5F];
	    
	    if(int_add[7:0] == 8'h60) iddata_to_read = SFDP_ARRAY[8'h60];
	    if(int_add[7:0] == 8'h61) iddata_to_read = SFDP_ARRAY[8'h61];
	    if(int_add[7:0] == 8'h62) iddata_to_read = SFDP_ARRAY[8'h62];
	    if(int_add[7:0] == 8'h63) iddata_to_read = SFDP_ARRAY[8'h63];
	    if(int_add[7:0] == 8'h64) iddata_to_read = SFDP_ARRAY[8'h64];
	    if(int_add[7:0] == 8'h65) iddata_to_read = SFDP_ARRAY[8'h65];
	    if(int_add[7:0] == 8'h66) iddata_to_read = SFDP_ARRAY[8'h66];
	    if(int_add[7:0] == 8'h67) iddata_to_read = SFDP_ARRAY[8'h67];
	    if(int_add[7:0] == 8'h68) iddata_to_read = SFDP_ARRAY[8'h68];
	    if(int_add[7:0] == 8'h69) iddata_to_read = SFDP_ARRAY[8'h69];
	    if(int_add[7:0] == 8'h6A) iddata_to_read = SFDP_ARRAY[8'h6A];
	    if(int_add[7:0] == 8'h6B) iddata_to_read = SFDP_ARRAY[8'h6B];
	    if(int_add[7:0] == 8'h6C) iddata_to_read = SFDP_ARRAY[8'h6C];
	    if(int_add[7:0] == 8'h6D) iddata_to_read = SFDP_ARRAY[8'h6D];
	    if(int_add[7:0] == 8'h6E) iddata_to_read = SFDP_ARRAY[8'h6E];
	    if(int_add[7:0] == 8'h6F) iddata_to_read = SFDP_ARRAY[8'h6F];
	    
	    if(int_add[7:0] == 8'h70) iddata_to_read = SFDP_ARRAY[8'h70];
	    if(int_add[7:0] == 8'h71) iddata_to_read = SFDP_ARRAY[8'h71];
	    if(int_add[7:0] == 8'h72) iddata_to_read = SFDP_ARRAY[8'h72];
	    if(int_add[7:0] == 8'h73) iddata_to_read = SFDP_ARRAY[8'h73];
	    if(int_add[7:0] == 8'h74) iddata_to_read = SFDP_ARRAY[8'h74];
	    if(int_add[7:0] == 8'h75) iddata_to_read = SFDP_ARRAY[8'h75];
	    if(int_add[7:0] == 8'h76) iddata_to_read = SFDP_ARRAY[8'h76];
	    if(int_add[7:0] == 8'h77) iddata_to_read = SFDP_ARRAY[8'h77];
	    if(int_add[7:0] == 8'h78) iddata_to_read = SFDP_ARRAY[8'h78];
	    if(int_add[7:0] == 8'h79) iddata_to_read = SFDP_ARRAY[8'h79];
	    if(int_add[7:0] == 8'h7A) iddata_to_read = SFDP_ARRAY[8'h7A];
	    if(int_add[7:0] == 8'h7B) iddata_to_read = SFDP_ARRAY[8'h7B];
	    if(int_add[7:0] == 8'h7C) iddata_to_read = SFDP_ARRAY[8'h7C];
	    if(int_add[7:0] == 8'h7D) iddata_to_read = SFDP_ARRAY[8'h7D];
	    if(int_add[7:0] == 8'h7E) iddata_to_read = SFDP_ARRAY[8'h7E];
	    if(int_add[7:0] == 8'h7F) iddata_to_read = SFDP_ARRAY[8'h7F];
	    
	    if(int_add[7:0] == 8'h80) iddata_to_read = SFDP_ARRAY[8'h80];
	    if(int_add[7:0] == 8'h81) iddata_to_read = SFDP_ARRAY[8'h81];
	    if(int_add[7:0] == 8'h82) iddata_to_read = SFDP_ARRAY[8'h82];
	    if(int_add[7:0] == 8'h83) iddata_to_read = SFDP_ARRAY[8'h83];
	    if(int_add[7:0] == 8'h84) iddata_to_read = SFDP_ARRAY[8'h84];
	    if(int_add[7:0] == 8'h85) iddata_to_read = SFDP_ARRAY[8'h85];
	    if(int_add[7:0] == 8'h86) iddata_to_read = SFDP_ARRAY[8'h86];
	    if(int_add[7:0] == 8'h87) iddata_to_read = SFDP_ARRAY[8'h87];
	    if(int_add[7:0] == 8'h88) iddata_to_read = SFDP_ARRAY[8'h88];
	    if(int_add[7:0] == 8'h89) iddata_to_read = SFDP_ARRAY[8'h89];
	    if(int_add[7:0] == 8'h8A) iddata_to_read = SFDP_ARRAY[8'h8A];
	    if(int_add[7:0] == 8'h8B) iddata_to_read = SFDP_ARRAY[8'h8B];
	    if(int_add[7:0] == 8'h8C) iddata_to_read = SFDP_ARRAY[8'h8C];
	    if(int_add[7:0] == 8'h8D) iddata_to_read = SFDP_ARRAY[8'h8D];
	    if(int_add[7:0] == 8'h8E) iddata_to_read = SFDP_ARRAY[8'h8E];
	    if(int_add[7:0] == 8'h8F) iddata_to_read = SFDP_ARRAY[8'h8F];
	    
	    if(int_add[7:0] == 8'h90) iddata_to_read = SFDP_ARRAY[8'h90];
	    if(int_add[7:0] == 8'h91) iddata_to_read = SFDP_ARRAY[8'h91];
	    if(int_add[7:0] == 8'h92) iddata_to_read = SFDP_ARRAY[8'h92];
	    if(int_add[7:0] == 8'h93) iddata_to_read = SFDP_ARRAY[8'h93];
	    if(int_add[7:0] == 8'h94) iddata_to_read = SFDP_ARRAY[8'h94];
	    if(int_add[7:0] == 8'h95) iddata_to_read = SFDP_ARRAY[8'h95];
	    if(int_add[7:0] == 8'h96) iddata_to_read = SFDP_ARRAY[8'h96];
	    if(int_add[7:0] == 8'h97) iddata_to_read = SFDP_ARRAY[8'h97];
	    if(int_add[7:0] == 8'h98) iddata_to_read = SFDP_ARRAY[8'h98];
	    if(int_add[7:0] == 8'h99) iddata_to_read = SFDP_ARRAY[8'h99];
	    if(int_add[7:0] == 8'h9A) iddata_to_read = SFDP_ARRAY[8'h9A];
	    if(int_add[7:0] == 8'h9B) iddata_to_read = SFDP_ARRAY[8'h9B];
	    if(int_add[7:0] == 8'h9C) iddata_to_read = SFDP_ARRAY[8'h9C];
	    if(int_add[7:0] == 8'h9D) iddata_to_read = SFDP_ARRAY[8'h9D];
	    if(int_add[7:0] == 8'h9E) iddata_to_read = SFDP_ARRAY[8'h9E];
	    if(int_add[7:0] == 8'h9F) iddata_to_read = SFDP_ARRAY[8'h9F];
	    
	    if(int_add[7:0] == 8'hA0) iddata_to_read = SFDP_ARRAY[8'hA0];
	    if(int_add[7:0] == 8'hA1) iddata_to_read = SFDP_ARRAY[8'hA1];
	    if(int_add[7:0] == 8'hA2) iddata_to_read = SFDP_ARRAY[8'hA2];
	    if(int_add[7:0] == 8'hA3) iddata_to_read = SFDP_ARRAY[8'hA3];
	    if(int_add[7:0] == 8'hA4) iddata_to_read = SFDP_ARRAY[8'hA4];
	    if(int_add[7:0] == 8'hA5) iddata_to_read = SFDP_ARRAY[8'hA5];
	    if(int_add[7:0] == 8'hA6) iddata_to_read = SFDP_ARRAY[8'hA6];
	    if(int_add[7:0] == 8'hA7) iddata_to_read = SFDP_ARRAY[8'hA7];
	    if(int_add[7:0] == 8'hA8) iddata_to_read = SFDP_ARRAY[8'hA8];
	    if(int_add[7:0] == 8'hA9) iddata_to_read = SFDP_ARRAY[8'hA9];
	    if(int_add[7:0] == 8'hAA) iddata_to_read = SFDP_ARRAY[8'hAA];
	    if(int_add[7:0] == 8'hAB) iddata_to_read = SFDP_ARRAY[8'hAB];
	    if(int_add[7:0] == 8'hAC) iddata_to_read = SFDP_ARRAY[8'hAC];
	    if(int_add[7:0] == 8'hAD) iddata_to_read = SFDP_ARRAY[8'hAD];
	    if(int_add[7:0] == 8'hAE) iddata_to_read = SFDP_ARRAY[8'hAE];
	    if(int_add[7:0] == 8'hAF) iddata_to_read = SFDP_ARRAY[8'hAF];

	    if(int_add[7:0] == 8'hB0) iddata_to_read = SFDP_ARRAY[8'hB0];
	    if(int_add[7:0] == 8'hB1) iddata_to_read = SFDP_ARRAY[8'hB1];
	    if(int_add[7:0] == 8'hB2) iddata_to_read = SFDP_ARRAY[8'hB2];
	    if(int_add[7:0] == 8'hB3) iddata_to_read = SFDP_ARRAY[8'hB3];
	    if(int_add[7:0] == 8'hB4) iddata_to_read = SFDP_ARRAY[8'hB4];
	    if(int_add[7:0] == 8'hB5) iddata_to_read = SFDP_ARRAY[8'hB5];
	    if(int_add[7:0] == 8'hB6) iddata_to_read = SFDP_ARRAY[8'hB6];
	    if(int_add[7:0] == 8'hB7) iddata_to_read = SFDP_ARRAY[8'hB7];
	    if(int_add[7:0] == 8'hB8) iddata_to_read = SFDP_ARRAY[8'hB8];
	    if(int_add[7:0] == 8'hB9) iddata_to_read = SFDP_ARRAY[8'hB9];
	    if(int_add[7:0] == 8'hBA) iddata_to_read = SFDP_ARRAY[8'hBA];
	    if(int_add[7:0] == 8'hBB) iddata_to_read = SFDP_ARRAY[8'hBB];
	    if(int_add[7:0] == 8'hBC) iddata_to_read = SFDP_ARRAY[8'hBC];
	    if(int_add[7:0] == 8'hBD) iddata_to_read = SFDP_ARRAY[8'hBD];
	    if(int_add[7:0] == 8'hBE) iddata_to_read = SFDP_ARRAY[8'hBE];
	    if(int_add[7:0] == 8'hBF) iddata_to_read = SFDP_ARRAY[8'hBF];

	    if(int_add[7:0] == 8'hC0) iddata_to_read = SFDP_ARRAY[8'hC0];
	    if(int_add[7:0] == 8'hC1) iddata_to_read = SFDP_ARRAY[8'hC1];
	    if(int_add[7:0] == 8'hC2) iddata_to_read = SFDP_ARRAY[8'hC2];
	    if(int_add[7:0] == 8'hC3) iddata_to_read = SFDP_ARRAY[8'hC3];
	    if(int_add[7:0] == 8'hC4) iddata_to_read = SFDP_ARRAY[8'hC4];
	    if(int_add[7:0] == 8'hC5) iddata_to_read = SFDP_ARRAY[8'hC5];
	    if(int_add[7:0] == 8'hC6) iddata_to_read = SFDP_ARRAY[8'hC6];
	    if(int_add[7:0] == 8'hC7) iddata_to_read = SFDP_ARRAY[8'hC7];
	    if(int_add[7:0] == 8'hC8) iddata_to_read = SFDP_ARRAY[8'hC8];
	    if(int_add[7:0] == 8'hC9) iddata_to_read = SFDP_ARRAY[8'hC9];
	    if(int_add[7:0] == 8'hCA) iddata_to_read = SFDP_ARRAY[8'hCA];
	    if(int_add[7:0] == 8'hCB) iddata_to_read = SFDP_ARRAY[8'hCB];
	    if(int_add[7:0] == 8'hCC) iddata_to_read = SFDP_ARRAY[8'hCC];
	    if(int_add[7:0] == 8'hCD) iddata_to_read = SFDP_ARRAY[8'hCD];
	    if(int_add[7:0] == 8'hCE) iddata_to_read = SFDP_ARRAY[8'hCE];
	    if(int_add[7:0] == 8'hCF) iddata_to_read = SFDP_ARRAY[8'hCF];
	    
	    if(int_add[7:0] == 8'hD0) iddata_to_read = SFDP_ARRAY[8'hD0];
	    if(int_add[7:0] == 8'hD1) iddata_to_read = SFDP_ARRAY[8'hD1];
	    if(int_add[7:0] == 8'hD2) iddata_to_read = SFDP_ARRAY[8'hD2];
	    if(int_add[7:0] == 8'hD3) iddata_to_read = SFDP_ARRAY[8'hD3];
	    if(int_add[7:0] == 8'hD4) iddata_to_read = SFDP_ARRAY[8'hD4];
	    if(int_add[7:0] == 8'hD5) iddata_to_read = SFDP_ARRAY[8'hD5];
	    if(int_add[7:0] == 8'hD6) iddata_to_read = SFDP_ARRAY[8'hD6];
	    if(int_add[7:0] == 8'hD7) iddata_to_read = SFDP_ARRAY[8'hD7];
	    if(int_add[7:0] == 8'hD8) iddata_to_read = SFDP_ARRAY[8'hD8];
	    if(int_add[7:0] == 8'hD9) iddata_to_read = SFDP_ARRAY[8'hD9];
	    if(int_add[7:0] == 8'hDA) iddata_to_read = SFDP_ARRAY[8'hDA];
	    if(int_add[7:0] == 8'hDB) iddata_to_read = SFDP_ARRAY[8'hDB];
	    if(int_add[7:0] == 8'hDC) iddata_to_read = SFDP_ARRAY[8'hDC];
	    if(int_add[7:0] == 8'hDD) iddata_to_read = SFDP_ARRAY[8'hDD];
	    if(int_add[7:0] == 8'hDE) iddata_to_read = SFDP_ARRAY[8'hDE];
	    if(int_add[7:0] == 8'hDF) iddata_to_read = SFDP_ARRAY[8'hDF];
 	    
	    if(int_add[7:0] == 8'hE0) iddata_to_read = SFDP_ARRAY[8'hE0];
	    if(int_add[7:0] == 8'hE1) iddata_to_read = SFDP_ARRAY[8'hE1];
	    if(int_add[7:0] == 8'hE2) iddata_to_read = SFDP_ARRAY[8'hE2];
	    if(int_add[7:0] == 8'hE3) iddata_to_read = SFDP_ARRAY[8'hE3];
	    if(int_add[7:0] == 8'hE4) iddata_to_read = SFDP_ARRAY[8'hE4];
	    if(int_add[7:0] == 8'hE5) iddata_to_read = SFDP_ARRAY[8'hE5];
	    if(int_add[7:0] == 8'hE6) iddata_to_read = SFDP_ARRAY[8'hE6];
	    if(int_add[7:0] == 8'hE7) iddata_to_read = SFDP_ARRAY[8'hE7];
	    if(int_add[7:0] == 8'hE8) iddata_to_read = SFDP_ARRAY[8'hE8];
	    if(int_add[7:0] == 8'hE9) iddata_to_read = SFDP_ARRAY[8'hE9];
	    if(int_add[7:0] == 8'hEA) iddata_to_read = SFDP_ARRAY[8'hEA];
	    if(int_add[7:0] == 8'hEB) iddata_to_read = SFDP_ARRAY[8'hEB];
	    if(int_add[7:0] == 8'hEC) iddata_to_read = SFDP_ARRAY[8'hEC];
	    if(int_add[7:0] == 8'hED) iddata_to_read = SFDP_ARRAY[8'hED];
	    if(int_add[7:0] == 8'hEE) iddata_to_read = SFDP_ARRAY[8'hEE];
	    if(int_add[7:0] == 8'hEF) iddata_to_read = SFDP_ARRAY[8'hEF];
	    
	    if(int_add[7:0] == 8'hF0) iddata_to_read = SFDP_ARRAY[8'hF0];
	    if(int_add[7:0] == 8'hF1) iddata_to_read = SFDP_ARRAY[8'hF1];
	    if(int_add[7:0] == 8'hF2) iddata_to_read = SFDP_ARRAY[8'hF2];
	    if(int_add[7:0] == 8'hF3) iddata_to_read = SFDP_ARRAY[8'hF3];
	    if(int_add[7:0] == 8'hF4) iddata_to_read = SFDP_ARRAY[8'hF4];
	    if(int_add[7:0] == 8'hF5) iddata_to_read = SFDP_ARRAY[8'hF5];
	    if(int_add[7:0] == 8'hF6) iddata_to_read = SFDP_ARRAY[8'hF6];
	    if(int_add[7:0] == 8'hF7) iddata_to_read = SFDP_ARRAY[8'hF7];
	    if(int_add[7:0] == 8'hF8) iddata_to_read = SFDP_ARRAY[8'hF8];
	    if(int_add[7:0] == 8'hF9) iddata_to_read = SFDP_ARRAY[8'hF9];
	    if(int_add[7:0] == 8'hFA) iddata_to_read = SFDP_ARRAY[8'hFA];
	    if(int_add[7:0] == 8'hFB) iddata_to_read = SFDP_ARRAY[8'hFB];
	    if(int_add[7:0] == 8'hFC) iddata_to_read = SFDP_ARRAY[8'hFC];
	    if(int_add[7:0] == 8'hFD) iddata_to_read = SFDP_ARRAY[8'hFD];
	    if(int_add[7:0] == 8'hFE) iddata_to_read = SFDP_ARRAY[8'hFE];
	    if(int_add[7:0] == 8'hFF) iddata_to_read = SFDP_ARRAY[8'hFF];
	    
		if(adress_2[1:0]==0 && !read_uid)begin
	    	if(qpim)
	    	begin
	    	    hold_bis <= #`TCLQV iddata_to_read[7 - bit_index*4] ;
        	    wp_bis <= #`TCLQV iddata_to_read[6 - bit_index*4] ;
        	    q_bis <= #`TCLQV iddata_to_read[5 - bit_index*4] ; 
        	    d_bis <= #`TCLQV iddata_to_read[4 - bit_index*4] ;
        	    bit_index = bit_index + 1;
        	    if(bit_index > 1)   bit_index = 0;

        	end else if(!qpim)
	    	begin
	    	    d_bis <= #`TSHQZ 1'bz ;
        	    q_bis <= #`TCLQV  iddata_to_read[7 - bit_index] ; 
        	    wp_bis <= #`TSHQZ 1'bz ;
        	    hold_bis <= #`TSHQZ 1'bz ;
        	    bit_index <= bit_index + 1 ;
	    	end	
		end

		else begin
	    	if(qpim)
	    	begin
	    	    hold_bis <= #`TCLQV 1 ;
        	    wp_bis <= #`TCLQV 1 ;
        	    q_bis <= #`TCLQV 1 ; 
        	    d_bis <= #`TCLQV 1 ;
        	    bit_index = bit_index + 1;
        	    if(bit_index > 1)   bit_index = 0;

        	end else if(!qpim)
	    	begin
	    	    d_bis <= #`TSHQZ 1'bz ;
        	    q_bis <= #`TCLQV   1 ; 
        	    wp_bis <= #`TSHQZ 1'bz ;
        	    hold_bis <= #`TSHQZ 1'bz ;
        	    bit_index <= bit_index + 1 ;
	    	end	


		end



	end
    end

 
     //------------------------------------------------------------------
      // OTP_Read
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         if ((!read_enable) && otprd && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : otprd Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
         if (otprd && read_enable)
         begin
            if (!select_ok)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               
            end
         end
      end
  
   always 
      @(negedge c_int)
      begin
	/////spi mode  48h output
         if (otprd && read_enable  && select_ok && (!qpim))
         begin
               d_bis <= #`TSHQZ 1'bz ;
               q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               bit_index <= bit_index + 1 ;
         end
	 
         else if (otprd && read_enable && (select_ok) && (!qpim))
         begin
             if (suspend_otppgm && !suspend_otpers) 
              begin 
                if ({suspend_add[13:12],suspend_add[9:8]} == {int_add[13:12],int_add[9:8]})                       
                   begin
                        bit_index <= 8'b00000000; 
                        d_bis <= #`TSHQZ 1'bx ;
                       q_bis <=  #`TSHQZ 1'bx;
                       wp_bis <= #`TSHQZ 1'bx ;
                       hold_bis <= #`TSHQZ 1'bx ;  
                   end
            
                else 
                    begin
                        d_bis <= #`TSHQZ 1'bz ;
                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                        wp_bis <= #`TSHQZ 1'bz ;
                        hold_bis <= #`TSHQZ 1'bz ;
                        bit_index <= bit_index + 1; 
                    end  
                end                      
             else if (suspend_otppgm && suspend_otpers) 
               begin                    

                if ({ers_add[13:12],ers_add[9:8]} == {int_add[13:12],int_add[9:8]})
                   begin
                        bit_index <= 8'b00000000; 
                        d_bis <= #`TSHQZ 1'bx ;
                       q_bis <=  #`TSHQZ 1'bx;
                       wp_bis <= #`TSHQZ 1'bx ;
                       hold_bis <= #`TSHQZ 1'bx ;  
                   end
            
                else
                    begin
                        d_bis <= #`TSHQZ 1'bz ;
                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                        wp_bis <= #`TSHQZ 1'bz ;
                        hold_bis <= #`TSHQZ 1'bz ;
                        bit_index <= bit_index + 1; 
                    end  


               end

            else if(!suspend_otppgm && suspend_otpers)
               begin                    

                if ({ers_add[13:12],ers_add[9:8]} == {int_add[13:12],int_add[9:8]})  
                  begin
                        bit_index <= 8'b00000000; 
                        d_bis <= #`TSHQZ 1'bx ;
                       q_bis <=  #`TSHQZ 1'bx;
                       wp_bis <= #`TSHQZ 1'bx ;
                       hold_bis <= #`TSHQZ 1'bx ;  
                   end
            
                else
                    begin
                        d_bis <= #`TSHQZ 1'bz ;
                        q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                        wp_bis <= #`TSHQZ 1'bz ;
                        hold_bis <= #`TSHQZ 1'bz ;
                        bit_index <= bit_index + 1; 
                    end  


               end

            else 
              begin
                 d_bis <= #`TSHQZ 1'bz ;
                 q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                 wp_bis <= #`TSHQZ 1'bz ;
                 hold_bis <= #`TSHQZ 1'bz ;
                 bit_index <= bit_index + 1 ;
              end   
         end
     
         
	/////qpi mode  48h output 
	if (otprd && read_enable && (!suspend_enable) && select_ok && (qpim))
         begin
	    hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
            wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
            q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
            d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
            bit_index <= bit_index + 1 ;
            if (bit_index == 1)
            begin
               bit_index <= 0;
            end
         end
	 
         else if (otprd && read_enable && (suspend_enable) && (select_ok) && (qpim))
         begin
             if (suspend_otppgm && !suspend_otpers) 
              begin 
                if ({suspend_add[13:12],suspend_add[9:8]} == {int_add[13:12],int_add[9:8]})                       
                   begin
                        bit_index <= 8'b00000000; 
                        d_bis <= #`TSHQZ 1'bx ;
                       q_bis <=  #`TSHQZ 1'bx;
                       wp_bis <= #`TSHQZ 1'bx ;
                       hold_bis <= #`TSHQZ 1'bx ;  
                   end
            
                else 
                    begin
                        hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                        wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                        q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                        d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                        bit_index <= bit_index + 1 ;
                        if (bit_index == 1)
                        begin
                        bit_index <= 0;
                        end
                    end  
                end                      
             else if (suspend_otppgm && suspend_otpers) 
               begin                    

                if ({ers_add[13:12],ers_add[9:8]} == {int_add[13:12],int_add[9:8]})
                   begin
                        bit_index <= 8'b00000000; 
                        d_bis <= #`TSHQZ 1'bx ;
                       q_bis <=  #`TSHQZ 1'bx;
                       wp_bis <= #`TSHQZ 1'bx ;
                       hold_bis <= #`TSHQZ 1'bx ;  
                   end
            
                else
                    begin
			hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                        wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                        q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                        d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                        bit_index <= bit_index + 1 ;
                        if (bit_index == 1)
                        begin
                        bit_index <= 0;
                        end 
                    end  


               end

            else if(!suspend_otppgm && suspend_otpers)
               begin                    

                if ({ers_add[13:12],ers_add[9:8]} == {int_add[13:12],int_add[9:8]})  
                  begin
                        bit_index <= 8'b00000000; 
                        d_bis <= #`TSHQZ 1'bx ;
                       q_bis <=  #`TSHQZ 1'bx;
                       wp_bis <= #`TSHQZ 1'bx ;
                       hold_bis <= #`TSHQZ 1'bx ;  
                   end
            
                else
                    begin
			hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                        wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                        q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                        d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                        bit_index <= bit_index + 1 ;
                        if (bit_index == 1)
                        begin
                        bit_index <= 0;
                        end 

                    end  


               end

            else 
              begin
                 d_bis <= #`TSHQZ 1'bz ;
                 q_bis <= #`TCLQV data_to_read[7 - bit_index] ; 
                 wp_bis <= #`TSHQZ 1'bz ;
                 hold_bis <= #`TSHQZ 1'bz ;
                 bit_index <= bit_index + 1 ;
              end   
         end
     end

 
     
     //------------------------------------------------------------------
      // DOFR
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
        if (dofr && (!read_enable) && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : dofr Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end

         if (dofr && read_enable)    //4byte mode
         begin
            if (!select_ok)
            begin
              
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
            end
         end
      end

 
   always 
      @(negedge c_int)
      begin
	if ( dofr && read_enable && (!suspend_enable) && select_ok)
         begin
            q_bis <= #`TCLQV data_to_read[7 - bit_index *2 ] ; 
               d_bis <= #`TCLQV data_to_read[6 - bit_index *2 ] ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               bit_index <=  bit_index + 1 ;
               if (bit_index == 3)
               begin
               bit_index <=  0 ;
               end 
              
         end

	else if (dofr && read_enable && suspend_enable && (select_ok))
         begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                end 
                end
          end
  end
     
     always 
      @(negedge c_int)
      begin
         if (dofr && read_enable)
         begin
            if (cpt==3)
            begin
              cpt<= 0 ;
             end
           end
       end
     
      always 
      @(posedge c_int)
      begin
         if (dofr && read_enable)
         begin
            if (cpt==3)
            begin
              byte_ok <= `TRUE ;
             end
           end
       end
     
      //------------------------------------------------------------------
      // QOFR
      //------------------------------------------------------------------

   always 
      @(select_ok)
      begin
         if (qofr && (!read_enable) && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : qofr Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end

         if (qofr && read_enable)
         begin
            if (!select_ok)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
                
            end
         end
      end
         
   always 
      @(negedge c_int)
      begin
         if (qofr && read_enable && (!suspend_enable) && select_ok)
         begin
                     
               hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
               wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
               q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
               d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
               bit_index <=  bit_index + 1 ;
               if (bit_index ==1)
               begin
               bit_index <=  0;
               end
         end
         else if (qofr && read_enable && (suspend_enable) && (select_ok))
           
         begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end

                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                end
          end
                
     end
         
      always 
      @(negedge c_int)
      begin
         if (qofr && (read_enable))
         begin
            if (cpt==1)
            begin
             cpt<= 0 ;
             end
           end
       end
       
        always 
      @(posedge c_int)
      begin
         if (qofr && (read_enable))
         begin
            if (cpt==1)
            begin
             byte_ok <= `TRUE ;
             end
           end
       end
    
      //------------------------------------------------------------------
      // DIOFR
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         
         if (diofr && (!read_enable) && (!select_ok))
         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : diofr Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 

        if (diofr && read_enable && (!select_ok))
         begin
            if (!diofr_crm_flag)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
                
              
            end
            if (diofr_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               
            end
           
         end
      end
  
   always 
      @(negedge c_int)
      begin
         
         if (diofr && read_enable && (!suspend_enable))
         begin
            if (select_ok)
            begin
               q_bis <= #`TCLQV data_to_read[ 7 - bit_index * 2 ] ; 
               d_bis <= #`TCLQV data_to_read[ 6 - bit_index * 2 ] ;
              
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               bit_index <= bit_index + 1 ;
               if (bit_index == 3)
               begin
               bit_index <= 0;
               end
            end 
         end
         
         else if (diofr && read_enable && (suspend_enable) && (select_ok))
           
         begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                q_bis <= #`TCLQV data_to_read[7 - bit_index*2] ; 
                                                d_bis <= #`TCLQV data_to_read[6 - bit_index*2] ;
                                                wp_bis <= #`TSHQZ 1'bz ;
                                                hold_bis <= #`TSHQZ 1'bz ;
                                                bit_index <=  bit_index + 1 ;
                                                if (bit_index == 3)
                                                begin
                                                bit_index <=   0;
                                                end 
                                end 
                end
          end
     end
     
     always 
      @(negedge c_int)
      begin
         if (diofr && read_enable)
         begin
            if (cpt==3)
            begin
              cpt<= 0 ;
             end
           end
       end
     
      always 
      @(posedge c_int)
      begin
         if (diofr && read_enable)
         begin
            if (cpt==3)
            begin
              byte_ok <= `TRUE  ;
             end
         end
         
         
       end
    





      //------------------------------------------------------------------
      // Manufacturer/Device ID by Dual I/O
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
        if (!manu_device_id_dual )
         begin
            inhib_manu_device_id_dual <= `FALSE;
            bit_index <= 8'b00000000; 
         end   

         
         if ((!read_enable) && manu_device_id_dual && (!select_ok))
         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : manu_device_id_dual Instruction canceled because the chip is deselected",$realtime); 
            inhib_manu_device_id_dual <= `TRUE ; 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 

         end 
        if (manu_device_id_dual && read_enable && (!select_ok))
         begin
            if (!manu_device_id_dual_crm_flag)
            begin
               inhib_manu_device_id_dual <= `TRUE ; 
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;

            end
            if (manu_device_id_dual_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               wp_bis <= #`TSHQZ 1'bz ;
               hold_bis <= #`TSHQZ 1'bz ;
               
            end
           
         end
      end
  
   always 
      @(negedge c_int)
      begin
         
         if (manu_device_id_dual && read_enable)
         begin
            if (select_ok)
            begin
                if(adress_3[0] == 1'b0)
                begin
                        q_bis <= #`TCLQV did0[ 15 - bit_index * 2 ] ; 
                        d_bis <= #`TCLQV did0[ 14 - bit_index * 2 ] ;
                        wp_bis <= #`TSHQZ 1'bz ;
                        hold_bis <= #`TSHQZ 1'bz ;
                end
                else if (adress_3[0] == 1'b1)
                begin
                        q_bis <= #`TCLQV did1[ 15 - bit_index * 2 ] ; 
                        d_bis <= #`TCLQV did1[ 14 - bit_index * 2 ] ;
                        wp_bis <= #`TSHQZ 1'bz ;
                        hold_bis <= #`TSHQZ 1'bz ;

                end
                else
                begin
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TSHQZ 1'bz;
                wp_bis <= #`TSHQZ 1'bz ;
                hold_bis <= #`TSHQZ 1'bz ;
                end 

               bit_index <= bit_index + 1 ;
               if (bit_index == 7)
               begin
               bit_index <= 0;
               end
            end 
         end
     end
     
     always 
      @(negedge c_int)
      begin
         if (manu_device_id_dual && read_enable)
         begin
            if (cpt==3)
            begin
              cpt<= 0 ;
             end
           end
       end
     
      always 
      @(posedge c_int)
      begin
         if (manu_device_id_dual && read_enable)
         begin
            if (cpt==3)
            begin
              byte_ok <= `TRUE  ;
             end
         end
         
       end

      //------------------------------------------------------------------
      // QIOFR
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         if (qiofr && (!read_enable) && (!select_ok) && !qpim)

         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : qiofr Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end

         if (qiofr && read_enable && (!qpim) && (!select_ok))
         begin
            if (!qiofr_crm_flag)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
            end
	    
            if (qiofr_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               
            end
         end


//-----------qpi mode added --------------------
         if (qiofr && (!read_enable) && (!select_ok) && qpim)
         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : qiofr Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 


         if (qiofr && read_enable && qpim && (!select_ok))
         begin
            if (!qiofr_crm_flag)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;

               
            end
            if (qiofr_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               
            end
         end
      end
 
   always 
      @(negedge c_int)
      begin
         
         if (qiofr && read_enable && (!suspend_enable) && select_ok)
         begin
               hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
               wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
               q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
               d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
               bit_index <= bit_index + 1 ;
               if (bit_index == 1)
               begin
               bit_index <= 0;
               end
         end


         else if (qiofr && read_enable && (suspend_enable) && (select_ok))
         begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end

                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                end
          end
           
     end

     
 always 
      @(negedge c_int)
      begin
         if (qiofr && (read_enable))
         begin
            if (cpt==1)
            begin
             cpt<= 0 ;
             end
           end
       end
       
 always 
      @(posedge c_int)
      begin
         if (qiofr && (read_enable))
         begin
            if (cpt==1)
            begin
             byte_ok <= `TRUE  ;
             end
         end
         
       end
     
     


      //------------------------------------------------------------------
      // Manufacturer/Device ID by Quad I/O
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         if (!manu_device_id_quad )
         begin
            inhib_manu_device_id_quad <= `FALSE;
            bit_index <= 1'b0;
         end  


         if ((!read_enable) && manu_device_id_quad && (!select_ok) && !qpim)

         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : manu_device_id_quad Instruction canceled because the chip is deselected",$realtime); 
            inhib_manu_device_id_quad <= `TRUE ; 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
         if (manu_device_id_quad && read_enable && (!select_ok))
         begin
            if (!manu_device_id_quad_crm_flag)
            begin
            inhib_manu_device_id_quad <= `TRUE ; 
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;

               
            end
            if (manu_device_id_quad_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
               
            end
         end
      end
 
   always 
      @(negedge c_int)
      begin
         
         if (manu_device_id_quad && read_enable)
         begin
            if (select_ok)
            begin
                if(adress_3[0] == 1'b0)
                begin
                        hold_bis <= #`TCLQV did0[15 - bit_index*4] ;
                        wp_bis <= #`TCLQV did0[14 - bit_index*4] ;
                        q_bis <= #`TCLQV did0[13 - bit_index*4] ; 
                        d_bis <= #`TCLQV did0[12 - bit_index*4] ;
                end
                else if (adress_3[0] == 1'b1)
                begin
                        hold_bis <= #`TCLQV did1[15 - bit_index*4] ;
                        wp_bis <= #`TCLQV did1[14 - bit_index*4] ;
                        q_bis <= #`TCLQV did1[13 - bit_index*4] ; 
                        d_bis <= #`TCLQV did1[12 - bit_index*4] ;
                end
                else
                begin
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TSHQZ 1'bz;
                wp_bis <= #`TSHQZ 1'bz ;
                hold_bis <= #`TSHQZ 1'bz ;
                end 
               bit_index <= bit_index + 1 ;
               if (bit_index == 3)
               begin
               bit_index <= 0;
               end

            end 
         end
     end

     
 always 
      @(negedge c_int)
      begin
         if (manu_device_id_quad && (read_enable))
         begin
            if (cpt==1)
            begin
             cpt<= 0 ;
             end
           end
       end
       
 always 
      @(posedge c_int)
      begin
         if (manu_device_id_quad && (read_enable))
         begin
            if (cpt==1)
            begin
             byte_ok <= `TRUE  ;
             end
         end
         

       end


      //------------------------------------------------------------------
      // QIOWFR E7H
      //------------------------------------------------------------------
   always 
      @(select_ok)
      begin
         if (qiowfr && (!read_enable) && (!select_ok))
         begin
            if (($time != 0) && ~reset_66h) $display("%t:  WARNING : qiowfr Instruction canceled because the chip is deselected",$realtime); 
            inhib_read <= `TRUE ; 
            bit_index <= 8'b00000000; 
         end 
	 
         if (qiowfr && read_enable && (!select_ok))
         begin
            if (!qiowfr_crm_flag)
            begin
               inhib_read <= `TRUE ; 
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
                
            end
            if (qiowfr_crm_flag)
            begin
               read_enable <= `FALSE;
               bit_index <= 8'b00000000; 
               hold_bis<= #`TSHQZ 1'bz ; 
               wp_bis<= #`TSHQZ 1'bz ; 
               q_bis <= #`TSHQZ 1'bz ; 
               d_bis <= #`TSHQZ 1'bz ;
                
            end
            
            
         end
      end
   
   always 
      @(negedge c_int)
      begin
      
         if (qiowfr && read_enable && (!suspend_enable) && select_ok)
         begin
               hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
               wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
               q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
               d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
               bit_index <= bit_index + 1 ;
               if (bit_index == 1)
               begin
               bit_index <= 0;
               end
         end
         else if (qiowfr && read_enable && (suspend_enable) && (select_ok))
           
         begin
                if (pgmsp)
                begin
                        if(ersp)
                        begin
                                if (suspend_ser) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end

                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if((ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16]) || (suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8]))
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                        end
                        else
                        begin
                                if (suspend_pp || suspend_quadpgm || suspend_ex_quadpgm)  
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):8] == int_add[(`BIT_TO_CODE_MEM-1):8])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;  
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otppgm )
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end  
                        end
                end
                else if(ersp)   
                begin

                                if (suspend_ser) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber32) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end

                                if (suspend_ber64) 
                                begin
                                        if(suspend_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])
                                        begin
                                                bit_index <= 8'b00000000; 
                                                d_bis <= #`TSHQZ 1'bx ;
                                                q_bis <=  #`TSHQZ 1'bx;
                                                wp_bis <= #`TSHQZ 1'bx ;
                                                hold_bis <= #`TSHQZ 1'bx ;   
                                        end
                                        else
                                        begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                        end
                                end
                                if (suspend_otpers)
                                begin
                                                hold_bis <= #`TCLQV data_to_read[7 - bit_index*4] ;
                                                wp_bis <= #`TCLQV data_to_read[6 - bit_index*4] ;
                                                q_bis <= #`TCLQV data_to_read[5 - bit_index*4] ; 
                                                d_bis <= #`TCLQV data_to_read[4 - bit_index*4] ;
                                                bit_index <= bit_index + 1 ;
                                                if (bit_index == 1)
                                                begin
                                                bit_index <= 0;
                                                end
                                end 
                end
          end
            
     end
        
     
 always 
      @(negedge c_int)
      begin
         if ( qiowfr && (read_enable))
         begin
            if (cpt==1)
            begin
             cpt<= 0 ;
             end
           end
       end
       
 always 
      @(posedge c_int)
      begin
         if ( qiowfr && (read_enable))
         begin
            if (cpt==1)
            begin
             byte_ok <= `TRUE  ;
             end
           end

         
       end
     
       //-----------------------------------------
      // CONTINUOUS READ MODE RESET
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!crmr)
         begin
            inhib_crmr <= `FALSE ; 
         end
         if (crmr && (!only_rdsr))
         begin
            if (!select_ok)
            begin
                reset_crmr <= 1'b1;
                inhib_crmr <= `TRUE ; 
            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (crmr && (!only_rdsr) && select_ok)
         begin
            inhib_crmr <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : crmr Instruction canceled because the chip is still selected",$realtime); 
         end
      end 

      //-----------------------------------------
      // Write_enable 
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!wren)
         begin
            inhib_wren <= `FALSE ; 
         end
         if (wren && (!only_rdsr))
         begin
            if (!select_ok)
            begin
               wel <= 1'b1 ; 
               inhib_wren <= `TRUE ; 
            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (wren && (!only_rdsr) && select_ok)
         begin
            inhib_wren <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : wren Instruction canceled because the chip is still selected",$realtime); 
         end
      end

      
      //-----------------------------------------
      // clear_sr_flags 30h
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!clear_sr_flags)
         begin
            inhib_clear_sr_flags <= `FALSE ; 
         end
         if (clear_sr_flags && (!only_rdsr))
         begin
            if (!select_ok)
            begin
               EE <= 1'b0;
	       PE <= 1'b0;
               inhib_clear_sr_flags <= `TRUE ; 
            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (clear_sr_flags && (!only_rdsr) && select_ok)
         begin
            inhib_clear_sr_flags <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : clear_sr_flags Instruction canceled because the chip is still selected",$realtime);
         end
      end


    //-----------------------------------------
      // enable_4byte_mode B7h
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!enable_4byte_mode)
         begin
            inhib_enable_4byte_mode <= `FALSE ; 
         end
         if (enable_4byte_mode && (!only_rdsr))
         begin
            if (!select_ok)
            begin
               ADS <= 1'b1;
               inhib_enable_4byte_mode <= `TRUE ; 
            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (enable_4byte_mode && (!only_rdsr) && select_ok)
         begin
            inhib_enable_4byte_mode <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : enable_4byte_mode Instruction canceled because the chip is still selected",$realtime);
         end
      end




      //-----------------------------------------
      // disable_4byte_mode e9h
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!disable_4byte_mode)
         begin
            inhib_disable_4byte_mode <= `FALSE ; 
         end
         if (disable_4byte_mode && (!only_rdsr))
         begin
            if (!select_ok)
            begin
               ADS <= 1'b0;
               inhib_disable_4byte_mode <= `TRUE ; 
            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (disable_4byte_mode && (!only_rdsr) && select_ok)
         begin
            inhib_disable_4byte_mode <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : enable_3byte_mode Instruction canceled because the chip is still selected",$realtime);
         end
      end
      
      //-----------------------------------------
      // Reset enable 66h
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!reset_66h)
         begin
            inhib_reset_66h <= `FALSE ; 
         end

         if (!select_ok)
         begin
             if(reset_66h)
             begin
                reset_enable <= `TRUE ; 
                inhib_reset_66h <= `TRUE ; 
             end
             else       reset_enable <= `FALSE ;
         end
      end

   always 
      @(posedge c_int)
      begin
         if (reset_66h && (!only_rdsr) && select_ok)
         begin
            inhib_reset_66h <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : reset_66h Instruction canceled because the chip is still selected",$realtime); 
         end
      end

                //-----------------------------------------
      // Reset HOLD 
      //-----------------------------------------

                always@(negedge hold)
                begin
                        if(!QE & HOLD_reset & (select_ok == 1'b0))
                        begin
                                HW_RST =`TRUE;
                                disable page_pgm_process;
                                disable quad_pgm_process;
                                disable otp_pgm_process;
                                disable chip_ers_process;
                                disable ber32_process;
                                disable ber64_process;
                                disable ser_process;
                                disable otp_ers_process;
                                disable wrsr_process;
                                disable ers_pgm_resume_process;
                                disable erase_pgm_susp_process;

                only_rdsr      = `FALSE;
                only_suspend   = `FALSE;
                select_ok      = `FALSE;
                raz            = `FALSE;
                byte_ok        = `FALSE;
        
                cpt         = 0;
                cpt_rst         = 0;
                byte_cpt    = 0;

                data_to_write  = 8'bxxxxxxxx;
                data_latch     = 8'bxxxxxxxx;
                read_data_request <= `FALSE;
                write_data_request <= `FALSE;
                
                wren          = `FALSE;
                reset_66h          = `FALSE;
                reset_99h          = `FALSE;
                reset_enable          = `FALSE;
                vwsr_enable          = `FALSE;
                vwsr          = `FALSE;
                wrdi          = `FALSE;
                rdsr_l        = `FALSE;  
                rdsr_m        = `FALSE; 
                rdsr_h        = `FALSE;  
               
		rd_ex_addr  = `FALSE;    //2008
		wr_ex_addr  = `FALSE;	

		rd_configuration_reg = `FALSE; //5109 cmlin
		wr_configuration_reg = `FALSE; //5109 cmlin
                read_data_3byte   = `FALSE;
                read_data_4byte   = `FALSE;
                fast_read_3byte   = `FALSE;
                fast_read_4byte   = `FALSE;

                DTR_single_read = `FALSE;
                
                dofr_3byte        = `FALSE;   
                dofr_4byte        = `FALSE;   

                diofr_3byte       = `FALSE;
                diofr_4byte       = `FALSE;

                qofr_3byte        = `FALSE;
                qofr_4byte        = `FALSE;

                qiofr_3byte       = `FALSE;
                qiofr_4byte       = `FALSE;

                qiowfr      = `FALSE;
                otprd       = `FALSE;  //new add cmd otprd
                manu_device_id_dual       = `FALSE;
                manu_device_id_quad       = `FALSE;
                
                
                diofr_crm_flag  = `FALSE;
                qiofr_crm_flag  = `FALSE;
                qiowfr_crm_flag = `FALSE;
                manu_device_id_dual_crm_flag  = `FALSE;
                manu_device_id_quad_crm_flag  = `FALSE;
                crmr        = `FALSE;
                crmr_flag   = `FALSE;
                ers_suspend_flag   = `FALSE;
                pgm_suspend_flag   = `FALSE;


                qpim      = `FALSE;
                wrapset   = `FALSE;
                wrap_8byte  = `FALSE; 
                wrap_16byte  = `TRUE; 
                wrap_32byte  = `FALSE; 
                wrap_64byte  = `FALSE; 

                set_read_para     = `FALSE;
                qpi_wrap_8byte  = `FALSE ; 
                qpi_wrap_16byte  = `FALSE; 
                qpi_wrap_32byte  = `FALSE; 
                qpi_wrap_64byte  = `FALSE; 
                qpi_dummy_4clk   = `TRUE;
                qpi_dummy_6clk   = `FALSE;
                qpi_dummy_8clk   = `FALSE;
                pp_3byte              = `FALSE;
		pp_4byte    =	`FALSE;
                quadpgm_3byte         = `FALSE;   
                quadpgm_4byte         = `FALSE;   
		ex_quadpgm_3byte	= `FALSE;
		ex_quadpgm_4byte	= `FALSE;
	
                otppgm          = `FALSE;
                otpers          = `FALSE;      
		ser_3byte            = `FALSE;
                ser_4byte            = `FALSE;

                ber32_3byte         = `FALSE;
                ber32_4byte         = `FALSE;
                ber64_3byte         = `FALSE;
                ber64_4byte         = `FALSE;
                  
                cer       = `FALSE;
                suspend_pp  = `FALSE;
                suspend_quadpgm  = `FALSE;  //new add cmd suspend 
		suspend_ex_quadpgm = `FALSE;

                suspend_otppgm  = `FALSE;      
                suspend_otpers  = `FALSE;      
                      
                suspend_ser = `FALSE;
                suspend_ber32 = `FALSE;
                suspend_ber64 = `FALSE;

                rdid        = `FALSE;
                mid         = `FALSE;       
                uniqueid         = `FALSE;       
                suspend     = `FALSE;
                resume      = `FALSE;
                rfdp        = `FALSE;   
                rfdpid      = `FALSE;  
                dpd         = `FALSE;  
                dpd_enable  = `FALSE;  
                
                q_bis          = 1'bz;
                d_bis          = 1'b1;
                wp_bis         = 1'b1;
                hold_bis       = 1'b1;


		//status register volatile bit reset
		status_register[0]  = 1'b0;	//WIP
		status_register[1]  = 1'b0;	//WEL
                status_register[15] = 1'b0;    //SUS1
                status_register[10] = 1'b0;     //SUS2

		status_register[18] = 1'b0;	//PE
		status_register[19] = 1'b0;	//EE
	
		extended_addr_reg = 8'h0;
		
		ADS =	ADP ? 1'b1 : 1'b0;
		

                hold_cond   = `FALSE;
                write_op    = `FALSE;
                read_op     = `FALSE;

		clear_sr_flags = `FALSE;       //2008
		inhib_clear_sr_flags = `TRUE;

		enable_4byte_mode = `FALSE;
		inhib_enable_4byte_mode = `TRUE;

		disable_4byte_mode = `FALSE;
		inhib_disable_4byte_mode = `TRUE;

                inhib_wren  = `TRUE;
                inhib_wrdi  = `TRUE;
                inhib_rdsr  = `TRUE;
		
		inhib_rd_ex_addr =  `TRUE;  

                inhib_read  = `TRUE;
                
            
                inhib_crmr  = `TRUE;
                inhib_wrap  = `TRUE;
                inhib_set_read_para  = `TRUE;
                
                inhib_pp    = `TRUE;
                inhib_ber32    = `TRUE;
                inhib_ber64    = `TRUE;

                inhib_cer    = `TRUE;
                
                inhib_quadpgm   = `TRUE;        //new add cmd inhibt
		inhib_ex_quadpgm = `TRUE;

                inhib_otppgm    = `TRUE;      
                inhib_otpers    = `TRUE;      
                inhib_ser     = `TRUE;
                inhib_wrsr    = `TRUE;   

                inhib_rdid  = `TRUE;
                inhib_mid   = `TRUE;    
                inhib_uniqueid   = `TRUE;    
                inhib_rfdpid  = `FALSE;  
                inhib_manu_device_id_dual   = `TRUE;    
                inhib_manu_device_id_quad   = `TRUE;    
                
                inhib_rfdp  = `TRUE;  
                
                inhib_suspend  = `TRUE;
                inhib_resume   = `TRUE;

                                inhib_reset_99h <= `TRUE ;
		add_pp_enable  = `FALSE;
		
                read_enable    = `FALSE;
                erase_enable    = `FALSE;
                write_enable    = `FALSE;

		dlp_read_enable = `FALSE;

                pp_enable      = `FALSE;
		quadpgm_enable     = `FALSE;  //new add cmd enable 
		ex_quadpgm_enable = `FALSE;

                otppgm_enable      = `FALSE;      
                
                cer_enable         = `FALSE;
                ber32_enable       = `FALSE;
                ber64_enable       = `FALSE;

                
                ser_enable      = `FALSE;
                otpers_enable   = `FALSE;     
                suspend_enable  = `FALSE;
                resume_enable   = `FALSE;
                rdsr_enable     = `FALSE;
                wrsr_l          = `FALSE;
                wrsr_m          = `FALSE;
                wrsr_h          = `FALSE;

                wrsr_enable     = `FALSE;
                wr_ex_addr_enable = `FALSE;  //2008
				rd_ex_addr_enable = `FALSE;

				wr_configuration_reg= `FALSE;//5109 cmlin
				wr_config_reg_enable= `FALSE;//5109 cmlin
				rdid_enable     = `FALSE;
                oen             = `FALSE; 
                bpbit_reg       = `FALSE;  // bpbit_reg
                wrsr_protect    = `FALSE;
                wrap_enable     = `FALSE;

                count_enable   = `FALSE;
                data           = 8'b00000000;
                data_rst           = 8'b00000000;

                // decode process
                bit_index      = 8'b00000000;
                bit_register   = 8'b00000000;


                    crm_bit     = 8'b00000000;
                wrap_bit        = 8'b00010000;  //W4=1
                qpi_para_bit    = 8'b00000000;  
                reset_crmr  = 1'b0;
                reset_wel   = 1'b0;
                wel         = 1'b0;
                
                dq_di = 1'bz ;
                dq_do = 1'bz ;
                dq_wp = 1'bz ;
                dq_hold = 1'bz ;
                bit_id = 5'b00000;

                                inhib_IB_lock = `TRUE;    //new added
                                IB_lock = `FALSE;          //new added
                                
                                inhib_IB_unlock = `TRUE;    //new added
                                IB_unlock = `FALSE;          //new added
                                
                                inhib_IB_read = `TRUE;    //new added
                                IB_read = `FALSE;          //new added
                                
                                inhib_GB_lock = `TRUE;    //new added
                                GB_lock = `FALSE;          //new added
                                
                                inhib_GB_unlock = `TRUE;    //new added
                                GB_unlock = `FALSE;          //new added

                                IB_lock_enable   = `FALSE;
                                IB_unlock_enable = `FALSE;
                                IB_read_enable   = `FALSE;
                                GB_lock_enable   = `FALSE;
                                GB_unlock_enable = `FALSE;


                                IS_bottom_sel = 16'hffff;
                                IS_top_sel    = 16'hffff;
                               lock_sel      = {(`BLOCK_NUM-1){1'b1}};
				lock_enable   = {(`BLOCK_NUM-1){1'b0}};
                                data_lock_en  = 8'b0;

                                wps_protect_sel = 1'b1;

                                wps_protect_bottom_sel = 1'b1;
                                wps_protect_top_sel = 1'b1;

                                factory_mode = `FALSE;

				wip =1'b1;

				bit_index_dlp = 3'b0;
				dlp_done = `FALSE;

				PE = 1'b0;
				EE = 1'b0;
                                

                        //      inhib_HOLD_reset <= `FALSE;
                                #`TRST;
                                HW_RST = `FALSE;
                wip = 1'b0;
                        


                        end

                end

        /*      always@(posedge inhib_HOLD_reset)
                begin
                        HOLD_reset <= `FALSE;
                end */
                                                

      //-----------------------------------------
      // Reset 99h 
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!reset_99h)
         begin
            inhib_reset_99h <= `FALSE ; 
         end
         if (reset_99h)
         begin
            if (!select_ok)
            begin
                SW_RST =`TRUE;
                disable page_pgm_process;
                disable quad_pgm_process;
                disable otp_pgm_process;
                disable chip_ers_process;
                disable ber32_process;
                disable ber64_process;
                disable ser_process;
                disable otp_ers_process;
                disable wrsr_process;
                disable ers_pgm_resume_process;
                disable erase_pgm_susp_process;

				diofr_crm_flag  = `FALSE;//5109
				qiofr_crm_flag  = `FALSE;//5109
				qiowfr_crm_flag = `FALSE;//5109
				crmr        = `FALSE;//5109
				crmr_flag   = `FALSE;//5109
				crm_bit         = 8'b00000000;//5109


                only_rdsr      = `FALSE;
                only_suspend   = `FALSE;
                select_ok      = `FALSE;
                raz            = `FALSE;
                byte_ok        = `FALSE;
                
                cpt         = 0;
                cpt_rst         = 0;
                byte_cpt    = 0;

                data_to_write  = 8'bxxxxxxxx;
                data_latch     = 8'bxxxxxxxx;
                read_data_request <= `FALSE;
                write_data_request <= `FALSE;
                
                wren          = `FALSE;
                reset_66h          = `FALSE;
                reset_99h          = `FALSE;
                reset_enable          = `FALSE;
                vwsr_enable          = `FALSE;
                vwsr          = `FALSE;
                wrdi          = `FALSE;
                rdsr_l        = `FALSE; 
                rdsr_m        = `FALSE;  
                rdsr_h        = `FALSE;  
               
		rd_ex_addr  = `FALSE;    //2008
		wr_ex_addr  = `FALSE;	

		rd_configuration_reg = `FALSE; //5109 cmlin
		wr_configuration_reg = `FALSE; //5109 cmlin

                read_data_3byte   = `FALSE;
                read_data_4byte   = `FALSE;
                fast_read_3byte   = `FALSE;
                fast_read_4byte   = `FALSE;

                DTR_single_read = `FALSE;
                
                dofr_3byte        = `FALSE;   
                dofr_4byte        = `FALSE;   

                diofr_3byte       = `FALSE;
                diofr_4byte       = `FALSE;
		
                qofr_3byte        = `FALSE;
                qofr_4byte        = `FALSE;

                qiofr_3byte       = `FALSE;
                qiofr_4byte       = `FALSE;

                qiowfr      = `FALSE;
                otprd       = `FALSE;  //new add cmd otprd
                manu_device_id_dual       = `FALSE;
                manu_device_id_quad       = `FALSE;
                
  
                ers_suspend_flag   = `FALSE;
                pgm_suspend_flag   = `FALSE;


                qpim      = `FALSE;
                wrapset   = `FALSE;
                wrap_8byte  = `FALSE; 
                wrap_16byte  = `TRUE ; 
                wrap_32byte  = `FALSE; 
                wrap_64byte  = `FALSE; 

                set_read_para     = `FALSE;
                qpi_wrap_8byte  = `FALSE; 
                qpi_wrap_16byte  = `FALSE ; 
                qpi_wrap_32byte  = `FALSE; 
                qpi_wrap_64byte  = `FALSE; 
                qpi_dummy_4clk   = `TRUE;
                qpi_dummy_6clk   = `FALSE;
                qpi_dummy_8clk   = `TRUE;
                pp_3byte              = `FALSE;
		pp_4byte = `FALSE;
		quadpgm_3byte         = `FALSE;   
		quadpgm_4byte         = `FALSE;   
                ex_quadpgm_3byte         = `FALSE;   
                ex_quadpgm_4byte         = `FALSE;   
		
                otppgm          = `FALSE;
                otpers          = `FALSE;      
		ser_3byte            = `FALSE;
                ser_4byte            = `FALSE;

                ber32_3byte         = `FALSE;
                ber32_4byte         = `FALSE;

                ber64_3byte         = `FALSE;
                ber64_4byte         = `FALSE;
                  
                cer       = `FALSE;
                suspend_pp  = `FALSE;
                suspend_quadpgm  = `FALSE;  //new add cmd suspend 
                suspend_ex_quadpgm  = `FALSE;  //new add cmd suspend 
                suspend_otppgm  = `FALSE;      
                suspend_otpers  = `FALSE;      
                      
                suspend_ser = `FALSE;
                suspend_ber32 = `FALSE;
                suspend_ber64 = `FALSE;

                rdid        = `FALSE;
                mid         = `FALSE;       
                uniqueid         = `FALSE;       
                suspend     = `FALSE;
                resume      = `FALSE;
                rfdp        = `FALSE;   
                rfdpid      = `FALSE;  
                dpd         = `FALSE;  
                dpd_enable  = `FALSE;  
                
                q_bis          = 1'bz;
                d_bis          = 1'b1;
                wp_bis         = 1'b1;
                hold_bis       = 1'b1;


		//status register volatile bit reset
		status_register[0]  = 1'b0;	//WIP
		status_register[1]  = 1'b0;	//WEL
        //  status_register[15] = 1'b0;    //SUS1
        // status_register[10] = 1'b0;     //SUS2
        SUS1 = 1'b0 ;
        SUS2 = 1'b0 ;
        

		status_register[18] = 1'b0;	//PE
		status_register[19] = 1'b0;	//EE
		
		extended_addr_reg = 8'h0;
		
		ADS =	ADP ? 1'b1 : 1'b0;
	

                hold_cond   = `FALSE;
                write_op    = `FALSE;
                read_op     = `FALSE;

		clear_sr_flags = `FALSE;       //2008
		inhib_clear_sr_flags = `TRUE;
    
		enable_4byte_mode = `FALSE;
		inhib_enable_4byte_mode = `TRUE;

		disable_4byte_mode = `FALSE;
		inhib_disable_4byte_mode = `TRUE;

                inhib_wren  = `TRUE;
                inhib_wrdi  = `TRUE;
                inhib_rdsr  = `TRUE;
		
		inhib_rd_ex_addr    =	`TRUE; //2008
		inhib_wr_ex_addr    =	`TRUE;

                inhib_read  = `TRUE;
                
                inhib_wrap  = `TRUE;
                inhib_set_read_para  = `TRUE;
                
                inhib_pp    = `TRUE;
                inhib_ber32    = `TRUE;
                inhib_ber64    = `TRUE;

                inhib_cer    = `TRUE;
                
                inhib_quadpgm   = `TRUE;        //new add cmd inhibt
                inhib_ex_quadpgm   = `TRUE;        //new add cmd inhibt
                inhib_otppgm    = `TRUE;      
                inhib_otpers    = `TRUE;      
                inhib_ser     = `TRUE;
                inhib_wrsr    = `TRUE;   

                inhib_rdid  = `TRUE;
                inhib_mid   = `TRUE;    
                inhib_uniqueid   = `TRUE;    
                inhib_rfdpid  = `FALSE;  
                inhib_manu_device_id_dual   = `TRUE;    
                inhib_manu_device_id_quad   = `TRUE;    
                
                inhib_rfdp  = `TRUE;  
                
                inhib_suspend  = `TRUE;
                inhib_resume   = `TRUE;

				add_pp_enable  = `FALSE;

                read_enable    = `FALSE;
                erase_enable    = `FALSE;
                write_enable    = `FALSE;

				dlp_read_enable = `FALSE;

                pp_enable      = `FALSE;
                quadpgm_enable     = `FALSE;  //new add cmd enable 
                ex_quadpgm_enable     = `FALSE;  //new add cmd enable 
                otppgm_enable      = `FALSE;      
                
                cer_enable         = `FALSE;
                ber32_enable       = `FALSE;
                ber64_enable       = `FALSE;

                
                ser_enable      = `FALSE;
                otpers_enable   = `FALSE;     
                suspend_enable  = `FALSE;
                resume_enable   = `FALSE;
                rdsr_enable     = `FALSE;
                wrsr_l          = `FALSE;
                wrsr_m          = `FALSE;
                wrsr_h          = `FALSE;
                wrsr_enable     = `FALSE;
                
				wr_ex_addr_enable = `FALSE;  //2008
				rd_ex_addr_enable = `FALSE;
				
				wr_configuration_reg = `FALSE;//5109 cmlin
				wr_config_reg_enable = `FALSE;//5109 cmlin

				rdid_enable     = `FALSE;
                oen             = `FALSE; 
                bpbit_reg       = `FALSE;  // bpbit_reg
                wrsr_protect    = `FALSE;
                wrap_enable     = `FALSE;

                count_enable   = `FALSE;
                data           = 8'b00000000;
                data_rst           = 8'b00000000;

                // decode process
                bit_index      = 8'b00000000;
                bit_register   = 8'b00000000;


                wrap_bit        = 8'b00010000;  //W4=1
                qpi_para_bit    = 8'b00000000;  
                reset_wel   = 1'b0;
                wel         = 1'b0;
                
                dq_di = 1'bz ;
                dq_do = 1'bz ;
                dq_wp = 1'bz ;
                dq_hold = 1'bz ;
                bit_id = 5'b00000;

                                inhib_IB_lock = `TRUE;    //new added
                                IB_lock = `FALSE;          //new added
                                
                                inhib_IB_unlock = `TRUE;    //new added
                                IB_unlock = `FALSE;          //new added
                                
                                inhib_IB_read = `TRUE;    //new added
                                IB_read = `FALSE;          //new added
                                
                                inhib_GB_lock = `TRUE;    //new added
                                GB_lock = `FALSE;          //new added
                                
                                inhib_GB_unlock = `TRUE;    //new added
                                GB_unlock = `FALSE;          //new added

                                IB_lock_enable   = `FALSE;
                                IB_unlock_enable = `FALSE;
                                IB_read_enable   = `FALSE;
                                GB_lock_enable   = `FALSE;
                                GB_unlock_enable = `FALSE;


                                IS_bottom_sel = 16'hffff;
                                IS_top_sel    = 16'hffff;
                                lock_sel      = {(`BLOCK_NUM-1){1'b1}};
				lock_enable   = {(`BLOCK_NUM-1){1'b0}};
                                data_lock_en  = 8'b0;

                                wps_protect_sel = 1'b1;

                                wps_protect_bottom_sel = 1'b1;
                                wps_protect_top_sel = 1'b1;

				factory_mode =`FALSE;

				bit_index_dlp = 3'b0;
				dlp_done = `FALSE;

				wip =1'b1;
				PE = 1'b0;
				EE = 1'b0;

                #`TRST;
                SW_RST = `FALSE;
                wip = 1'b0;
                        


                inhib_reset_99h <= `TRUE ;

            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (reset_99h && (!only_rdsr) && select_ok)
         begin
            inhib_reset_99h <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : reset_99h Instruction canceled because the chip is still selected",$realtime); 
         end
      end


      //-----------------------------------------
      // volatile SR write enable 
      //-----------------------------------------
   always @(select_ok)
     begin
       if (!select_ok)
         begin
           if (vwsr && (!only_rdsr))
             begin
               $display("%t:  volatile SR write enable is valid  ",$realtime);
               vwsr_enable <= `TRUE;
             end
           else
             vwsr_enable <= `FALSE ; 
         end
      end

   always 
      @(posedge c_int)
      begin
         if (vwsr && (!only_rdsr) && select_ok)
         begin
            vwsr_enable <= `FALSE ; 
            if ($time != 0) $display("%t:  WARNING : vwsr Instruction canceled because the chip is still selected",$realtime); 
         end
      end



       //-----------------------------------------
      // write extended address register (volatile) 
	//--------------------------------------- 
always @(select_ok)
   begin
      if (!wr_ex_addr)
      begin
         inhib_wr_ex_addr <= `FALSE ;
	 wr_ex_addr_enable <= `FALSE;
      end 
   
     if (( (byte_cpt == 0) || (!byte_ok) )  && wr_ex_addr && (!only_rdsr)) 
      begin
         if (!select_ok) 
         begin
            if ($time != 0) $display("%t:  WARNING : wr_ex_addr Instruction canceled because the chip is deselected",$realtime); 
            inhib_wr_ex_addr <= `TRUE ; 
             
         end 
      end 

      if ((( ((byte_cpt == 2) && (cpt == 0)) || ((byte_cpt == 1) && ((cpt == 7) && !qpim || (cpt ==1) && qpim))) && byte_ok) && wr_ex_addr && (!only_rdsr))     
      begin
         if (!select_ok) 
         begin
         wr_ex_addr_enable <= `TRUE ; 
        inhib_wr_ex_addr <= `TRUE ; 
                
        reset_wel <= 1'b1 ; 

          end 
      end
   
   end

 always @(posedge c_int)
   begin
      if (byte_cpt >= 2 && wr_ex_addr && (!only_rdsr))
      begin
         if (select_ok)
         begin
            if ($time != 0) $display("%t:  WARNING : wrsr Instruction canceled because the chip is still selected",$realtime); 
            inhib_wr_ex_addr <= `TRUE ;
         end
      end
   end  


      //-----------------------------------------
      // Write_disable 
      //-----------------------------------------
   always 
      @(select_ok)
      begin
         if (!wrdi)
         begin
            inhib_wrdi <= `FALSE ; 
         end
         if (wrdi && (!only_rdsr))
         begin
            if (!select_ok)
            begin
               wel <= 1'b0 ; 
               inhib_wrdi <= `TRUE ; 
            end
         end
      end

   always 
      @(posedge c_int)
      begin
         if (wrdi && (!only_rdsr) && select_ok)
         begin
            inhib_wrdi <= `TRUE ; 
            if ($time != 0) $display("%t:  WARNING : wrdi Instruction canceled because the chip is still selected",$realtime); 
         end
      end
      
      
      //-------------------------------------------
      // WRSR PROCESS
      //-------------------------------------------
event wrsr_event;
always @(wrsr_event)
begin:wrsr_process
        #`TW ;
        if ($time != 0) $display("%t:  NOTE : wrsr cycle is finished",$realtime); 
        wrsr_enable <= `FALSE ; 
        wr_config_reg_enable<= `FALSE ; 
        inhib_wrsr <= `TRUE ; 
        wip <= 1'b0 ; 
                
        reset_wel <= 1'b1 ; 

end

always @(select_ok)
	begin
      	if (!wrsr_l || ! wrsr_m || ! wrsr_h)
      	begin
        	inhib_wrsr <= `FALSE ; 
      	end 
     	if (( (byte_cpt == 0) || (!byte_ok)) && (wrsr_l || wrsr_m || wrsr_h) && (!vwsr_enable) && (!only_rdsr)) 
      	begin
         	if (!select_ok) 
         	begin
            	if ($time != 0) $display("%t:  WARNING : wrsr Instruction canceled because the chip is deselected",$realtime); 
            	inhib_wrsr <= `TRUE ; 
             
         	end 
      	end 
      	if ((((((byte_cpt == 3) && (cpt == 0)) || ((byte_cpt == 2) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)))) && byte_ok && wrsr_l) || ((((byte_cpt == 2) &&
		(cpt == 0)) || ((byte_cpt == 1) && (((cpt == 7) && !qpim) || ((cpt ==1) && qpim)))) && byte_ok && (wrsr_l || wrsr_m || wrsr_h))) && (!vwsr_enable) && (!only_rdsr))    
      	begin

        	if (!select_ok) 
         	begin
            	if (wel == 1'b0)
            	begin
               		if ($time != 0) $display("%t:  WARNING : wrsr Instruction canceled because WEL or Volatile write enable is reset",$realtime); 
               		wrsr_enable <= `FALSE ; 
               		inhib_wrsr <= `TRUE ; 
               
            	end
            	else 
            	begin
                	if(!wrsr_protect)
                	begin
                        if ($time != 0) $display("%t:  NOTE : wrsr cycle has begun",$realtime); 
                        wrsr_enable <= `TRUE ; 
                        reset_wel <= 1'b0 ;
                        wip <= 1'b1 ;
                        ->wrsr_event;
                	end
                	else
                  	begin
                 		if ($time != 0) $display("%t:  NOTE : this wrsr op protected,wrsr operation is inhibted",$realtime);
                  		inhib_wrsr <= `TRUE ;
		    			wel <= 0;  //2008 reset wel no matter program/erase successful or not	
                  	end
            	end
         	end 
      	end


		if ((((((byte_cpt == 3) && (cpt == 0)) || ((byte_cpt == 2) && (((cpt == 7) && (!qpim)) || ((cpt ==1) && qpim)))) && byte_ok && wr_configuration_reg ) || ((((byte_cpt == 2) &&
		(cpt == 0)) || ((byte_cpt == 1) && (((cpt == 7) && !qpim) || ((cpt ==1) && qpim)))) && byte_ok && ( wr_configuration_reg ))) && (!vwsr_enable) && (!only_rdsr))    
      	begin

        	if (!select_ok) 
         	begin
            	if (wel == 1'b0)
            	begin
               		if ($time != 0) $display("%t:  WARNING : wrsr Instruction canceled because WEL or Volatile write enable is reset",$realtime); 
               		wr_config_reg_enable <= `FALSE ; 
               		inhib_wrsr <= `TRUE ; 
               
            	end
            	else 
            	begin
                	if(!wrsr_protect)
                	begin
                        if ($time != 0) $display("%t:  NOTE : wrsr cycle has begun",$realtime); 
                        wr_config_reg_enable <= `TRUE ; 
                        reset_wel <= 1'b0 ;
                        wip <= 1'b1 ;
                        ->wrsr_event;
                	end
                	else
                  	begin
                 		if ($time != 0) $display("%t:  NOTE : this wrsr op protected,wrsr operation is inhibted",$realtime);
                  		inhib_wrsr <= `TRUE ;
		    			wel <= 0;  //2008 reset wel no matter program/erase successful or not	
                  	end
            	end
         	end 
      	end


   
 
      	if ((((byte_cpt == 3) || ((byte_cpt == 2) && ((cpt == 7) && !qpim || (cpt ==1) && qpim) && byte_ok)) || ((byte_cpt == 2) || ((byte_cpt == 1) && ((cpt == 7) &&  !qpim || (cpt ==1) && qpim) && byte_ok))) && (wrsr_l || wrsr_m || wrsr_h||wr_configuration_reg) && (vwsr_enable) && (!only_rdsr))     
      	begin
         	if (!select_ok) 
         	begin
                  wrsr_l <= `FALSE ;
                  wrsr_m <= `FALSE ;
                  wrsr_h <= `FALSE ;
                //  wr_configuration_reg <= `FALSE ;//5109 cmlin

         	end 
      	end
   end

  
always @(posedge c_int)
   begin
      if ((byte_cpt == 3) && (wrsr_l || wrsr_m || wrsr_h) && (!only_rdsr) && select_ok)
         begin
            if ($time != 0) $display("%t:  WARNING : wrsr Instruction canceled because the chip is still selected",$realtime); 
            inhib_wrsr <= `TRUE ;
	    wel <= 1'b0;

         end
   end   


      //-------------------------------------------
      // Set burst with wrap PROCESS
      //-------------------------------------------

always @(select_ok)
   begin
      if (!wrapset)
      begin
         inhib_wrap <= `FALSE ; 
      end 
     if (((byte_cpt <= 4) && (!byte_ok) ) && wrapset && (!only_rdsr)) 
      begin
         if (!select_ok) 
         begin
            if ($time != 0) $display("%t:  WARNING : wrapset Instruction canceled because the chip is deselected",$realtime); 
            inhib_wrap <= `TRUE ; 
         end 
      end 


      if ( ((byte_cpt == 5) || ((byte_cpt == 4) && (cpt == 1) && byte_ok)) && wrapset && (!only_rdsr))
      begin
         if (!select_ok) 
         begin

                $display("%t:   NOTE: set burst with wrap has begun ",$realtime);
                if (wrap_bit[4] == 1'h0)
                begin
                        wrap_enable <= `TRUE;
                end
                else
                begin
                        wrap_enable <= `FALSE;

                end
                #1;
                        case ({wrap_bit[6], wrap_bit[5]})
                          2'b00  :
                                begin
                                        if(wrap_enable) 
                                        begin
                                         wrap_16byte   <= `TRUE;
                                         wrap_32byte  <= `FALSE;
                                         wrap_64byte  <= `FALSE;
                                        end

                                         qpi_wrap_16byte   <= `TRUE;
                                         qpi_wrap_32byte  <= `FALSE;
                                         qpi_wrap_64byte  <= `FALSE;

                                end
                          2'b01  :
                                begin
                                        if(wrap_enable) 
                                        begin
                                         wrap_16byte  <= `TRUE;
                                         wrap_32byte  <= `FALSE;
                                         wrap_64byte  <= `FALSE;
                                        end

                                         qpi_wrap_16byte  <= `TRUE;
                                         qpi_wrap_32byte  <= `FALSE;
                                         qpi_wrap_64byte  <= `FALSE;
                                end
                          2'b10  :
                                begin
                                        if(wrap_enable) 
                                        begin
                                         wrap_16byte  <= `FALSE;
                                         wrap_32byte  <= `TRUE;
                                         wrap_64byte  <= `FALSE;
                                        end

                                         qpi_wrap_16byte  <= `FALSE;
                                         qpi_wrap_32byte  <= `TRUE;
                                         qpi_wrap_64byte  <= `FALSE;

                                end
                          2'b11  :
                                begin
                                        if(wrap_enable) 
                                        begin
                                         wrap_16byte  <= `FALSE;
                                         wrap_32byte  <= `FALSE;
                                         wrap_64byte  <= `TRUE;
                                        end

                                         qpi_wrap_16byte  <= `FALSE;
                                         qpi_wrap_32byte  <= `FALSE;
                                         qpi_wrap_64byte  <= `TRUE;
                                end
                        endcase
                 end
                inhib_wrap <= `TRUE ;

         end 
   end
   
  
always @(posedge c_int)
   begin
      if ( ((byte_cpt == 5) || ((byte_cpt == 4) && (cpt == 1) && byte_ok)) && wrapset && (!only_rdsr))
      begin
         if (byte_cpt == 5 && select_ok)
         begin
            if ($time != 0)  $display("%t:   NOTE: set burst with wrap is finished ",$realtime); 
            inhib_wrap <= `TRUE ;
            
         end
      end
   end   




      //-------------------------------------------
      // Set read parameters in QPI mode PROCESS
      //-------------------------------------------

always @(select_ok)
   begin
      if (!set_read_para)
      begin
         inhib_set_read_para <= `FALSE ; 
      end 
     if (( (byte_cpt == 0) || (byte_cpt == 1) && (!byte_ok) ) && set_read_para && (!only_rdsr)) 
      begin
         if (!select_ok) 
         begin
            if ($time != 0) $display("%t:  WARNING : set_read_para Instruction canceled because the chip is deselected",$realtime); 
            inhib_set_read_para <= `TRUE ; 
         end 
      end 


      if ( ((byte_cpt == 2) || ((byte_cpt == 1) && (cpt == 1) && byte_ok)) && set_read_para && (!only_rdsr))
      begin
         if (!select_ok) 
         begin
	    if(qpi_para_bit[2] == 1'b0)     //p2 = 0, qpi enable wrap
	    begin
                $display("%t:   NOTE: Set read parameters in QPI mode has begun",$realtime);
               case ({qpi_para_bit[1], qpi_para_bit[0]})       //wrap length set
                 2'b00  :
                       begin
                               // qpi_wrap_8byte   <= `TRUE;//5109 cmlin
                                qpi_wrap_16byte  <= `TRUE;//5109 cmlin
                                qpi_wrap_32byte  <= `FALSE;
                                qpi_wrap_64byte  <= `FALSE;

                               if(wrap_enable)
                               begin
                              //  wrap_8byte   <= `TRUE;//5109 cmlin
                                wrap_16byte  <= `TRUE;//5109 cmlin
                                wrap_32byte  <= `FALSE;
                                wrap_64byte  <= `FALSE;
                               end
                       end
                 2'b01  :
                       begin
                              //  qpi_wrap_8byte   <= `FALSE;//5109 cmlin
                                qpi_wrap_16byte  <= `TRUE;
                                qpi_wrap_32byte  <= `FALSE;
                                qpi_wrap_64byte  <= `FALSE;

                               if(wrap_enable)
                               begin
                            //    wrap_8byte   <= `FALSE;//5109 cmlin
                                wrap_16byte  <= `TRUE;
                                wrap_32byte  <= `FALSE;
                                wrap_64byte  <= `FALSE;
                               end
                       end
                 2'b10  :
                       begin

                            //    qpi_wrap_8byte   <= `FALSE;//5109 cmlin
                                qpi_wrap_16byte  <= `FALSE;
                                qpi_wrap_32byte  <= `TRUE;
                                qpi_wrap_64byte  <= `FALSE;

                               if(wrap_enable)
                               begin
                             //   wrap_8byte   <= `FALSE;//5109 cmlin
                                wrap_16byte  <= `FALSE;
                                wrap_32byte  <= `TRUE;
                                wrap_64byte  <= `FALSE;
                               end
                       end
                 2'b11  :
                       begin
                              //  qpi_wrap_8byte   <= `FALSE;//5109 cmlin
                                qpi_wrap_16byte  <= `FALSE;
                                qpi_wrap_32byte  <= `FALSE;
                                qpi_wrap_64byte  <= `TRUE;

                               if(wrap_enable)
                               begin
                            //    wrap_8byte   <= `FALSE;//5109 cmlin
                                wrap_16byte  <= `FALSE;
                                wrap_32byte  <= `FALSE;
                                wrap_64byte  <= `TRUE;
                               end
                       end
               endcase

	    end else if(qpi_para_bit[2] == 1'b1) 
	    begin
		//qpi_wrap_8byte   <= `TRUE;//5109 cmlin
                qpi_wrap_16byte  <= `TRUE;//5109 cmlin
                qpi_wrap_32byte  <= `FALSE;
                qpi_wrap_64byte  <= `FALSE;
	    end
	 


               case ({qpi_para_bit[5], qpi_para_bit[4]})       //dummy clocks set for 0bh,ebh,0ch
                 2'b00  :
                       begin
                               //5109 cmlin  qpi_dummy_4clk  <= `TRUE;
                               //5109 cmlin  qpi_dummy_6clk  <= `FALSE;
                               //5109 cmlin  qpi_dummy_8clk  <= `FALSE;

								qpi_dummy_8clk   <= `TRUE;
								qpi_dummy_6clk   <= `FALSE;
								qpi_dummy_12clk  <= `FALSE;
								qpi_dummy_16clk  <= `FALSE;


                       end
                 2'b01  :
                       begin
                              //5109 cmlin  qpi_dummy_4clk  <= `TRUE;
                              //5109 cmlin  qpi_dummy_6clk  <= `FALSE;
                              //5109 cmlin  qpi_dummy_8clk  <= `FALSE;

							  	qpi_dummy_8clk   <= `FALSE;
								qpi_dummy_6clk   <= `TRUE ;
								qpi_dummy_12clk  <= `FALSE;
								qpi_dummy_16clk  <= `FALSE;


                       end
                 2'b10  :
                       begin
                             //5109 cmlin   qpi_dummy_4clk  <= `FALSE;
                             //5109 cmlin   qpi_dummy_6clk  <= `TRUE;
                             //5109 cmlin   qpi_dummy_8clk  <= `FALSE;


							 	qpi_dummy_8clk   <= `FALSE;
								qpi_dummy_6clk   <= `FALSE;
								qpi_dummy_12clk  <= `TRUE ;
								qpi_dummy_16clk  <= `FALSE;

                       end
                 2'b11  :
                       begin
                            //5109 cmlin    qpi_dummy_4clk  <= `FALSE;
                            //5109 cmlin    qpi_dummy_6clk  <= `FALSE;
                            //5109 cmlin    qpi_dummy_8clk  <= `TRUE;

								qpi_dummy_8clk   <= `FALSE;
								qpi_dummy_6clk   <= `FALSE;
								qpi_dummy_12clk  <= `FALSE ;
								qpi_dummy_16clk  <= `TRUE ;

                       end
               endcase
	



                inhib_set_read_para <= `TRUE ;

         end 
      end 


   end
   
 
  
always @(posedge c_int)
   begin
      if ( ((byte_cpt == 2) || ((byte_cpt == 1) && (cpt == 1) && byte_ok)) && set_read_para && (!only_rdsr))
      begin
         if (byte_cpt == 2 && select_ok)
         begin
            if ($time != 0) $display("%t:   NOTE: Set read parameters in QPI mode is finished",$realtime); 
            inhib_set_read_para <= `TRUE ;
            
         end
      end
   end   





      //-------------------------------------------
      // CHIP_erase
      //-------------------------------------------
event chip_ers_event;

always @(chip_ers_event)
begin:chip_ers_process
    for(j = 1; j <= tCE; j = j + 1) // Chip erase duration = tCE x Tbase = tCE x 1ms (to avoid number wider thab 32 bit)
       begin
        #`Tbase ;
       end
    if ((!suspend_enable) && (!resume_enable))
    begin
    if ($time != 0) $display("%t:  NOTE : Chip erase cycle is finished",$realtime); 
    cer_enable <= `FALSE ;
    inhib_cer <= `TRUE ;  
    wip <= 1'b0 ; 
        
    reset_wel <= 1'b1 ; 
    end

end

   always @(select_ok)
   begin
      if (!cer)
      begin
         inhib_cer <= `FALSE ; 
      end 
      if (cer && (!only_rdsr))
      begin
         if ((!select_ok) && (!resume_enable) )
         begin
            if (wel == 1'b0)
            begin
               if ($time != 0) $display("%t:  WARNING : cer Instruction canceled because WEL is reset",$realtime); 
               cer_enable <= `FALSE ; 
               inhib_cer <= `TRUE ; 
			   EE  <=	`TRUE;
            end
            else
        begin
              #2;
              if(!bpbit)
              begin
               if ($time != 0) $display("%t:  NOTE : Chip erase cycle has begun",$realtime); 
               cer_enable <= `TRUE ; 
               reset_wel <= 1'b0 ;
               wip <= 1'b1 ;
                   EE  <=`FALSE;        

               
                ->chip_ers_event;
            end
            else
            begin 
            if ($time != 0) $display("%t:  NOTE : Chip is protected,no erase occur",$realtime); 
		inhib_cer <= `TRUE ; 
		EE  <=	`TRUE;

			wel <= 0;  //2008 reset wel no matter program/erase successful or not	
            end
         end  
       end
     end
   end

   always @(posedge c_int)
   begin
      if (cer && (!only_rdsr) && select_ok)
      begin
         if ($time != 0) $display("%t:  WARNING : chip erase Instruction canceled because the chip is still selected",$realtime); 
         inhib_cer <= `TRUE ;

      end
   end

      //-------------------------------------------
      // BLOCK_erase(32k)
      //-------------------------------------------
event ber32_event;
always @(ber32_event)
begin:ber32_process
     for(j = 1; j <= tBE1; j = j + 1) // Block erase duration = tBE x Tbase = tBE x 1ms (to avoid number wider thab 32 bit)
        begin
         #`Tbase ;
        end
      if ((!suspend_enable) && (!resume_enable) && !ers_suspend_flag)
     begin
     if ($time != 0) $display("%t:  NOTE : Block erase cycle is finished",$realtime); 
     inhib_ber32 <= `TRUE ; 
     
     wip <= 1'b0 ; 
         

     reset_wel <= 1'b1 ; 
     end

end
   always @(select_ok)
   begin
      if (!ber32)
      begin
         inhib_ber32 <= `FALSE ; 
      end 
      if ((!erase_enable) && ber32 && (!only_rdsr))
      begin
         if ((!select_ok) && (!resume_enable) && (!suspend_enable))
         begin
            if ($time != 0) $display("%t:  WARNING : ber32 Instruction canceled because the chip is deselected",$realtime); 
            inhib_ber32 <= `TRUE ; 
             
         end 
      end 
      if (erase_enable && ber32 && (!only_rdsr) && byte_ok)
      begin
         if ((!select_ok) && (!resume_enable))
         begin
            if (wel == 1'b0)
            begin
               if ($time != 0) $display("%t:  WARNING : ber32 Instruction canceled because WEL is reset",$realtime); 
               inhib_ber32 <= `TRUE ; 
			   EE  <=	`TRUE;
               
            end
             else 
            begin
            
             #2;
              if(!bpbit)
              begin
               ber32_time <= $time;
               if ($time != 0) $display("%t:  NOTE : Block erase cycle has begun",$realtime); 
               ber32_enable <= `TRUE ; 
               reset_wel <= 1'b0 ;
               wip <= 1'b1 ;
                 EE  <=	`FALSE;          
		
                
                ->ber32_event;
              end
             else begin
		if ($time != 0) $display("%t:  NOTE : this block protected,ber32 operation is inhibted",$realtime);
		    inhib_ber32 <= `TRUE ;
		    EE  <=	`TRUE;
		    
		    	wel <= 0;  //2008 reset wel no matter program/erase successful or not	
               end
            end
         end 
      end
   end
  /////////////////////
  ////////////////////////
   always @(posedge c_int)
   begin
      if (erase_enable && ber32 && (!only_rdsr) && select_ok)
      begin
            if ($time != 0) $display("%t:  WARNING : ber32 Instruction canceled because the chip is still selected",$realtime); 
            inhib_ber32 <= `TRUE ;
  
      end
   end

 //-------------------------------------------
 // BLOCK_erase(64k)
 //-------------------------------------------
event ber64_event;
always @(ber64_event)
begin:ber64_process
     for(j = 1; j <= tBE2; j = j + 1) // Block erase duration = tBE x Tbase = tBE x 1ms (to avoid number wider thab 64 bit)
     begin
          #`Tbase ;
      end
     if ((!suspend_enable) && (!resume_enable) && !ers_suspend_flag)
     begin
     if ($time != 0) $display("%t:  NOTE : Block erase cycle is finished",$realtime); 
     inhib_ber64 <= `TRUE ; 
     wip <= 1'b0 ; 
         

     reset_wel <= 1'b1 ; 
     end

end
   always @(select_ok)
   begin
      if (!ber64)
      begin
         inhib_ber64 <= `FALSE ; 
      end 
      if ((!erase_enable) && ber64 && (!only_rdsr))
      begin
         if ((!select_ok) && (!resume_enable) && (!suspend_enable))
         begin
            if ($time != 0) $display("%t:  WARNING : ber64 Instruction canceled because the chip is deselected",$realtime); 
            inhib_ber64 <= `TRUE ; 
             
         end 
      end 
      if (erase_enable && ber64 && (!only_rdsr) && byte_ok)
      begin
         if ((!select_ok) && (!resume_enable))
         begin
            if (wel == 1'b0)
            begin
               if ($time != 0) $display("%t:  WARNING : ber64 Instruction canceled because WEL is reset",$realtime); 
               inhib_ber64 <= `TRUE ; 
			   EE  <=	`TRUE;
               
            end
            else 
            begin
             #2;
              if(!bpbit)
              begin
               ber64_time <= $time;
               if ($time != 0) $display("%t:  NOTE : Block erase cycle has begun",$realtime); 
               ber64_enable <= `TRUE ; 
               reset_wel <= 1'b0 ;
               wip <= 1'b1 ;
                    EE <= `FALSE;       

                
                ->ber64_event;
              end

             else
             begin
                if ($time != 0) $display("%t:  NOTE : this block is protected, ber64 operation is inhibted",$realtime); 
                inhib_ber64 <= `TRUE ; 
		EE  <=	`TRUE;
	wel <= 0;  //2008 reset wel no matter program/erase successful or not	
             end

            end 
         end 
      end
   end
   
   always @(posedge c_int)
   begin
    if (erase_enable && ber64 && (!only_rdsr) && select_ok)
      begin
            if ($time != 0) $display("%t:  WARNING : ber64 Instruction canceled because the chip is still selected",$realtime); 
            inhib_ber64 <= `TRUE ;
 
      end
   end
  

       //-------------------------------------------
      // SECTOR_erase
      //-------------------------------------------
event ser_event;
always @(ser_event)
begin:ser_process
     for(j = 1; j <= tSE; j = j + 1) // Sector erase duration = tSE x Tbase = tSE x 1ms (to avoid number wider thab 32 bit)
        begin
          #`Tbase ; 
        end
     if ((!suspend_enable) && (!resume_enable) && !ers_suspend_flag)
     begin
        if ($time != 0) $display("%t:  NOTE : Sector erase cycle is finished",$realtime); 
        inhib_ser <= `TRUE ; 
        wip <= 1'b0 ; 
                

        reset_wel <= 1'b1 ; 
     end

end

   always @(select_ok)
   begin
      if (!ser)
      begin
         inhib_ser <= `FALSE ; 
      end 
      if ((!erase_enable) && ser && (!only_rdsr))
      begin
         if ((!select_ok) && (!resume_enable) && (!suspend_enable))
         begin
            if ($time != 0) $display("%t:  WARNING : ser Instruction canceled because the chip is deselected",$realtime); 
            inhib_ser <= `TRUE ; 
         end 
      end
      
      if (erase_enable && ser && (!only_rdsr) && byte_ok)
      begin
         if ((!select_ok) && (!resume_enable))
         begin
            if (wel == 1'b0)
            begin
               if ($time != 0) $display("%t:  WARNING : ser Instruction canceled because WEL is reset",$realtime); 
               inhib_ser <= `TRUE ; 
			   EE  <=	`TRUE;
            end
            else 
             begin
              #2;
              if(!bpbit)
               begin
               ser_time <= $time;
               if ($time != 0) $display("%t:  NOTE : Sector erase cycle has begun",$realtime); 
               ser_enable <= `TRUE ; 
               reset_wel <= 1'b0 ;
               wip <= 1'b1 ; 
                EE <= `FALSE;   

                ->ser_event;
               end
             else
               begin
               if ($time != 0) $display("%t:  NOTE : this sectore is protected, sector erase is inhibted",$realtime); 
               inhib_ser <= `TRUE ; 
	       EE  <=	`TRUE;
	wel <= 0;  //2008 reset wel no matter program/erase successful or not	
               end
            end 
         end 
      end
   end
   
   always @(posedge c_int)    
   begin
    if (erase_enable && ser && (!only_rdsr) && select_ok)
      begin
            if ($time != 0) $display("%t:  WARNING : ser Instruction canceled because the chip is still selected",$realtime); 
            inhib_ser <= `TRUE ; 
      end
   end
    


       //-------------------------------------------
      // OTP_erase
      //-------------------------------------------
event otp_ers_event;
always @(otp_ers_event)
begin:otp_ers_process
      for(j = 1; j <= tSE; j = j + 1) // otp Sector erase duration = tSE x Tbase = tSE x 1ms (to avoid number wider thab 32 bit)
         begin
           #`Tbase ; 
         end
      if ((!suspend_enable) && (!resume_enable) && !ers_suspend_flag)
      begin
      if ($time != 0) $display("%t:  NOTE : otp Sector erase cycle is finished",$realtime); 
      inhib_otpers <= `TRUE ; 
      wip <= 1'b0 ; 
          

      reset_wel <= 1'b1 ; 
      end

end
   always @(select_ok)
   begin
      if (!otpers)
      begin
         inhib_otpers <= `FALSE ; 
      end 
      if ((!erase_enable) && otpers && (!only_rdsr))
      begin
         if ((!select_ok) && (!resume_enable) && (!suspend_enable))
         begin
            if ($time != 0) $display("%t:  WARNING : opters Instruction canceled because the chip is deselected",$realtime); 
            inhib_otpers <= `TRUE ; 
			
         end 
      end 
      if (erase_enable && otpers && (!only_rdsr) && byte_ok)
      begin
         if ((!select_ok) && (!resume_enable))
         begin
            if (wel == 1'b0)
            begin
               if ($time != 0) $display("%t:  WARNING : otpers Instruction canceled because WEL is reset",$realtime); 
               inhib_otpers <= `TRUE ; 
			   EE  <=	`TRUE;
            end
            else 
             begin
              #2;
			  
			  if(address_otp[3:2] == 0)begin
			  	wip <= 1'b0 ;
				otpers_enable <= `FALSE ;
			  end
              else if(!bpbit)
               begin
               otperss_time <= $time;
               if ($time != 0) $display("%t:  NOTE : OTP Sector erase cycle has begun",$realtime); 
               otpers_enable <= `TRUE ; 
               reset_wel <= 1'b0 ;
               wip <= 1'b1 ; 
                  EE <= `FALSE;         

                
                ->otp_ers_event;
               end
             else
               begin
               if ($time != 0) $display("%t:  NOTE : this otp sectore is protected, sector erase is inhibted",$realtime); 
               inhib_otpers <= `TRUE ; 
	       EE  <=	`TRUE;
	wel <= 0;  //2008 reset wel no matter program/erase successful or not	
               end
            end 
         end 
      end
   end
   
   always @(posedge c_int)
   begin
    if (erase_enable && otpers && (!only_rdsr) && select_ok)
      begin
            if ($time != 0) $display("%t:  WARNING : otpers Instruction canceled because the chip is still selected",$realtime); 
            inhib_otpers <= `TRUE ; 

      end
   end    
   



      //-------------------------------------------
      // Page_Program
      //-------------------------------------------
event page_pgm_event;

   always @(c_int or select_ok)
   begin
      if (pp_cmd_addr_enable && pp && (!only_rdsr) && byte_ok)
      begin
	add_pp_enable <= `TRUE ; 
         if (wel == 1'b0)
         begin
            if ($time != 0) $display("%t:  WARNING : pp Instruction canceled because WEL is reset",$realtime); 
            pp_enable <= `FALSE ; 
            inhib_pp <= `TRUE ;
         end
      end 
   end

always @(page_pgm_event)
begin:page_pgm_process
        if ((ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable)) && !pgm_suspend_flag)
        begin
                #(tPP-1);
                if ($time != 0) $display("%t:  NOTE : Page program cycle is finished",$realtime); 
                pp_enable <= `TRUE ; 
                wip <= 1'b0 ; 
                inhib_pp <= `TRUE ; 
                reset_wel <= 1'b1 ;
        end
end


   always @(select_ok)
   begin

      if (!pp)
      begin
         inhib_pp <= `FALSE ;
	 add_pp_enable <= `FALSE ; 
         pp_enable <= `FALSE ; 
      end 
   end

   always @(negedge select_ok )
   begin
      if ((!write_enable) && pp && (!only_rdsr) && (!select_ok))
      begin
           if (ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable))
            begin
                if ($time != 0) $display("%t:  WARNING : pp Instruction canceled because the chip is deselected",$realtime); 
                inhib_pp <= `TRUE ;
            end
      end
      
      if (write_enable && pp && (!only_rdsr) && byte_ok)
      begin
         if (!resume_enable)
         begin
               #2;
                if((suspend_ser && (ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])) || (suspend_ber32 && (ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add[(`BIT_TO_CODE_MEM-1):15])) || (suspend_ber64 && (ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])))
                begin
                        if ($time != 0) $display("%t:  WARNING : Instruction canceled because the address is erasing area",$realtime); 
                        inhib_pp <= `TRUE ; 
                end
                else
                begin
                      if(!bpbit)
                        begin
                          pps_time = $time;
                          if ($time != 0) $display("%t:  NOTE : Page program cycle is started",$realtime); 
                          reset_wel <= 1'b0 ;
                          wip <= 1'b1 ;
			    PE <=   `FALSE;
                                          
                          ->page_pgm_event;
                        end
                        else
                        begin
                         if ($time != 0) $display("%t:  NOTE : this page is protected, no pgm occur",$realtime); 
                         inhib_pp <= `TRUE ;
			 PE	<=  `TRUE;
			
			wel <= 0;  //2008 reset wel no matter program/erase successful successful or not			
                        end
                end
         end
      end
    end

    always@(negedge select_ok)
    begin
      if (write_enable && pp && (!only_rdsr) && (!byte_ok) && (!resume_enable) && (!suspend_enable))
      begin
         if ($time != 0) $display("%t:  WARNING : pp Instruction canceled because the chip is deselected",$realtime); 
         inhib_pp <= `TRUE ; 
         pp_enable <= `FALSE ;

	
      end           
   end

    //-------------------------------------------
      //Quad Page_Program
      //-------------------------------------------
event quad_pgm_event;
always @(quad_pgm_event)
begin:quad_pgm_process   
       #(tPP-1); 
      if ((ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable)) && !pgm_suspend_flag)
      begin
        if ($time != 0) $display("%t:  NOTE1 : quad Page program cycle is finished",$realtime); 
        quadpgm_enable <= `TRUE ; 
        inhib_quadpgm <= `TRUE ; 
        wip <= 1'b0 ; 

        reset_wel <= 1'b1 ; 
      end 

end

   always @(c_int or select_ok)
   begin
      if (quadpgm_cmd_addr_enable && quadpgm && (!only_rdsr) && byte_ok)
      begin
	add_pp_enable <= `TRUE ;
         if (wel == 1'b0)
         begin
            if ($time != 0) $display("%t:  WARNING : quadpgm Instruction canceled because WEL is reset",$realtime); 
            quadpgm_enable <= `FALSE ; 
            inhib_quadpgm <= `TRUE ; 
         end
      end 
   end
   
   always @(select_ok)
   begin
      if (!quadpgm)
      begin
         inhib_quadpgm <= `FALSE ;
	 add_pp_enable <= `FALSE ;
         quadpgm_enable <= `FALSE ; 
      end 
   end



   always @(negedge select_ok)
   begin
      if ((!write_enable) && quadpgm && (!only_rdsr) && (!select_ok))
         begin
           if (ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable))
            begin
                if ($time != 0) $display("%t:  WARNING : quadpgm Instruction canceled because the chip is deselected",$realtime); 
                inhib_quadpgm <= `TRUE ; 
            end
         end

      if (write_enable && quadpgm && (!only_rdsr) && byte_ok)
      begin
         if (!resume_enable)
         begin
               #2;

                if((suspend_ser && (ers_add[20:16] == adress_1[7:0]) && (ers_add[15:12] == adress_2[7:4])) || (suspend_ber32 && (ers_add[20:15] == {adress_1[7:0],adress_2[7]})) || (suspend_ber64 && (ers_add[20:16] == adress_1[7:0])))
                begin
                        
                        if ($time != 0) $display("%t:  WARNING : Instruction canceled because the address is erasing area",$realtime); 
                        inhib_quadpgm <= `TRUE ; 
                end
                else
                begin
                      if(!bpbit)
                      begin
                          quadpgms_time = $time;
                          if ($time != 0) $display("%t:  NOTE : quad Page program cycle is started",$realtime); 
                          reset_wel <= 1'b0 ;
                          wip <= 1'b1 ; 
                                PE <=   `FALSE;          
                          
                          ->quad_pgm_event;
                        end
                        else
                        begin
                            if ($time != 0) $display("%t:  NOTE : this page is protected, no quad pgm occur",$realtime); 
                            inhib_quadpgm <= `TRUE ;
			    PE	<=  `TRUE;

			    	wel <= 0;  //2008 reset wel no matter program/erase successful or not	
                        end
                end
        end
      end
    end

    always@(negedge select_ok)
    begin
      if (write_enable && quadpgm && (!byte_ok) && (!resume_enable) && (!suspend_enable))
      begin
         if ($time != 0) $display("%t:  WARNING : quadpgm Instruction canceled because the chip is deselected",$realtime); 
         inhib_quadpgm <= `TRUE ; 
         quadpgm_enable <= `FALSE ;


      end           
   end



    //-------------------------------------------
      //extended Quad Page_Program
      //-------------------------------------------
event ex_quad_pgm_event;
always @(ex_quad_pgm_event)
begin:ex_quad_pgm_process   
       #(tPP-1); 
      if ((ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable)) && !pgm_suspend_flag)
      begin
        if ($time != 0) $display("%t:  NOTE1 : extended quad Page program cycle is finished",$realtime); 
        ex_quadpgm_enable <= `TRUE ; 
        inhib_ex_quadpgm <= `TRUE ; 
        wip <= 1'b0 ; 
                

        reset_wel <= 1'b1 ; 
      end 

end

always @(c_int or select_ok)
   begin
      if (ex_quadpgm_cmd_addr_enable && ex_quadpgm && (!only_rdsr) && byte_ok)
      begin
      add_pp_enable <= `TRUE ; 
         if (wel == 1'b0)
         begin
            if ($time != 0) $display("%t:  WARNING : ex_quadpgm Instruction canceled because WEL is reset",$realtime); 
            ex_quadpgm_enable <= `FALSE ; 
            inhib_ex_quadpgm <= `TRUE ; 
         end
      end 
   end
   
   always @(select_ok)
   begin
      if (!ex_quadpgm)
      begin
         inhib_ex_quadpgm <= `FALSE ;
	 add_pp_enable <= `FALSE ; 
         ex_quadpgm_enable <= `FALSE ; 
      end 
   end



always @(negedge select_ok)
   begin
      if ((!write_enable) && ex_quadpgm && (!only_rdsr) && (!select_ok))
         begin
           if (ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable))
            begin
                if ($time != 0) $display("%t:  WARNING : ex_quadpgm Instruction canceled because the chip is deselected",$realtime); 
                inhib_ex_quadpgm <= `TRUE ; 
            end
         end
      if (write_enable && ex_quadpgm && (!only_rdsr) && byte_ok)
      begin
         if (!resume_enable)
         begin
               #2;
	    if((suspend_ser && (ers_add[(`BIT_TO_CODE_MEM-1):12] == int_add[(`BIT_TO_CODE_MEM-1):12])) || (suspend_ber32 && (ers_add[(`BIT_TO_CODE_MEM-1):15] == int_add		[(`BIT_TO_CODE_MEM-1):15])) || (suspend_ber64 && (ers_add[(`BIT_TO_CODE_MEM-1):16] == int_add[(`BIT_TO_CODE_MEM-1):16])))
                begin
                        
                        if ($time != 0) $display("%t:  WARNING : Instruction canceled because the address is erasing area",$realtime); 
                        inhib_ex_quadpgm <= `TRUE ; 
                end
                else
                begin
                      if(!bpbit)
                      begin
                          ex_quadpgms_time = $time;
                          if ($time != 0) $display("%t:  NOTE : quad Page program cycle is started",$realtime); 
                          reset_wel <= 1'b0 ;
                          wip <= 1'b1 ; 
                              PE <=   `FALSE;            
                          
                          ->ex_quad_pgm_event;
                        end
                        else
                        begin
                            if ($time != 0) $display("%t:  NOTE : this page is protected, no quad pgm occur",$realtime); 
                            inhib_ex_quadpgm <= `TRUE ;
			    PE	<=  `TRUE;

			    	wel <= 0;  //2008 reset wel no matter program/erase successful or not	
                        end
                end
        end
      end
   end


  always@(negedge select_ok)
  begin
    if (write_enable && ex_quadpgm && (!only_rdsr) && (!byte_ok) && (!resume_enable) && (!suspend_enable))
      begin
         if ($time != 0) $display("%t:  WARNING : ex_quadpgm Instruction canceled because the chip is deselected",$realtime); 
         inhib_ex_quadpgm <= `TRUE ; 
         ex_quadpgm_enable <= `FALSE ; 

      end           
   end


  //-------------------------------------------
  //OTP Page_Program
  //-------------------------------------------
event otp_pgm_event;
always @(otp_pgm_event)
begin:otp_pgm_process   
     #(tPP-1); 
    if ((ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable)) && !pgm_suspend_flag)
    begin
    if ($time != 0) $display("%t:  NOTE1 : otp Page program cycle is finished",$realtime); 
	otppgm_enable <= `TRUE ; 
	inhib_otppgm <= `TRUE ; 
	wip <= 1'b0 ; 
	reset_wel <= 1'b1 ; 
    end 
end

   always @(c_int or select_ok)
   begin
    if (otppgm_cmd_addr_enable && otppgm && (!only_rdsr) && byte_ok)
      begin

	add_pp_enable <= `TRUE ; 
         if (wel == 1'b0)
         begin
            if ($time != 0) $display("%t:  WARNING : otppgm Instruction canceled because WEL is reset",$realtime); 
            otppgm_enable <= `FALSE ; 
            inhib_otppgm <= `TRUE ; 
         end
      end 
   end


   always @(select_ok)
   begin
      if (!otppgm)
      begin
         inhib_otppgm <= `FALSE ;
	add_pp_enable <= `FALSE; 
         otppgm_enable <= `FALSE ; 
      end 
   end

    
   always @(negedge select_ok)
   begin
      if ((!write_enable) && otppgm && (!only_rdsr) && (!select_ok))
         begin
           if (ersp && (!resume_enable) || (!suspend_enable) && (!resume_enable))
            begin
                if ($time != 0) $display("%t:  WARNING : otppgm Instruction canceled because the chip is deselected",$realtime); 
                inhib_otppgm <= `TRUE ; 
            end
         end
	 
      if (write_enable && otppgm && (!only_rdsr) && byte_ok)
      begin
         if (!resume_enable)
         begin
               #2;
                if(suspend_otpers && (ers_add[13:12] == adress_2[5:4]))
                begin
                        
                        if ($time != 0) $display("%t:  WARNING : Instruction canceled because the address is erasing area",$realtime); 
                        inhib_otppgm <= `TRUE ; 
                end

                else
                begin
						  if(address_otp[3:2] == 0)begin
			  					wip <= 1'b0 ;
			  			  end
                          else if(!bpbit)
                          begin

                                otppgms_time = $time;
                                if ($time != 0) $display("%t:  NOTE : otp Page program cycle is started",$realtime); 
                                reset_wel <= 1'b0 ;
                                wip <= 1'b1 ; 
								PE <=   `FALSE;
				
                             	->otp_pgm_event;

                           end
                          else
                           begin
                            if ($time != 0) $display("%t:  NOTE : this otp page is protected, no pgm occur",$realtime); 
                            inhib_otppgm <= `TRUE ;
			    			PE	<=  `TRUE;

			    			wel <= 0;  //2008 reset wel no matter program/erase successful or not	
                            end
                end
         end
      end 
 end

 always@(negedge select_ok)
 begin
     if (write_enable && otppgm && (!only_rdsr) && (!byte_ok) && (!resume_enable) && (!suspend_enable))
      begin
         if ($time != 0) $display("%t:  WARNING : otppgm Instruction canceled because the chip is deselected",$realtime); 
         inhib_otppgm <= `TRUE ; 
         otppgm_enable <= `FALSE ;

      end           
   end  


   
      //-------------------------------------------
      //Erase/Program suspend
      //-------------------------------------------
event ers_pgm_susp_event;
always @(ers_pgm_susp_event)
begin : erase_pgm_susp_process
               if ($time != 0) $display("%t:  NOTE : Erase/Program suspend cycle has begun",$realtime); 
                disable ers_pgm_resume_process;
               inhib_suspend = `TRUE ;

                if(ersp)        
                begin
                        ers_suspend_flag <= `TRUE ;
                                        SUS1 <= `TRUE ;
                end
                if(pgmsp)
                begin
                        pgm_suspend_flag <= `TRUE ;
                                        SUS2 <= `TRUE ;
                end
              #`TSUS;
               suspend_enable <= `TRUE ; 
                wip <=  1'b0 ;
                

                wel <=  1'b0 ; //2104 changed;
                                                //wel <= 1'b1;//2005 changed

end


   always @(select_ok)
   begin 
      if (!suspend)
      begin
         inhib_suspend <= `FALSE ; 
      end 
      if (suspend && only_suspend)
      begin
         if (!select_ok)
         begin
            if (wip == 1'b0)
            begin
               if ($time != 0) $display("%t:  WARNING : Instruction canceled because wip is 0",$realtime); 
               suspend_enable <= `FALSE ; 
               inhib_suspend <= `TRUE ; 
            end
            else
            begin
                ->ers_pgm_susp_event;
            end
         end
      end
          
   end



   always @(posedge c_int)
   begin
      if (suspend && (only_suspend) && select_ok)
      begin
         if ($time != 0) $display("%t:  WARNING : suspend Instruction canceled because the chip is still selected",$realtime); 
         inhib_suspend <= `TRUE ; 
         suspend_enable <= `FALSE ; 
         suspend_pp <= `FALSE;
         suspend_quadpgm <= `FALSE;  
         suspend_ex_quadpgm <= `FALSE;  
         suspend_otppgm <= `FALSE;
         suspend_otpers <= `FALSE;
         suspend_ser <= `FALSE;
         suspend_ber32 <= `FALSE;
         suspend_ber64 <= `FALSE;
     
      end
   end
      
      //-------------------------------------------
      //Erase/Program resume
      //-------------------------------------------
event ers_pgm_resume_event;
always @(ers_pgm_resume_event)
begin:ers_pgm_resume_process
    if (pp)
    begin
        if ($time != 0) $display("%t:  NOTE : Page program cycle is resumed",$realtime); 
        disable page_pgm_process;
        reset_wel <= 1'b0 ;
        wip <= 1'b1 ; 
                SUS2 <= `FALSE ;

        suspend_enable <=`FALSE;
        suspend_pp <= `FALSE;
        inhib_resume <= `TRUE ;
        pgm_suspend_flag <= 1'b0;
        pps_time = $time;
        #(tPP-pps_time_add); 
        if ($time != 0) $display("%t:  NOTE : after resumed Page program cycle is finished",$realtime); 
        pp_enable <= `TRUE ; 
        wip <= 1'b0 ; 
                
        inhib_pp <= `TRUE ; 
        reset_wel <= 1'b1 ; 
        
    end

    // quadpgm resume
    if (quadpgm)
        begin
        
         if ($time != 0) $display("%t:  NOTE : quad Page program cycle is resumed",$realtime); 
        disable quad_pgm_process;
        reset_wel <= 1'b0 ;
        wip <= 1'b1 ; 
            SUS2 <= `FALSE ;    
                
        suspend_enable <=`FALSE;
        suspend_quadpgm <= `FALSE;
        inhib_resume <= `TRUE ;
        pgm_suspend_flag <= 1'b0;
        quadpgms_time = $time;
        #(tPP-quadpgms_time_add); 
        if ($time != 0) $display("%t:  NOTE : quad page program cycle is finished",$realtime); 
        quadpgm_enable <= `TRUE ; 
        wip <= 1'b0 ; 
                


                
        inhib_quadpgm <= `TRUE ; 
        reset_wel <= 1'b1 ; 
        
        end
   

   // extended quadpgm resume
    if (ex_quadpgm)
        begin
        
         if ($time != 0) $display("%t:  NOTE : quad Page program cycle is resumed",$realtime); 
        disable quad_pgm_process;
        reset_wel <= 1'b0 ;
        wip <= 1'b1 ; 
            SUS2 <= `FALSE ;    
                
        suspend_enable <=`FALSE;
        suspend_ex_quadpgm <= `FALSE;
        inhib_resume <= `TRUE ;
        pgm_suspend_flag <= 1'b0;
        ex_quadpgms_time = $time;
        #(tPP-ex_quadpgms_time_add); 
        if ($time != 0) $display("%t:  NOTE : quad page program cycle is finished",$realtime); 
        ex_quadpgm_enable <= `TRUE ; 
        wip <= 1'b0 ; 
                


                
        inhib_ex_quadpgm <= `TRUE ; 
        reset_wel <= 1'b1 ; 
        
        end
    
    // otppgm resume
    if (otppgm)
        begin
         if ($time != 0) $display("%t:  NOTE : otp Page program cycle is resumed",$realtime); 
        disable otp_pgm_process;
        reset_wel <= 1'b0 ;
        wip <= 1'b1 ; 
                SUS2 <= `FALSE ;

                

        suspend_enable <=`FALSE;
        suspend_otppgm <= `FALSE;
        inhib_resume <= `TRUE ;
        pgm_suspend_flag <= 1'b0;
        otppgms_time = $time;
        #(tPP-otppgms_time_add); 
        if ($time != 0) $display("%t:  NOTE : otp page program cycle is finished",$realtime); 
        otppgm_enable <= `TRUE ; 
        wip <= 1'b0 ; 
                
        inhib_otppgm <= `TRUE ; 
        reset_wel <= 1'b1 ; 
        
        end
    
     // otpers suspend 
     if (otpers)
        begin
        if ($time != 0) $display("%t:  NOTE : otp Sector erase cycle has resumed",$realtime); 
        disable otp_ers_process;
        otpers_enable <= `TRUE ;
        reset_wel <= 1'b0 ;
        wip <= 1'b1 ; 
                SUS1 <= `FALSE ;

                
        suspend_enable <=`FALSE;
        suspend_otpers <= `FALSE;
        inhib_resume <= `TRUE ;
        ers_suspend_flag <= 1'b0;

        otperss_time = $time;
         #(tSE*`Tbase-otperss_time_add); 
        if ($time != 0) $display("%t:  NOTE : otp Sector erase cycle is finished",$realtime); 
        inhib_otpers <= `TRUE ;
        
        wip <= 1'b0 ; 
                
        reset_wel <= 1'b1 ; 
        end
    
    
    if (ser)
    begin
    if ($time != 0) $display("%t:  NOTE : Sector erase cycle has resumed",$realtime); 
    disable ser_process;
    ser_enable <= `TRUE ;
    reset_wel <= 1'b0 ;
    wip <= 1'b1 ; 
        SUS1 <= `FALSE ;

        
    suspend_enable <=`FALSE;
    suspend_ser <= `FALSE;
    inhib_resume <= `TRUE ;
    ers_suspend_flag <= 1'b0;
    ser_time = $time;
     #(tSE*`Tbase-ser_time_add); 
    if ($time != 0) $display("%t:  NOTE : Sector erase cycle is finished",$realtime); 
    inhib_ser <= `TRUE ;
    
    wip <= 1'b0 ; 
        
    reset_wel <= 1'b1 ; 

    end

    if (ber32)
    begin
    if ($time != 0) $display("%t:  NOTE : Block erase cycle has resumed",$realtime); 
    disable ber32_process;
    ber32_enable <= `TRUE ; 
    reset_wel <= 1'b0 ;
    wip <= 1'b1 ; 
        SUS1 <= `FALSE ;

        
    suspend_enable <=`FALSE;
    suspend_ber32 <= `FALSE;
    inhib_resume <= `TRUE ;
    ers_suspend_flag <= 1'b0;
    ber32_time = $time;
    #(tBE1*`Tbase-ber32_time_add);
    if ($time != 0) $display("%t:  NOTE : Block erase cycle is finished",$realtime); 
    inhib_ber32 <= `TRUE ; 
    
    wip <= 1'b0 ; 
        
    reset_wel <= 1'b1 ; 

    end
    
    if (ber64)
    begin
    if ($time != 0) $display("%t:  NOTE : Block erase cycle has resumed",$realtime); 
    disable ber64_process;
    ber64_enable <= `TRUE ; 
    reset_wel <= 1'b0 ;
    wip <= 1'b1 ; 
        SUS1 <= `FALSE ;

        
    suspend_enable <=`FALSE;
    suspend_ber64 <= `FALSE;
    inhib_resume <= `TRUE ;
    ers_suspend_flag <= 1'b0;

    ber64_time = $time;
    #(tBE2*`Tbase-ber64_time_add);
    if ($time != 0) $display("%t:  NOTE : Block erase cycle is finished",$realtime); 
    inhib_ber64 <= `TRUE ; 
    
    wip <= 1'b0 ;
        
    reset_wel <= 1'b1 ; 
    end
end

   always @( select_ok)
   begin
      if (!resume)
      begin
         inhib_resume <= `FALSE ; 
      end 
     if (resume && (!only_suspend))
      begin
         if (!select_ok)
         begin

               resume_enable <= `FALSE ; 
               inhib_resume <= `TRUE ; 
        end
        end
end

   always @(negedge select_ok)
   begin 

        if(resume_enable)
        begin
        ->ers_pgm_resume_event;
        end 
   end

   always @(posedge c_int)
   begin
      if (resume && (!only_suspend) && select_ok)
      begin
         if ($time != 0) $display("%t:  WARNING : resume Instruction canceled because the chip is still selected",$realtime); 
         inhib_resume <= `TRUE ; 
         resume_enable <= `FALSE;
         ser_3byte <= `FALSE;
         ser_4byte <= `FALSE;

         ber32_3byte <= `FALSE;
         ber32_4byte <= `FALSE;

         ber64_3byte <= `FALSE;       
         ber64_4byte <= `FALSE;       

         pp_3byte <= `FALSE;
	 pp_4byte <= `FALSE;
         quadpgm_3byte <= `FALSE;  
         quadpgm_4byte <= `FALSE;  
         ex_quadpgm_3byte <= `FALSE;  
         ex_quadpgm_4byte <= `FALSE;  
         otppgm <= `FALSE;
         otpers <= `FALSE;
      end
   end   
  
  
   //-------------------------------------------------------
   //deep power down and release form deep power down
    /////////////////////////////////////////////////////// //
 // This process generates the dpwd when it is valid
 always  @(select_ok)
      begin
      
      if (!dpd) 
      begin
      inhib_dpd <= `FALSE ;
      end
      if ( dpd && (select_ok) )
      begin
      inhib_dpd <=  `TRUE ;
      end
      if (dpd && (!select_ok) && (!only_suspend)  )
      begin
            dpd_enable <= `TRUE ;
            if ($time != 0) $display("%t:  NOTE: DEEP POWER DOWN COMMUNICATION PAUSED",$realtime); 
      end
   end 

 always @(select_ok)
 begin
if (rfdp && ((byte_cpt == 0) && (cpt == 7) || (byte_cpt == 1) && (cpt == 0)) && (!only_rdsr) && !qpim)
      begin
      if (dpd_enable)
         begin
         if ($time != 0) $display("%t:  NOTE : The chip is releasing from DEEP POWER DOWN",$realtime); 
         inhib_rfdp <= `FALSE; 
         inhib_dpd <= `FALSE; 
         #`TRES1;
         inhib_rfdp <= `TRUE; 
         inhib_dpd <= `TRUE; 
         end
       end 
 else if(rfdp && ((byte_cpt == 0) && (cpt == 1) || (byte_cpt == 1) && (cpt == 0)) && (!only_rdsr) && qpim)
      begin
      if (dpd_enable)
         begin
         if ($time != 0) $display("%t:  NOTE : The chip is releasing from DEEP POWER DOWN",$realtime); 
         inhib_rfdp <= `FALSE; 
         inhib_dpd <= `FALSE; 
         #`TRES1;
         inhib_rfdp <= `TRUE; 
         inhib_dpd <= `TRUE; 
         end
       end 
     
                
      else if ((byte_cpt>=1) && rfdp && (!only_rdsr))
      begin
                
                 if (dpd_enable)
                     begin
                     if ($time != 0) $display("%t:  NOTE : The Chip is releasing from DEEP POWER DOWN",$realtime); 
                     inhib_rfdpid <= `FALSE ; 
                     inhib_dpd <=  `FALSE ;
                     #`TRES2;
                     inhib_rfdpid <= `TRUE ; 
                     inhib_rfdp <= `TRUE; 
                     inhib_dpd <=  `TRUE;
                     end
        end

         else  
        begin
                inhib_rfdp <= `FALSE; 
                inhib_dpd <= `FALSE; 
        end

    
end 
always  @(select_ok )         
begin
        if(~select_ok)
        begin
                                #1;rfdp=1'b0;
                inhib_rdid = `TRUE;

        end
end
 //-------------------------------------------------------  
 /////////////////////////////////////////////////////// //
   // This process shifts out identification on data output
   always  @(select_ok )         
      begin
         if (!rdid )
         begin
            inhib_rdid <= `FALSE;
         end
         if(rdid && (!select_ok) && !qpim)
         begin
             bit_id <= 5'b00000;
            d_bis <= #`TSHQZ 1'bz;
            q_bis <= #`TSHQZ 1'bz;
            inhib_rdid <= `TRUE;
            
         end         
         
        if(rdid && (!select_ok) && qpim)        //qpi added
         begin
             bit_id <= 5'b00000;
            d_bis <= #`TSHQZ 1'bz;
            q_bis <= #`TSHQZ 1'bz;
            wp_bis <= #`TSHQZ 1'bz;
            hold_bis <= #`TSHQZ 1'bz;
            inhib_rdid <= `TRUE;
            
         end    //2005 delete 9f(qpi)  

      end
      
      
    always
        @(negedge c_int)
        begin
            if(rdid && (select_ok) && !qpim)
            begin
              rdid_enable <= `TRUE;
              d_bis <= #`TSHQZ 1'bz;
              q_bis <= #`TCLQV id[23 - bit_id];
              bit_id = bit_id + 1;
              if(bit_id > 23)   bit_id = 0;
            end

           if(rdid && (select_ok) && qpim)      //qpi added
            begin
              rdid_enable <= `TRUE;
               hold_bis <= #`TCLQV id[23 - bit_id*4] ;
               wp_bis <= #`TCLQV id[22 - bit_id*4] ;
               q_bis <= #`TCLQV id[21 - bit_id*4] ; 
               d_bis <= #`TCLQV id[20 - bit_id*4] ;
              bit_id = bit_id + 1;
              if(bit_id > 5)   bit_id = 0;

            end  //2005 delete 9f(qpi)



        end

   //---------------------------------------------------------
   // This process shifts out manufactureid did on data output
   //---------------------------------------------------------
   always
      @(select_ok )         
      begin
         if (!mid )
         begin
            inhib_mid <= `FALSE;
            bit_id <= 5'b00000;
         end   
         
         if (((byte_cpt <= 2) || ((byte_cpt == 3) && ((cpt != 7) && !qpim || (cpt != 1) && qpim))) && mid && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : mid Instruction canceled because the chip is deselected",$realtime); 
            inhib_mid <= `TRUE ; 
            bit_id <= 0; 
         end 
         
         
         if ( mid && (((byte_cpt == 3) && (cpt == 7)) || (byte_cpt >= 4)) && !qpim)
         begin  
                if (!select_ok)
                begin
                   bit_id <= 0;
                   d_bis <= #`TSHQZ 1'bz;
                   q_bis <= #`TSHQZ 1'bz;
                   inhib_mid <= `TRUE;  
                   
                end
         end 
                        
        if ( mid && (((byte_cpt == 3) && (cpt == 1)) || (byte_cpt >= 4)) && qpim)
         begin  
                if (!select_ok)
                begin
                        bit_id <= 0;
                        d_bis <= #`TSHQZ 1'bz;
                        q_bis <= #`TSHQZ 1'bz;
                        wp_bis <= #`TSHQZ 1'bz;
                        hold_bis <= #`TSHQZ 1'bz;
                        inhib_mid <= `TRUE;  
                   
                end
         end 
        
      end
      
      
      
always @(negedge c_int)
begin
           if(mid && (select_ok) && (((byte_cpt == 3) && (cpt == 7)) || (byte_cpt >= 4)) && !qpim)
           begin
                if (adress_3[0] == 1'b0)
                begin
                rdid_enable <= `TRUE;
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TCLQV did0 [15 - bit_id];
                wp_bis <= #`TSHQZ 1'bz;
                hold_bis <= #`TSHQZ 1'bz;
                bit_id = bit_id + 1;
                if(bit_id > 15)   bit_id = 0;
                end
                
                else if (adress_3[0] == 1'b1)
                begin
                rdid_enable <= `TRUE;
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TCLQV did1 [15 - bit_id];
                wp_bis <= #`TSHQZ 1'bz;
                hold_bis <= #`TSHQZ 1'bz;
                bit_id = bit_id + 1;
                if(bit_id > 15)   bit_id = 0;
                end
                
                else
                begin
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TSHQZ 1'bx;
                wp_bis <= #`TSHQZ 1'bz;
                hold_bis <= #`TSHQZ 1'bz;
                
                end 
             
           end


          if(mid && (select_ok) && (((byte_cpt == 3) && (cpt == 1)) || (byte_cpt >= 4)) && qpim)
             begin
                if (adress_3[0] == 1'b0)
                begin
                rdid_enable <= `TRUE;
                hold_bis <= #`TCLQV did0[15 - bit_id*4] ;
                wp_bis <= #`TCLQV did0[14 - bit_id*4] ;
                q_bis <= #`TCLQV did0[13 - bit_id*4] ; 
                d_bis <= #`TCLQV did0[12 - bit_id*4] ;

                bit_id = bit_id + 1;
                if(bit_id > 3)   bit_id = 0;
                end
                
                else if (adress_3[0] == 1'b1)
                begin
                rdid_enable <= `TRUE;
                hold_bis <= #`TCLQV did1[15 - bit_id*4] ;
                wp_bis <= #`TCLQV did1[14 - bit_id*4] ;
                q_bis <= #`TCLQV did1[13 - bit_id*4] ; 
                d_bis <= #`TCLQV did1[12 - bit_id*4] ;

                bit_id = bit_id + 1;
                if(bit_id > 3)   bit_id = 0;
                end
                
                else
                begin
                        d_bis <= #`TSHQZ 1'bz;
                        q_bis <= #`TSHQZ 1'bz;
                        wp_bis <= #`TSHQZ 1'bz;
                        hold_bis <= #`TSHQZ 1'bz;
                
                end 
             end
             

 end

      
   //---------------------------------------------------------
   // read unique ID
   //---------------------------------------------------------
   always
      @(select_ok )         
      begin
         if (!uniqueid )
         begin
            inhib_uniqueid <= `FALSE;
            bit_id <= 0;
         end   
         
         if (((byte_cpt <= 2) || ((byte_cpt == 3) && ((cpt != 7) && !qpim))) && uniqueid && (!select_ok))
         begin
            if ($time != 0) $display("%t:  WARNING : uniqueid Instruction canceled because the chip is deselected",$realtime); 
            inhib_uniqueid <= `TRUE ; 
            bit_id <= 0; 
         end 
         
         
         if ( uniqueid && (((byte_cpt == 3) && (cpt == 7)) || (byte_cpt >= 4)) && !qpim)
         begin  
                if (!select_ok)
                begin
                   bit_id <= 0;
                   d_bis <= #`TSHQZ 1'bz;
                   q_bis <= #`TSHQZ 1'bz;
                   inhib_uniqueid <= `TRUE;  
                   
                end
         end 
     end

      
      
always @(negedge c_int)
begin
           if(uniqueid && (select_ok) && (((byte_cpt == 3) && (cpt == 7)) || (byte_cpt >= 4)) && !qpim)
           begin
                if (adress_3[0] == 1'b0)
                begin
                rdid_enable <= `TRUE;
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TCLQV 1'b0;
                bit_id = bit_id + 1;
                if(bit_id > 15)   bit_id = 0;
                end
                
                else if (adress_3[0] == 1'b1)
                begin
                rdid_enable <= `TRUE;
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TCLQV 1'b0;
                bit_id = bit_id + 1;
                if(bit_id > 15)   bit_id = 0;
                end
                
                else
                begin
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TSHQZ 1'bx;
                
                end 
             
           end
 end


  
   //---------------------------------------------------------
   // This process shifts out device id on data output
   //---------------------------------------------------------


   always
      @(select_ok )         
      begin
         if (!rfdpid )
         begin
            inhib_rfdpid <= `FALSE;
         end   
         
         if (((byte_cpt <= 2) || ((byte_cpt == 3) && ((cpt != 7) && !qpim || (cpt != 1) && qpim))) && rfdpid && (!select_ok))
         begin
            
            inhib_rfdpid <= `TRUE ; 
            bit_id <= 1'b0; 
         end 
         
         
         if ( rfdpid && (((byte_cpt == 3) && (cpt == 7)) || (byte_cpt >= 4)) && !qpim)

         begin  
         if (!select_ok)
             begin
            bit_id <= 1'b0;
            d_bis <= #`TSHQZ 1'bz;
            q_bis <= #`TSHQZ 1'bz;
            inhib_rfdpid <= `TRUE; 
             
            end
         end 
                        if (((byte_cpt == 0) || (byte_cpt == 1) || (byte_cpt == 2) || (byte_cpt == 3) || (byte_cpt ==4) || ((byte_cpt == 5) && (cpt != 1))) && rfdpid && qpi_dummy_4clk && (!qpi_dummy_6clk) && (!qpi_dummy_8clk) && (!select_ok) && qpim)      //2005 added
         begin
            if ($time != 0) $display("%t:  WARNING : rfdpid Instruction canceled because the chip is deselected",$realtime); 
            inhib_rfdpid <= `TRUE ; 
            bit_id <= 0; 
         end 

         if (((byte_cpt == 0) || (byte_cpt == 1) || (byte_cpt == 2) || (byte_cpt == 3) || (byte_cpt ==4) || (byte_cpt ==5) || ((byte_cpt == 6) && (cpt != 1))) && rfdpid && (!qpi_dummy_4clk) && qpi_dummy_6clk && (!qpi_dummy_8clk) && (!select_ok) && qpim)   //2005 added
         begin
            if ($time != 0) $display("%t:  WARNING : rfdpid Instruction canceled because the chip is deselected",$realtime); 
            inhib_rfdpid <= `TRUE ; 
            bit_id <= 0; 
         end 

         if (((byte_cpt == 0) || (byte_cpt == 1) || (byte_cpt == 2) || (byte_cpt == 3) || (byte_cpt ==4) || (byte_cpt ==5) || (byte_cpt ==6) || ((byte_cpt == 7) && (cpt != 1))) && rfdpid && (!qpi_dummy_4clk) && (!qpi_dummy_6clk) && qpi_dummy_8clk && (!select_ok) && qpim) //2005 added
         begin
            if ($time != 0) $display("%t:  WARNING : rfdpid Instruction canceled because the chip is deselected",$realtime); 
            inhib_rfdpid <= `TRUE ; 
            bit_id <= 0; 
         end 


         if (rfdpid && ((((byte_cpt == 5) && qpi_dummy_4clk || (byte_cpt == 6) && qpi_dummy_6clk || (byte_cpt == 7) && qpi_dummy_8clk) && (cpt == 1)) || ((byte_cpt >= 6) && qpi_dummy_4clk || (byte_cpt >= 7) && qpi_dummy_6clk || (byte_cpt >=8) && qpi_dummy_8clk)) && qpim) //2005 added

         begin  
         if (!select_ok)
             begin
                bit_id <= 1'b0;
                d_bis <= #`TSHQZ 1'bz;
                q_bis <= #`TSHQZ 1'bz;
                wp_bis <= #`TSHQZ 1'bz;
                hold_bis <= #`TSHQZ 1'bz;
                inhib_rfdpid <= `TRUE; 
             
            end
         end 

      end

always @(negedge c_int)
begin
            if(rfdp  && (((byte_cpt == 3) && (cpt == 7)) || (byte_cpt >= 4)) && !qpim)
            begin
                if(! dpd_enable)
                begin               
                        if(select_ok)    //only to read id
                          begin
                          rdid_enable <= `TRUE;
                          d_bis <= #`TSHQZ 1'bz;
                          q_bis <= #`TCLQV resdid [7 - bit_id];
                          bit_id = bit_id + 1;
                          if(bit_id > 7)   bit_id = 0;
                          end
                end


                else if(rfdp)
                begin
                        if(select_ok)    
                        begin
                        rdid_enable <= `TRUE;
                        d_bis <= #`TSHQZ 1'bz;
                        q_bis <= #`TCLQV resdid [7 - bit_id];
                        bit_id = bit_id + 1;
                        if(bit_id > 7)   bit_id = 0;
                        end
                end
            end


            if(rfdp  && (((byte_cpt == 3) && (cpt == 1)) || (byte_cpt >= 4)) && qpim)
            begin
                if(! dpd_enable)
                begin               
                        if(select_ok)    //only to read id
                          begin
                                rdid_enable <= `TRUE;
                                hold_bis <= #`TCLQV resdid[7 - bit_id*4] ;
                                wp_bis <= #`TCLQV resdid[6 - bit_id*4] ;
                                q_bis <= #`TCLQV resdid[5 - bit_id*4] ; 
                                d_bis <= #`TCLQV resdid[4 - bit_id*4] ;
                                bit_id = bit_id + 1;
                                if(bit_id > 1)   bit_id = 0;

                          end
                end


                else if(rfdp) 
                begin
                        if(select_ok)    
                        begin
                                rdid_enable <= `TRUE;
                                hold_bis <= #`TCLQV resdid[7 - bit_id*4] ;
                                wp_bis <= #`TCLQV resdid[6 - bit_id*4] ;
                                q_bis <= #`TCLQV resdid[5 - bit_id*4] ; 
                                d_bis <= #`TCLQV resdid[4 - bit_id*4] ;
                                bit_id = bit_id + 1;
                                if(bit_id > 1)   bit_id = 0;
                        end
                end
            end


end


        //-------------------------------------------
   //Block lock or unclk or read process
   //-------------------------------------------

                //3d
        always@(select_ok)
        begin
                if(!IB_read)
                begin
                        inhib_IB_read <= `FALSE;
                        bit_id        <= 5'b0;
                end

                if((!read_enable) && IB_read && (!select_ok) )
                begin
                        if($time != 0) $display("%t:  WARNING : 3d Instruction canceled because the chip is deselected",$realtime);
                        inhib_IB_read <= `TRUE;
                        bit_id     <= 5'b0;
                end

                if(read_enable && IB_read && (!select_ok))
                begin

                     bit_id <= 5'b0;
                     d_bis  <= #`TSHQZ 1'bz;
                     q_bis  <= #`TSHQZ 1'bz;
                     wp_bis <= #`TSHQZ 1'bz;
                     hold_bis <= #`TSHQZ 1'bz;
                     inhib_IB_read <= `TRUE;

                end

        
        end

        always@(negedge c_int)
        begin
                if(read_enable && IB_read && (!qpim) && (select_ok))
                begin
                        IB_read_enable <= `TRUE;
                        GB_unlock_enable <= `FALSE;
                        IB_unlock_enable <= `FALSE;
                        IB_lock_enable <= `FALSE;
                        GB_lock_enable <= `FALSE;
                        d_bis  <= #`TSHQZ 1'bz;
                        q_bis  <= #`TCLQV data_lock_en[7-bit_id];
                        wp_bis <= #`TSHQZ 1'bz;
                        hold_bis <= #`TSHQZ 1'bz;
                        bit_id = bit_id + 1;
                        if(bit_id > 7) bit_id = 0;
                end
                        


                if(read_enable && IB_read && (qpim) && (select_ok))
                begin
                        IB_read_enable <= `TRUE;
                        GB_unlock_enable <= `FALSE;
                        IB_unlock_enable <= `FALSE;
                        IB_lock_enable <= `FALSE;
                        GB_lock_enable <= `FALSE;
                        hold_bis <= #`TCLQV data_lock_en[7 - bit_id*4];
                        wp_bis   <= #`TCLQV data_lock_en[6 - bit_id*4];
                        q_bis    <= #`TCLQV data_lock_en[5 - bit_id*4];
                        d_bis    <= #`TCLQV data_lock_en[4 - bit_id*4];
                        bit_id   = bit_id + 1;
                        if(bit_id > 1) bit_id = 0;
                end

        end

        //36
        always@(select_ok)
        begin
                if(!IB_lock)
                begin
                        inhib_IB_lock <= `FALSE;
                end

                if((!IB_lock_cmd_addr_enable) && IB_lock && (!select_ok))
                begin
                        if($time != 0) $display("%t:  WARNING : 36 Instruction canceled because the chip is deselected",$realtime);
                        inhib_IB_lock <= `TRUE;
                end

                if(IB_lock_cmd_addr_enable && IB_lock && (!only_rdsr) && (!select_ok))
                begin
                      $display("%t : NOTE : IB_lock has begun",$realtime);
                      IB_lock_enable <= `TRUE;
                      inhib_IB_lock <= `TRUE;
                      IB_unlock_enable <= `FALSE;
                      GB_unlock_enable <= `FALSE;
                      GB_lock_enable <= `FALSE;
                end

        end

        always@(posedge c_int)
        begin
                if((((byte_cpt == 4) && (!ADS))
		    || ((byte_cpt == 5) && ADS))
		    && IB_lock && (!only_rdsr) && select_ok)
                begin
                    if($time != 0) $display("%t : NOTE: IB_lock is finished",$realtime);
                        inhib_IB_lock <= `TRUE;
                end

        end


        //39
        always@(select_ok)
        begin
                if(!IB_unlock)
                begin
                        inhib_IB_unlock <= `FALSE;
                end

                if((!IB_unlock_cmd_addr_enable) && IB_unlock && (!select_ok))
                begin
                        if($time != 0) $display("%t:  WARNING : 39 Instruction canceled because the chip is deselected",$realtime);
                        inhib_IB_unlock <= `TRUE;
                end

                if(IB_unlock_cmd_addr_enable && IB_unlock && (!only_rdsr) && (!select_ok))
                begin
                      $display("%t : NOTE : IB_unlock has begun",$realtime);
                      IB_unlock_enable <= `TRUE;
                      inhib_IB_unlock <= `TRUE;
                      IB_lock_enable <= `FALSE;
                      GB_unlock_enable <= `FALSE;
                      GB_lock_enable <= `FALSE;
                end

        end

        always@(posedge c_int)
        begin
               if((((byte_cpt == 4) && (!ADS))
		    || ((byte_cpt == 5) && ADS))		    
		    && IB_unlock && (!only_rdsr) && select_ok)
                begin
                    if($time != 0) $display("%t : NOTE: IB_unlock is finished",$realtime);
                        inhib_IB_unlock <= `TRUE;
                end

        end



        //7e
        always@(select_ok)
        begin
                if(!GB_lock)
                begin
                        inhib_GB_lock <= `FALSE;
                end
                if(GB_lock && (!only_rdsr))
                begin
                        if(!select_ok)
                        begin
                                GB_lock_enable <= `TRUE;
                                inhib_GB_lock <= `TRUE;
                                IB_unlock_enable <= `FALSE;
                                GB_unlock_enable <= `FALSE;
                                IB_lock_enable <= `FALSE;
                        end
                end
        end

        always@(posedge c_int)
        begin
                if(GB_lock && (!only_rdsr) && select_ok)
                begin
                        inhib_GB_lock <= `TRUE;
                        if ($time != 0) $display("%t:  WARNING : GB_lock Instruction canceled because the chip is still selected",$realtime);
                end
        end


        //98
        always@(select_ok)
        begin
                if(!GB_unlock)
                begin
                        inhib_GB_unlock <= `FALSE;
                end
                if(GB_unlock && (!only_rdsr))
                begin
                        if(!select_ok)
                        begin
                                GB_unlock_enable <= `TRUE;
                                inhib_GB_unlock <= `TRUE;
                                IB_unlock_enable <= `FALSE;
                                IB_lock_enable <= `FALSE;
                                GB_lock_enable <= `FALSE;
                        end
                end
        end

        always@(posedge c_int)
        begin
                if(GB_unlock && (!only_rdsr) && select_ok)
                begin
                        inhib_GB_unlock <= `TRUE;
                        if ($time != 0) $display("%t:  WARNING : GB_unlock Instruction canceled because the chip is still selected",$realtime);
                end
        end


        
     /////////////////////////////////////////////////////// //
   // block protected bits set
   /////////////////////////////////////////////////////// //
   always @(status_register or tmp_wp or configuration_reg )
     begin
       bp[4:0] = status_register[6:2];//5109 cmlin
       //T_B = status_register[6];
       srp = status_register[7];
       srp1 = status_register[16];
       
       //ADS = status_register[8];    
       
       QE = status_register[9] || qpim;
	WPS = status_register[14];          //new added
                  //SUS1 = status_register[15];
           //SUS2 = status_register[10];

	   LC0 = status_register[17];//5109 cmlin
       LC1 = status_register[23];//5109 cmlin
	   CRC1= configuration_reg[7] ; 
	   CRC0= configuration_reg[6]; 
	   ECC = configuration_reg[0]; 

	    
	    //PE = status_register[18];
	    //EE = status_register[19];


	    if($time != 0)  begin 
		ADP = status_register[20];   //2008  //allow to set ADP at initial part
	    end

           DRV[0] = status_register[21];
           DRV[1] = status_register[22];
                 
	//HOLD_reset = status_register[23];   ////5109 cmlin 

       wrsr_protect =( srp & !srp1 & (!tmp_wp & !QE) )  |  (srp & srp1) |  (!srp & srp1) ;
      end 
       
   always @(status_register)
     begin 
		if( status_register[13] == 1'b1)
        begin
	    LB3 = 1'b1;
        end


        if( status_register[12] == 1'b1)
        begin
	    LB2 = 1'b1;
        end
	
        if( status_register[11] == 1'b1)   //new added
        begin
	    LB1 = 1'b1;
        end 

     end
    
always @( cut_add or select_ok or bp)
     begin
	if(T_B == 1'b0) //5109 cmlin no T_B bit
	  begin 
	    casez ( bp )
      	      5'b00001 : 
      	      begin
      	         if( (cut_add >= 32'h3ff0000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end   
      	      
      	      5'b00010 : 
      	      begin
      	         if( (cut_add >= 32'h3fe0000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end   
      	      
      	      5'b00011 : 
      	      begin
      	         if( (cut_add >= 32'h3fc0000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end   

      	      5'b00100 : 
      	      begin
      	         if( (cut_add >= 32'h3f80000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
      	      
      	     5'b00101 : 
      	      begin
      	         if( (cut_add >= 32'h3f00000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end    
     
      	    5'b00110 : 
	      begin
      	         if( (cut_add >= 32'h3e00000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end     
      	                           
      	            
      	      5'b00111 : 
      	      begin
      	         if( (cut_add >= 32'h3c00000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end  
      	      
      	       5'b01000 : 
      	      begin
      	         if( (cut_add >= 32'h3800000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end  
      	      
      	      5'b01001 : 
      	      begin
      	         if( (cut_add >= 32'h3000000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end

	      5'b01010 : 
      	      begin
      	         if( (cut_add >= 32'h2000000) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end

	      5'b10001 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'hffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b10010 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h1ffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b10011 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h3ffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b10100 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h7ffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b10101 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'hfffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b10110 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h1fffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b10111 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h3fffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b11000 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h7fffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b11001 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'hffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b11010 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h1ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
	      5'b?11?? : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end

		  5'b?1011 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h3ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end

	       
      	  default:  bpbit_reg<= `FALSE;
        
    
	    endcase

	  end

	else if (T_B == 1'b1) 
	  begin
	    case ( bp )
      	      4'b0001 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'hffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end   
      	      
      	      4'b0010 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h1ffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end   
      	      
      	      4'b0011 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h3ffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end   

      	      4'b0100 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h7ffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end
      	      
      	     4'b0101 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'hfffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end    
     
      	    4'b0110 : 
	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h1fffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end     
      	                           
      	            
      	      4'b0111 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h3fffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end  
      	      
      	       4'b1000 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h7fffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end  

      	      
      	      4'b1001 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'hffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end

	     4'b1010 : 
      	      begin
      	         if( (cut_add >= 32'h0) && (cut_add <= 32'h1ffffff) )
      	          begin
      	             bpbit_reg<= `TRUE;
      	           end
      	           
      	          else  bpbit_reg<= `FALSE;
      	      end

 
	      4'b1011: bpbit_reg <= `TRUE;
	      4'b1100: bpbit_reg <= `TRUE;
	      4'b1101: bpbit_reg <= `TRUE;
	      4'b1110: bpbit_reg <= `TRUE;
	      4'b1111: bpbit_reg <= `TRUE;
  
      	     default:  bpbit_reg<= `FALSE;
            
	    endcase


	  end
     end



        always@(cut_add or select_ok or address_IB_lock or address_IS_lock or GB_unlock_enable or GB_lock_enable or IB_unlock_enable or IB_lock_enable or IB_read)
        begin
                if(GB_unlock_enable)
                begin
                        IS_bottom_sel <= 16'h0000;
                end
                else if(GB_lock_enable)
                begin
                        IS_bottom_sel <= 16'hffff;
                end
                else if(address_IB_lock == 0)       
                begin   
                        case(address_IS_lock)    //cut_add[15:12])
                        4'b0000:        IS_bottom_sel[0]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[0])); 
                        4'b0001:        IS_bottom_sel[1]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[1])); 
                        4'b0010:        IS_bottom_sel[2]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[2])); 
                        4'b0011:        IS_bottom_sel[3]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[3])); 
                        4'b0100:        IS_bottom_sel[4]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[4])); 
                        4'b0101:        IS_bottom_sel[5]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[5])); 
                        4'b0110:        IS_bottom_sel[6]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[6])); 
                        4'b0111:        IS_bottom_sel[7]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[7])); 
                        4'b1000:        IS_bottom_sel[8]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[8])); 
                        4'b1001:        IS_bottom_sel[9]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[9])); 
                        4'b1010:        IS_bottom_sel[10] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[10])); 
                        4'b1011:        IS_bottom_sel[11] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[11])); 
                        4'b1100:        IS_bottom_sel[12] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[12])); 
                        4'b1101:        IS_bottom_sel[13] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[13])); 
                        4'b1110:        IS_bottom_sel[14] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[14])); 
                        4'b1111:        IS_bottom_sel[15] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_bottom_sel[15]));
                        endcase
                end
                else
                        IS_bottom_sel <= IS_bottom_sel;
        end

        always@(*)
        begin
                if(GB_unlock_enable)
                begin
                        IS_top_sel <= 16'h0000;
                end
                else if(GB_lock_enable)
                begin
                        IS_top_sel <= 16'hffff;
                end
                else if(address_IB_lock == (`BLOCK_NUM-1)) 
                begin   
                        case(address_IS_lock)//       cut_add[15:12])
                        4'b0000:        IS_top_sel[0]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[0])); 
                        4'b0001:        IS_top_sel[1]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[1])); 
                        4'b0010:        IS_top_sel[2]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[2])); 
                        4'b0011:        IS_top_sel[3]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[3])); 
                        4'b0100:        IS_top_sel[4]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[4])); 
                        4'b0101:        IS_top_sel[5]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[5])); 
                        4'b0110:        IS_top_sel[6]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[6])); 
                        4'b0111:        IS_top_sel[7]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[7])); 
                        4'b1000:        IS_top_sel[8]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[8])); 
                        4'b1001:        IS_top_sel[9]  <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[9])); 
                        4'b1010:        IS_top_sel[10] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[10])); 
                        4'b1011:        IS_top_sel[11] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[11])); 
                        4'b1100:        IS_top_sel[12] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[12])); 
                        4'b1101:        IS_top_sel[13] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[13])); 
                        4'b1110:        IS_top_sel[14] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[14])); 
                        4'b1111:        IS_top_sel[15] <=  ( ~IB_unlock_enable & (IB_lock_enable | IS_top_sel[15]));
                        endcase
                end
                else
                        IS_top_sel <= IS_top_sel;
        end

        assign IS_lock_top = (address_IB_lock == (`BLOCK_NUM-1));
        assign IS_lock_bottom = (address_IB_lock == 0);

        assign wps_protect_ber32_bottom_sel = cut_add[15] ? (| IS_bottom_sel[15:8]) : (| IS_bottom_sel[7:0]);
        assign wps_protect_ber32_top_sel        = cut_add[15] ? (| IS_top_sel[15:8]) : (| IS_top_sel[7:0]);

        assign wps_protect_ber32_bottom = ber32 & wps_protect_ber32_bottom_sel;
        assign wps_protect_ber32_top      = ber32 & wps_protect_ber32_top_sel    ;      

        assign wps_protect_ber64_bottom = ber64 & (|IS_bottom_sel);
        assign wps_protect_ber64_top    = ber64 & (|IS_top_sel)  ;


        always@(*)
        begin
            if(GB_unlock_enable | GB_lock_enable)
            begin
                    lock_enable <= {`BLOCK_NUM{1'b1}};
            end
            else if(IB_unlock_enable | IB_lock_enable)
            begin
                    if((address_IB_lock > 0) & (address_IB_lock < (`BLOCK_NUM-1)))
                    begin
                            lock_enable = 0;
                            lock_enable[address_IB_lock] = 1'b1;     //select the block which is wanted to be locked or unlocked
                    end
            end
            else
                        lock_enable <= lock_enable;
        end

        assign wps_lock_sel =	GB_unlock_enable ? 1'b0 :	   
				GB_lock_enable   ? 1'b1 :
				IB_lock_enable && ((address_IB_lock > 0) & (address_IB_lock < (`BLOCK_NUM-1)))? 1'b1:
                                IB_unlock_enable && ((address_IB_lock > 0) & (address_IB_lock < (`BLOCK_NUM-1)))? 1'b0:
                                wps_lock_sel;

        always@(*)
        begin
            for(i = 0; i <= (`BLOCK_NUM-1); i=i+1 )
            begin
                    lock_sel[i] = lock_enable[i] ? wps_lock_sel : lock_sel[i];
            end
        end

        always@(*)
        begin
            if((cut_add[(`BIT_TO_CODE_MEM -1):16] == 0) )
            begin
                    wps_protect_bottom_sel <= (wps_protect_ber64_bottom  | wps_protect_ber32_bottom | ((pp | quadpgm | ex_quadpgm | ser) & IS_bottom_sel[cut_add[15:12]])) ;
            end
            else
            begin
                    wps_protect_bottom_sel <= wps_protect_bottom_sel;
            end
        end

        always@(*)
        begin
                if((cut_add[(`BIT_TO_CODE_MEM -1):16] == (`BLOCK_NUM-1)) )
                begin
                        wps_protect_top_sel <= (wps_protect_ber64_top  | wps_protect_ber32_top | ((pp | quadpgm | ex_quadpgm | ser) & IS_top_sel[cut_add[15:12]])) ;
                end
                else
                begin
                        wps_protect_top_sel <= wps_protect_top_sel;
                end
        end


        always@(*)
        begin
                if(cut_add[(`BIT_TO_CODE_MEM -1):16] == 0)
                begin
                        wps_protect_sel <= wps_protect_bottom_sel;
                end
                else if(cut_add[(`BIT_TO_CODE_MEM -1):16] == (`BLOCK_NUM-1))
                begin
                        wps_protect_sel <= wps_protect_top_sel;
                end
                else if((cut_add[(`BIT_TO_CODE_MEM -1):16] > 0) & (cut_add[(`BIT_TO_CODE_MEM -1):16] < (`BLOCK_NUM-1)))
                begin
                        wps_protect_sel <= lock_sel[cut_add[(`BIT_TO_CODE_MEM -1):16]];
                end
                else wps_protect_sel <= wps_protect_sel;
        end
        

        assign wps_protect = (wps_protect_sel & (pp | quadpgm | ex_quadpgm | ser | ber32 | ber64) ) | (cer & ((|lock_sel[(`BLOCK_NUM-2):1]) | (|IS_bottom_sel) | (|IS_top_sel)) ); 

        always@(*)
        begin
                if(address_IB_read == 0)
                        data_lock_en[0] <= IS_bottom_sel[address_IS_read];
                        else if(address_IB_read == (`BLOCK_NUM-1))
                        data_lock_en[0] <= IS_top_sel[address_IS_read];
                else
                        data_lock_en[0] <= lock_sel[address_IB_read];
        end

     
wire bpbit_otp =((otppgm|otpers) & (address_otp[3] & (address_otp[2])) & LB3) | ((otppgm|otpers) & (address_otp[3] & (!address_otp[2])) & LB2) | ((otppgm|otpers) & ((!address_otp[3]) & address_otp[2]) & LB1);
wire bp_none =  (bp[4:0] == 5'b0) ? 1'b1 : 1'b0;


wire bp_lock = (( pp | quadpgm | ex_quadpgm | ser | ber32 | ber64) & bpbit_reg) | (cer & ~bp_none);

assign bpbit_content = WPS ? wps_protect : bp_lock;

assign  bpbit = bpbit_otp | bpbit_content;


   //-------------------------------------------------------
   // status register protected bits set
   //-------------------------------------------------------   
     always  @(posedge (wrsr_l || wrsr_m || wrsr_h))  
       begin
         case ( { srp1, srp, tmp_wp } )
           3'b010  : 
                        begin
                        if(QE==1'b0)
                        inhib_wrsr <= `TRUE;
                        else    inhib_wrsr <= `FALSE;
                        end

           3'b11?  : inhib_wrsr <= `TRUE;     
           default : inhib_wrsr <= `FALSE; 
         endcase
       end
   //-------------------------------------------------------
   //-------------------------------------------------------
   // This process shifts out status register on data output
   always  @(select_ok )
      begin
         if ((!rdsr_l) || (!rdsr_m)|| (!rdsr_h)  || (!rd_configuration_reg))             
         begin
            inhib_rdsr <= `FALSE ; 
         end 

         if ( (rdsr_l || rdsr_m || rdsr_h || rd_configuration_reg) && (!select_ok) && !qpim)  
         begin
            bit_register <= 0; 
            q_bis <= #`TSHQZ 1'bz ; 
            inhib_rdsr <= `TRUE ; 
             
         end

         if ( (rdsr_l || rdsr_m || rdsr_h || rd_configuration_reg ) && (!select_ok) && qpim)   //qpi added
         begin
                bit_register <= 0; 
                hold_bis<= #`TSHQZ 1'bz ; 
                wp_bis<= #`TSHQZ 1'bz ; 
                q_bis <= #`TSHQZ 1'bz ; 
                d_bis <= #`TSHQZ 1'bz ;

                inhib_rdsr <= `TRUE ; 
         end

      end

   always 
      @(negedge c_int)
      begin

         if (rdsr_l && (select_ok) && !qpim)
         begin
                rdsr_enable <= `TRUE ;
                d_bis <= #`TSHQZ 1'bz ;
                q_bis <= #`TCLQV status_register[7 - bit_register] ; 
                bit_register = bit_register + 1; 
         end
         
          if (rdsr_m && (select_ok) && !qpim)    
         begin
                rdsr_enable <= `TRUE ;
                d_bis <= #`TSHQZ 1'bz ;
                q_bis <= #`TCLQV status_register[15 - bit_register] ; 
                bit_register = bit_register + 1; 
         end

         if (rdsr_h && (select_ok) && !qpim)    
         begin
                rdsr_enable <= `TRUE ;
                d_bis <= #`TSHQZ 1'bz ;
                q_bis <= #`TCLQV status_register[23 - bit_register] ; 
                bit_register = bit_register + 1; 
         end
		 
		 if (rd_configuration_reg  && (select_ok) && !qpim)    
         begin
                rdsr_enable <= `TRUE ;
                d_bis <= #`TSHQZ 1'bz ;
                q_bis <= #`TCLQV configuration_reg[7 - bit_register] ; 
                bit_register = bit_register + 1; 
         end


         if (rdsr_l && (select_ok) && qpim)             //qpi added
         begin
                rdsr_enable <= `TRUE ;
                hold_bis <= #`TCLQV status_register[7 - bit_register*4] ;
                wp_bis <= #`TCLQV status_register[6 - bit_register*4] ;
                q_bis <= #`TCLQV status_register[5 - bit_register*4] ; 
                d_bis <= #`TCLQV status_register[4 - bit_register*4] ;
                bit_register[0] = bit_register[0] + 1; 
                bit_register[2:1]=2'b00;

          end 

         
          if (rdsr_m && (select_ok) && qpim)            //qpi added
         begin
                rdsr_enable <= `TRUE ;
                hold_bis <= #`TCLQV status_register[15 - bit_register*4] ;
                wp_bis <= #`TCLQV status_register[14 - bit_register*4] ;
                q_bis <= #`TCLQV status_register[13 - bit_register*4] ; 
                d_bis <= #`TCLQV status_register[12 - bit_register*4] ;
                bit_register[0] = bit_register[0] + 1; 
                bit_register[2:1]=2'b00;


         end

        if (rdsr_h && (select_ok) && qpim)            //qpi added
          begin
                rdsr_enable <= `TRUE ;
                hold_bis <= #`TCLQV status_register[23 - bit_register*4] ;
                wp_bis <= #`TCLQV status_register[22 - bit_register*4] ;
                q_bis <= #`TCLQV status_register[21 - bit_register*4] ; 
                d_bis <= #`TCLQV status_register[20 - bit_register*4] ;
                bit_register[0] = bit_register[0] + 1; 
                bit_register[2:1]=2'b00;


         end

		 if (rd_configuration_reg && (select_ok) && qpim)            //qpi added
          begin
                rdsr_enable <= `TRUE ;
                hold_bis <= #`TCLQV configuration_reg[7 - bit_register*4] ;
                wp_bis <= #`TCLQV configuration_reg[6 - bit_register*4] ;
                q_bis <= #`TCLQV configuration_reg[5 - bit_register*4] ; 
                d_bis <= #`TCLQV configuration_reg[4 - bit_register*4] ;
                bit_register[0] = bit_register[0] + 1; 
                bit_register[2:1]=2'b00;


         end

      end
     

   //-------------------------------------------------------
   //-------------------------------------------------------
   // This process shifts out extended address register on data output
   // //2008
   always  @(select_ok )
      begin
         if (!rd_ex_addr)             
         begin
            inhib_rd_ex_addr <= `FALSE ; 
         end 

         if (rd_ex_addr && (!select_ok) && !qpim)  
         begin
            bit_register <= 0; 
            q_bis <= #`TSHQZ 1'bz ; 
            inhib_rd_ex_addr <= `TRUE ; 
             
         end

         if (rd_ex_addr && (!select_ok) && qpim)   //qpi added
         begin
                bit_register <= 0; 
                hold_bis<= #`TSHQZ 1'bz ; 
                wp_bis<= #`TSHQZ 1'bz ; 
                q_bis <= #`TSHQZ 1'bz ; 
                d_bis <= #`TSHQZ 1'bz ;

                inhib_rd_ex_addr <= `TRUE ; 
         end

      end

   always 
      @(negedge c_int)
      begin

         if (rd_ex_addr && (select_ok) && !qpim)
         begin
                rd_ex_addr_enable <= `TRUE ;
		d_bis <= #`TSHQZ 1'bz ;
                q_bis <= #`TCLQV extended_addr_reg[7 - bit_register] ; 
                bit_register = bit_register + 1; 
         end
         
         

         if (rd_ex_addr && (select_ok) && qpim)             //qpi added
         begin
                rd_ex_addr_enable <= `TRUE ;
                hold_bis <= #`TCLQV extended_addr_reg[7 - bit_register*4] ;
                wp_bis <= #`TCLQV extended_addr_reg[6 - bit_register*4] ;
                q_bis <= #`TCLQV extended_addr_reg[5 - bit_register*4] ; 
                d_bis <= #`TCLQV extended_addr_reg[4 - bit_register*4] ;
                bit_register[0] = bit_register[0] + 1; 
                bit_register[2:1]=2'b00;

          end 
      end



 //-------------------------------------------------------
 //---------------output enable-------------------------------
  always @(negedge c_int or negedge select_ok) begin
    if (!select_ok)
        oen <=  `FALSE;
    else begin
        #0.1;
        if (read_enable || rdsr_enable || rdid_enable || IB_read_enable || dlp_read_enable)
            oen <=  `TRUE;
        else 
            oen <=  `FALSE;
        end
    end     
     
  //-----------------------------------------------------------
 //--------------------------------------------------------------------------------------
   // This process checks select and deselect conditions. Some other conditions are tested:
   // prog cycle, deep power down mode and read electronic signature.
   always 
   begin : pin_s
      @(s); 
      begin
      if (s == 1'b0)
      begin
         select_ok <= `TRUE ; 
      end 
      else
      begin
         select_ok <= `FALSE ; 
      end 
      end
   end 

   always 
   begin : signal_wip
      @(wip); 
      begin
      if (wip == 1'b1)
      begin
         if (pp || quadpgm || ex_quadpgm || otppgm || otpers  || cer || ber32 || ber64 || ser || (wrsr_l || wrsr_m || wrsr_h || wr_configuration_reg))
         begin
            if ($time != 0) $display("%t:  NOTE :  Read Status Register instruction will be valid",$realtime); 
            only_rdsr <= `TRUE ; 
         end
         if ((pp || quadpgm || ex_quadpgm || otppgm || otpers  || ber32 || ber64 || ser))
         begin
            if ($time != 0) $display("%t:  NOTE :  Erase/Program suspend instruction will be valid",$realtime); 
            only_suspend <= `TRUE ;         
         end 
      end 
      else
      begin
         only_rdsr <= `FALSE ; 
         write_op  <= `FALSE ;
         only_suspend <= `FALSE ;
      end 
      end
   end 

   //factory mode 
 always @(*) begin
   	if(factory_mode) begin
		tSE = `TSE_F;   //combine with `Tbase
		tBE1 = `TBE1_F;
		tBE2 = `TBE2_F;
		tCE = `TCE_F;
		tPP = `TPP_F;
	end
	else begin
		tSE = `TSE;
		tBE1 = `TBE1;
		tBE2 = `TBE2;
		tCE = `TCE;
		tPP = `TPP;
	end
   end 


always @(negedge select_ok)
begin
    dlp_done <= `FALSE;
    bit_index_dlp <= `FALSE;
end


//output dlp
always@ (c_int)
begin
    #0.5;
    if ((DTR_quad_read || DTR_single_read) && dlp_read_enable && (!suspend_enable) && select_ok)
    begin
	if(DLP && (!dlp_done))
	    begin
		#1;
		hold_bis <= dlp_bit[7- bit_index_dlp] ;
		wp_bis	<= dlp_bit[7 - bit_index_dlp] ;
                q_bis	<= dlp_bit[7 - bit_index_dlp] ; 
		d_bis	<= dlp_bit[7 - bit_index_dlp] ;
		bit_index_dlp <= bit_index_dlp + 1'b1;
		
		if(bit_index_dlp == 7)  
		begin
		    dlp_done = `TRUE;
		end

	    end
    end
end


//output dlp read enable
always@ (posedge byte_ok)
begin
    if( (DTR_quad_read_with_dlp || DTR_single_read_with_dlp) && (!dlp_done))
    begin
	dlp_read_enable <= `TRUE;	
    end else if(dlp_done)
    begin
	dlp_read_enable <= `FALSE;
    end
end
 
always@(negedge select_ok)
begin
    read_enable <=  `FALSE;
    erase_enable <=  `FALSE;
    write_enable <=  `FALSE;
end


endmodule
