.DEFAULT_GOAL := test
TOMATO_FPGA ?= ../tomato/hardware/fpga
TOP := pineapple_top
SRC := $(wildcard rtl/board/*.v rtl/host/*.v rtl/gpu/*.v rtl/memory/*.v) rtl/pineapple_top.v rtl/cube_top.v
XDC := constr/nexys.xdc
FREQ_MHZ := 50
# nextpnr-xilinx cannot reliably route the mapped DSP carry ports on this install.
SYNTH_OPTS := -nodsp

.PHONY: test verify clean fpga-cube program-cube synth-cube docs docs-clean docs-open
fpga-cube:
	$(MAKE) fpga TOP=cube_top
program-cube:
	$(MAKE) program TOP=cube_top
synth-cube:
	$(MAKE) synth TOP=cube_top
test:
	@mkdir -p build
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_board -o build/tb_board $(SRC) tb/tb_board.v
	vvp build/tb_board
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_keypad -o build/tb_keypad rtl/board/keypad.v tb/tb_keypad.v
	vvp build/tb_keypad
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_camera -o build/tb_camera rtl/host/camera_controller.v tb/tb_camera.v
	vvp build/tb_camera
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_framebuffer -o build/tb_framebuffer rtl/memory/render_target.v tb/tb_framebuffer.v
	vvp build/tb_framebuffer
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_reciprocal -o build/tb_reciprocal rtl/gpu/reciprocal.v tb/tb_reciprocal.v
	vvp build/tb_reciprocal
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_drawerr -o build/tb_drawerr $(SRC) tb/tb_drawerr.v
	vvp build/tb_drawerr
	python3 tools/generate_tests.py
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_shader -o build/tb_shader rtl/gpu/shader_core.v rtl/memory/texture_mem.v tb/tb_shader.v
	vvp build/tb_shader
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_rasterizer -o build/tb_rasterizer rtl/gpu/rasterizer.v tb/tb_rasterizer.v
	vvp build/tb_rasterizer
	iverilog -g2012 -Wall -DPINEAPPLE_SIM -s tb_uart -o build/tb_uart rtl/board/uart_rx.v rtl/gpu/shader_loader.v tb/tb_uart.v
	vvp build/tb_uart

# Pixel-exact full-pipeline check: RTL frames must match the integer reference
# for the cube (all six shader modes), the pineapple showcase, and DRAW errors.
# Slow (several minutes of simulation); run before claiming any GPU change.
verify:
	@mkdir -p build
	iverilog -g2012 -DPINEAPPLE_SIM -s tb_gpu -o build/tb_gpu $(SRC) tb/tb_gpu.v
	vvp build/tb_gpu +YAW=5 +OUT=build/rtl-frame.mem
	python3 tools/check_frame.py --yaw 5 --rtl build/rtl-frame.mem
	iverilog -g2012 -DPINEAPPLE_SIM -DPINE_TEST_SHOWCASE -s tb_gpu -o build/tb_showcase $(SRC) tb/tb_gpu.v
	vvp build/tb_showcase +OUT=build/showcase-frame.mem
	python3 tools/check_frame.py --asset pineapple --rtl build/showcase-frame.mem
	for mode in 1 2 3 4 5; do \
	  vvp build/tb_gpu +MODE=$$mode +YAW=5 +OUT=build/cube-mode-$$mode.mem && \
	  python3 tools/check_frame.py --mode $$mode --yaw 5 --rtl build/cube-mode-$$mode.mem || exit 1; \
	done

# Reuse the installed flow; no copied toolchain or destructive setup targets.
ifneq ($(wildcard $(TOMATO_FPGA)/common.mk),)
include $(TOMATO_FPGA)/common.mk

else
.PHONY: fpga program synth
fpga program synth:
	@echo 'Set TOMATO_FPGA to Tomato hardware/fpga (see README.md)'; exit 1
endif
clean:
	rm -rf build

# Technical manual (Asciidoctor, no Node/npm). Output: build/docs/index.html
docs:
	./scripts/build-docs.sh

docs-clean:
	rm -rf build/docs

docs-open: docs
	@if command -v open >/dev/null 2>&1; then open build/docs/index.html; \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open build/docs/index.html; \
	else echo 'Built build/docs/index.html (no open/xdg-open found)'; fi

$(JSON): Makefile $(wildcard assets/packed/*.mem assets/packed/*.vh assets/cube/*.mem assets/cube/*.vh) assets/program.mem assets/camera.mem
