# GD25LF256F 命令控制模块（ctrl_if）功能设计文档

| 项目 | 内容 |
|---|---|
| 文档版本 | v1.0 |
| 日期 | 2026-08-24 |
| 来源 Spec | `GD25LF256F.pdf`（256Mbit 1.8V Uniform Sector Dual/Quad Serial Flash） |
| 目标模块 | `ctrl_if`：SPI/QPI 命令译码、周期计数、采样/驱动模式与执行使能生成 |
| 用途 | 作为 RTL 编码的直接依据；所有命令拍数、模式、使能和状态转移均应能在本文查到 |
| 关联实现 | `ctrl_if_v1.v`~`ctrl_if_v5.v`（现有参考实现），本文以 PDF 规格为准，现有 RTL 仅作交叉核对 |

## 目录

1. 范围与设计目标
2. 参考文档与术语
3. 顶层接口定义
4. 全局行为与复位
5. 内部寄存器定义
6. 命令合法性规则
7. 全命令详细规格表（131 条指令×模式）
8. 特殊功能详细设计（QPI/ADS/50h/软件复位/DPD/XIP/连续读/77h-C0h/暂停/密码/SFDP）
9. 命令译码伪代码（RTL 骨架）
10. 未决项与实现前必须确认的问题
11. 与现有 ctrl_if_v4 的主要差异
12. 签核前检查清单

## 0. 文档使用说明

- 本文所有 **SCLK 拍数**均为 SCLK 周期数，不是 bit 数。
- 地址拍数按当前地址模式 `ADS` 给出公式；`ADS=0` 为 3 字节地址，`ADS=1` 为 4 字节地址。
- `SPI` 指标准 SPI 命令入口；数据/地址过程中可切换 dual/quad/DTR。`QPI` 指 2 拍四线命令入口。
- `BC` = Byte Boundary，命令要求 CS# 在字节边界拉高；`CS_ANY` = 读数据期间 CS# 可任意时刻拉高。
- 表中 `*_en` 均为组合译码输出，默认 0，命令命中并满足合法性时置 1；下游 FSM 在 `posedge sclk` 采样执行。
- 标 ⚠ 的条目为 PDF 文字与波形图/表格存在解释差异，RTL 实现前必须人工确认并冻结。

## 1. 范围与设计目标

本模块实现 GD25LF256F 的数字命令控制部分：

1. 检测 CS# 下降沿，在 SPI/QPI 模式下锁存命令字节；
2. 按命令码输出本命令的采样模式、驱动模式、命令/地址/模式字节/dummy/数据拍数；
3. 输出写 SR、写阵列、读阵列、擦除、暂停/恢复、锁定、密码、DPD、复位等**执行使能**；
4. 管理 QPI 模式、ADS 地址模式、DPD 状态、软件复位使能、volatile SR 写使能、wrap/read 参数；
5. 实现 POR-XIP 与 Continuous Read Mode 的 XIP 时序；
6. 依据 WEL/WIP/SUS/PWD/保护状态拒绝非法命令（状态本身可由阵列 FSM/寄存器维护，本模块消费）。

不在本模块实现：SI/SO/IO 物理移位电路、Flash 存储阵列、电荷泵、模拟时序、ECC/CRC 计算器、DQS 输出电路。这些由阵列 FSM / 模拟顶层实现，但本模块输出其需要的全部数字控制。

## 2. 参考文档与术语

| 缩写 | 含义 |
|---|---|
| SPI | Serial Peripheral Interface，单/双/四线 SPI 模式 |
| QPI | Quad Peripheral Interface，命令也以 4 线 2 拍输入 |
| STR / DTR | Single / Double Transfer Rate |
| ADS | Address Status，1 表示 4 字节地址模式 |
| EAR | Extended Address Register |
| WEL / WIP | Write Enable Latch / Write In Progress |
| DPD | Deep Power-Down |
| XIP | Execute In Place，连续读模式 |
| POR-XIP | 上电后直接进入 XIP |
| SR1/2/3 | Status Register 1/2/3 |
| FSR | Flag Status Register |
| NVCR / VCR | Nonvolatile / Volatile Configuration Register |
| NVLR / VLR | Nonvolatile / Volatile Lock Register |
| PWD | Password Protection Mode 指示 |
| SFDP | Serial Flash Discoverable Parameter |

PDF 命令章节页码：9.1~9.55 见 PDF 第 55~99 页；命令输入格式注意项见第 52~54 页。

## 3. 顶层接口定义

### 3.1 端口列表

接口保持与现有 `ctrl_if_v4` 兼容，并增加命令合法性所需状态输入。`*` 为本文新增建议端口。

| 方向 | 信号 | 宽度 | 说明 |
|---|---|---|---|
| input | `sclk` | 1 | 串行时钟，模块唯一时钟 |
| input | `rstn` | 1 | 异步硬件复位，低有效 |
| input | `cs` | 1 | 片选，低有效；1 表示 deselect |
| input | `cmd` | 8 | 当前锁存的命令字节（由移位逻辑输入，命令阶段有效） |
| input | `cm` | 8 | Continuous Read mode byte / 模式字节（XIP 相关） |
| input | `por_xip` | 1 | 上电/复位后是否直接进入 XIP |
| input | `vncr_0` | 8 | POR-XIP 配置字节（FC/FD/FE/FB 等） |
| input | `ads` | 1 | 当前地址模式：0=3B，1=4B |
| input | `pwd` | 1 | 当前密码保护模式：0=normal，1=advanced password protection |
| input | `spi_wrap_data` | 8 | 77h 命令收到的 wrap/dummy 数据字节（W6-W4） |
| input | `qpi_read_param` | 8 | C0h 命令收到的 read parameter（P7-P0） |
| input* | `wel` | 1 | 当前 WEL 状态 |
| input* | `wip` | 1 | 当前 WIP 状态 |
| input* | `sus` | 3 | 当前 SUS3/SUS2/SUS1 状态，0=未挂起 |
| output | `clear_por_xip` | 1 | 清除 POR-XIP 状态（XIP mode byte !=10 时） |
| output | `write_SR_shadow_en` | 1 | 50h 使能后写 SR 影子/易失副本 |
| output | `write_SR_en` | 1 | 普通 WRSR 执行使能 |
| output | `write_array_en` | 1 | Page Program 写阵列使能 |
| output | `read_array_en` | 1 | 读阵列使能（含 Fast Read/SFDP） |
| output | `read_SR_en` | 1 | 读状态寄存器使能 |
| output | `set_wel` | 1 | WREN：置 WEL |
| output | `clear_wel` | 1 | WRDI：清 WEL |
| output | `clear_FSR` | 1 | 清 Flag Status Register |
| output | `read_FSR_en` | 1 | 读 FSR |
| output | `erase_sector_en` | 1 | 4KB Sector Erase |
| output | `erase_block32_en` | 1 | 32KB Block Erase |
| output | `erase_block64_en` | 1 | 64KB Block Erase |
| output | `erase_chip_en` | 1 | Chip Erase |
| output | `pes_en` | 1 | Program/Erase/DIC Suspend |
| output | `per_en` | 1 | Program/Erase/DIC Resume |
| output | `data_crc_en` | 1 | Data Integrity Check（5Bh）执行 |
| output | `global_block_sector_lock_en` | 1 | 7Eh 全局锁定 |
| output | `global_block_sector_unlock_en` | 1 | 98h 全局解锁 |
| output | `write_VCR_en` | 1 | 写 Volatile Configuration Register |
| output | `read_VCR_en` | 1 | 读 VCR |
| output | `write_NVCR_en` | 1 | 写 Nonvolatile Configuration Register |
| output | `read_NVCR_en` | 1 | 读 NVCR |
| output | `read_manuid_devid_en` | 1 | 90h 读 Manufacturer/Device ID |
| output | `rdid_en` | 1 | 9Fh 读 JEDEC ID |
| output | `read_devid_en` | 1 | ABh 释放 DPD 时读 Device ID |
| output | `read_itcrcr_en` | 1 | 64h 读 Interface CRC Register |
| output | `write_EAR_en` | 1 | C5h 写扩展地址寄存器 |
| output | `read_EAR_en` | 1 | C8h 读扩展地址寄存器 |
| output | `write_VLR_en` | 1 | E1h 写 Volatile Lock Register |
| output | `read_VLR_en` | 1 | E0h 读 VLR |
| output | `read_NVLR_en` | 1 | E2h 读 NVLR |
| output | `set_NVLR_en` | 1 | E3h 写 NVLR |
| output | `clear_all_NVLR_en` | 1 | E4h 清全部 NVLR |
| output | `set_ads` | 1 | B7h：进入 4B 地址模式 |
| output | `clear_ads` | 1 | E9h：退回 3B 地址模式 |
| output | `write_sec_reg_en` | 1 | 42h 写 Security Register |
| output | `erase_sec_reg_en` | 1 | 44h 擦 Security Register |
| output | `read_sec_reg_en` | 1 | 48h 读 Security Register |
| output | `read_uid_en` | 1 | 4Bh 读 Unique ID |
| output | `rst_all` | 1 | 软件复位脉冲，复位全部易失状态 |
| output | `exit_dpd_en` | 1 | 退出 Deep Power-Down |
| output | `enter_dpd_en` | 1 | 进入 Deep Power-Down |
| output | `write_pwd_en` | 1 | 28h 写密码寄存器 |
| output | `read_pwd_en` | 1 | 27h 读密码寄存器 |
| output | `pwd_lock_unlock_en` | 1 | 29h 密码锁定/解锁校验 |
| output | `wrap_len` | 7 | 当前 wrap 长度（字节数，8/16/32/64） |
| output | `cm_cycle` | 8 | mode byte 拍数 |
| output | `cmd_cycle` | 8 | 命令拍数 |
| output | `dummy_cycle` | 8 | dummy 拍数 |
| output | `data_cycle` | 8 | 定长数据拍数；连续数据命令为参考值 |
| output | `addr_cycle` | 8 | 地址拍数 |
| output | `sample_cmd_mode` | 3 | 命令采样模式 |
| output | `sample_mode` | 3 | 地址/数据采样模式 |
| output | `drive_mode` | 3 | 数据输出驱动模式 |
| output | `write_SR_addr` | 2 | WRSR 目标：0=SR1&SR2，2=SR3 |
| output | `read_SR_addr` | 2 | RDSR 目标：0=SR1，1=SR2，2=SR3 |

### 3.2 模式编码

| 编码 | 名称 | 说明 |
|---|---|---|
| 0 | `IDLE_MODE` | 无采样/驱动 |
| 1 | `STD` | standard SPI，1 bit/边沿 |
| 2 | `DUAL` | dual SPI，2 bit/SCLK（STR） |
| 3 | `QUAD` | quad SPI/QPI，4 bit/SCLK（STR） |
| 4 | `DDR2` | dual DTR，2 lane × 2 edge = 4 bit/SCLK |
| 5 | `DDR4` | quad DTR，4 lane × 2 edge = 8 bit/SCLK |

### 3.3 拍数换算

| 模式 | 1 字节命令 | 3B 地址 | 4B 地址 | 1 字节数据 |
|---|---|---|---|---|
| SPI STD | 8 | 24 | 32 | 8 |
| SPI DUAL | - | 12 | 16 | 4 |
| SPI QUAD | - | 6 | 8 | 2 |
| QPI QUAD | 2 | 6 | 8 | 2 |
| SPI/QPI DDR2 | - | 6 | 8 | 4 bit/SCLK |
| SPI/QPI DDR4 | - | 3 | 4 | 8 bit/SCLK |

## 4. 全局行为与复位

### 4.1 复位

| 复位源 | 触发 | 模块动作 |
|---|---|---|
| 硬件复位 | `rstn=0` | 异步清全部寄存器，状态回 `IDLE` |
| 上电复位 POR | 顶层给 `rstn` 或复位脉冲 | 同硬件复位，另 `por_xip` 由顶层按 VNCR 给出 |
| 软件复位 | 66h + 99h 序列 | `rst_all` 脉冲一拍；清 `qpi_mode_reg`、`dpd_reg`、`en_rst_reg`、`write_VSR_en_reg`、`spi_wrap_data_reg`、`qpi_read_param_reg/valid`、`cmd_xip`；状态回 `IDLE`；`por_xip` 是否保留由顶层决定 |

复位后默认值：

| 寄存器 | 复位值 | PDF 依据 |
|---|---|---|
| `current_state` | `IDLE` | 复位后回 Standby，任何复位后直接进入 idle |
| `cnt` | 0 | - |
| `qpi_mode_reg` | 0（SPI 模式） | 器件默认 SPI |
| `dpd_reg` | 0 | 上电/复位退出 DPD |
| `en_rst_reg` | 0 | - |
| `write_VSR_en_reg` | 0 | 50h 使能被复位清除 |
| `spi_wrap_data_reg` | `8'h10`（W4=1，不 wrap） | 复位清 wrap setting |
| `qpi_read_param_reg` | 0 | 复位清 P7-P0 |
| `qpi_read_param_valid` | 0 | 复位后使用默认 dummy 值 |
| `cmd_xip` | 0 | 复位清连续读模式位 |
| `cmd_reg` | 0 | - |

### 4.2 SCLK 计数器 `cnt`

```text
if (!rstn || rst_all || cs==1)     cnt <= 0;
else if (cs_fall)                 cnt <= 1;   // CS#下降沿后的第一个sclk
else if (cnt == 8'hFF)           cnt <= cnt; // 饱和，防连续读回绕
else                              cnt <= cnt + 1;
```

`cs_fall = cs_prev & ~cs`，`cs_prev` 在 `posedge sclk` 更新。

### 4.3 CS# 规则

| 命令类型 | CS# 结束规则 |
|---|---|
| 读类（阵列/寄存器/ID/SFDP/UID） | 数据输出期间任意时刻 CS#↑ 结束，回 `IDLE` |
| 写/擦/配置/DPD/复位/仅命令类 | 必须在字节边界（SPI 第 8n 拍、QPI 第 2n 拍）CS#↑；提前/滞后则命令 reject，状态回 `IDLE` |
| PP/QPP/Security Program | 地址后至少 1 字节数据，数据字节边界 CS#↑；不足一个字节则不执行且 WEL 不清 |
| WRSR 01h | SPI 允许第 8 或 16 数据位 CS#↑；仅 8 位时 SR2 可变位清 0 |
| 28h/29h | 必须正好 64 bit 数据后 CS#↑，否则不执行 |
| 5Bh | 两段 4B 地址共 8 字节后 CS#↑ |
| 77h | 命令+24 dummy bit 后 CS#↑ |

### 4.4 命令采样

- SPI：`cmd_cycle=8`，`sample_cmd_mode=STD`，MSB first，rising edge 锁存。
- QPI：`cmd_cycle=2`，`sample_cmd_mode=QUAD`，第 1 拍锁存 C7-C4，第 2 拍锁存 C3-C0。
- 命令阶段 `cnt < cmd_cycle` 时保持当前状态；`cnt >= cmd_cycle` 后按命令分支译码。

### 4.5 输出时序约定

全部输出为组合逻辑：当前状态、`cnt`、`cmd`、配置寄存器的函数。默认值全 0；`next_state` 默认保持。下游 FSM 在 `posedge sclk` 采样。`*_en` 在命令执行窗口内保持为 1，窗口结束回 0。

## 5. 内部寄存器定义

| 寄存器 | 位置/更新 | 置位 | 清除 | 说明 |
|---|---|---|---|---|
| `current_state` | posedge sclk | `next_state` | 复位 | 4 状态 FSM |
| `cs_prev` | posedge sclk | `cs` | 复位=1 | 产生 `cs_fall` |
| `cnt` | posedge sclk | +1/饱和 | cs=1/复位 | 见 4.2 |
| `qpi_mode_reg` | posedge sclk | 38h | FFh/复位 | QPI 模式 |
| `dpd_reg` | posedge sclk | `enter_dpd_en` | `exit_dpd_en`/复位 | DPD 状态 |
| `en_rst_reg` | posedge sclk | 66h | 99h 执行/复位 | 软件复位使能 |
| `write_VSR_en_reg` | posedge sclk | 50h | 非 50/01/11 命令边界；WRSR 完成；复位 | volatile SR 写使能 |
| `spi_wrap_data_reg` | posedge sclk | `spi_wrap_data_en` | 复位=0x10 | 77h 配置 |
| `qpi_read_param_reg` | posedge sclk | `qpi_read_param_en` | 复位 | C0h 配置 |
| `qpi_read_param_valid` | posedge sclk | `qpi_read_param_en` | 复位 | 0=用默认 dummy |
| `cmd_reg` | posedge sclk | `cmd` | 复位 | XIP 连续读保存上一条读命令 |
| `cmd_xip` | posedge sclk | `cm[5:4]==2'b10` 采样成立 | 其他 | 连续读模式标志 |

## 6. 命令合法性规则（PDF 提取）

### 6.1 WEL 要求

| 要求 WEL=1 | 指令 |
|---|---|
| 是 | 01,11,02,12,32,34,20,21,52,5C,D8,DC,60,C7,44,42,28,C5,B1,81,E1,E3,E4 |
| 否 | 06,04,05,35,15,70,30,50,03,13,0B,0C,0E,3B,3C,6B,6C,BB,BC,BD,BE,EB,EC,ED,EE,38,FF,B9,AB,66,99,75,7A,7E,98,27,29,48,4B,5A,5B,64,90,9F,C0,77,C8,B5,85,E0,E2 |
| 条件 | 75h 需 WIP=1 且 SUS=0；7Ah 需 SUS!=0 且 WIP=0；27h/28h 需 PWD=0；29h 需 PWD=1；30h 需 WIP=0；E4h 另需 PWD=0 或 PWDVFY=1 |

### 6.2 忙/挂起期间命令限制

- WIP=1 时：除 RDSR(05/35/15)、RDFSR(70h) 外，写/擦/配置/读阵列命令 reject。
- Program/Data Integrity Check Suspend 期间禁止：01,11,B1,AA,55,44,42,20,21,52,5C,D8,DC,60,C7,02,12,32,34,5B,50,27,28,29,E1,E3,E4,7E,98。
- Erase Suspend 期间禁止：01,11,B1,AA,55,44,20,21,52,5C,D8,DC,60,C7,5B,50,27,28,29,E1,E3,E4,7E,98。
- DPD 期间仅允许：AB,66,99；其余一律 reject。

### 6.3 保护条件

| 条件 | 处理 |
|---|---|
| PP/SE/BE/CE 地址落在 BP 保护区 | 命令不执行（地址译码/保护判断在阵列 FSM） |
| Security Register Lock Bit=1 | 44h/42h 忽略 |
| E1h 数据非 00h/FFh | 忽略 |
| 28h 数据不足/超过 8 字节 | 不执行 |
| C5h 在 ADS=1 | 地址字节忽略/被后续 4B 地址替换 |
| CE 且存在 sector 被保护 | 忽略 |

## 7. 全命令详细规格表

图例：`BC`=字节边界；`CS_ANY`=CS#可随时结束；`TH`=到拍数阈值回 idle；`CONT`=连续至 CS#↑。`addr` 均为 SCLK 拍数表达式。

### 7.1 WEL/状态类


#### 写使能/状态寄存器

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 06h | SPI | p55 §9.1 | Write Enable WREN | 8 | - | - | - | - | STD | STD | - | set_wel=1 | BC | N | CS#在命令字节边界拉高 |
| 06h | QPI | p55 §9.1 | Write Enable WREN | 2 | - | - | - | - | QUAD | QUAD | - | set_wel=1 | BC | N | - |
| 04h | SPI | p55 §9.2 | Write Disable WRDI | 8 | - | - | - | - | STD | STD | - | clear_wel=1 | BC | N | - |
| 04h | QPI | p55 §9.2 | Write Disable WRDI | 2 | - | - | - | - | QUAD | QUAD | - | clear_wel=1 | BC | N | - |
| 05h | SPI | p56 §9.3 | Read SR1 | 8 | - | - | - | - | STD | STD | STD | read_SR_en=1; read_SR_addr=0 | CS_ANY | - | - |
| 05h | QPI | p56 §9.3 | Read SR1 | 2 | - | - | - | - | QUAD | QUAD | QUAD | read_SR_en=1; read_SR_addr=0 | CS_ANY | - | - |
| 35h | SPI | p56 §9.3 | Read SR2 | 8 | - | - | - | - | STD | STD | STD | read_SR_en=1; read_SR_addr=1 | CS_ANY | - | - |
| 35h | QPI | p56 §9.3 | Read SR2 | 2 | - | - | - | - | QUAD | QUAD | QUAD | read_SR_en=1; read_SR_addr=1 | CS_ANY | - | - |
| 15h | SPI | p56 §9.3 | Read SR3 | 8 | - | - | - | - | STD | STD | STD | read_SR_en=1; read_SR_addr=2 | CS_ANY | - | - |
| 15h | QPI | p56 §9.3 | Read SR3 | 2 | - | - | - | - | QUAD | QUAD | QUAD | read_SR_en=1; read_SR_addr=2 | CS_ANY | - | - |
| 70h | SPI | p56 §9.4 | Read Flag Status Register | 8 | - | - | - | - | STD | STD | STD | read_FSR_en=1 | CS_ANY | - | 可连续读，WIP=1 也可读 |
| 70h | QPI | p56 §9.4 | Read Flag Status Register | 2 | - | - | - | - | QUAD | QUAD | QUAD | read_FSR_en=1 | CS_ANY | - | - |
| 30h | SPI | p61 §9.9 | Clear FSR | 8 | - | - | - | - | STD | STD | - | clear_FSR=1 | BC | N | WIP=1 时忽略；WEL 不变 |
| 30h | QPI | p61 §9.9 | Clear FSR | 2 | - | - | - | - | QUAD | QUAD | - | clear_FSR=1 | BC | N | - |
| 50h | SPI | p60 §9.8 | Write Enable for Volatile SR | 8 | - | - | - | - | STD | STD | - | set_volatile_sr_write=1 | BC | N | 不置 WEL；任何其他命令（除01/11）清除 |
| 50h | QPI | p60 §9.8 | Write Enable for Volatile SR | 2 | - | - | - | - | QUAD | QUAD | - | set_volatile_sr_write=1 | BC | N | - |
| 01h | SPI | p57 §9.5 | Write SR1&2 | 8 | - | - | - | 16（允许 8 提前结束） | STD | STD | - | write_SR_en 或 write_SR_shadow_en；write_SR_addr=0 | BC | Y | 50h 后走 shadow；8位结束则SR2可变位清0；完成清WEL |
| 01h | QPI | p57 §9.5 | Write SR1&2 | 2 | - | - | - | 4（允许 2 提前结束） | QUAD | QUAD | - | write_SR_en 或 write_SR_shadow_en；write_SR_addr=0 | BC | Y | - |
| 11h | SPI | p57 §9.5 | Write SR3 | 8 | - | - | - | 8 | STD | STD | - | write_SR_en 或 write_SR_shadow_en；write_SR_addr=2 | BC | Y | 完成清WEL |
| 11h | QPI | p57 §9.5 | Write SR3 | 2 | - | - | - | 2 | QUAD | QUAD | - | write_SR_en 或 write_SR_shadow_en；write_SR_addr=2 | BC | Y | - |

#### EAR/配置寄存器

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C8h | SPI | p59 §9.6 | Read EAR | 8 | - | - | - | - | STD | STD | STD | read_EAR_en=1 | CS_ANY | - | ADS=1 时 EAR 值被忽略 |
| C8h | QPI | p59 §9.6 | Read EAR | 2 | - | - | - | - | QUAD | QUAD | QUAD | read_EAR_en=1 | CS_ANY | - | - |
| C5h | SPI | p59 §9.7 | Write EAR | 8 | - | - | - | 8 | STD | STD | - | write_EAR_en=1 | BC | Y | 仅 ADS=0 有效；复位清0 |
| C5h | QPI | p59 §9.7 | Write EAR | 2 | - | - | - | 2 | QUAD | QUAD | - | write_EAR_en=1 | BC | Y | - |
| B1h | SPI | p61 §9.10 | Write NVCR | 8 | ADS?32:24 | - | - | 8 | STD | STD | - | write_NVCR_en=1 | BC | Y | 完成清WEL，tW |
| B1h | QPI | p61 §9.10 | Write NVCR | 2 | ADS?8:6 | - | - | 2 | QUAD | QUAD | - | write_NVCR_en=1 | BC | Y | - |
| 81h | SPI | p61 §9.10 | Write VCR | 8 | ADS?32:24 | - | - | 8 | STD | STD | - | write_VCR_en=1 | BC | Y | volatile 立即生效 |
| 81h | QPI | p61 §9.10 | Write VCR | 2 | ADS?8:6 | - | - | 2 | QUAD | QUAD | - | write_VCR_en=1 | BC | Y | - |
| B5h | SPI | p62 §9.11 | Read NVCR | 8 | ADS?32:24 | - | 8 | - | STD | STD | STD | read_NVCR_en=1 | CS_ANY | - | 忙时 reject |
| B5h | QPI | p62 §9.11 | Read NVCR | 2 | ADS?8:6 | - | 8 | - | QUAD | QUAD | QUAD | read_NVCR_en=1 | CS_ANY | - | - |
| 85h | SPI | p62 §9.11 | Read VCR | 8 | ADS?32:24 | - | 8 | - | STD | STD | STD | read_VCR_en=1 | CS_ANY | - | - |
| 85h | QPI | p62 §9.11 | Read VCR | 2 | ADS?8:6 | - | 8 | - | QUAD | QUAD | QUAD | read_VCR_en=1 | CS_ANY | - | - |

#### 读阵列与快速读

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 03h | SPI | p63 §9.12 | Read Data Bytes | 8 | ADS?32:24 | - | - | - | STD | STD | STD | read_array_en=1 | CS_ANY | - | 忙时 reject；地址自动递增 |
| 13h | SPI | p63 §9.12 | Read Data Bytes 4B | 8 | 32 | - | - | - | STD | STD | STD | read_array_en=1 | CS_ANY | - | - |
| 0Bh | SPI | p63 §9.13 | Fast Read | 8 | ADS?32:24 | - | 8 | - | STD | STD | STD | read_array_en=1 | CS_ANY | - | - |
| 0Bh | QPI | p63 §9.13 | Fast Read QPI | 2 | ADS?8:6 | - | C0_STR(P5-P4)；复位默认 6 ⚠ | - | QUAD | QUAD | QUAD | read_array_en=1 | CS_ANY | - | - |
| 0Ch | SPI | p63 §9.13 | Fast Read 4B | 8 | 32 | - | 8 | - | STD | STD | STD | read_array_en=1 | CS_ANY | - | - |
| 0Ch | QPI | p72 §9.20 | Burst Read with Wrap | 2 | ADS?8:6 | - | C0_STR(P5-P4)；复位默认 4 | - | QUAD | QUAD | QUAD | read_array_en=1; wrap_len=C0 P1-P0 | CS_ANY | - | wrap 8/16/32/64B |
| 0Eh | QPI | p72 §9.21 | DTR Burst Read with Wrap | 2 | ADS?4:3 | - | C0_DDR(P5-P4)；复位默认 10 | - | QUAD | DDR4 | DDR4 | read_array_en=1; wrap_len=C0 P1-P0 | CS_ANY | - | - |
| 3Bh | SPI | p65 §9.14 | Dual Output Fast Read | 8 | ADS?32:24 | - | 8 | - | STD | STD | DUAL | read_array_en=1 | CS_ANY | - | 地址 standard，数据 dual |
| 3Ch | SPI | p65 §9.14 | Dual Output Fast Read 4B | 8 | 32 | - | 8 | - | STD | STD | DUAL | read_array_en=1 | CS_ANY | - | - |
| 6Bh | SPI | p65 §9.15 | Quad Output Fast Read | 8 | ADS?32:24 | - | 8 | - | STD | STD | QUAD | read_array_en=1 | CS_ANY | - | 地址 standard，数据 quad |
| 6Ch | SPI | p65 §9.15 | Quad Output Fast Read 4B | 8 | 32 | - | 8 | - | STD | STD | QUAD | read_array_en=1 | CS_ANY | - | - |
| BBh | SPI | p66 §9.16 | Dual I/O Fast Read | 8 | ADS?16:12 | 4 | 0 | - | STD | DUAL | DUAL | read_array_en=1 | CS_ANY | - | M5-4=10 则下次免命令 |
| BCh | SPI | p66 §9.16 | Dual I/O Fast Read 4B | 8 | 16 | 4 | 0 | - | STD | DUAL | DUAL | read_array_en=1 | CS_ANY | - | - |
| BDh | SPI | p68 §9.17 | Dual I/O DTR Read | 8 | ADS?8:6 | 2 | 4 | - | STD | DDR2 | DDR2 | read_array_en=1 | CS_ANY | - | - |
| BEh | SPI | p68 §9.17 | Dual I/O DTR Read 4B | 8 | 8 | 2 | 4 | - | STD | DDR2 | DDR2 | read_array_en=1 | CS_ANY | - | - |
| EBh | SPI | p69 §9.18 | Quad I/O Fast Read | 8 | ADS?8:6 | 2 | 4 | - | STD | QUAD | QUAD | read_array_en=1 | CS_ANY | - | - |
| ECh | SPI | p69 §9.18 | Quad I/O Fast Read 4B | 8 | 8 | 2 | 4 | - | STD | QUAD | QUAD | read_array_en=1 | CS_ANY | - | - |
| EBh | QPI | p69 §9.18 | Quad I/O Fast Read QPI | 2 | ADS?8:6 | 2 | C0_STR；复位默认 2 | - | QUAD | QUAD | QUAD | read_array_en=1 | CS_ANY | - | - |
| ECh | QPI | p69 §9.18 | Quad I/O Fast Read 4B QPI | 2 | 8 | 2 | C0_STR；复位默认 2 | - | QUAD | QUAD | QUAD | read_array_en=1 | CS_ANY | - | - |
| EDh | SPI | p70 §9.19 | Quad I/O DTR Read | 8 | ADS?4:3 | 1 | 7 | - | STD | DDR4 | DDR4 | read_array_en=1 | CS_ANY | - | - |
| EEh | SPI | p70 §9.19 | Quad I/O DTR Read 4B | 8 | 4 | 1 | 7 | - | STD | DDR4 | DDR4 | read_array_en=1 | CS_ANY | - | - |
| EDh | QPI | p70 §9.19 | Quad I/O DTR Read QPI | 2 | ADS?4:3 | 1 | C0_DDR；复位默认 9 | - | QUAD | DDR4 | DDR4 | read_array_en=1 | CS_ANY | - | - |
| EEh | QPI | p70 §9.19 | Quad I/O DTR Read 4B QPI | 2 | 4 | 1 | C0_DDR；复位默认 9 | - | QUAD | DDR4 | DDR4 | read_array_en=1 | CS_ANY | - | - |

#### 编程/擦除

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 02h | SPI | p74 §9.24 | Page Program | 8 | ADS?32:24 | - | - | CONT(1~256B) | STD | STD | - | write_array_en=1 | CONT+BC | Y | CS#字节边界；>256B只留最后256B；完成清WEL |
| 02h | QPI | p74 §9.24 | Page Program | 2 | ADS?8:6 | - | - | CONT(1~256B) | QUAD | QUAD | - | write_array_en=1 | CONT+BC | Y | - |
| 12h | SPI | p74 §9.24 | Page Program 4B | 8 | 32 | - | - | CONT(1~256B) | STD | STD | - | write_array_en=1 | CONT+BC | Y | - |
| 12h | QPI | p74 §9.24 | Page Program 4B | 2 | 8 | - | - | CONT(1~256B) | QUAD | QUAD | - | write_array_en=1 | CONT+BC | Y | - |
| 32h | SPI | p75 §9.25 | Quad Page Program | 8 | ADS?32:24 | - | - | CONT(1~256B) | STD | STD→QUAD@addr_end | - | write_array_en=1 | CONT+BC | Y | 地址 standard，数据 quad |
| 34h | SPI | p75 §9.25 | Quad Page Program 4B | 8 | 32 | - | - | CONT(1~256B) | STD | STD→QUAD@addr_end | - | write_array_en=1 | CONT+BC | Y | - |
| 20h | SPI | p76 §9.26 | Sector Erase 4KB | 8 | ADS?32:24 | - | - | - | STD | STD | - | erase_sector_en=1 | BC | Y | 地址最后字节边界CS#↑；完成清WEL |
| 20h | QPI | p76 §9.26 | Sector Erase 4KB | 2 | ADS?8:6 | - | - | - | QUAD | QUAD | - | erase_sector_en=1 | BC | Y | - |
| 21h | SPI | p76 §9.26 | Sector Erase 4B | 8 | 32 | - | - | - | STD | STD | - | erase_sector_en=1 | BC | Y | - |
| 21h | QPI | p76 §9.26 | Sector Erase 4B | 2 | 8 | - | - | - | QUAD | QUAD | - | erase_sector_en=1 | BC | Y | - |
| 52h | SPI | p77 §9.27 | 32KB Block Erase | 8 | ADS?32:24 | - | - | - | STD | STD | - | erase_block32_en=1 | BC | Y | - |
| 52h | QPI | p77 §9.27 | 32KB Block Erase | 2 | ADS?8:6 | - | - | - | QUAD | QUAD | - | erase_block32_en=1 | BC | Y | - |
| 5Ch | SPI | p77 §9.27 | 32KB Block Erase 4B | 8 | 32 | - | - | - | STD | STD | - | erase_block32_en=1 | BC | Y | - |
| 5Ch | QPI | p77 §9.27 | 32KB Block Erase 4B | 2 | 8 | - | - | - | QUAD | QUAD | - | erase_block32_en=1 | BC | Y | - |
| D8h | SPI | p78 §9.28 | 64KB Block Erase | 8 | ADS?32:24 | - | - | - | STD | STD | - | erase_block64_en=1 | BC | Y | - |
| D8h | QPI | p78 §9.28 | 64KB Block Erase | 2 | ADS?8:6 | - | - | - | QUAD | QUAD | - | erase_block64_en=1 | BC | Y | - |
| DCh | SPI | p78 §9.28 | 64KB Block Erase 4B | 8 | 32 | - | - | - | STD | STD | - | erase_block64_en=1 | BC | Y | - |
| DCh | QPI | p78 §9.28 | 64KB Block Erase 4B | 2 | 8 | - | - | - | QUAD | QUAD | - | erase_block64_en=1 | BC | Y | - |
| 60h | SPI | p79 §9.31 | Chip Erase | 8 | - | - | - | - | STD | STD | - | erase_chip_en=1 | BC | Y | BP2-BP0=0 且无扇区保护才执行 |
| 60h | QPI | p79 §9.31 | Chip Erase | 2 | - | - | - | - | QUAD | QUAD | - | erase_chip_en=1 | BC | Y | - |
| C7h | SPI | p79 §9.31 | Chip Erase | 8 | - | - | - | - | STD | STD | - | erase_chip_en=1 | BC | Y | - |
| C7h | QPI | p79 §9.31 | Chip Erase | 2 | - | - | - | - | QUAD | QUAD | - | erase_chip_en=1 | BC | Y | - |

#### 模式/复位/低功耗

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| B7h | SPI | p79 §9.29 | Enable 4-Byte Address Mode | 8 | - | - | - | - | STD | STD | - | set_ads=1 | BC | - | 上电默认由ADP决定 |
| B7h | QPI | p79 §9.29 | Enable 4-Byte Address Mode | 2 | - | - | - | - | QUAD | QUAD | - | set_ads=1 | BC | - | - |
| E9h | SPI | p79 §9.30 | Disable 4-Byte Address Mode | 8 | - | - | - | - | STD | STD | - | clear_ads=1 | BC | - | - |
| E9h | QPI | p79 §9.30 | Disable 4-Byte Address Mode | 2 | - | - | - | - | QUAD | QUAD | - | clear_ads=1 | BC | - | - |
| 38h | SPI | p80 §9.32 | Enable QPI | 8 | - | - | - | - | STD | STD | - | set_qpi_mode=1 | BC | - | WEL/SUS/wrap 保持 |
| FFh | QPI | p80 §9.33 | Disable QPI | 2 | - | - | - | - | QUAD | QUAD | - | clear_qpi_mode=1 | BC | - | WEL/SUS/wrap 保持 |
| 66h | SPI | p98 §9.54 | Enable Reset | 8 | - | - | - | - | STD | STD | - | set_en_rst=1 | BC | - | 之后须发 99h |
| 66h | QPI | p98 §9.54 | Enable Reset | 2 | - | - | - | - | QUAD | QUAD | - | set_en_rst=1 | BC | - | - |
| 99h | SPI | p98 §9.54 | Reset | 8 | - | - | - | - | STD | STD | - | 若en_rst_reg：rst_all=1, clear_en_rst=1 | BC | - | 清易失配置；复位期间不接受命令 |
| 99h | QPI | p98 §9.54 | Reset | 2 | - | - | - | - | QUAD | QUAD | - | 若en_rst_reg：rst_all=1, clear_en_rst=1 | BC | - | - |
| B9h | SPI | p81 §9.34 | Enter Deep Power-Down | 8 | - | - | - | - | STD | STD | - | enter_dpd_en=1 | BC | - | WIP=1 时 reject；CS#↑后 tDP 进入 |
| B9h | QPI | p81 §9.34 | Enter Deep Power-Down | 2 | - | - | - | - | QUAD | QUAD | - | enter_dpd_en=1 | BC | - | - |
| ABh | SPI | p81 §9.35 | Release from DPD / Device ID | 8 | - | - | 0(CS#↑) 或 24+DID | - | STD | STD | STD | exit_dpd_en / read_devid_en | CS_ANY | - | 仅命令后CS#↑：只退DPD；继续给dummy：先出DID再退DPD；WIP=1忽略 |
| ABh | QPI | p81 §9.35 | Release from DPD / Device ID | 2 | - | - | 0(CS#↑) 或 6+DID | - | QUAD | QUAD | QUAD | exit_dpd_en / read_devid_en | CS_ANY | - | 同上 |

#### ID/SFDP/暂停/CRC/完整性

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 4Bh | SPI | p82 §9.36 | Read Unique ID | 8 | ADS?32:24 | - | 8 | - | STD | STD | STD | read_uid_en=1 | CS_ANY | - | 地址应为全0；输出128bit |
| 90h | SPI | p82 §9.37 | Read Manufacturer/Device ID | 8 | 24 | - | 0 | - | STD | STD | STD | read_manuid_devid_en=1 | CS_ANY | - | 地址固定000000h |
| 90h | QPI | p82 §9.37 | Read Manufacturer/Device ID | 2 | 6 | - | 0 | - | QUAD | QUAD | QUAD | read_manuid_devid_en=1 | CS_ANY | - | - |
| 9Fh | SPI | p84 §9.38 | Read JEDEC ID | 8 | - | - | - | - | STD | STD | STD | rdid_en=1 | CS_ANY | - | 忙时不解码；DPD中不应发 |
| 9Fh | QPI | p84 §9.38 | Read JEDEC ID | 2 | - | - | - | - | QUAD | QUAD | QUAD | rdid_en=1 | CS_ANY | - | - |
| 5Ah | SPI | p99 §9.55 | Read SFDP | 8 | 24 | - | 8 | - | STD | STD | STD | read_array_en=1 | CS_ANY | - | JEDEC JESD216C |
| 5Ah | QPI | p99 §9.55 | Read SFDP | 2 | 6 | - | 8 | - | QUAD | QUAD | QUAD | read_array_en=1 | CS_ANY | - | - |
| 75h | SPI | p85 §9.39 | Program/Erase/DIC Suspend | 8 | - | - | - | - | STD | STD | - | pes_en=1 | BC | COND | WIP=1 且 SUS=0 才接受 |
| 75h | QPI | p85 §9.39 | Program/Erase/DIC Suspend | 2 | - | - | - | - | QUAD | QUAD | - | pes_en=1 | BC | COND | - |
| 7Ah | SPI | p86 §9.40 | Program/Erase/DIC Resume | 8 | - | - | - | - | STD | STD | - | per_en=1 | BC | COND | SUS!=0 且 WIP=0 才接受 |
| 7Ah | QPI | p86 §9.40 | Program/Erase/DIC Resume | 2 | - | - | - | - | QUAD | QUAD | - | per_en=1 | BC | COND | - |
| 64h | SPI | p97 §9.52 | Read Interface CRC Register | 8 | 32 | - | 0 | - | STD | STD | STD | read_itcrcr_en=1 | CS_ANY | - | 4B地址视作dummy |
| 64h | QPI | p97 §9.52 | Read Interface CRC Register | 2 | 8 | - | 0 | - | QUAD | QUAD | QUAD | read_itcrcr_en=1 | CS_ANY | - | - |
| 5Bh | SPI | p97 §9.53 | Data Integrity Check | 8 | 64（4B起始+4B结束） | - | - | - | STD | STD | - | data_crc_en=1 | BC | N | 地址结束字节边界CS#↑；挂起期间禁止 |
| 5Bh | QPI | p97 §9.53 | Data Integrity Check | 2 | 16（4B起始+4B结束） | - | - | - | QUAD | QUAD | - | data_crc_en=1 | BC | N | - |

#### Security/密码/锁

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 44h | SPI | p87 §9.41 | Erase Security Registers | 8 | ADS?32:24 | - | - | - | STD | STD | - | erase_sec_reg_en=1 | BC | Y | Security Lock Bit=1 忽略 |
| 42h | SPI | p87 §9.42 | Program Security Registers | 8 | ADS?32:24 | - | - | CONT | STD | STD | - | write_sec_reg_en=1 | CONT+BC | Y | - |
| 48h | SPI | p88 §9.43 | Read Security Registers | 8 | ADS?32:24 | - | 8 | - | STD | STD | STD | read_sec_reg_en=1 | CS_ANY | - | 地址映射 A15-A12=1/2/3 |
| 7Eh | SPI | p89 §9.44 | Global Block/Sector Lock | 8 | - | - | - | - | STD | STD | - | global_block_sector_lock_en=1 | BC | - | - |
| 7Eh | QPI | p89 §9.44 | Global Block/Sector Lock | 2 | - | - | - | - | QUAD | QUAD | - | global_block_sector_lock_en=1 | BC | - | - |
| 98h | SPI | p89 §9.44 | Global Block/Sector Unlock | 8 | - | - | - | - | STD | STD | - | global_block_sector_unlock_en=1 | BC | - | - |
| 98h | QPI | p89 §9.44 | Global Block/Sector Unlock | 2 | - | - | - | - | QUAD | QUAD | - | global_block_sector_unlock_en=1 | BC | - | - |
| 27h | SPI | p90 §9.45 | Read Password Register | 8 | - | - | 0 | - | STD | STD | STD | pwd=0 时 read_pwd_en=1 | CS_ANY | COND | PWD=1 忽略；输出64bit |
| 27h | QPI | p90 §9.45 | Read Password Register | 2 | - | - | 8 | - | QUAD | QUAD | QUAD | pwd=0 时 read_pwd_en=1 | CS_ANY | COND | PDF note13：QPI 需 8 dummy |
| 28h | SPI | p91 §9.46 | Program Password Register | 8 | - | - | - | 64 | STD | STD | - | pwd=0 时 write_pwd_en=1 | BC | Y | 必须正好64bit；WEL完成清 |
| 28h | QPI | p91 §9.46 | Program Password Register | 2 | - | - | - | 16 | QUAD | QUAD | - | pwd=0 时 write_pwd_en=1 | BC | Y | - |
| 29h | SPI | p92 §9.47 | Password Unlock/Lock | 8 | - | - | - | 64 | STD | STD | - | pwd=1 时 pwd_lock_unlock_en=1 | BC | COND | 正好64bit；比较结果决定PWDVFY/NL |
| 29h | QPI | p92 §9.47 | Password Unlock/Lock | 2 | - | - | - | 16 | QUAD | QUAD | - | pwd=1 时 pwd_lock_unlock_en=1 | BC | COND | - |
| E3h | SPI | p93 §9.48 | Set Nonvolatile Lock Register | 8 | 32 | - | - | - | STD | STD | - | set_NVLR_en=1 | BC | Y | 4B地址定位sector/block |
| E3h | QPI | p93 §9.48 | Set Nonvolatile Lock Register | 2 | 8 | - | - | - | QUAD | QUAD | - | set_NVLR_en=1 | BC | Y | - |
| E4h | SPI | p94 §9.49 | Clear All NVLR | 8 | - | - | - | - | STD | STD | - | clear_all_NVLR_en=1 | BC | Y | 另需 PWD=0 或 PWDVFY=1；SPI第8拍/QPI第2拍CS#↑ |
| E4h | QPI | p94 §9.49 | Clear All NVLR | 2 | - | - | - | - | QUAD | QUAD | - | clear_all_NVLR_en=1 | BC | Y | - |
| E1h | SPI | p95 §9.50 | Write Volatile Lock Register | 8 | 32 | - | - | 8 | STD | STD | - | write_VLR_en=1 | BC | Y | 数据仅00h/FFh，否则忽略 |
| E1h | QPI | p95 §9.50 | Write Volatile Lock Register | 2 | 8 | - | - | 2 | QUAD | QUAD | - | write_VLR_en=1 | BC | Y | - |
| E0h | SPI | p96 §9.51 | Read Volatile Lock Register | 8 | 32 | - | 0 | - | STD | STD | STD | read_VLR_en=1 | CS_ANY | - | 忙时忽略 |
| E0h | QPI | p96 §9.51 | Read Volatile Lock Register | 2 | 8 | - | 8 | - | QUAD | QUAD | QUAD | read_VLR_en=1 | CS_ANY | - | QPI 波形含 8 dummy |
| E2h | SPI | p96 §9.51 | Read Nonvolatile Lock Register | 8 | 32 | - | 0 | - | STD | STD | STD | read_NVLR_en=1 | CS_ANY | - | 忙时忽略 |
| E2h | QPI | p96 §9.51 | Read Nonvolatile Lock Register | 2 | 8 | - | 8 | - | QUAD | QUAD | QUAD | read_NVLR_en=1 | CS_ANY | - | - |

#### 读参数/Wrap

| 指令 | 模式 | PDF | 功能 | cmd拍 | addr拍 | cm拍 | dummy拍 | data拍 | 命令采样 | 地址/数据采样 | 驱动 | 关键输出 | 结束 | WEL | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 77h | SPI | p73 §9.22 | Set Burst with Wrap | 8 | - | - | 6（24 dummy bit，4线×6拍） | 总8拍：第7拍W4/W5/W6，第8拍trailing x；cnt==cmd_cycle+8 时 spi_wrap_data_en=1 | STD | QUAD | - | spi_wrap_data_en=1 | BC | N | W4=1不wrap；W6-W5选8/16/32/64B；波形XObject文字：SCLK 8~15，W位于第7个后命令拍 |
| C0h | QPI | p73 §9.23 | Set Read Parameters | 2 | - | - | - | 2 | QUAD | QUAD | - | cnt==cmd_cycle+2 时 qpi_read_param_en=1 | BC | N | P5-P4 dummy；P1-P0 wrap |

全表共 131 条指令 × 模式组合。未列出的指令 × 模式组合为 PDF 未定义/不支持组合，RTL 应将其译码为 `next_state=IDLE` 且不产生任何使能。

## 8. 特殊功能详细设计

### 8.1 QPI/SPI 模式切换

- 38h 仅在 SPI 模式有效：`set_qpi_mode=1`，下一拍 `qpi_mode_reg=1`，后续 CS#↓ 进入 QPI。
- FFh 仅在 QPI 模式有效：`clear_qpi_mode=1`，下一拍回 SPI。
- 切换时 **WEL、SUS、wrap length 保持不变**（PDF §9.32/§9.33）。
- 复位默认 SPI（`qpi_mode_reg=0`）。

### 8.2 ADS / 地址模式

- `ads=0`：3 字节地址；`ads=1`：4 字节地址。
- B7h 置 ADS，E9h 清 ADS；POR/复位后 ADS 由 SR ADP 位初始化（顶层提供 `ads`）。
- 固定 4B 指令（12/13/0C(SPI)/21/5C/DC/34/3C/6C/BC/BE/EC/EE/E0/E1/E2/E3/64）在 ADS=0 时仍按 4 字节地址拍数译码。
- C5h 写 EAR 仅 ADS=0 有效；复位清 EAR。

### 8.3 50h Volatile SR 写

```text
50h:  set_volatile_sr_write=1; write_VSR_en_reg<=1;  // 不置 WEL
任何非50/01/11命令到达cmd_boundary: write_VSR_en_reg<=0;
01/11h 且 write_VSR_en_reg==1: 路由 write_SR_shadow_en，完成写数据后清 write_VSR_en_reg;
01/11h 且 write_VSR_en_reg==0: 路由 write_SR_en（需 WEL=1）;
```

### 8.4 软件复位 66h+99h

- 66h：`set_en_rst=1`，`en_rst_reg<=1`，必须 CS# 在命令边界拉高。
- 99h：若 `en_rst_reg==1`，`rst_all=1`、`clear_en_rst=1`，下一拍回 `IDLE`；否则忽略。
- 复位清除：易失 SR、WEL、SUS、P7-P0、DPD、M7-M0、W6-W4（PDF §9.54）。
- ⚠ 待确认：66h 与 99h 之间是否允许插入其他命令；保守实现建议“插入任何其他命令则清 `en_rst_reg`”。

### 8.5 Deep Power-Down

```text
B9h 命令边界且 CS#↑: enter_dpd_en=1; dpd_reg<=1;   // WIP=1 时忽略
DPD 状态下: 仅 AB/66/99 可继续译码，其他命令 next_state=IDLE 且无使能
ABh 后立即 CS#↑: exit_dpd_en=1; dpd_reg<=0;  // tRES1 后接受新命令
ABh 后 CS# 保持低:
   SPI: 等待 24 dummy 拍后 read_devid_en=1, drive STD;
   QPI: 等待 6 dummy 拍后 read_devid_en=1, drive QUAD;
   CS#↑ 结束 Device ID 输出时 exit_dpd_en=1, dpd_reg<=0;
```

⚠ 注意：现有 `ctrl_if_v4` 在 AB+dummy 分支中提前置 `exit_dpd_en`；按 PDF 时序图和 readme 记录，正确行为是 **先输出 Device ID，再退出 DPD**。RTL 必须按本伪代码实现。

### 8.6 POR-XIP 与 Continuous Read Mode

进入条件：

| 条件 | 说明 |
|---|---|
| `por_xip=1` | 上电/复位后按 `vncr_0` 配置进入 XIP |
| `cmd_xip=1` | 上一条 BB/BC/BD/BE/EB/EC/ED/EE 读的 mode byte `cm[5:4]==2'b10` |

XIP 状态输出 `read_array_en=1`，按下表译码：

| 来源 | 配置 | sample | addr | cm | dummy | drive |
|---|---|---|---|---|---|---|
| POR-XIP | `vncr_0=FC` | DUAL | ADS?16:12 | 4 | 0 | DUAL |
| POR-XIP | `vncr_0=FD` | DDR2 | ADS?8:6 | 2 | 4 | DDR2 |
| POR-XIP | `vncr_0=FE` | QUAD | ADS?8:6 | 2 | 4 | QUAD |
| POR-XIP | `vncr_0=FB` | DDR4 | ADS?4:3 | 1 | 9 | DDR4 |
| 连续读 | BB | DUAL | ADS?16:12 | 4 | 0 | DUAL |
| 连续读 | BC | DUAL | 16 | 4 | 0 | DUAL |
| 连续读 | BD | DDR2 | ADS?8:6 | 2 | 4 | DDR2 |
| 连续读 | BE | DDR2 | 8 | 2 | 4 | DDR2 |
| 连续读 | EB | QUAD | ADS?8:6 | 2 | 4 | QUAD |
| 连续读 | EC | QUAD | 8 | 2 | 4 | QUAD |
| 连续读 | ED | DDR4 | ADS?4:3 | 1 | 9 | DDR4 |
| 连续读 | EE | DDR4 | 4 | 1 | 9 | DDR4 |

退出：XIP 中当 `cnt >= addr_cycle + cm_cycle` 采样 `cm[5:4]`；若 != `10`，`clear_por_xip=1` 并回 `IDLE`。

⚠ 设计约束：连续读下一次 CS#↓ 时不发命令码，因此上游必须在事务间保持 `cmd_reg` 为上一条读命令；`cmd_reg` 只在命令阶段更新，**不得**在 CS# 高/空闲期间被清成 00。

### 8.7 Continuous Read Mode 位

- BB/BC/BD/BE/EB/EC/ED/EE 在地址后输入 mode byte：
  - Dual：`cm_cycle=4`，M7-M0 从 IO0/IO1 按 PDF note 5 位序输入；
  - Quad：`cm_cycle=2`，M7-M0 按 PDF note 7 位序输入；
  - DTR：`cm_cycle=2`(dual)/1(quad)。
- `cm[5:4]==2'b10` 时 `cmd_xip<=1`，否则清 0；复位清 0。

### 8.8 77h Set Burst with Wrap 与 C0h Set Read Parameters

C0h（QPI）读参数 P7-P0：

| P5-P4 | STR dummy 拍数 | DTR dummy 拍数 | P1-P0 | Wrap length |
|---|---|---|---|---|---|
| 00（default） | 4 | 10 | 00（default） | 8 Byte |
| 01 | 6 | 8 | 01 | 16 Byte |
| 10 | 8 | 10 | 10 | 32 Byte |
| 11 | 10 | 10 | 11 | 64 Byte |

77h（SPI）：命令后输入 dummy/wrap bits，`W4=1` 表示不 wrap；`W4=0` 时 `W6-W5` 选 8/16/32/64 Byte。

```text
C0h: if (cnt == cmd_cycle + 2) qpi_read_param_en=1;
     qpi_read_param_reg <= qpi_read_param;
77h: sample_mode=QUAD;
     if (cnt == cmd_cycle + data_cycle) spi_wrap_data_en=1;
     spi_wrap_data_reg <= spi_wrap_data;
```

77h 波形解析结论（来自 PDF 第 73 页 Form XObject 波形文字）：
- 命令占 SCLK 0~7；
- 命令后 SCLK 8~15，共 **8 拍**；
- 前 6 拍（SCLK 8~13）为 4 线 × 6 拍 = **24 dummy bit**，与正文“Send 24 dummy bits”一致；
- 第 7 个后命令拍（SCLK 14）在 IO0/IO1/IO2 上出现 W4/W5/W6，IO3 为 x；
- 第 8 拍（SCLK 15）为 trailing x；
- 因此 `dummy_cycle=6`（若单独输出），而 `spi_wrap_data_en` 的锁存时刻为 `cnt==cmd_cycle+8`，与现有 RTL `data_cycle=8` 一致。

⚠ Wrap 参数跨模式：PDF §9.22 明确“模式切换时 wrap setting 保持不变”，§9.32/9.33 再次强调。若 SPI(77h) 与 QPI(C0h) 使用两套参数，必须在集成层保证切换后行为仍符合规格；建议 RTL 保留单一 wrap 配置寄存器或顶层做等价映射。

### 8.9 Suspend/Resume

```text
75h: if (wip==1 && sus==0) pes_en=1; else 忽略;
7Ah: if (sus!=0 && wip==0) per_en=1; else 忽略;
```

挂起期间禁止指令清单见 §6.2。

### 8.10 密码寄存器

```text
27h: if (pwd==0) read_pwd_en=1;  // SPI无dummy，QPI dummy=8
28h: if (pwd==0 && wel==1) write_pwd_en=1; data必须正好64bit;
29h: if (pwd==1) pwd_lock_unlock_en=1; data必须正好64bit;
```

### 8.11 SFDP / Interface CRC / Data Integrity Check

- 5Ah：地址 24bit + 8 dummy，然后连续输出 SFDP；`read_array_en` 置 1，array FSM 按地址映射 SFDP 空间。
- 64h：4B 地址视作 dummy；SPI 地址 32 拍、QPI 地址 8 拍后直接驱动数据输出。
- 5Bh：4B 起始地址 + 4B 结束地址，SPI 共 64 拍、QPI 共 16 拍；结束地址字节边界 CS#↑ 后 `data_crc_en=1`。

## 9. 命令译码伪代码（RTL 骨架）

```systemverilog
// 参数
localparam IDLE=0, XIP=1, QPI=2, SPI=3;
localparam IDLE_MODE=0, STD=1, DUAL=2, QUAD=3, DDR2=4, DDR4=5;

// 计数器
always_ff @(posedge sclk or negedge rstn) begin
  if (!rstn)                cnt <= 0;
  else if (rst_all)         cnt <= 0;
  else if (cs)              cnt <= 0;
  else if (cs_fall)         cnt <= 1;
  else if (cnt != 8'hFF)   cnt <= cnt + 1;
end

// 状态
always_ff @(posedge sclk or negedge rstn) begin
  if (!rstn)          {current_state,cs_prev} <= {IDLE,1'b1};
  else if (rst_all)   {current_state,cs_prev} <= {IDLE,1'b1};
  else                {current_state,cs_prev} <= {next_state,cs};
end

// 组合译码
always_comb begin
  // 1) 全部输出赋默认 0，next_state=current_state;
  // 2) case(current_state)
  //    IDLE: if(cs_fall) next_state = (por_xip|cmd_xip)? XIP : qpi_mode_reg? QPI : SPI;
  //    XIP : 按 8.6 表译码;
  //    QPI : cmd_cycle=2; sample_cmd_mode=QUAD; sample_mode=QUAD;
  //          if(cnt<2) hold; else if(dpd_reg && cmd!={AB,66,99}) next=IDLE;
  //          else case(cmd[7:4]) ... 按第7节全表译码;
  //    SPI : cmd_cycle=8; sample_cmd_mode=STD; sample_mode=STD;
  //          if(cnt<8) hold; else if(dpd_reg && cmd!={AB,66,99}) next=IDLE;
  //          else case(cmd[7:4]) ... 按第7节全表译码;
end
```

RTL 实现注意：

1. 组合块先写**全部输出默认值**，再在 case 内覆盖，避免 latch。
2. QPI 按 `cmd[7:4]` 外层 case、`cmd[3:0]` 内层 case 实现；SPI 相同。
3. 所有 `*_en` 在命令执行窗口内为 1，窗口结束条件按第 7 节 `end` 列实现。
4. `read_*_en` 类命令在数据输出期间持续为 1，直到 `cs==1`；写/擦/命令类在 CS# 边界拉高后由下游执行。
5. 合法性检查（WEL/WIP/SUS/PWD/DPD）应在译码后、输出使能前统一做 gating；RDSR/RDFSR 在 WIP=1 时仍可输出。

## 10. 未决项与实现前必须确认的问题

| ID | 问题 | PDF 依据 | 建议 |
|---|---|---|---|
| Q-01 | 77h 命令后 dummy 为 6 拍还是 8 拍 | **已解析**：p73 Form XObject 波形文字显示 SCLK 8~15；前 6 拍为 24 dummy bit，第 7 拍为 W4-W6，第 8 拍 trailing x；`spi_wrap_data_en` 应在第 8 拍末锁存 | 已关闭：dummy_cycle=6，总采样窗=8 拍 |
| Q-02 | C0h P5-P4=00 默认 dummy=4，但 QPI 0Bh 波形初值显示 6 | p74 表 vs p63 图 | 确认 POR 后 P7-P0 初值来源 |
| Q-03 | wrap 参数在 SPI/QPI 切换时如何保持 | §9.22/§9.32/§9.33 | 建议单一 wrap 寄存器 |
| Q-04 | 66h 与 99h 之间能否插入其他命令 | §9.54 | 原厂确认；保守实现插入即清使能 |
| Q-05 | POR-XIP 退出是否同时清 `por_xip` 标志及 SAF 流程 | §4.5/§4.6 | 核对 PDF 中 POR-XIP/Safe Boot 流程图（正文图片页） |
| Q-06 | 5Ah 地址在 4B 模式下是否仍为 24bit | §9.55 波形 | 按 SFDP 标准 24bit 实现，原厂确认 |
| Q-07 | 7Eh/98h、75h/7Ah 是否需要 WEL | §9.39/§9.44 未明确 | 原厂确认 |
| Q-08 | QPI 模式是否支持 03h/13h、32h/34h、42h/44h/48h、4Bh 等 SPI 图命令 | PDF 仅给出 SPI 波形 | 按本文支持矩阵实现；与 model 比对 |
| Q-09 | PDF §9.39 出现 AAh/55h 命令，但全文无对应命令说明 | §9.39 | 原厂确认 AAh/55h 是否为合法 WRSR/保留命令，RTL 暂不实现 |

## 11. 与现有 ctrl_if_v4 的主要差异

| 项 | v4 | 本文要求 |
|---|---|---|
| AB+dummy 释放 DPD | `exit_dpd_en` 提前置 1 | 先读 Device ID，CS#↑时再退出 |
| CS# 字节边界 reject | 未检查 | 必须检查并 reject |
| WEL/WIP/SUS/PWD 门控 | 无输入 | 增加输入并统一 gating |
| 77h 拍数 | 8 | 确认正确：6 拍 dummy + W 拍 + trailing x；锁存点在 8 拍末 |
| wrap 跨模式 | 两套寄存器 | 需保证规格一致 |
| 软件复位使能 | 不因插命令清除 | 建议插命令清除 |
| 输出使能 | 译码即输出 | 合法性通过后才输出 |

## 12. 签核前检查清单

- [ ] 第 7 节全部 131 行有 RTL case 分支与测试用例；
- [ ] 第 10 节 Q-01~Q-09 全部关闭或有正式 waiver；
- [ ] CS# 边界 reject 场景全部仿真通过；
- [ ] DPD AB 两种释放路径仿真通过；
- [ ] 复位/模式切换/XIP 状态转移 SVA 全部通过；
- [ ] 与 `VerMdl_XM25Q512F` Flash model 端到端回归通过。
