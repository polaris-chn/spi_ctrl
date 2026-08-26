# ctrl_if_v4 功能完整性分析、验证计划与验证测试点

| 项目 | 内容 |
|---|---|
| 文档版本 | v0.1 |
| 日期 | 2026-08-24 |
| 被测设计 | `ctrl_if_v4.v`（顶层 `ctrl_if`，1871 行） |
| 参考 Spec | `GD25LF256F.pdf`（GD25LF256F Uniform Sector Dual and Quad Serial Flash，121 页） |
| 关联文件 | `ctrl_if_v1.v`~`ctrl_if_v5.v`、`readme.md`、`VerMdl_XM25*.v`、`vcs_sim/` |
| 验证阶段 | 模块级功能验证（前端验证） |

> 说明：本文中的行号均指当前目录根下的 `ctrl_if_v4.v`。

---

## 1. 结论摘要

### 1.1 总体结论

**`ctrl_if_v4.v` 是一个已经可综合、可仿真的命令译码/时序控制框架，但还不是功能完整的 GD25LF256F 控制器实现。**

- 语法/编译：Verilator `--lint-only -Wall` 无告警；VCS 编译 0 error、0 warning，现有 TB 可运行。
- 指令覆盖：**SPI 模式 73 条指令、QPI 模式 58 条指令、XIP 连续读 8 条、POR-XIP 配置 4 种**，与 datasheet 的 SPI/QPI 指令图基本一一对应，指令码覆盖完整。
- 功能完整性：**未完全**。主要缺口集中在：命令合法执行条件（WEL/WIP/SUS/保护/CS# 字节边界）不在本模块内检查；AB 释放 DPD 的时序与 datasheet/readme 描述不一致；读参数初始值模型不完整；SPI 77h 采样宽度与 datasheet 文字描述需进一步核对；SPI/QPI wrap 参数是否应共用仍按 readme 的“暂定”方案实现。
- 定位：v4 属于 readme 所述的“初步完成代码框架”版本，适合继续开发，不建议未经补齐和回归直接流片/交付。

### 1.2 关键问题清单

| ID | 级别 | 位置（v4 行号） | 问题描述 | 判定依据 |
|---|---|---|---|---|
| F-01 | 高 | QPI L925-940；SPI L1608-1626 | AB+dummy 方式释放 DPD 时，`exit_dpd_en` 与 `read_devid_en` 在 dummy 前同时置 1，而不是“先输出 Device ID，再退出 DPD” | readme 20260806 记录；datasheet 9.35 |
| F-02 | 高 | 例：L709、L970、L1159、L1471 等 | WRSR/PP/SE/BE/CE/DPD/B1/C5 等“必须 CS# 在字节边界拉高才执行”的命令，译码逻辑只按 `cnt` 阈值切回 idle，未检查 CS# 是否在正确边界拉高，也未对提前/滞后拉高产生 reject 行为 | datasheet 9.x “otherwise the command is rejected” |
| F-03 | 高 | 端口表 L2-73；全部写/擦类 case | 模块没有 WEL、WIP、SUS、BP/锁保护等状态输入，无法在模块内拒绝“无 WREN 的写/擦”或“忙时命令”等非法命令；若集成层不做，则功能缺失 | datasheet 9.5/9.24/9.26/9.39 等 |
| F-04 | 中 | L276-297 | `qpi_read_param_valid` 只在收到 C0h 后置 1；POR/复位后的读参数初值、NVCR 下载值、DC dummy 配置没有建模，复位后 dummy 只能使用硬编码 fallback 值 | datasheet 8.x/9.23、9.54 |
| F-05 | 已关闭 | L1527-1533 | 77h 波形（PDF p73 Form XObject 文字）显示命令后 SCLK 8~15 共 8 拍：前 6 拍为 24 dummy bit，第 7 拍 W4-W6，第 8 拍 trailing x；v4 `data_cycle=8` 锁存 `spi_wrap_data` 与波形一致。注意单独输出 `dummy_cycle` 时应为 6 | PDF p73 波形文字 |
| F-06 | 中 | L980-983、L1751-1761 | SPI 用 77h W6-W5、QPI 用 C0h P1-P0 两套 wrap 参数；datasheet 9.22 说明模式切换不改变 wrap 设置，readme 也注明该点“还需确认，暂定分开”。当前实现与 datasheet 可能不一致 | datasheet 9.22；readme 20260821 |
| F-07 | 中 | L192-208、L394-558 | `cmd_xip`/`cmd_reg` 每个 sclk 无条件采样，未用“mode byte 有效窗口”或 CS# 门控；XIP 读 dummy 也不受 C0h 读参数影响。若上游在事务间清 `cmd`/`cm`，连续读会错误退回 idle | datasheet 9.16-9.19 连续读模式 |
| F-08 | 中 | L224-235、L904-911 | 软件复位使能 `en_rst_reg` 在 66h 后不被其他命令清除，66h 与 99h 之间插入任意命令后仍可复位；需确认规格是否要求 66h/99h 连续 | datasheet 9.54 |
| F-09 | 中 | 全部端口 | DQS/Data Strobe、Safe Boot、ECC/ECS、Interface CRC 检查值复位等 datasheet 功能在 v4 中无对应输入/输出/状态，需确认是否在集成层实现 | datasheet 4.4/4.6/6.x |
| F-10 | 低 | L579-596 等 | 50h 使能的 volatile WRSR 及普通 WRSR 完成条件只按 `cnt` 阈值，不检查 CS#；错误长度/提前拉高时仍可能清 VSR 使能或返回 idle | datasheet 9.5/9.8 |

---

## 2. GD25LF256F Datasheet 分析摘要

### 2.1 器件特征

GD25LF256F 是 256Mbit、1.8V、4KB 均匀扇区的 SPI/QPI NOR Flash，支持：

- Standard/Dual/Quad SPI、DTR、QPI 四种接口协议；
- 3/4 字节地址模式（ADS、B7h/E9h、EAR C8h/C5h）；
- XIP 连续读、POR-XIP、Safe Boot；
- Deep Power-Down、硬件复位、软件复位 66h+99h、上电复位；
- WEL/WIP、SR1/2/3、Flag Status Register、NVCR/VCR、ECC/CRC/Data Integrity Check；
- 块/扇区保护、Global Lock、Nonvolatile/Volatile Lock、Security Register、Password 保护。

### 2.2 指令分组

| 类别 | 指令 |
|---|---|
| WEL/状态 | 06h, 04h, 05h, 35h, 15h, 70h, 30h, 50h |
| 状态/配置寄存器 | 01h, 11h, B1h, 81h, B5h, 85h, C5h, C8h |
| 读阵列 | 03h, 13h, 0Bh, 0Ch, 3Bh, 3Ch, 6Bh, 6Ch, BBh, BCh, BDh, BEh, EBh, ECh, EDh, EEh；QPI 0Ch/0Eh Burst Wrap |
| 编程/擦除 | 02h, 12h, 32h, 34h, 20h, 21h, 52h, 5Ch, D8h, DCh, 60h, C7h |
| 模式/复位/低功耗 | 38h, FFh, B7h, E9h, 66h, 99h, B9h, ABh |
| ID/SFDP | 90h, 9Fh, 4Bh, 5Ah |
| 暂停/恢复 | 75h, 7Ah |
| Security/密码/锁 | 44h, 42h, 48h, 27h, 28h, 29h, 7Eh, 98h, E3h, E4h, E1h, E2h, E0h |
| CRC/完整性 | 64h, 5Bh |
| 读参数/Wrap | 77h, C0h |

### 2.3 与 ctrl_if_v4 直接相关的规格要点

| 规格项 | 要点 | v4 对应 |
|---|---|---|
| 命令移入 | SPI：SI 单线、8 个 SCLK 采样 1 字节；QPI：IO[3:0]、2 个 SCLK 采样 1 字节 | `cmd_cycle=8`(SPI) / `cmd_cycle=2`(QPI) |
| 读命令 | 地址后按命令要求插入 dummy，随后连续输出，CS# 可随时拉高结束 | `read_array_en` + `dummy_cycle` + `drive_mode` |
| 写/擦命令 | CS# 必须在字节边界拉高，否则命令不执行；WEL=1 前置条件 | v4 只译码不检查（见 F-02/F-03） |
| 连续读模式 | mode bit M[5:4]=10 时，下一次 CS# 拉低不需要命令码；M[5:4]!=10 退出 | `cmd_xip`/`xip` 状态（见 F-07） |
| POR-XIP | 上电后按 VNCR 配置直接进入 XIP，M[5:4]!=10 时退出 | `por_xip` + `vncr_0` FC/FD/FE/FB |
| DPD | B9h 进入；DPD 中仅 ABh/66h/99h 有效；ABh 后立即拉高仅退出 DPD，继续给 dummy 则先出 Device ID 再退出 | `dpd_reg` + AB 分支（F-01） |
| 复位 | 66h 使能 + 99h 复位，复位后回 idle 并清易失配置 | `set_en_rst`/`en_rst_reg`/`rst_all` |
| 读参数 | C0h 设置 dummy 和 wrap length；复位清除 | `qpi_read_param_reg/valid`（F-04） |
| Wrap | 77h 在 SPI 设置 W6-W4；模式切换不应改变 | `spi_wrap_data_reg`（F-05/F-06） |
| ADS | B7h/E9h 切换 4/3 字节地址；地址类命令按 ADS 选择地址拍数 | `set_ads`/`clear_ads`，`addr_cycle=ads?xx:yy` |

---

## 3. ctrl_if_v4 结构分析

### 3.1 模块边界

现有 `vcs_sim/tb/tb_ctrl_if.sv` 仅为手工波形/打印型冒烟 TB（无 scoreboard 自动比对），不能作为签核环境，需按第 5 节重建或增强。

`ctrl_if` 是命令译码与时序控制模块，输入为已经移位/拼接好的 `cmd`、`cm`、`spi_wrap_data`、`qpi_read_param` 等字节，输出为下游 array FSM/OSC FSM 所需的使能与周期参数。它不直接包含 SI/SO/IO 物理移位逻辑。

### 3.2 状态机

| 状态 | 功能 |
|---|---|
| `idle` | 等待 CS# 下降沿，根据 `por_xip/cmd_xip/qpi_mode_reg` 决定进入 `xip/qpi/spi` |
| `xip` | POR-XIP 或连续读模式，按 `vncr_0` 或上一条读命令配置 address/cm/dummy/drive 模式 |
| `qpi` | QPI 命令译码，`cmd_cycle=2`，命令/地址/数据默认 quad |
| `spi` | SPI 命令译码，`cmd_cycle=8`，命令默认 standard，命令分支可切 dual/quad |

### 3.3 关键内部逻辑

| 逻辑 | 实现 |
|---|---|
| sclk 计数器 `cnt` | CS#=1 清零；CS# 下降沿后第一拍置 1；0xFF 饱和 |
| `cmd_boundary` | `(state==qpi or spi) && cnt>=cmd_cycle`，用于清除 50h 易失写使能 |
| QPI 模式寄存器 | 38h 置 1，FFh 清 0，复位清 0 |
| DPD 寄存器 | B9h 置 1，ABh 清 0，复位清 0；DPD 中非 AB/66/99 命令回 idle |
| 软复位 | 66h 置 `en_rst_reg`，之后 99h 产生 `rst_all` 脉冲 |
| Volatile SR 写 | 50h 置 `write_VSR_en_reg`；其他命令在命令边界清除；WRSR 路由到 `write_SR_shadow_en` |
| 读参数 | C0h 采样 `qpi_read_param`，P5-P4 经查表生成 STR/DTR dummy，P1-P0 生成 wrap_len |
| SPI Wrap | 77h 采样 `spi_wrap_data`，复位默认 W4=1（不 wrap） |

### 3.4 指令覆盖

经静态扫描，SPI 73 条、QPI 58 条指令码分支均存在；XIP 状态覆盖 BB/BC/BD/BE/EB/EC/ED/EE 连续读和 FC/FD/FE/FB 四种 POR-XIP 配置。详见附录 A。

---

## 4. 功能完整性判断（PDF vs v4 逐项核对）

| Datasheet 功能 | v4 状态 | 说明 |
|---|---|---|
| SPI 指令译码 | 已覆盖 | 73 条分支齐全 |
| QPI 指令译码 | 已覆盖 | 58 条分支齐全 |
| XIP/POR-XIP 读时序 | 部分覆盖 | 8+4 种配置存在；cmd/cm 采样窗口、C0 dummy 联动不完整 |
| ADS/4B 地址模式 | 已覆盖 | B7/E9/C5/C8 与 `ads` 地址拍数选择 |
| 读命令 dummy/drive 模式 | 部分覆盖 | fallback 与 C0 表存在；初值模型缺失 |
| Wrap 配置 | 部分覆盖 | 77h/C0h 均能锁存；SPI/QPI 是否独立与 datasheet 存疑；77h 采样宽度待核对 |
| QPI/SPI 模式切换 | 已覆盖 | 38h/FFh |
| 硬/软/POR 复位 | 部分覆盖 | 复位回 idle、清状态已做；66/99 间插命令行为待确认 |
| DPD | 部分覆盖 | 进入/隔离/释放命令存在；AB+dummy 释放时序错误 |
| WEL/WIP/SUS/保护合法性 | 未覆盖 | 模块无相关输入，需集成层实现 |
| CS# 字节边界 reject | 未覆盖 | 写/擦/DPD 等只按 cnt 返回 idle |
| Security/Password/Lock | 译码覆盖，执行条件未覆盖 | 指令分支齐全；pwd 仅门控 27/28/29 入口 |
| DQS/Safe Boot/ECC/ECS | 未覆盖 | 无对应端口和逻辑 |

**结论：指令码译码层面完整，命令执行语义层面不完整。**

---

## 5. 验证策略

### 5.1 验证目标

- 确认 v4 的 4 状态 FSM、73 条 SPI、58 条 QPI、8 条 XIP、4 种 POR-XIP 译码与 datasheet 一致；
- 确认所有 `*_cycle`、`sample_mode`、`drive_mode`、`*_en` 输出的相对时序正确；
- 暴露 F-01~F-10 问题，并跟踪关闭；
- 达到签核覆盖率目标，形成可回归的自动化验证环境。

### 5.2 验证层次

| 层次 | 内容 | 用途 |
|---|---|---|
| 模块级 | 对 `ctrl_if_v4` 做白盒定向 + 约束随机验证 | 本计划主体 |
| 集成级 | `ctrl_if + OSC FSM + array FSM + VerMdl_XM25Q512F` | 确认使能握手、Flash 行为一致 |
| SoC 级 | CPU/总线发 SPI/QPI 事务 | 启动、XIP、复位流程 |

### 5.3 验证方法

- SystemVerilog + UVM-lite（或结构化 SV TB），参考模型按 datasheet 命令表建模；
- 定向测试保证每条指令至少命中一次；约束随机覆盖 ADS、cnt 到达时刻、CS# 拉高时刻、pwd、vncr_0、C0/77 数据；
- SVA 检查状态机合法性、关键输出 one-hot/脉冲宽度、DPD 隔离、软复位序列；
- 形式验证补充：死锁、非法状态、计数器回绕、X 传播；
- 门级仿真在综合后重复关键用例。

### 5.4 验证环境组件

| 组件 | 实现建议 |
|---|---|
| `ctrl_if_agent` | 驱动 `sclk/cs/cmd/cm/pwd/ads/vncr_0/spi_wrap_data/qpi_read_param/por_xip`，支持 SPI/QPI/XIP 事务序列 |
| `ctrl_if_monitor` | 采样输入事务与 DUT 输出，输出给 scoreboard/coverage |
| `ctrl_if_reference_model` | 按 datasheet 生成期望命令译码、cycle 数、en 使能、状态转移 |
| `ctrl_if_scoreboard` | 比较使能、模式、周期、wrap_len、SR 选择、DPD 行为 |
| `ctrl_if_assertions` | 协议与内部时序断言 |
| `ctrl_if_cov` | 指令/模式/ADS/读参数/CS 边界/错误注入覆盖 |
| `flash_bfm` | 集成层挂 `VerMdl_XM25Q512F` 或自研 BFM，回读状态与数据 |

### 5.5 激励与检查机制

- 事务级 sequence：`write_enable -> page_program -> read_status -> read_array` 等组合场景；
- 每条指令构造：合法长度、短于/长于合法长度、CS# 提前/滞后拉高、字节边界内外；
- 自动检查：golden log/scoreboard 比对 + SVA + 覆盖率；禁止“只看波形”用例。

### 5.6 覆盖率目标

| 覆盖类型 | 目标 |
|---|---|
| 指令覆盖 | SPI 73/73，QPI 58/58，XIP 8/8，POR-XIP 4/4 |
| 地址模式交叉 | 每条地址类指令 × `ads=0/1` |
| 读参数交叉 | C0h P5-P4/P1-P0 × 0Bh/0Ch/0Eh/EB/EC/ED/EE |
| SPI wrap 交叉 | 77h W6-W4 × EB/EC/ED/EE |
| 状态机 | idle/xip/qpi/spi 全转移 + 非法转移 0 |
| 错误注入 | CS# 早/晚拉高、未知指令、DPD 中非法指令、复位打断 |
| 代码覆盖 | line/FSM 100%，branch ≥ 95%，toggle ≥ 90%（未达项逐条 review/waive） |
| 断言覆盖 | 关键断言 100% 有激活证据，fail 0 |

### 5.7 准入/准出

| 阶段 | 标准 |
|---|---|
| 入口 | RTL 语法/Lint 干净；接口定义冻结；datasheet 歧义点评审关闭 |
| 出口 | 功能覆盖 100%（豁免已批准）；代码覆盖达标；P0/P1 bug 清零，P2 有明确处理意见；全量回归通过率 100%；验证报告签核 |

---

## 6. 验证测试点

### 6.1 测试点总表（按功能域）

| ID | 功能域 | 测试点 | 激励 | 检查/判据 | 覆盖点 | 优先级 |
|---|---|---|---|---|---|---|
| VP_RST_001 | 复位 | 异步复位 | 随机时刻拉低 `rstn` | 全部 reg 清零，`current_state=idle`，所有 `*_en=0` | `rstn` | P0 |
| VP_RST_002 | 复位 | 复位释放后首拍 | 复位释放时 CS# 分别为 0/1 | CS#=1 时保持 idle、cnt=0；CS#=0 时首拍按正常 CS 下降沿进入命令状态、cnt=1；两者均无毛刺使能 | `rstn_release` | P0 |
| VP_RST_003 | 复位 | 软件复位 66h+99h | SPI/QPI 各发 66h→99h | `en_rst_reg` 66 后置 1；99 后 `rst_all` 脉宽 1 拍，回 idle，清 qpi/dpd/wrap/read_param | `soft_reset` | P0 |
| VP_RST_004 | 复位 | 99h 单独发送 | 不发 66h 直接 99h | 不产生 `rst_all`，状态不变 | `soft_reset_seq` | P0 |
| VP_RST_005 | 复位 | 66h 后插入其他命令再 99h | 66h→05h→99h | 按 datasheet 解释检查是否允许；若不允许则判 RTL bug（F-08） | `soft_reset_seq` | P1 |
| VP_RST_006 | 复位 | 复位打断读/写/擦命令 | 读数据中途、WRSR 数据中途复位 | 立即回 idle，使能清零，无残余状态 | `reset_intr` | P0 |
| VP_CNT_001 | 计数器 | CS#=1 清零 | 任意状态拉高 CS# | 下一拍 cnt=0 | `cnt_clr` | P0 |
| VP_CNT_002 | 计数器 | CS# 下降沿后首拍 | 拉低 CS# 后再给 sclk | 第一拍 cnt=1 | `cnt_start` | P0 |
| VP_CNT_003 | 计数器 | 0xFF 饱和 | 连续 260 拍有效 sclk | cnt 保持 0xFF，不回绕，读使能不丢 | `cnt_saturate` | P1 |
| VP_FSM_001 | 状态机 | 默认 SPI 进入 | 复位后 `qpi_mode=0`，CS#↓ | idle→spi，`cmd_cycle=8`，`sample_cmd_mode=standard` | `fsm_spi_entry` | P0 |
| VP_FSM_002 | 状态机 | 38h 后进入 QPI | SPI 发 38h，再 CS#↓ | `qpi_mode_reg=1`，idle→qpi，`cmd_cycle=2` | `fsm_qpi_entry` | P0 |
| VP_FSM_003 | 状态机 | FFh 后回 SPI | QPI 发 FFh，再 CS#↓ | `qpi_mode_reg=0`，idle→spi | `fsm_qpi_exit` | P0 |
| VP_FSM_004 | 状态机 | XIP 进入 | `por_xip=1` 且 `vncr_0=FC/FD/FE/FB`；或 `cmd_xip=1` | idle→xip，`read_array_en=1` | `fsm_xip_entry` | P0 |
| VP_FSM_005 | 状态机 | XIP 退出 | mode byte `cm[5:4]!=10` | `clear_por_xip=1` 或下一事务回普通命令模式 | `fsm_xip_exit` | P0 |
| VP_FSM_006 | 状态机 | 未知指令 | 各状态发非法指令码 | 返回 idle，不产生非法使能组合 | `fsm_illegal` | P1 |
| VP_FSM_007 | 状态机 | CS# 提前结束读 | 读命令数据输出任意拍拉高 CS# | 下一拍回 idle，读使能撤销 | `fsm_cs_term` | P0 |
| VP_MODE_001 | 模式 | B7h/E9h 地址模式 | SPI/QPI 发 B7h、E9h | `set_ads`/`clear_ads` 单拍脉冲 | `ads_mode` | P1 |
| VP_MODE_002 | 模式 | ADS 影响地址拍数 | 每条地址类命令 × ads=0/1 | `addr_cycle` 与 datasheet 一致 | `ads_x_cmd` | P0 |
| VP_SR_001 | 寄存器 | RDSR 路由 | 05h/35h/15h，SPI/QPI | `read_SR_en=1`，`read_SR_addr=SR1/SR2/SR3`，`drive_mode` 正确，连续读直到 CS#↑ | `sr_read` | P0 |
| VP_SR_002 | 寄存器 | WRSR 01h/11h | SPI/QPI，合法数据长度 | `write_SR_en=1`，`write_SR_addr=0/SR3`，`data_cycle=16/8(SPI)、4/2(QPI)` | `sr_write` | P0 |
| VP_SR_003 | 寄存器 | WRSR 非法数据长度 | 01h 只给 8 个 SPI 数据位或提前 CS#↑ | 不产生错误写使能，状态按 datasheet 处理（当前可能不满足，见 F-10） | `sr_write_err` | P1 |
| VP_VSR_001 | 寄存器 | 50h 易失 SR 写 | 50h→01h/11h | WRSR 路由到 `write_SR_shadow_en`，完成清 VSR 使能，不置 WEL | `vsr_write` | P1 |
| VP_VSR_002 | 寄存器 | 50h 后插其他命令 | 50h→05h→01h | 05h 命令边界清 `write_VSR_en_reg`，01h 回到普通 `write_SR_en` | `vsr_clear` | P1 |
| VP_CFG_001 | 寄存器 | VCR/NVCR 读写 | 81/85/B1/B5 × SPI/QPI × ADS | 使能、地址、数据/dummy 拍数正确 | `cfg_reg` | P1 |
| VP_CFG_002 | 寄存器 | EAR 读写 | C5h/C8h × SPI/QPI | `write_EAR_en`/`read_EAR_en` 与 data_cycle 正确 | `ear` | P1 |
| VP_RD_001 | 读 | 普通/快速读 | 03/13/0B/0C SPI × ADS | `read_array_en` 时序、dummy、drive 模式、CS# 结束 | `rd_basic` | P0 |
| VP_RD_002 | 读 | Dual/Quad 输出读 | 3B/3C/6B/6C SPI × ADS | 地址后切 dual/quad 驱动，dummy 正确 | `rd_dq` | P0 |
| VP_RD_003 | 读 | Dual I/O 连续读 | BB/BC/BD/BE SPI × ADS | 地址拍数、cm_cycle、dummy、drive 模式正确 | `rd_dio` | P1 |
| VP_RD_004 | 读 | Quad I/O 连续读 | EB/EC/ED/EE SPI/QPI × ADS | 地址拍数、cm_cycle、dummy、drive 模式正确 | `rd_qio` | P0 |
| VP_RD_005 | 读 | QPI Fast/Burst Read | 0B/0C/0E QPI × ADS × C0 参数 | dummy 查表、wrap_len 正确 | `rd_qpi_burst` | P0 |
| VP_WR_001 | 编程 | PP/QPP | 02/12 SPI/QPI、32/34 SPI，ADS=0/1 | `write_array_en=1`，地址拍数正确，32/34 地址后 sample_mode 切 quad | `pp` | P0 |
| VP_ER_001 | 擦除 | SE/BE32/BE64/CE | 20/21/52/5C/D8/DC/60/C7 × SPI/QPI × ADS | 对应 `erase_*_en`，命令+地址拍数正确 | `erase` | P0 |
| VP_DPD_001 | 低功耗 | B9h 进入 DPD | SPI/QPI 发 B9h 并 CS#↑ | `enter_dpd_en` 单拍，`dpd_reg=1` | `dpd_enter` | P0 |
| VP_DPD_002 | 低功耗 | DPD 中命令隔离 | DPD 后发 06/05/02 等 | 状态回 idle，不产生 set_wel/read 等非法使能；仅 AB/66/99 有效 | `dpd_isolate` | P0 |
| VP_DPD_003 | 低功耗 | ABh 立即释放 | DPD 后发 ABh，命令码后立即 CS#↑ | `exit_dpd_en=1`，`dpd_reg=0`，无 read_devid_en | `dpd_exit_fast` | P0 |
| VP_DPD_004 | 低功耗 | ABh+dummy 释放并读 DID | DPD 后发 ABh，继续 dummy 周期 | 先 `read_devid_en` 和 dummy/drive，Device ID 输出结束后才 `exit_dpd_en`；**预期当前 RTL 不满足（F-01）** | `dpd_exit_did` | P0 |
| VP_WEL_001 | 保护 | WREN/WRDI | 06/04 SPI/QPI | `set_wel`/`clear_wel` 单拍；WEL 状态保持由集成层/array FSM 确认 | `wel` | P0 |
| VP_WEL_002 | 保护 | 无 WEL 写/擦（集成层） | 不发 06 直接 02/20/D8/01/B1 | Flash 不执行，状态不变；确认 gating 位于集成层或列为 v4 缺口 | `wel_gate` | P0 |
| VP_PWD_001 | 密码 | 27/28/29 的 pwd 门控 | `pwd=0/1` 下发送 27/28/29 | pwd=1 时 27/28 忽略；pwd=0 时 29 忽略；使能/拍数正确 | `pwd` | P2 |
| VP_SUS_001 | 暂停 | 75/7A 译码 | SPI/QPI 发 75h/7Ah | `pes_en`/`per_en` 单拍，状态回 idle | `suspend` | P1 |
| VP_SUS_002 | 暂停 | 暂停期间非法命令（集成层） | 挂起后发 01/11/B1/02/20 等 | 命令被忽略；确认集成层实现 | `suspend_gate` | P1 |
| VP_XIP_001 | XIP | POR-XIP 四种配置 | `por_xip=1`，`vncr_0=FC/FD/FE/FB`，ADS=0/1 | sample/drive/cm/dummy/addr 各参数正确 | `por_xip_cfg` | P0 |
| VP_XIP_002 | XIP | 连续读 8 指令 | 先发 BB/BC/BD/BE/EB/EC/ED/EE 且 cm[5:4]=10，下一次 CS#↓ 不给指令 | 按上条指令进入 xip，参数正确，read_array_en 有效 | `xip_cmd` | P0 |
| VP_XIP_003 | XIP | 连续读退出 | XIP 中 `cm[5:4]!=10` | `clear_por_xip=1`，退出 XIP | `xip_exit` | P0 |
| VP_XIP_004 | XIP | 事务间 cmd/cm 保持约束 | 上游在事务间清 cmd/cm | 确认 XIP 不误退；若 RTL 依赖 cmd/cm 保持则形成接口约束（F-07） | `xip_if` | P1 |
| VP_WRAP_001 | Wrap | C0h 参数锁存 | QPI 发 C0h，P5-P4/P1-P0 遍历 | `qpi_read_param_en` 对齐数据拍，读参数生效 | `c0_param` | P0 |
| VP_WRAP_002 | Wrap | C0h dummy 查表 | 0B/0C/0E/EB/EC/ED/EE × P=00/01/10/11 | `qpi_dummy_sel` 输出 4/6/8/10(STR)、10/8/10/10(DTR) | `c0_dummy` | P0 |
| VP_WRAP_003 | Wrap | C0h wrap_len | 0C/0E × P1-P0 | wrap_len=8/16/32/64 | `c0_wrap` | P0 |
| VP_WRAP_004 | Wrap | 77h 参数锁存 | SPI 发 77h + 8 个后命令拍，W4-W6 遍历 | `spi_wrap_data_en` 在 `cnt==cmd_cycle+8` 处锁存；W4/W5/W6 应出现在第 7 个后命令拍 | `spi_wrap` | P0 |
| VP_WRAP_005 | Wrap | 77h wrap_len 生效 | W4=0 时 EB/EC/ED/EE，W6-W5 遍历 | wrap_len=8/16/32/64；W4=1 不 wrap | `spi_wrap_len` | P1 |
| VP_WRAP_006 | Wrap | 模式切换后 wrap 保持 | 设 77h 参数→38h→QPI 读；或 C0h→FFh→SPI 读 | 按 datasheet 确认 wrap 不应变；当前两套参数可能不满足（F-06） | `wrap_mode_switch` | P1 |
| VP_ERR_001 | 错误注入 | CS# 提前拉高 | 写/擦/DPD 命令未到字节边界 | 命令 reject，无执行使能 | `err_cs_early` | P0 |
| VP_ERR_002 | 错误注入 | CS# 滞后拉高 | 写命令超过规定数据长度后拉高 | 命令 reject 或按 datasheet 行为，状态安全回 idle | `err_cs_late` | P1 |
| VP_ERR_003 | 错误注入 | 未知/保留指令 | 全命令空间随机遍历 | 不产生多使能同时置 1 的非法组合 | `err_unknown` | P1 |
| VP_ERR_004 | 错误注入 | DPD 中非法指令 | B9h 后发随机指令（除 AB/66/99） | 全部忽略 | `err_dpd` | P0 |
| VP_INT_001 | 集成 | Flash model 端到端 | `ctrl_if + OSC/array FSM + VerMdl_XM25Q512F` | 读回 ID/SR、写读数据一致、擦除后 FF、DPD 电流行为模型 | `int_flash` | P0 |
| VP_INT_002 | 集成 | XIP 启动流程 | POR-XIP + Safe Boot 条件 | 按 datasheet 4.5/4.6 流程进入/退出 | `int_xip` | P1 |
| VP_INT_003 | 集成 | 软硬件复位流程 | CPU 发 66+99、RESET# 拉低 | 全系统回 idle，易失配置恢复默认 | `int_reset` | P0 |
| VP_CRG_001 | 回归 | 种子回归 | 全用例 × ≥200 随机种子 | 通过率 100%，覆盖率收敛 | `regr` | P0 |
| VP_CRG_002 | 回归 | Bug 收敛 | 每周统计新增/关闭 | 连续 2 周无新增 P0/P1，曲线收敛 | `bug_curve` | P0 |

### 6.2 指令级测试点矩阵

下表为每条指令 × 模式的译码级测试点，必须逐条命中。`功能` 列为 datasheet 定义，详细拍数在参考模型中按附录 B 期望值检查。

| ID | 指令 | 模式 | 功能 | 优先级 |
|---|---|---|---|---|
| CMD_SPI_01 | 01h | SPI | Write Status Register 1/2（WRSR） | P0 |
| CMD_QPI_01 | 01h | QPI | Write Status Register 1/2（WRSR） | P0 |
| CMD_SPI_02 | 02h | SPI | Page Program，3/4 字节地址 | P0 |
| CMD_QPI_02 | 02h | QPI | Page Program，3/4 字节地址 | P0 |
| CMD_SPI_03 | 03h | SPI | Read Data Bytes，3/4 字节地址 | P0 |
| CMD_SPI_04 | 04h | SPI | Write Disable（WRDI） | P0 |
| CMD_QPI_04 | 04h | QPI | Write Disable（WRDI） | P0 |
| CMD_SPI_05 | 05h | SPI | Read Status Register 1 | P0 |
| CMD_QPI_05 | 05h | QPI | Read Status Register 1 | P0 |
| CMD_SPI_06 | 06h | SPI | Write Enable（WREN） | P0 |
| CMD_QPI_06 | 06h | QPI | Write Enable（WREN） | P0 |
| CMD_SPI_0B | 0Bh | SPI | Fast Read / QPI Fast Read，3/4 字节地址 | P0 |
| CMD_QPI_0B | 0Bh | QPI | Fast Read / QPI Fast Read，3/4 字节地址 | P0 |
| CMD_SPI_0C | 0Ch | SPI | SPI：Fast Read（4B 地址）；QPI：Burst Read with Wrap | P0 |
| CMD_QPI_0C | 0Ch | QPI | SPI：Fast Read（4B 地址）；QPI：Burst Read with Wrap | P0 |
| CMD_QPI_0E | 0Eh | QPI | QPI：DTR Burst Read with Wrap | P1 |
| CMD_SPI_11 | 11h | SPI | Write Status Register 3 | P0 |
| CMD_QPI_11 | 11h | QPI | Write Status Register 3 | P0 |
| CMD_SPI_12 | 12h | SPI | Page Program，4 字节地址 | P0 |
| CMD_QPI_12 | 12h | QPI | Page Program，4 字节地址 | P0 |
| CMD_SPI_13 | 13h | SPI | Read Data Bytes，4 字节地址 | P0 |
| CMD_SPI_15 | 15h | SPI | Read Status Register 3 | P0 |
| CMD_QPI_15 | 15h | QPI | Read Status Register 3 | P0 |
| CMD_SPI_20 | 20h | SPI | Sector Erase，3/4 字节地址 | P0 |
| CMD_QPI_20 | 20h | QPI | Sector Erase，3/4 字节地址 | P0 |
| CMD_SPI_21 | 21h | SPI | Sector Erase，4 字节地址 | P1 |
| CMD_QPI_21 | 21h | QPI | Sector Erase，4 字节地址 | P1 |
| CMD_SPI_27 | 27h | SPI | Read Password Register | P2 |
| CMD_QPI_27 | 27h | QPI | Read Password Register | P2 |
| CMD_SPI_28 | 28h | SPI | Program Password Register | P2 |
| CMD_QPI_28 | 28h | QPI | Program Password Register | P2 |
| CMD_SPI_29 | 29h | SPI | Password Unlock/Lock | P2 |
| CMD_QPI_29 | 29h | QPI | Password Unlock/Lock | P2 |
| CMD_SPI_30 | 30h | SPI | Clear Flag Status Register | P1 |
| CMD_QPI_30 | 30h | QPI | Clear Flag Status Register | P1 |
| CMD_SPI_32 | 32h | SPI | Quad Page Program，3/4 字节地址（SPI） | P1 |
| CMD_SPI_34 | 34h | SPI | Quad Page Program，4 字节地址（SPI） | P1 |
| CMD_SPI_35 | 35h | SPI | Read Status Register 2 | P0 |
| CMD_QPI_35 | 35h | QPI | Read Status Register 2 | P0 |
| CMD_SPI_38 | 38h | SPI | Enable QPI（SPI） | P0 |
| CMD_SPI_3B | 3Bh | SPI | Dual Output Fast Read，3/4 字节地址（SPI） | P1 |
| CMD_SPI_3C | 3Ch | SPI | Dual Output Fast Read，4 字节地址（SPI） | P1 |
| CMD_SPI_42 | 42h | SPI | Program Security Registers（SPI） | P2 |
| CMD_SPI_44 | 44h | SPI | Erase Security Registers（SPI） | P2 |
| CMD_SPI_48 | 48h | SPI | Read Security Registers（SPI） | P2 |
| CMD_SPI_4B | 4Bh | SPI | Read Unique ID（SPI） | P1 |
| CMD_SPI_50 | 50h | SPI | Write Enable for Volatile Status Register | P1 |
| CMD_QPI_50 | 50h | QPI | Write Enable for Volatile Status Register | P1 |
| CMD_SPI_52 | 52h | SPI | 32KB Block Erase，3/4 字节地址 | P1 |
| CMD_QPI_52 | 52h | QPI | 32KB Block Erase，3/4 字节地址 | P1 |
| CMD_SPI_5A | 5Ah | SPI | Read SFDP | P1 |
| CMD_QPI_5A | 5Ah | QPI | Read SFDP | P1 |
| CMD_SPI_5B | 5Bh | SPI | Data Integrity Check（起始+结束地址） | P1 |
| CMD_QPI_5B | 5Bh | QPI | Data Integrity Check（起始+结束地址） | P1 |
| CMD_SPI_5C | 5Ch | SPI | 32KB Block Erase，4 字节地址 | P1 |
| CMD_QPI_5C | 5Ch | QPI | 32KB Block Erase，4 字节地址 | P1 |
| CMD_SPI_60 | 60h | SPI | Chip Erase | P1 |
| CMD_QPI_60 | 60h | QPI | Chip Erase | P1 |
| CMD_SPI_64 | 64h | SPI | Read Interface CRC Register | P1 |
| CMD_QPI_64 | 64h | QPI | Read Interface CRC Register | P1 |
| CMD_SPI_66 | 66h | SPI | Enable Reset（软件复位使能） | P0 |
| CMD_QPI_66 | 66h | QPI | Enable Reset（软件复位使能） | P0 |
| CMD_SPI_6B | 6Bh | SPI | Quad Output Fast Read，3/4 字节地址（SPI） | P0 |
| CMD_SPI_6C | 6Ch | SPI | Quad Output Fast Read，4 字节地址（SPI） | P1 |
| CMD_SPI_70 | 70h | SPI | Read Flag Status Register | P0 |
| CMD_QPI_70 | 70h | QPI | Read Flag Status Register | P0 |
| CMD_SPI_75 | 75h | SPI | Program/Erase/Data Integrity Check Suspend | P1 |
| CMD_QPI_75 | 75h | QPI | Program/Erase/Data Integrity Check Suspend | P1 |
| CMD_SPI_77 | 77h | SPI | Set Burst with Wrap（SPI，24 dummy bits） | P0 |
| CMD_SPI_7A | 7Ah | SPI | Program/Erase/Data Integrity Check Resume | P1 |
| CMD_QPI_7A | 7Ah | QPI | Program/Erase/Data Integrity Check Resume | P1 |
| CMD_SPI_7E | 7Eh | SPI | Global Block/Sector Lock | P2 |
| CMD_QPI_7E | 7Eh | QPI | Global Block/Sector Lock | P2 |
| CMD_SPI_81 | 81h | SPI | Write Volatile Configuration Register | P1 |
| CMD_QPI_81 | 81h | QPI | Write Volatile Configuration Register | P1 |
| CMD_SPI_85 | 85h | SPI | Read Volatile Configuration Register | P1 |
| CMD_QPI_85 | 85h | QPI | Read Volatile Configuration Register | P1 |
| CMD_SPI_90 | 90h | SPI | Read Manufacturer ID / Device ID（REMS） | P1 |
| CMD_QPI_90 | 90h | QPI | Read Manufacturer ID / Device ID（REMS） | P1 |
| CMD_SPI_98 | 98h | SPI | Global Block/Sector Unlock | P2 |
| CMD_QPI_98 | 98h | QPI | Global Block/Sector Unlock | P2 |
| CMD_SPI_99 | 99h | SPI | Reset（软件复位，须在 66h 之后） | P0 |
| CMD_QPI_99 | 99h | QPI | Reset（软件复位，须在 66h 之后） | P0 |
| CMD_SPI_9F | 9Fh | SPI | Read Identification（RDID） | P0 |
| CMD_QPI_9F | 9Fh | QPI | Read Identification（RDID） | P0 |
| CMD_SPI_AB | ABh | SPI | Release from Deep Power-Down（可带 Device ID 输出） | P0 |
| CMD_QPI_AB | ABh | QPI | Release from Deep Power-Down（可带 Device ID 输出） | P0 |
| CMD_SPI_B1 | B1h | SPI | Write Nonvolatile Configuration Register | P1 |
| CMD_QPI_B1 | B1h | QPI | Write Nonvolatile Configuration Register | P1 |
| CMD_SPI_B5 | B5h | SPI | Read Nonvolatile Configuration Register | P1 |
| CMD_QPI_B5 | B5h | QPI | Read Nonvolatile Configuration Register | P1 |
| CMD_SPI_B7 | B7h | SPI | Enable 4-Byte Address Mode | P1 |
| CMD_QPI_B7 | B7h | QPI | Enable 4-Byte Address Mode | P1 |
| CMD_SPI_B9 | B9h | SPI | Enter Deep Power-Down | P0 |
| CMD_QPI_B9 | B9h | QPI | Enter Deep Power-Down | P0 |
| CMD_SPI_BB | BBh | SPI | Dual I/O Fast Read，3/4 字节地址（SPI，连续读） | P1 |
| CMD_SPI_BC | BCh | SPI | Dual I/O Fast Read，4 字节地址（SPI，连续读） | P1 |
| CMD_SPI_BD | BDh | SPI | Dual I/O DTR Read，3/4 字节地址（SPI，连续读） | P1 |
| CMD_SPI_BE | BEh | SPI | Dual I/O DTR Read，4 字节地址（SPI，连续读） | P1 |
| CMD_QPI_C0 | C0h | QPI | Set Read Parameters（QPI，dummy + wrap 配置） | P0 |
| CMD_SPI_C5 | C5h | SPI | Write Extended Address Register | P1 |
| CMD_QPI_C5 | C5h | QPI | Write Extended Address Register | P1 |
| CMD_SPI_C7 | C7h | SPI | Chip Erase | P1 |
| CMD_QPI_C7 | C7h | QPI | Chip Erase | P1 |
| CMD_SPI_C8 | C8h | SPI | Read Extended Address Register | P1 |
| CMD_QPI_C8 | C8h | QPI | Read Extended Address Register | P1 |
| CMD_SPI_D8 | D8h | SPI | 64KB Block Erase，3/4 字节地址 | P0 |
| CMD_QPI_D8 | D8h | QPI | 64KB Block Erase，3/4 字节地址 | P0 |
| CMD_SPI_DC | DCh | SPI | 64KB Block Erase，4 字节地址 | P1 |
| CMD_QPI_DC | DCh | QPI | 64KB Block Erase，4 字节地址 | P1 |
| CMD_SPI_E0 | E0h | SPI | Read Volatile Lock Register | P2 |
| CMD_QPI_E0 | E0h | QPI | Read Volatile Lock Register | P2 |
| CMD_SPI_E1 | E1h | SPI | Write Volatile Lock Register | P2 |
| CMD_QPI_E1 | E1h | QPI | Write Volatile Lock Register | P2 |
| CMD_SPI_E2 | E2h | SPI | Read Nonvolatile Lock Register | P2 |
| CMD_QPI_E2 | E2h | QPI | Read Nonvolatile Lock Register | P2 |
| CMD_SPI_E3 | E3h | SPI | Set Nonvolatile Lock Register | P2 |
| CMD_QPI_E3 | E3h | QPI | Set Nonvolatile Lock Register | P2 |
| CMD_SPI_E4 | E4h | SPI | Clear All Nonvolatile Lock Registers | P2 |
| CMD_QPI_E4 | E4h | QPI | Clear All Nonvolatile Lock Registers | P2 |
| CMD_SPI_E9 | E9h | SPI | Disable 4-Byte Address Mode | P1 |
| CMD_QPI_E9 | E9h | QPI | Disable 4-Byte Address Mode | P1 |
| CMD_SPI_EB | EBh | SPI | Quad I/O Fast Read，3/4 字节地址（连续读） | P0 |
| CMD_QPI_EB | EBh | QPI | Quad I/O Fast Read，3/4 字节地址（连续读） | P0 |
| CMD_SPI_EC | ECh | SPI | Quad I/O Fast Read，4 字节地址（连续读） | P1 |
| CMD_QPI_EC | ECh | QPI | Quad I/O Fast Read，4 字节地址（连续读） | P1 |
| CMD_SPI_ED | EDh | SPI | Quad I/O DTR Read，3/4 字节地址（连续读） | P1 |
| CMD_QPI_ED | EDh | QPI | Quad I/O DTR Read，3/4 字节地址（连续读） | P1 |
| CMD_SPI_EE | EEh | SPI | Quad I/O DTR Read，4 字节地址（连续读） | P1 |
| CMD_QPI_EE | EEh | QPI | Quad I/O DTR Read，4 字节地址（连续读） | P1 |
| CMD_QPI_FF | FFh | QPI | Disable QPI（QPI） | P0 |

共 131 条指令 × 模式译码测试点。

---

## 7. 回归与资源

| 项目 | 安排 |
|---|---|
| 工具 | VCS（仿真）、Verdi（调试）、Verilator（快速 lint/回归） |
| 回归节奏 | 每日冒烟（P0 用例），每周全量回归 |
| 随机种子 | 每条随机用例 ≥ 200 seeds，合并覆盖率 |
| 缺陷管理 | P0：立即修复并重跑；P1：迭代内关闭；P2：评估后 close/waive |
| 环境 bring-up | 第 1 周：agent/monitor/refmodel 基本通路 + 06/05/03/02 冒烟 |
| 里程碑 | W1 环境 bring-up；W2 全指令定向通过；W3 随机回归与错误注入；W4 覆盖率收敛与签核 |

---

## 8. 风险与开放问题

| ID | 风险/开放问题 | 应对 |
|---|---|---|
| R-01 | datasheet 部分波形图/表格为图片，文字提取不完整（尤其 77h/C0h/DC 表） | 以原厂 FAE/示波器波形确认为准，补充规格 review |
| R-02 | 模块不直接含 SI/SO 移位逻辑，cmd/cm/data 对齐契约未文档化 | 与设计者确认接口时序，写接口规范 |
| R-03 | WEL/WIP/SUS/保护可能由其他 FSM 实现，模块级测试无法关闭 F-03 | 增加集成级用例 VP_WEL_002/VP_SUS_002 |
| R-04 | v5 已开始重构（cnt 改输入、decode 拆分），v4 结论是否迁移到 v5 需评估 | 验证计划按版本维护，v5 重新做差异分析 |
| R-05 | wrap 跨模式保持等 datasheet 与 RTL 存在解释差异 | 先冻结解释，再改 RTL 或 waive |

---

## 附录 A：v4 指令覆盖对照

| 指令 | SPI | QPI | v4 SPI 行号 | v4 QPI 行号 |
|---|---|---|---|---|
| 01h | Y | Y | L1159 | L579 |
| 02h | Y | Y | L1177 | L597 |
| 03h | Y | N(SPI only) | L1183 | - |
| 04h | Y | Y | L1193 | L603 |
| 05h | Y | Y | L1197 | L607 |
| 06h | Y | Y | L1204 | L614 |
| 0Bh | Y | Y | L1208 | L618 |
| 0Ch | Y | Y | L1219 | L629 |
| 0Eh | N(QPI only) | Y | - | L647 |
| 11h | Y | Y | L1236 | L672 |
| 12h | Y | Y | L1254 | L690 |
| 13h | Y | N(SPI only) | L1260 | - |
| 15h | Y | Y | L1270 | L696 |
| 20h | Y | Y | L1283 | L709 |
| 21h | Y | Y | L1289 | L715 |
| 27h | Y | Y | L1295 | L721 |
| 28h | Y | Y | L1305 | L735 |
| 29h | Y | Y | L1315 | L745 |
| 30h | Y | Y | L1331 | L761 |
| 32h | Y | N(SPI only) | L1335 | - |
| 34h | Y | N(SPI only) | L1344 | - |
| 35h | Y | Y | L1353 | L765 |
| 38h | Y | N(SPI only) | L1360 | - |
| 3Bh | Y | N(SPI only) | L1364 | - |
| 3Ch | Y | N(SPI only) | L1375 | - |
| 42h | Y | N(SPI only) | L1392 | - |
| 44h | Y | N(SPI only) | L1398 | - |
| 48h | Y | N(SPI only) | L1404 | - |
| 4Bh | Y | N(SPI only) | L1415 | - |
| 50h | Y | Y | L1432 | L778 |
| 52h | Y | Y | L1436 | L782 |
| 5Ah | Y | Y | L1442 | L788 |
| 5Bh | Y | Y | L1453 | L799 |
| 5Ch | Y | Y | L1459 | L805 |
| 60h | Y | Y | L1471 | L817 |
| 64h | Y | Y | L1475 | L821 |
| 66h | Y | Y | L1485 | L831 |
| 6Bh | Y | N(SPI only) | L1489 | - |
| 6Ch | Y | N(SPI only) | L1500 | - |
| 70h | Y | Y | L1517 | L841 |
| 75h | Y | Y | L1523 | L847 |
| 77h | Y | N(SPI only) | L1527 | - |
| 7Ah | Y | Y | L1535 | L851 |
| 7Eh | Y | Y | L1539 | L855 |
| 81h | Y | Y | L1549 | L865 |
| 85h | Y | Y | L1556 | L872 |
| 90h | Y | Y | L1573 | L889 |
| 98h | Y | Y | L1583 | L900 |
| 99h | Y | Y | L1587 | L904 |
| 9Fh | Y | Y | L1596 | L913 |
| ABh | Y | Y | L1608 | L925 |
| B1h | Y | Y | L1631 | L948 |
| B5h | Y | Y | L1638 | L955 |
| B7h | Y | Y | L1649 | L966 |
| B9h | Y | Y | L1653 | L970 |
| BBh | Y | N(SPI only) | L1657 | - |
| BCh | Y | N(SPI only) | L1669 | - |
| BDh | Y | N(SPI only) | L1681 | - |
| BEh | Y | N(SPI only) | L1694 | - |
| C0h | N(QPI only) | Y | - | L980 |
| C5h | Y | Y | L1713 | L990 |
| C7h | Y | Y | L1719 | L996 |
| C8h | Y | Y | L1723 | L1000 |
| D8h | Y | Y | L1735 | L1012 |
| DCh | Y | Y | L1741 | L1018 |
| E0h | Y | Y | L1763 | L1030 |
| E1h | Y | Y | L1773 | L1041 |
| E2h | Y | Y | L1780 | L1048 |
| E3h | Y | Y | L1790 | L1059 |
| E4h | Y | Y | L1796 | L1065 |
| E9h | Y | Y | L1800 | L1069 |
| EBh | Y | Y | L1804 | L1073 |
| ECh | Y | Y | L1817 | L1085 |
| EDh | Y | Y | L1830 | L1097 |
| EEh | Y | Y | L1843 | L1110 |
| FFh | N(QPI only) | Y | - | L1129 |

XIP 状态命令分支：BBh L451、BCh L464、BDh L476、BEh L489、EBh L502、ECh L515、EDh L528、EEh L541。
POR-XIP 配置分支：`vncr_0=FC` L397、`FD` L409、`FE` L422、`FB` L435。

---

## 附录 B：主要周期参数期望值（datasheet 核对）

| 命令 | 模式 | 命令拍数 | 地址拍数 | dummy/data/cm | 输出驱动 |
|---|---|---|---|---|---|
| 01h WRSR | SPI | 8 | - | data=16 | - |
| 01h WRSR | QPI | 2 | - | data=4 | - |
| 11h WRSR | SPI | 8 | - | data=8 | - |
| 11h WRSR | QPI | 2 | - | data=2 | - |
| 02h/20h/52h/D8h 等可变地址 | SPI | 8 | ads?32:24 | - | - |
| 02h/20h/52h/D8h 等可变地址 | QPI | 2 | ads?8:6 | - | - |
| 12h/21h/5Ch/DCh 等 4B 地址 | SPI | 8 | 32 | - | - |
| 12h/21h/5Ch/DCh 等 4B 地址 | QPI | 2 | 8 | - | - |
| 0Bh Fast Read | SPI | 8 | ads?32:24 | dummy=8 | drive_standard |
| 0Bh Fast Read | QPI | 2 | ads?8:6 | dummy=C0 表，fallback 6 | drive_quad |
| 0Ch | SPI | 8 | 32 | dummy=8 | drive_standard |
| 0Ch Burst Wrap | QPI | 2 | ads?8:6 | dummy=C0 表，fallback 4；wrap=C0 P1-P0 | drive_quad |
| 0Eh DTR Burst Wrap | QPI | 2 | ads?4:3 | dummy=C0 DTR 表，fallback 10；wrap=C0 P1-P0 | drive_dtr_quad |
| 3B/6B/48/4B/5A 等 SPI 读 | SPI | 8 | ads?32:24 | dummy=8（5A 地址固定 24） | drive_standard/dual/quad |
| EB/EC SPI 连续读 | SPI | 8 | ads?8:6 / 8 | cm=2，dummy=4 | drive_quad |
| ED/EE SPI 连续读 | SPI | 8 | ads?4:3 / 4 | cm=1，dummy=7 | drive_dtr_quad |
| BB/BC SPI 连续读 | SPI | 8 | ads?16:12 / 16 | cm=4，dummy=0 | drive_dual |
| BD/BE SPI 连续读 | SPI | 8 | ads?8:6 / 8 | cm=2，dummy=4 | drive_dtr_dual |
| EB/EC QPI 连续读 | QPI | 2 | ads?8:6 / 8 | cm=2，dummy=C0 表 fallback 2 | drive_quad |
| ED/EE QPI 连续读 | QPI | 2 | ads?4:3 / 4 | cm=1，dummy=C0 DTR 表 fallback 9 | drive_dtr_quad |
| 27h Read Password | QPI | 2 | - | dummy=8 | drive_quad |
| 28h/29h Password | QPI | 2 | - | data=16 | - |
| ABh Release DPD | SPI | 8 | - | 无 dummy（CS#↑）或 dummy=24+DID | 释放时序见 F-01 |
| ABh Release DPD | QPI | 2 | - | 无 dummy（CS#↑）或 dummy=6+DID | 释放时序见 F-01 |
| 64h Interface CRC | SPI | 8 | 32 | - | drive_standard |
| 64h Interface CRC | QPI | 2 | 8 | - | drive_quad |
| 5Bh Data Integrity | SPI | 8 | 64（8 字节地址） | - | - |
| 5Bh Data Integrity | QPI | 2 | 16 | - | - |
| C0h Set Read Param | QPI | 2 | - | data=2 | 锁存读参数 |
| 77h Set Burst Wrap | SPI | 8 | - | 8 个后命令拍：6 拍=24 dummy bit，第 7 拍 W4-W6，第 8 拍 trailing x；锁存点 cnt=16 | 锁存 W6-W4 |

> 表中“fallback”指 `qpi_read_param_valid=0` 时 v4 使用的硬编码 dummy 值，其与器件 POR 初值的一致性必须由测试确认（F-04）。

---

## 附录 C：文档修订记录

| 版本 | 日期 | 修订内容 |
|---|---|---|
| v0.1 | 2026-08-24 | 初稿：PDF 功能分析、v4 完整性判断、验证计划与测试点 |
