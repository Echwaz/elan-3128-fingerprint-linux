# ELAN7001 / eFSA80SC (`04f3:3128`) Fingerprint Driver for Linux (CachyOS / Arch / Ubuntu / Fedora)

Working press-type fingerprint driver and hybrid matcher (`Rotated-ZNCC + SIFT-RANSAC`) for the **ELAN SPI fingerprint sensor (`acpi:ELAN7001:`, `eFSA80SC` 80×80)** paired with **touchpad I2C-HID `04f3:3128`**, found in the **ASUS VivoBook X421EQY / K413EQ** and related VivoBook models.

---

## Why Stock `libfprint` (and Standard `sigfm`) Fails on `04f3:3128`

1. **Press vs. Swipe State Machine Mismatch (`elanspi.c`)**:
   Although the physical sensor in the touchpad corner is a small square **press** sensor (`80×80` pixels, ~4×4 mm), upstream `elanspi` treats it as a 43-pixel-high swipe sensor, discarding stationary frames (`difference < ELANSPI_MIN_FRAME_TO_FRAME_DIFF`) and requiring 8+ moving frames before finger lift.
2. **State Machine Race Condition Between `WAITUP` and `fpi-image-device`**:
   Submitting frames or reporting `finger_status = FALSE` before completing the capture SSM overwrites `self->capturing = FALSE` across stages, leaving a zombie SSM on stage 8 that collides with subsequent `fprintd-verify` calls.
3. **50/60 Hz AC Mains Hum Banding on Capacitive Row Readout**:
   Reading 80 rows over ~20 ms couples 1–2 cycles of 50/60 Hz AC mains hum across rows, creating random horizontal bands that corrupt raw SIFT keypoints.
4. **Matcher Failure on 80×80 Sensors**:
   Both NBIS (`bozorth3`) and stock `sigfm` fail to discriminate or match 80×80 press captures reliably (stock `sigfm` scores `0` on genuine pairs due to `cv::Point2i` integer truncation on 80×80 grids and `asin(>1.0) = NaN`).

---

## What This Driver Fixes

- **Native 80×80 Multi-Frame Press Capture**:
  Captures a fast 5-frame press burst (~0.11s) without requiring finger movement, selects the sharpest frame using row-dehummed ridge variance, and averages aligned frames ($r \ge 0.80$) to suppress thermal/capacitive noise.
- **50/60 Hz Row De-Humming & Bandpass Ridge/Pore Enhancement**:
  Removes row/column common-mode interference, applies a ridge-tuned DoG bandpass filter ($\sigma \in [0.8, 5.0]$), and normalizes local variance.
- **Hybrid Dual-Generator Matcher (Coarse-to-Fine Rotated ZNCC + SIFT-RANSAC Pose Verification)**:
  Combines 2D rotated normalized cross-correlation ($\pm 28^\circ$) with geometrically verified SIFT/pore keypoint inliers (position, scale, and orientation consistency).
- **Clean Background Calibration Cache (`/var/lib/fprint/elanspi_calib.bin`)**:
  Prevents calibration corruption when a finger is already resting on the sensor as `fprintd-verify` or `sudo` starts.
- **Automatic OpenCV 4 & OpenCV 5 Support**:
  Works out of the box on both rolling-release distros (CachyOS / Arch with OpenCV 5) and Ubuntu/Debian/Fedora (OpenCV 4).

---

## Quick Install (English)

Confirm your hardware matches (`spi-ELAN7001:00` and touchpad HID `04F3:3128`):

```bash
ls /sys/bus/spi/devices/ | grep -i elan
grep -i '^HID_ID' /sys/bus/hid/devices/*/uevent 2>/dev/null | grep -i 04F3
```

Run the automated installer:

```bash
git clone https://github.com/YOUR_USERNAME/elan-3128-fingerprint-linux.git
cd elan-3128-fingerprint-linux
chmod +x install.sh
./install.sh
```

Then enroll (8 quick presses — touch for ~0.2s and lift your finger each time) and verify:

```bash
fprintd-delete "$USER"
fprintd-enroll -f right-index-finger
fprintd-verify
```

---

## Panduan Singkat (Bahasa Indonesia)

Repositori ini menyediakan driver `libfprint` khusus untuk sensor sidik jari **ELAN7001 / eFSA80SC (80×80 SPI)** dengan touchpad **I2C-HID `04f3:3128`** (ASUS VivoBook X421EQY / K413EQ) di CachyOS, Arch Linux, Ubuntu/Debian, dan Fedora.

### Cara Pasang:
```bash
git clone https://github.com/USERNAME_ANDA/elan-3128-fingerprint-linux.git
cd elan-3128-fingerprint-linux
chmod +x install.sh
./install.sh
```

### Cara Daftar & Uji Sidik Jari:
Tempelkan jari dengan tenang selama ~0,2 detik lalu **angkat jari Anda** pada setiap tahap (8 kali):
```bash
fprintd-delete "$USER"
fprintd-enroll -f right-index-finger
fprintd-verify
```

---

## Credits & License
- Based on [`mincrmatt12/elan-spi-fingerprint`](https://github.com/mincrmatt12/elan-spi-fingerprint), [`goodix-fp-linux-dev/libfprint`](https://github.com/goodix-fp-linux-dev/libfprint) (`sigfm` branch), and [`matemiller/elan-3104-fingerprint-linux`](https://github.com/matemiller/elan-3104-fingerprint-linux).
- Distributed under **LGPL-2.1-or-later** (see [`LICENSE`](LICENSE)).
