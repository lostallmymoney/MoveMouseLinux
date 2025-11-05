# mouseMoveUtility — Absolute Touch Pointer Daemon SystemCTL Service (Linux uinput)
One liner install : 
```bash
sudo apt install unzip wget -y && wget https://github.com/lostallmymoney/MoveMouseLinux/archive/refs/heads/main.zip -O MoveMouseLinux.zip && unzip -o MoveMouseLinux.zip && cd MoveMouseLinux-main && sh install.sh && cd .. && rm -rf MoveMouseLinux-main MoveMouseLinux.zip
```


DISCLAIMER : Relog for udev rules to apply !

Piping file is "/run/user/1000/mouseMoveUtility/mc.pipe", look at the usage section for details.

`mouseMoveUtility` is a tiny Wayland/X11–agnostic absolute pointer daemon that emulates
a touchscreen-like input device using **uinput**.  
It accepts normalized coordinates (`0.0` → `1.0`) via a FIFO pipe and taps the screen
at that location. Useful for UI automation, centered clicks, accessibility tools, bots,
games, and remote input. `0.5 0.5` would be the screen center.

✅ **Works without root after install**  
✅ **Wayland–compatible (no pointer lock tricks)**  
✅ **Precise absolute coordinates (`precision = 10000`)**  
✅ **Systemd service already included**

---

## Features

- Creates a virtual absolute pointer (`/dev/uinput`)
- Moves/taps at coordinates `(0..1, 0..1)`
- Automatically centers with `movetocenter`
- “Wiggles” the cursor by 1px to ensure motion is recognized

---

## Requirements

- Linux kernel with `uinput`
- `systemd`
- `g++`
- `/dev/uinput` available from kernel modules

---

## Installation

Clone the repository and run the installer as a **regular user**:

```sh
./install.sh
```

## Usage

Pipe commands into /run/user/1000/mouseMoveUtility/mc.pipe like this:
echo "movetocenter" > /run/user/1000/mouseMoveUtility/mc.pipe
echo "moveto 0.1 0.1" > /run/user/1000/mouseMoveUtility/mc.pipe

Example in C++:
#include <fcntl.h>
#include <unistd.h>
#include <cstring>

int main() {
    int fd = open("/run/user/1000/mouseMoveUtility/mc.pipe", O_WRONLY);
    const char* cmd = "movetocenter\n";
    write(fd, cmd, strlen(cmd));
    close(fd);
}
