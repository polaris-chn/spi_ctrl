20260804
完成v1版本，但是发现重大缺陷，修改至v2版本

20260805
完成v2版本50%指令译码，但还是很粗糙，有些控制信号不统一且肯定有错漏，
在v3版本中希望将decode分为decode_qpi和decode_spi

复位方式：
（1）硬件复位：拉低RESET# : reset_hard;
（2）软件复位：66+99指令  ：reset_soft;
（3）上电复位：por        ：reset_por;
无论哪种复位方式，在复位后都直接进入idle stage

assgin rstn = reset_hard | reset_soft | reset_por;

20260806
（1）从时序图看，AB指令如果在指令输入之后就拉高cs#，那么只退出deep power down模式；如果指令输入之后还有dummy cycle，则先输入device id，再退出deep power down模式
（2）0C指令在spi和qpi模式下功能不同，在spi下是fast read with 4B address; 在qpi下是burst read with wrap

使用了git进行版本控制，更方便开发
云平台相应也使用了git版本控制


20260807
（1）版本3中 50指令有效，则01/11指令写入的是sr的副本，否则写入的是sr的本体
（2）完成版本3中fsm主体，现在看来只有3个大的状态，idle, decode, drive
（3）spi共73条指令；qpi共58条指令


20260821
（1）初步完成v4代码框架，进行人工逻辑梳理；
（2）burst读在qpi模式下使用C0H配置wrap length参数（还有dummy周期和时钟周期参数）；在spi模式下使用77H配置wrap length参数；所以这有两套参数，但是datasheet指明模式切换不影响wrap length等参数，此点还需确认；暂定在spi模式下用spi的参数，在qpi模式下用qpi的参数；				
（3）在qpi模式下使用burst读的指令为0CH和0EH；v4代码中存储该信息的是qpi_read_param_reg
（4）在spi模式下使用burst读的指令为EB/EC/ED/EEh；v4代码中存储该信息的是spi_wrap_data_reg；
（5）50H指令功能是让SR中的NV位变成Volatile位，现在实现的方案是对NV bit设置影子副本