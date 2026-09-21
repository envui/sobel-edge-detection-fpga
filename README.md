# Real-Time Sobel Edge Detection Video System on FPGA with HDMI Output

A streaming Sobel edge-detection video pipeline in Verilog, targeting the
**Digilent Zybo Z7-10** (Xilinx `xc7z010clg400-1`). A 320x240 8-bit grayscale
image held in on-chip memory is processed one pixel per clock cycle at 125 MHz,
thresholded into a binary edge map, stored in a dual-port framebuffer, upscaled
2x, and driven out as **640x480 @ 60 Hz HDMI** through Digilent's `rgb2dvi` TMDS
encoder IP.

CECS 460 (Digital Design with FPGAs) final project, California State University,
Long Beach. Built entirely in the PL fabric — the Zynq ARM core is not used.

| | |
|---|---|
| **Board / part** | Zybo Z7-10, `xc7z010clg400-1` |
| **Tools** | Vivado 2020.2; Icarus Verilog 12.0 for testbench regression |
| **Processing clock** | 125 MHz (board oscillator, pin K17) |
| **Pixel clock** | 25 MHz (`clk_wiz_0` CLKOUT1) |
| **TMDS serial clock** | 125 MHz (`clk_wiz_0` CLKOUT2) |
| **Source image** | 320x240, 8-bit gray, 76,800 px (`data/image.mem`) |
| **Display** | 640x480 @ 60 Hz, 2x nearest-neighbor upscale |
| **Throughput** | 1 px/cycle after fill, 614.4 us per frame (27x the 16.67 ms display period) |
| **Utilization** | 233 LUTs (1.3%), 246 FFs (0.7%), 16 BRAM (26.7%), 0 DSP |

---

## Why an FPGA

Sobel is a 3x3 convolution applied at every pixel — repetitive, local, and fully
data-parallel. A CPU walks it with nested loops, paying instruction fetch,
decode, and branch cost per pixel. Here the window generator, both gradient
adders, the magnitude approximation, the threshold compare, and the framebuffer
write are all concurrent dedicated hardware. After a 5-cycle pipeline fill the
design accepts a new pixel every clock: 125 Mpixel/s, deterministic, with zero
instruction overhead.

The kernel weights are only -2, -1, 0, +1, +2, so the whole datapath is adds,
subtracts, and shifts — **no multipliers, and no DSP slices consumed.**

## The algorithm

For a 3x3 neighborhood `p00..p22`:

```
Gx  = -p00 + p02 - 2*p10 + 2*p12 - p20 + p22     (horizontal gradient)
Gy  = -p00 - 2*p01 - p02 + p20 + 2*p21 + p22     (vertical gradient)
mag = |Gx| + |Gy|                                 (Manhattan approximation)
out = (mag > threshold) ? 0xFF : 0x00
```

The true Euclidean magnitude `sqrt(Gx^2 + Gy^2)` needs a square root, which is
expensive in fabric. The Manhattan approximation costs two absolute values and
one add, and is more than accurate enough for thresholded binary edge output.

## Architecture

Two clock domains, bridged by the framebuffer:

```
== PROCESSING DOMAIN - 125 MHz ===================================
                                                                 |
 image_streamer --addr,x,y--> image_rom --pixel--> line_buffer_window
  (raster scan)              (BRAM, 1 cyc)        (2 line buffers,
       |                                           3x3 shift regs)
       | x,y delayed 1 cycle to match ROM latency        |
       v                                          p00..p22, valid
   led[1] busy                                           v
                                                    sobel_core
                                                 (Gx, Gy, |Gx|+|Gy|,
                                                  threshold compare)
                                                         |
                                                  edge_pixel, x, y
                                                         v
                                           simple_dual_port_ram  <-- write @ 125 MHz
=========================================================|========
                                                         |  CDC boundary
== DISPLAY DOMAIN - 25 MHz ==============================|========
                                                         |
 video_timing_640x480 --disp_x,disp_y--> display_mapper_2x --rd_addr-+
       |                                  (>>1 each axis)            |
   hsync/vsync/de                                   rd_data <--------+
       |                                               |
       +---------------------------> rgb_gray <--------+
                                         | r,g,b (24-bit)
=========================================|========================
                                         v
                                  rgb2dvi_0 (Digilent IP)
                                         | TMDS differential pairs
                                         v
                                   HDMI TX connector
```

`clk_wiz_0` derives the 25 MHz pixel clock and the 125 MHz serial clock from the
board's 125 MHz oscillator (an exact 5:1 ratio). Its `locked` output holds the
whole design in reset until both clocks are stable:

```verilog
assign rst = rst_btn | ~clk_locked;
```

See [`docs/architecture.md`](docs/architecture.md) for the per-stage pipeline and
timing walkthrough.

## Repository layout

```
rtl/          Synthesizable Verilog - all modules
sim/          Four testbenches + Icarus Makefile
constraints/  Zybo-Z7-Master.xdc (clock, switches, button, LEDs, HDMI TMDS)
ip/           clk_wiz_0.xci, rgb2dvi_0.xci - the two Vivado IP configurations
data/         image.mem (320x240 source), image_small.mem (8x8 test pattern)
scripts/      create_project.tcl - rebuilds the Vivado project from scratch
docs/         Architecture, module reference, verification notes, final report
attic/        Superseded LED-only bring-up top level, kept for reference
```

## Module reference

| Module | Function | Clock domain |
|---|---|---|
| `image_rom.v` | 320x240 grayscale ROM, `$readmemh` from `image.mem` | proc_clk |
| `image_streamer.v` | Row-major address + x/y coordinate generator | proc_clk |
| `line_buffer_window.v` | Two line buffers forming a sliding 3x3 window | proc_clk |
| `sobel_core.v` | Gx, Gy, magnitude approximation, threshold compare | proc_clk |
| `simple_dual_port_ram.v` | Edge-map framebuffer; bridges the two domains | wr: proc_clk / rd: pix_clk |
| `display_mapper_2x.v` | 640x480 display coords to 320x240 source address | combinational |
| `video_timing_640x480.v` | hsync, vsync, de, x, y generation | pix_clk |
| `rgb_gray.v` | Gray to R=G=B, blanked outside active video | combinational |
| `sobel_video_core.v` | Integrates processing and display paths | dual-clock |
| `top_hdmi_zybo.v` | **Board top**: clocking wizard + `rgb2dvi` HDMI | dual-clock + TMDS |
| `top_sobel_video_zybo.v` | Simulation top; `clock_div_5` stands in for the PLL | dual-clock |
| `clock_div_5.v` | Divide-by-5 clock divider, simulation only | — |

Full port-level detail in [`docs/modules.md`](docs/modules.md).

### Two top levels, deliberately

`top_hdmi_zybo.v` is what gets built for the board. `top_sobel_video_zybo.v`
exists so the pipeline can be simulated without instantiating a PLL: it swaps
`clk_wiz_0` for the behavioral `clock_div_5` and exposes the raw video signals
instead of TMDS pairs. `tb_top_small` drives this one. Do not synthesize it —
`clock_div_5` produces a clock on fabric routing rather than a global buffer.

## Board controls

**Threshold** is set live from the four slide switches, replicated into both
nibbles: `threshold = {sw, sw}`.

| `sw` | Threshold | Behavior |
|---|---|---|
| `0x0` | 0 | Maximum sensitivity — every gradient, including noise |
| `0x4` | `0x44` = 68 | Moderate; the value used throughout verification |
| `0xF` | `0xFF` = 255 | Only the strongest edges survive |

**LEDs** report pipeline status:

| LED | Signal | Meaning |
|---|---|---|
| 0 | `frame_done` latch | Latches high ~614 us after reset — one full frame processed |
| 1 | `str_busy` | Brief flash during the image streaming pass |
| 2 | `edge_valid` | Pulses while the Sobel core emits pixels |
| 3 | `vid_de` | Active video region; glows dim at the 60 Hz frame rate |

**BTN0** (`rst_btn`, pin K18) is the synchronous reset.

## Building

### Vivado project

```tcl
# From the repo root, in the Vivado Tcl console:
source scripts/create_project.tcl
```

This creates `build/sobel_hdmi_fpga.xpr` targeting `xc7z010clg400-1`, adds all
RTL, constraints, and memory files, and imports both IP cores.

The `rgb2dvi` core is **not** in the stock Vivado IP catalog. Install the
[Digilent vivado-library](https://github.com/Digilent/vivado-library) and add it
as an IP repository first, or `ip/rgb2dvi_0.xci` will fail to resolve. The
script looks for it at `$::env(DIGILENT_IP)` and warns if unset.

Then run synthesis, implementation, and bitstream generation, and program over
JTAG with the Hardware Manager.

> `data/image.mem` must be reachable from the synthesis working directory — the
> script adds it to the design sources so Vivado copies it alongside the run.

### Simulation (Icarus Verilog)

```bash
cd sim
make          # run all four testbenches
make sobel    # just tb_sobel_core
```

Three of the four are self-checking: they print `PASS: <name>` and call
`$finish`, or print `FAIL: <reason>` and call `$stop`. `tb_line_buffer_window`
only *prints* its windows for manual inspection — it cannot fail. See
[`docs/verification.md`](docs/verification.md).

## Verification

| Testbench | Size | Stimulus | Pass criterion |
|---|---|---|---|
| `tb_image_streamer` | 4x3 | One start pulse after reset | Exactly 12 requests in raster order |
| `tb_line_buffer_window` | 4x4 | Sequential pixels, rows 0-3 | Center (2,2) reads `[10 11 12 / 20 21 22 / 30 31 32]` — **checked by eye, not asserted** |
| `tb_sobel_core` | standalone | Flat patch, then vertical step | Flat gives `0x00`; edge gives `0xFF` |
| `tb_top_small` | 8x8 | Full pipeline with `image_small.mem` | `frame_done` / LED[0] asserts after one scan |

All four pass under both Icarus Verilog 12.0 and Vivado 2020.2 behavioral
simulation. See [`docs/verification.md`](docs/verification.md).

## Design notes worth reading

Four decisions in this design are non-obvious, and each caused a real bug before
it was resolved. They are written up in
[`docs/architecture.md`](docs/architecture.md):

- **Signed arithmetic** — `-p00` on an unsigned 8-bit value wraps to `256-p00`,
  turning a negative kernel weight into a large positive contribution. Pixels
  are zero-extended to 12 bits (`{4'b0, pXX}`) and cast with `$signed()` before
  the weights apply; `<<<` preserves sign through the x2 terms.
- **Read-before-write in the line buffer** — blocking reads capture the old row
  values before the non-blocking writes land, or the window sees the current row
  where row N-2 should be.
- **ROM latency alignment** — `image_rom` is synchronous, so `valid`, `x`, and
  `y` are delayed one cycle to stay aligned with the returned pixel data.
- **Border gating** — the first two rows and columns cannot form a full window.
  `window_valid` is gated on `x_in >= 2 && y_in >= 2`, with centers offset by
  (-1,-1) for the shift-register depth. The resulting 2-pixel black border is
  imperceptible at 320-pixel width.

## Status and known gaps

The design synthesizes and implements cleanly in Vivado 2020.2 with all timing
constraints met, and the bitstream generates successfully. **An on-board video
demonstration was not captured** — the Zybo Z7-10 was returned to the department
before a recording could be made. Correctness rests on the four RTL testbenches,
the SystemC LT reference model, and the post-implementation reports.

The SystemC Loosely Timed model described in Section IV of the report is **not
in this repository** — it was not recovered with the Vivado project sources.

`sobel_video_core.v` currently has the framebuffer path commented out, with a
second `image_rom` instance feeding the display directly. That is a bring-up
configuration left over from the black-screen debug session: it shows the
*source* image rather than the edge map. `top_sobel_video_zybo.v` retains the
full framebuffer path. Restoring the commented block in `sobel_video_core.v` is
the one change needed for the HDMI top to display processed edges.

## Possible extensions

Live camera input over MIPI CSI-2; Gaussian pre-filtering to suppress noise;
non-maximum suppression for Canny-style edge thinning; 1080p output; AXI-Lite
runtime control of the threshold from the ARM core rather than slide switches.

## License

MIT — see [`LICENSE`](LICENSE). This covers the Verilog, scripts, and
documentation written by the authors.

It does **not** cover third-party material included for reproducibility:
`ip/rgb2dvi_0.xci` and `ip/clk_wiz_0.xci` are Vivado IP configurations, and the
`rgb2dvi` core itself is Digilent's, distributed under its own terms in the
[vivado-library](https://github.com/Digilent/vivado-library) repository.
`constraints/Zybo-Z7-Master.xdc` derives from Digilent's board master
constraints file.

## Authors

Matthew Margulies, Kyle Leng, Juan Miguel Constantino, Noah Luu
College of Engineering, California State University, Long Beach

## References

1. Digilent Inc., *Zybo Z7 Reference Manual*, Rev. B.
2. Digilent Inc., *rgb2dvi IP Core*, Vivado Library.
3. AMD/Xilinx, *Vivado Design Suite User Guide: Synthesis*, UG901, 2020.
4. AMD/Xilinx, *Clocking Wizard Product Guide*, PG065, 2019.
5. I. Sobel and G. Feldman, *A 3x3 Isotropic Gradient Operator for Image Processing*, Stanford AI Project, 1968.
6. Accellera Systems Initiative, *IEEE Std 1666-2011: SystemC Language Reference Manual*, 2012.
7. R. C. Gonzalez and R. E. Woods, *Digital Image Processing*, 4th ed., Pearson, 2018.
