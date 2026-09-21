# Verification

Four testbenches in `sim/`, each sized small enough that expected output can be
checked by hand. All were run under Icarus Verilog 12.0 and Vivado 2020.2
behavioral simulation.

## Summary

| Testbench | DUT | Image size | Self-checking | Pass criterion |
|---|---|---|---|---|
| `tb_sobel_core` | `sobel_core` | standalone windows | yes | Flat patch gives `0x00`; vertical step gives `0xFF` |
| `tb_image_streamer` | `image_streamer` | 4x3 | yes | Exactly 12 valid requests, raster order |
| `tb_line_buffer_window` | `line_buffer_window` | 4x4 | **no — prints for inspection** | Window at center (2,2) reads `[10 11 12 / 20 21 22 / 30 31 32]` |
| `tb_top_small` | `top_sobel_video_zybo` | 8x8 | yes | `frame_done` / LED[0] asserts within 500 cycles |

Three testbenches fail loudly: they `$display("FAIL: ...")` and `$stop`. One
does not — see the caveat below.

## `tb_sobel_core`

Drives two hand-computed windows past the core with `threshold = 8'd50`.

**Test 1 — flat patch.** All nine pixels are `8'd10`. Both gradients cancel to
zero, so `mag = 0`, which is below threshold. Expects `edge_pixel == 8'h00`.
This catches sign-handling bugs immediately: if the unsigned-wrap bug is present,
a flat patch produces a large nonzero magnitude.

**Test 2 — vertical step.** The right column is `8'd255`, the rest `8'd0`:

```
  0   0  255
  0   0  255
  0   0  255
```

`Gx = -0 + 255 - 0 + 2*255 - 0 + 255 = 1020`, `Gy = 0` (the pattern is
vertically uniform). `mag = 1020`, far above threshold. Expects
`edge_pixel == 8'hFF`.

1020 is also the maximum possible gradient, which is what sets the 12-bit width
of `gx_calc`/`gy_calc` — it fits inside the +/-2047 signed range with margin.

Prints `PASS: sobel_core` at 75 ns.

## `tb_image_streamer`

Configures a 4x3 image, releases reset, and issues a single `start` pulse. It
then watches 20 clock cycles and counts every cycle where `pixel_req_valid` is
high, printing `addr`, `x`, and `y` for each.

Expected trace: `addr` increments 0 through 11, `x` cycles 0-3 within each row,
`y` increments once per row. The check is on the count — exactly `IMG_W * IMG_H`
= 12 requests. More means the streamer failed to terminate; fewer means it
stopped early or `start` was missed.

The printed addresses are the real value of this test: they confirm row-major
ordering and that `addr == y*IMG_W + x` holds throughout.

Prints `PASS: image_streamer` at 235 ns.

## `tb_line_buffer_window`

Feeds a 4x4 image where each pixel encodes its own position — row 0 is
`0,1,2,3`, row 1 is `10,11,12,13`, row 2 is `20,21,22,23`, row 3 is
`30,31,32,33`. Any window can therefore be verified by reading the digits: the
tens digit is the source row, the ones digit the column.

After all 16 pixels are streamed, it prints every window where `window_valid` is
high. The window centered on (2,2) should read:

```
center=(2,2)
10 11 12
20 21 22
30 31 32
```

which is exactly rows 1-3, columns 0-2 — the correct 3x3 neighborhood. This is
the test that validates the read-before-write ordering described in
[`architecture.md`](architecture.md). Get that ordering wrong and the top row
comes back as `20 21 22` or `30 31 32` instead of `10 11 12`.

> **Caveat: this testbench does not self-check.** It prints windows and ends
> with `INFO: inspect printed windows for correctness`, then `$finish` — it
> never calls `$stop`, so it "passes" regardless of what the window contains.
> A regression in `line_buffer_window` would not be caught automatically. Adding
> an explicit comparison against the expected `(2,2)` window is the highest-value
> improvement available to this test suite.

## `tb_top_small`

An integration test over the whole pipeline. It instantiates
`top_sobel_video_zybo` re-parameterized down to an 8x8 image (`ADDR_W=6`,
`XY_W=4`) backed by `image_small.mem` — four black columns followed by four
white columns, repeated for eight rows, giving one strong vertical edge down the
middle.

`sw` is held at `4'h4`, so `threshold = 8'h44` = 68.

After reset it waits 500 processing clock cycles and checks that `led[0]`
(`frame_done`) has asserted. That single bit transitively exercises a lot: the
streamer must have run to completion and pulsed `done`, the 4-deep `done_pipe`
shift register must have propagated it, and the latch must have held. The
waveform also shows `vid_de` pulsing over the active region and `vid_pclk`
running at one fifth of `proc_clk_in` from `clock_div_5`.

Note that the 8x8 image is mostly border — with `x >= 2 && y >= 2` gating, only
a 6x6 region produces windows. The test verifies frame completion and video
timing, not edge-map contents.

Prints `PASS: top_small`.

## Running

```bash
cd sim
make            # all four
make sobel      # tb_sobel_core
make streamer   # tb_image_streamer
make window     # tb_line_buffer_window
make top        # tb_top_small
make clean
```

The Makefile copies `data/image_small.mem` into the simulation directory before
running `tb_top_small`, because `$readmemh` resolves relative to the simulator's
working directory.

In Vivado, set the simulation top in the Sources window (Simulation Sources set
`sim_1`) and run Behavioral Simulation. Results appear in the Tcl Console.

## What is not covered

- **No full-frame golden-image comparison.** Nothing verifies the 320x240 output
  against a reference edge map. A Python or C model producing an expected
  `.mem`, compared against a simulation dump, would close this gap.
- **No timing simulation.** All four are behavioral only. Post-implementation
  timing simulation was not run — static timing analysis in Vivado is the only
  timing evidence.
- **No HDMI/TMDS verification.** `rgb2dvi` is a black box in simulation; its
  serialization was never exercised outside hardware.
- **Threshold sweep untested.** Only `sw = 0x4` appears in any testbench. The
  extremes (`0x0`, `0xF`) were exercised only on hardware.
- **CDC behavior unverified.** The dual-clock framebuffer is never simulated
  with the two clocks at their real 5:1 ratio under contention.

## Supporting evidence

Beyond simulation, correctness rests on:

- **SystemC LT model** (described in Section IV of the report, not present in
  this repository) — an independent C++ implementation of the same algorithm
  that reported 1,152 edge pixels on a synthetic 320x240 checkerboard, 1.50% of
  the frame, with all 76,800 pixels written.
- **Post-implementation reports** — Vivado 2020.2 met all timing constraints and
  generated a bitstream. Utilization: 233 LUTs (1.3%), 246 registers (0.7%),
  97 slices (2.2%), 16 BRAM tiles (26.7%), 8 OLOGIC, 0 DSP.

An on-board video capture was not made; the board was returned before recording.
