# Module reference

Port-level detail for every module in `rtl/`. Common parameters:

| Parameter | Default | Meaning |
|---|---|---|
| `IMG_W`, `IMG_H` | 320, 240 | Source image dimensions |
| `DATA_W` | 8 | Pixel width in bits (grayscale) |
| `ADDR_W` | 17 | Address width; must hold `IMG_W*IMG_H` (76,800 needs 17 bits) |
| `XY_W` | 10 | Coordinate width; must hold `max(IMG_W, IMG_H)` |
| `MEM_FILE` | `"image.mem"` | Hex file loaded by `$readmemh` |

All four testbenches re-parameterize these down to small values, so keep any new
module fully parameterized rather than hardcoding 320/240.

---

## `image_streamer.v`

Raster-scan address generator. One pixel request per clock.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Processing clock and synchronous reset |
| `start` | in | 1 | Single-cycle pulse begins a scan |
| `busy` | out | 1 | High for the duration of the scan |
| `pixel_req_valid` | out | 1 | Address/coordinates valid this cycle |
| `pixel_req_addr` | out | `ADDR_W` | `y*IMG_W + x` |
| `pixel_req_x`, `_y` | out | `XY_W` | Current coordinates |
| `done` | out | 1 | Single-cycle pulse at end of frame |

`start` is ignored while `running` is set, so a held-high `start` will not
restart a scan mid-frame. The top level generates exactly one pulse by
registering `rst`:

```verilog
always @(posedge proc_clk_in)
    start_stream <= rst ? 1'b1 : 1'b0;
```

This fires the scan once on reset release. There is no mechanism to re-trigger
a scan afterwards without another reset — adequate for a static frame, and the
first thing to change for live video.

---

## `image_rom.v`

Synchronous single-port ROM initialized from a hex file.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Read clock |
| `addr` | in | `ADDR_W` | Read address |
| `dout` | out | `DATA_W` | Pixel data, valid one cycle after `addr` |

Memory is zero-filled in an `initial` block before `$readmemh(MEM_FILE, mem)`,
so a short or missing memory file leaves black pixels rather than X's — which
keeps simulation interpretable when the file path is wrong.

Out-of-range addresses return zero. **Output is registered**, so consumers must
account for the one-cycle latency; the top levels do this by delaying `valid`,
`x`, and `y` to match.

---

## `line_buffer_window.v`

Converts a raster pixel stream into a sliding 3x3 window.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock and synchronous reset |
| `pixel_valid_in` | in | 1 | Input pixel valid |
| `pixel_in` | in | `DATA_W` | Incoming pixel |
| `x_in`, `y_in` | in | `XY_W` | Coordinates of `pixel_in` |
| `window_valid` | out | 1 | A complete 3x3 window is present |
| `center_x`, `center_y` | out | `XY_W` | Coordinates of the window center |
| `p00`..`p22` | out | `DATA_W` | The 3x3 neighborhood |

Two line buffers (`line1` = row N-1, `line2` = row N-2) sized `IMG_W`, plus
three 3-element register chains. Storage is 2 x `IMG_W` bytes regardless of
image height — the reason a line-buffer architecture is used instead of holding
whole rows.

Window orientation: `p00 p01 p02` is the **oldest** row (N-2), `p20 p21 p22` the
newest (N). The incoming pixel lands in `p22`, which is why the center trails by
(-1,-1).

`window_valid` is gated on `x_in >= 2 && y_in >= 2`. See
[`architecture.md`](architecture.md) for the read-before-write ordering that the
shift logic depends on.

---

## `sobel_core.v`

Gradient computation and thresholding. One window in, one edge pixel out, one
cycle of latency.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst` | in | 1 | Clock and synchronous reset |
| `window_valid` | in | 1 | Window inputs valid |
| `x_in`, `y_in` | in | `XY_W` | Window center coordinates |
| `p00`..`p22` | in | `DATA_W` | The 3x3 neighborhood |
| `threshold` | in | 8 | Edge threshold, `{sw, sw}` from the top level |
| `edge_valid` | out | 1 | Output valid |
| `x_out`, `y_out` | out | `XY_W` | Coordinates, passed through |
| `edge_pixel` | out | 8 | `0xFF` for edge, `0x00` otherwise |

Internals are `reg signed [11:0] gx_calc, gy_calc` and `reg [12:0] mag_calc`,
all assigned with blocking assignments inside the clocked block — they are
combinational intermediates, not state, and only the outputs are registered.

Purely additive: no multipliers, no DSP slices. The x2 weights are arithmetic
left shifts.

---

## `simple_dual_port_ram.v`

Simple dual-port RAM: one write port, one read port, independent clocks. Serves
as the edge-map framebuffer and the only crossing between clock domains.

| Port | Dir | Width | Description |
|---|---|---|---|
| `wr_clk`, `wr_en` | in | 1 | Write clock and enable |
| `wr_addr` | in | `ADDR_W` | Write address |
| `wr_data` | in | `DATA_W` | Write data |
| `rd_clk` | in | 1 | Read clock |
| `rd_addr` | in | `ADDR_W` | Read address |
| `rd_data` | out | `DATA_W` | Read data, one cycle after `rd_addr` |

`DEPTH` defaults to 76,800. Both ports bounds-check their address. At 320x240x8
this infers roughly 16 BRAM tiles — the dominant resource in the design.

There is no synchronization between the ports. That is safe only under this
design's write-once-then-read-forever pattern; see the CDC section of
[`architecture.md`](architecture.md).

---

## `video_timing_640x480.v`

VGA 640x480 @ 60 Hz timing generator. Runs at 25 MHz.

| Port | Dir | Width | Description |
|---|---|---|---|
| `pix_clk`, `rst` | in | 1 | Pixel clock and synchronous reset |
| `hsync`, `vsync` | out | 1 | Sync pulses, **active low** |
| `de` | out | 1 | Data enable — high during active video |
| `x` | out | 11 | Display column, 0 outside active region |
| `y` | out | 10 | Display row, 0 outside active region |

```
Horizontal: 640 active + 16 front + 96 sync + 48 back = 800 total
Vertical:   480 active + 10 front +  2 sync + 33 back = 525 total
25 MHz / (800 x 525) = 59.52 Hz
```

All outputs are registered, so they lag the internal counters by one cycle —
consistent across `de`, `x`, `y`, and both syncs, so the relative alignment the
downstream path sees is correct.

---

## `display_mapper_2x.v`

Purely combinational 2x nearest-neighbor upscale.

| Port | Dir | Width | Description |
|---|---|---|---|
| `disp_x`, `disp_y` | in | `XY_W` | Display coordinates |
| `src_addr` | out | `ADDR_W` | Source framebuffer address |

```verilog
assign src_addr = (disp_y >> 1) * SRC_W + (disp_x >> 1);
```

Each source pixel becomes a 2x2 block, mapping 320x240 onto 640x480 exactly. The
shift is free in hardware; the multiply by `SRC_W` synthesizes into a small
constant-coefficient adder tree since `SRC_W` is a parameter.

Only viable for integer scale factors that are powers of two. Non-power-of-two
scaling would need an accumulator or a divider.

---

## `rgb_gray.v`

Combinational grayscale-to-RGB expansion with blanking.

| Port | Dir | Width | Description |
|---|---|---|---|
| `gray` | in | 8 | Grayscale value |
| `de` | in | 1 | Data enable |
| `r`, `g`, `b` | out | 8 | Equal RGB channels, forced to 0 when `de` is low |

The blanking is not cosmetic — driving non-zero color during the porch and sync
intervals corrupts the signal the monitor locks onto.

---

## `sobel_video_core.v`

Integrates the processing pipeline and the display path. Dual-clock.

| Port | Dir | Width | Description |
|---|---|---|---|
| `proc_clk_in` | in | 1 | 125 MHz processing clock |
| `pix_clk_in` | in | 1 | 25 MHz pixel clock |
| `rst_btn` | in | 1 | Reset |
| `sw` | in | 4 | Threshold switches |
| `led` | out | 4 | Status LEDs |
| `vid_hsync`, `vid_vsync`, `vid_de` | out | 1 | Video sync signals |
| `vid_r`, `vid_g`, `vid_b` | out | 8 | 24-bit RGB |
| `vid_pclk` | out | 1 | Pixel clock passthrough |

The display path reads from the framebuffer: `display_mapper_2x` generates
`fb_rd_addr` from the video timing coordinates, `simple_dual_port_ram` returns
the stored edge value on `pix_clk_in`, and `rgb_gray` expands it to RGB. This
wiring is identical to `top_sobel_video_zybo.v`, which `tb_top_small` exercises.

> **History:** this module previously had the framebuffer commented out, with a
> second `image_rom` feeding the display directly — a bring-up configuration
> that displayed the source image rather than the edge map. That is the
> configuration the report's synthesis results were measured on. See the git
> history for the original.

---

## `top_hdmi_zybo.v`

**Board top level.** This is what gets synthesized.

| Port | Dir | Width | Pin | Description |
|---|---|---|---|---|
| `proc_clk_in` | in | 1 | K17 | 125 MHz system clock |
| `rst_btn` | in | 1 | K18 | BTN0 reset |
| `sw` | in | 4 | G15 P15 W13 T16 | Threshold switches |
| `led` | out | 4 | M14 M15 G14 D18 | Status LEDs |
| `hdmi_tx_clk_p/n` | out | 1 | H16 / H17 | TMDS clock pair |
| `hdmi_tx_p/n` | out | 3 | D19/D20, C20/B20, B19/A20 | TMDS data pairs |

Instantiates `clk_wiz_0` (25 MHz pixel + 125 MHz serial from the 125 MHz input),
`sobel_video_core`, and `rgb2dvi_0`. Holds reset until the MMCM locks:

```verilog
assign rst = rst_btn | ~clk_locked;
```

RGB is packed `{vid_r, vid_g, vid_b}` into the 24-bit `vid_pData` bus.

---

## `top_sobel_video_zybo.v`

**Simulation top level.** Same pipeline, no vendor IP — `clock_div_5` replaces
the clocking wizard and raw video signals replace TMDS pairs. Driven by
`tb_top_small`.

Unlike `sobel_video_core.v`, this one wires the full framebuffer path:
`sobel_core` writes to `simple_dual_port_ram`, which `display_mapper_2x` reads
through to `rgb_gray`. It is the reference for correct integration.

Do not synthesize it. `clock_div_5` generates a clock from fabric logic rather
than a clock-management tile, so it never reaches a global clock buffer.

---

## `clock_div_5.v`

Divide-by-5 clock divider. Simulation only.

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk_in`, `rst` | in | 1 | Input clock, synchronous reset |
| `clk_out` | out | 1 | `clk_in` / 5 |

Counts to 4 and toggles. Strictly speaking this is a divide-by-10 in period
terms — it toggles every 5 input cycles, so a 125 MHz input yields 12.5 MHz, not
25 MHz. That discrepancy does not affect `tb_top_small`, which only checks frame
completion and that `vid_de` pulses, but it is worth knowing if this module is
ever reused for timing-sensitive simulation.

On real hardware this role belongs to `clk_wiz_0`.
