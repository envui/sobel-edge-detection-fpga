# Icarus Verilog regression for the Sobel HDMI pipeline.
#
#   make            run all four testbenches
#   make sobel      tb_sobel_core
#   make streamer   tb_image_streamer
#   make window     tb_line_buffer_window
#   make top        tb_top_small
#   make clean

IVERILOG := iverilog
VVP      := vvp
RTL      := ../rtl
DATA     := ../data
FLAGS    := -g2005 -Wall -I$(RTL)

SRC := $(RTL)/sobel_core.v \
       $(RTL)/image_streamer.v \
       $(RTL)/image_rom.v \
       $(RTL)/line_buffer_window.v \
       $(RTL)/simple_dual_port_ram.v \
       $(RTL)/display_mapper_2x.v \
       $(RTL)/video_timing_640x480.v \
       $(RTL)/rgb_gray.v \
       $(RTL)/clock_div_5.v \
       $(RTL)/top_sobel_video_zybo.v

.PHONY: all sobel streamer window top clean

all: sobel streamer window top
	@echo ""
	@echo "=== all testbenches complete ==="

sobel: tb_sobel_core.v $(RTL)/sobel_core.v
	@echo "--- tb_sobel_core ---"
	$(IVERILOG) $(FLAGS) -o build_sobel.vvp $< $(RTL)/sobel_core.v
	$(VVP) build_sobel.vvp

streamer: tb_image_streamer.v $(RTL)/image_streamer.v
	@echo "--- tb_image_streamer ---"
	$(IVERILOG) $(FLAGS) -o build_streamer.vvp $< $(RTL)/image_streamer.v
	$(VVP) build_streamer.vvp

window: tb_line_buffer_window.v $(RTL)/line_buffer_window.v
	@echo "--- tb_line_buffer_window ---"
	@echo "    NOTE: prints windows for inspection; does not self-check."
	@echo "    Expect center=(2,2) -> 10 11 12 / 20 21 22 / 30 31 32"
	$(IVERILOG) $(FLAGS) -o build_window.vvp $< $(RTL)/line_buffer_window.v
	$(VVP) build_window.vvp

# $readmemh resolves relative to the simulator's working directory, so the
# memory file is copied in beside the compiled output.
top: tb_top_small.v $(SRC)
	@echo "--- tb_top_small ---"
	cp $(DATA)/image_small.mem .
	$(IVERILOG) $(FLAGS) -o build_top.vvp $< $(SRC)
	$(VVP) build_top.vvp

clean:
	rm -f *.vvp *.vcd image_small.mem image.mem
