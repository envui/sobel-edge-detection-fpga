# attic

Superseded files kept for reference. Nothing here is built or simulated.

## `top_sobel_video_zybo_ledtest_backup.v`

The earliest bring-up top level, from before HDMI was attached. It exposes only
the LED outputs, so the only evidence the pipeline ran was `frame_done` lighting
LED[0] roughly 614 us after reset.

It is preserved because it is the minimal reproduction of the processing path:
streamer, ROM, line buffer, Sobel core, framebuffer, with no video timing and no
TMDS encoding. If the pipeline ever needs isolating from the display path again,
start here rather than reconstructing it.

Superseded by `rtl/top_sobel_video_zybo.v` (simulation) and
`rtl/top_hdmi_zybo.v` (board).
