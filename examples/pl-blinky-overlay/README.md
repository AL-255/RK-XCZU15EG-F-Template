# Example: load a PL design from Linux and drive an AXI-GPIO

A worked example of the workflow in `docs/04-bitstream-from-ps.md`: take a
Vivado design that contains one **AXI-GPIO** (the one `hw/create_project.tcl`
instantiates as `axi_gpio_led` on the PS `M_AXI_HPM0_FPD` master), program it
from userspace, and toggle an LED — all without rebooting.

## 1. Build the design (once, on the host)

```bash
make hw MODE=all                 # -> build/hw/rk_xczu15eg_f.bit (+ .xsa)
scripts/bit2bin.sh build/hw/rk_xczu15eg_f.bit
# -> build/hw/rk_xczu15eg_f.bit.bin
```

(Or use the bundled golden bitstream `board/hw-handoff/IMAGE_15EG_wrapper.bit`
for a smoke test — convert it the same way.)

Copy the raw bitstream and this overlay to the board:

```bash
scp build/hw/rk_xczu15eg_f.bit.bin riguke@<ip>:/lib/firmware/
scp examples/pl-blinky-overlay/blinky-axi-gpio.dtso riguke@<ip>:/tmp/
```

## 2. Program + bind drivers (on the board)

The overlay both programs the fabric **and** declares the AXI-GPIO so Linux binds
the `gpio-xilinx` driver to it:

```bash
# point firmware-name at your bitstream, then apply:
sudo dtc -@ -I dts -O dtb -o /tmp/blinky.dtbo /tmp/blinky-axi-gpio.dtso
sudo mkdir -p /sys/kernel/config/device-tree/overlays/blinky
sudo cp /tmp/blinky.dtbo /sys/kernel/config/device-tree/overlays/blinky/dtbo

cat /sys/class/fpga_manager/fpga0/state          # operating
```

## 3. Toggle the LED

```bash
# find the new gpiochip the AXI-GPIO created
gpiodetect
gpioset $(gpiofind "" 2>/dev/null; gpiodetect | grep -m1 gpio | cut -d' ' -f1) 0=1
```

(or via sysfs / libgpiod, depending on your design's GPIO mapping).

## 4. Swap designs

```bash
sudo rmdir /sys/kernel/config/device-tree/overlays/blinky
sudo load-bitstream.sh /lib/firmware/another_design.bit.bin
```

> Addresses (`reg`) must match your Vivado address editor. The values in
> `blinky-axi-gpio.dtso` assume the AXI-GPIO is mapped at `0xA000_0000`
> (the default for an IP on `M_AXI_HPM0_FPD`); change it to whatever your build
> assigns.
