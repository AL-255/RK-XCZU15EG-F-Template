# Golden hardware hand-off

These files are the **known-good factory hardware definition** for the
RK-XCZU15EG-F. They let you build the device tree and boot chain immediately,
without re-running Vivado synthesis/implementation, and serve as a reference for
any design you create yourself.

| file | what it is |
|------|------------|
| `IMAGE_15EG.xsa` | hardware hand-off (the `.hwh` block-design description + metadata). Consumed by `gen_devicetree.sh` (XSCT) and `build_fsbl_pmufw.sh`. |
| `IMAGE_15EG_wrapper.bit` | the factory PL bitstream — a **golden reference** design (includes the EMIO LEDs/keys and the `gmii_to_rgmii` second-Ethernet core that the device tree's `phy1`/EMIO nodes assume). Convert with `scripts/bit2bin.sh` to test PS-side loading. |
| `IMAGE_15EG_wrapper.mmi` | BRAM memory-map info for the bitstream. |
| `psu_init_gpl.c` / `.h` | the PS initialisation (DDR4, MIO, clocks) in source form — what the FSBL applies. |
| `psu_init.tcl` | the same PS init as a Tcl script. |

## Provenance & versions

This hand-off was extracted from the vendor factory PetaLinux BSP
(`image_15eg.bsp`) and was generated with **Vivado/Vitis 2020.2**. The rest of
this template builds against **2025.2**; the 2020.2 `.hwh` is forward-compatible
with the 2025.2 device-tree generator and FSBL flow (verified — the device tree
and `BOOT.BIN` in this template were built from exactly this XSA).

## Regenerating from scratch

To produce a fresh hand-off from your own design instead of using the factory
one:

```bash
make hw MODE=all                       # -> build/hw/rk_xczu15eg_f.xsa (+ .bit)
make devicetree XSA=build/hw/rk_xczu15eg_f.xsa
make boot
```

The factory bitstream/XSA remain here as a fallback and a behavioural reference
(e.g. confirming the EMIO LED/key wiring matches `system-user.dtsi`).
