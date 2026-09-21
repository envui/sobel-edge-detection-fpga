# Architecture

How a pixel travels from ROM to HDMI connector, and the four design decisions
that were not obvious.

## Pipeline stages

The processing domain runs at 125 MHz. After fill, one edge pixel is produced
per clock cycle.

| Stage | Module | Latency | What happens |
|---|---|---|---|
| 0 | `image_streamer` | 1 cycle | Emits `pixel_req_addr = y*IMG_W + x` plus `x`, `y`, and `pixel_req_valid`, scanning row-major across all 76,800 pixels |
| 1 | `image_rom` | 1 cycle | Synchronous BRAM read returns the 8-bit gray value |
| 1 | (top-level delay regs) | 1 cycle | `valid`, `x`, `y` are re-registered so they arrive with the ROM data, not ahead of it |
| 2 | `line_buffer_window` | 1 cycle | Shifts the pixel into the row-N register chain, retires old rows into the two line buffers, presents `p00..p22` |
| 3 | `sobel_core` | 1 cycle | Computes Gx, Gy, the Manhattan magnitude, and the threshold compare; registers `edge_pixel`, `x_out`, `y_out`, `edge_valid` |
| 4 | `simple_dual_port_ram` | 1 cycle | Writes `edge_pixel` at `edge_y*IMG_W + edge_x` |

Five cycles of fill, then steady-state throughput of one pixel per cycle. A
320x240 frame takes 76,800 / 125 MHz = **614.4 us**, roughly 27x faster than the
16.67 ms display frame period. The pipeline finishes a frame long before the
display needs it, which is why a single static frame works without any
back-pressure or handshaking.

`image_streamer` self-terminates when it reaches `(IMG_W-1, IMG_H-1)`, pulsing
`done`. The top level catches that pulse in a 4-deep shift register and latches
`frame_done`, which drives LED[0].

## The display domain

The display side runs at 25 MHz and is entirely independent of the processing
side. It free-runs from reset:

1. `video_timing_640x480` counts `hcnt` 0..799 and `vcnt` 0..524 — the standard
   VGA 640x480 @ 60 Hz timing (H: 640 active, 16 front porch, 96 sync, 48 back
   porch; V: 480 active, 10 front porch, 2 sync, 33 back porch). It emits
   active-low `hsync` and `vsync`, plus `de` and display coordinates `x`, `y`.
2. `display_mapper_2x` converts display coordinates to a source address by
   right-shifting each axis: `src_addr = (disp_y >> 1) * SRC_W + (disp_x >> 1)`.
   This is 2x nearest-neighbor upscaling — 320x240 fills the 640x480 screen,
   each source pixel becoming a 2x2 block. It is purely combinational, so it
   costs no latency and no registers.
3. `simple_dual_port_ram` returns the stored edge value on the `pix_clk` read
   port.
4. `rgb_gray` replicates that 8-bit value onto all three channels and forces
   black outside the active region: `r = g = b = de ? gray : 8'h00`. The
   blanking is required — driving color during the porches corrupts the sync
   that the monitor locks onto.

## Clock domain crossing

The two domains meet only at `simple_dual_port_ram`: `wr_clk`/`wr_en`/`wr_addr`
on the 125 MHz side, `rd_clk`/`rd_addr` on the 25 MHz side. No handshake, no
FIFO, no synchronizer chain.

That is safe *here* because of the access pattern, not because dual-port BRAM is
magically CDC-proof:

- The write side runs exactly once, finishing 614.4 us after reset.
- The read side then reads a static frame forever after.
- The only window where a read could catch a half-written location is during
  that first 614 us, and the visible consequence is a partial edge map on the
  very first displayed frame. Nothing hangs, nothing metastabilizes into control
  logic, because no control signal crosses the boundary — only data through
  BRAM.

**This assumption breaks the moment the source becomes live video.** A
continuously updating writer would need double-buffering (ping-pong between two
frame regions, swapped on `vsync`) or tearing becomes permanent and visible.

The clocks themselves come from one `clk_wiz_0` MMCM instance, so 25 MHz and
125 MHz are phase-related at an exact 5:1 ratio rather than genuinely
asynchronous — which is what makes the arrangement tolerable at all.

## Reset strategy

`rst_btn` (BTN0) is OR'd with the inverted PLL lock:

```verilog
assign rst = rst_btn | ~clk_locked;
```

The design stays in reset until the MMCM reports both output clocks stable and
phase-locked. Without this, the pipeline would start clocking on an unstable
clock during PLL acquisition, and `frame_done` could latch off garbage.

The reset is used synchronously inside every module (`if (rst)` inside
`always @(posedge clk)`), which is the preferred style for Xilinx 7-series —
the flip-flops have a synchronous reset input, so no extra logic is inferred.

## Design notes

Each of these was a real bug before it was a design decision.

### 1. Signed arithmetic

The Sobel kernels contain negative coefficients. In Verilog, `-p00` on an
unsigned 8-bit value does not produce a negative number — it wraps to
`256 - p00`, contributing a large *positive* value where a negative one was
intended. Gradients came out wrong in every direction.

The fix is explicit width extension and an explicit signed cast:

```verilog
reg signed [11:0] gx_calc, gy_calc;
reg        [12:0] mag_calc;

gx_calc = -$signed({4'b0,p00}) + $signed({4'b0,p02})
        - ($signed({4'b0,p10}) <<< 1) + ($signed({4'b0,p12}) <<< 1)
        - $signed({4'b0,p20}) + $signed({4'b0,p22});
```

Two details matter:

- **Zero-extend before casting.** `{4'b0, pXX}` widens the 8-bit pixel to 12
  bits with a guaranteed-zero top nibble, so `$signed()` on it is always a
  non-negative number. Casting the raw 8-bit value would make `0xFF` read as
  -1.
- **Use `<<<`, not `<<`.** The arithmetic left shift preserves the sign
  extension through the x2 kernel weights.

12 bits is the right width: the worst-case gradient is 4 x 255 = 1020, well
inside the +/-2047 range of a 12-bit signed value, and the magnitude sum needs
13 bits to hold up to 2040.

### 2. Read-before-write in the line buffer

`line_buffer_window` keeps two line buffers, `line1` (row N-1) and `line2`
(row N-2), and shifts each row through a 3-element register chain. At every
valid pixel it must both *read* the outgoing values and *write* the incoming
ones at the same address, `x_in`.

Ordering is everything:

```verilog
s_line1 = line1[x_in];        // blocking - capture old values FIRST
s_line2 = line2[x_in];

line2[x_in] <= line1[x_in];   // non-blocking - writes land at end of cycle
line1[x_in] <= pixel_in;

prv20 <= prv21; prv21 <= prv22; prv22 <= s_line2;   // row N-2 shift
prv0  <= prv1;  prv1  <= prv2;  prv2  <= s_line1;   // row N-1 shift
cur0  <= cur1;  cur1  <= cur2;  cur2  <= pixel_in;  // row N shift
```

The blocking assignments (`=`) execute immediately, capturing the values that
were in the buffers before this cycle's writes. The non-blocking assignments
(`<=`) all commit at the end of the cycle. Reverse the order — or make the
reads non-blocking — and the window sees the *current* row where rows N-1 and
N-2 belong, producing gradients that are mathematically valid but spatially
meaningless.

This read-before-write discipline is also exactly what Vivado recognizes as a
true dual-port BRAM pattern, so both line buffers infer into block RAM rather
than distributed LUT RAM.

### 3. ROM latency alignment

`image_rom` registers its output — the pixel arrives one cycle after the address
is presented. But `image_streamer` emits `x`, `y`, and `valid` in the same cycle
as the address. Left alone, coordinates run one pixel ahead of the data, and
every edge lands one position off.

The top level delays them to match:

```verilog
always @(posedge proc_clk_in) begin
    pix_valid_d <= str_valid;
    x_d         <= str_x;
    y_d         <= str_y;
end
```

`line_buffer_window` consumes the delayed versions, so data and coordinates
enter the window generator together.

### 4. Border gating

A 3x3 window needs one pixel of context on every side. The first two rows and
the first two columns cannot supply it — at those positions the line buffers
still hold their zero-initialized contents, and a real pixel against a field of
zeros looks like a maximum-strength edge. Left ungated, the output frame gets a
bright false border.

The window is gated instead:

```verilog
if ((x_in >= 2) && (y_in >= 2)) begin
    window_valid <= 1'b1;
    center_x     <= x_in - 1;
    center_y     <= y_in - 1;
end
```

The `-1` offset accounts for the shift-register depth: when pixel `(x, y)` is
shifted in, the fully-formed window is centered on `(x-1, y-1)`, because the
newest pixel occupies the bottom-right corner `p22`.

The cost is a 2-pixel black border on a 320-pixel-wide image — under 1% of the
width, and invisible once upscaled and displayed.

## HDMI output

Raw RGB, hsync, vsync, and DE cannot be wired to the HDMI connector. HDMI uses
**TMDS** (Transition-Minimized Differential Signaling): three differential data
pairs plus one differential clock pair, each carrying 8b/10b-encoded serialized
data.

Digilent's `rgb2dvi` IP handles the encoding and serialization. It takes the
24-bit parallel video bus plus sync signals at the pixel clock, and needs a
serial clock at 5x the pixel rate to clock out 10 bits per pixel per channel
through OLOGIC/OSERDES primitives:

```verilog
rgb2dvi_0 u_rgb2dvi (
    .TMDS_Clk_p (hdmi_tx_clk_p), .TMDS_Clk_n (hdmi_tx_clk_n),
    .TMDS_Data_p(hdmi_tx_p),     .TMDS_Data_n(hdmi_tx_n),
    .aRst       (rst),
    .vid_pData  ({vid_r, vid_g, vid_b}),
    .vid_pVDE   (vid_de),
    .vid_pHSync (vid_hsync), .vid_pVSync (vid_vsync),
    .PixelClk   (clk_pix),   .SerialClk  (clk_serial)
);
```

25 MHz pixel x 5 = 125 MHz serial, which is exactly the board oscillator
frequency — so `clk_wiz_0` produces both from one MMCM with no awkward ratios.

All four differential pairs are constrained `IOSTANDARD TMDS_33` in
`constraints/Zybo-Z7-Master.xdc`. Assigning them LVCMOS33 gets you a monitor
that reports "no signal" with no other diagnostic.

This is also where most of the design's logic sits: `rgb2dvi` uses 153 of the
233 total LUTs, against 80 for the entire Sobel pipeline.

## Bring-up: debugging a black screen

Worth recording because the method generalizes. The monitor synced to the HDMI
signal but displayed black — meaning clocks, TMDS, and timing were fine, and
something in the data path was wrong.

The display path was bisected with forced patterns:

1. **Forced white** (`vid_r = vid_g = vid_b = 8'hFF`) — screen went white. This
   cleared the clocking wizard, `rgb2dvi`, the TMDS pin constraints, and the
   monitor itself in one test.
2. **Gradient pattern** driven from `disp_x`/`disp_y` — displayed correctly,
   clearing `video_timing_640x480`, the DE blanking in `rgb_gray`, and the
   24-bit RGB bus.
3. Reconnecting the framebuffer read path brought the fault back, isolating it
   to address alignment in the display mapper.

Each step cut the suspect region roughly in half, and every stage cleared stayed
cleared. The LED-only top level preserved in `attic/` is from the earliest phase
of this same process — before HDMI was attached at all, `frame_done` on LED[0]
was the only evidence the pipeline ran.
