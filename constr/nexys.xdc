## Pineapple GPU P1 — Nexys A7-100T (xc7a100tcsg324-1)
## Top: pineapple_top (cube_top wraps it with ASSET=cube/INDEX_COUNT=36).
## Video leaves on the 12-bit TFP410 DVI PMOD across JC + JD.
## Clocks (rtl/board/clock_reset.v): 100 MHz E3 -> div/2 gpu_clk 50 MHz
## (GPU, host, keypad, UART) + div/4 pix_clk 25 MHz (scanout, DVI), each BUFG.
## CDC: render_target request/ack is 2-flop synced both ways and swaps only at
## vblank_start; buttons/UART RX are 2-flop synced at their receivers; resets
## are async-assert/sync-release per domain. nextpnr-xilinx takes --freq 50
## for timing and warns on the two [current_design] lines below; they are for
## Vivado. The Vivado-only CDC exceptions are kept as comments so the FOSS
## flow never has to parse them:
##   set_false_path -from [get_ports {btnu btnd btnl btnr btnc RsRx cpu_resetn}]
##   set_false_path -from [get_clocks -of_objects [get_pins clocks/div_reg*]] -to ...
##   (gpu_clk -> pix_clk req_sync[*], pix_clk -> gpu_clk ack_sync[*])
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ---- 100 MHz board oscillator -------------------------------------------
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

## ---- CPU_RESETN (red button, high at rest) -------------------------------
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports cpu_resetn]

## ---- D-pad: stands in for a keyboard (rtl/board/keypad.v) ----------------
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports btnc]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports btnu]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports btnd]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports btnl]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports btnr]

## ---- USB-UART receive (shader upload, 115200 8N1) -------------------------
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports RsRx]

## ---- 12-bit DVI PMOD v1.1b -----------------------------------------------
## Identical mapping to hardware/fpga/hdmi_test — the bring-up that lit a screen.
## JC = R/G (PMOD1A): pin1 R3, pin2 R1, pin3 G3, pin4 G1, pin7 R2, pin8 R0, pin9 G2, pin10 G0
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[3]}]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[1]}]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[3]}]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[1]}]
set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[2]}]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_r[0]}]
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[2]}]
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_g[0]}]

## JD = B + CLK/HS/VS/DE (PMOD1B): pin1 B3, pin2 CLK, pin3 B0, pin4 HS, pin7 B2, pin8 B1, pin9 DE, pin10 VS
set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[3]}]
set_property -dict { PACKAGE_PIN H1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_clk]
set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[0]}]
set_property -dict { PACKAGE_PIN G3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_hs]
set_property -dict { PACKAGE_PIN H2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[2]}]
set_property -dict { PACKAGE_PIN G4 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports {dvi_b[1]}]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_de]
set_property -dict { PACKAGE_PIN F3 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8 } [get_ports dvi_vs]

