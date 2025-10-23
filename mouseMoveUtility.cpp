#include <iostream>
#include <cstring>
#include <string>
#include <fcntl.h>
#include <linux/uinput.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <cstdlib>

// ============================================================================
// CONFIGURATION
// ============================================================================
static const int precision = 10000;

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================
static int write_event(int fd, __u16 type, __u16 code, __s32 value) {
    input_event ev{};
    ev.type  = type;
    ev.code  = code;
    ev.value = value;
    return write(fd, &ev, sizeof(ev));
}

static void move_to(int fd, int x, int y, bool wiggle = true) {
    // Touch down
    write_event(fd, EV_KEY, BTN_TOUCH, 1);
    write_event(fd, EV_ABS, ABS_X, x);
    write_event(fd, EV_ABS, ABS_Y, y);
    write_event(fd, EV_SYN, SYN_REPORT, 0);
    usleep(3000); // faster than 10ms, safe

    // Wiggle slightly
    if (wiggle) {
        write_event(fd, EV_ABS, ABS_X, x + 1);
        write_event(fd, EV_ABS, ABS_Y, y + 1);
        write_event(fd, EV_SYN, SYN_REPORT, 0);
    }

    // Release
    write_event(fd, EV_KEY, BTN_TOUCH, 0);
    write_event(fd, EV_SYN, SYN_REPORT, 0);
}

// ============================================================================
// UINPUT DEVICE CREATION
// ============================================================================
static int create_device() {
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        perror("open /dev/uinput");
        return -1;
    }

    ioctl(fd, UI_SET_EVBIT, EV_ABS);
    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    ioctl(fd, UI_SET_EVBIT, EV_SYN);

    ioctl(fd, UI_SET_ABSBIT, ABS_X);
    ioctl(fd, UI_SET_ABSBIT, ABS_Y);

    ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH);
    ioctl(fd, UI_SET_KEYBIT, BTN_LEFT);
    ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT);

    uinput_abs_setup absx{};
    absx.code = ABS_X;
    absx.absinfo.minimum = 0;
    absx.absinfo.maximum = precision;
    ioctl(fd, UI_ABS_SETUP, &absx);

    uinput_abs_setup absy{};
    absy.code = ABS_Y;
    absy.absinfo.minimum = 0;
    absy.absinfo.maximum = precision;
    ioctl(fd, UI_ABS_SETUP, &absy);

    uinput_setup us{};
    us.id.bustype = BUS_USB;
    us.id.vendor  = 0x1234;
    us.id.product = 0x5678;
    strncpy(us.name, "mouseMoveUtility absolute pointer", sizeof(us.name)-1);

    ioctl(fd, UI_DEV_SETUP, &us);
    if (ioctl(fd, UI_DEV_CREATE) < 0) {
        perror("UI_DEV_CREATE");
        close(fd);
        return -1;
    }

    usleep(300000);
    return fd;
}

// ============================================================================
// MAIN (PIPE/INTERACTIVE DAEMON)
// ============================================================================
int main(int argc, char *argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: mouseMoveUtility <fifo-path>\n";
        return 1;
    }

    const char *fifo_path = argv[1];

    int fd = create_device();
    if (fd < 0) {
        return 1;
    }

    std::cout << "mouseMoveUtility daemon ready\n";
    std::cout.flush();

    // Infinite processing loop
    while (true) {
        // Open FIFO for reading — blocks until a writer connects
        FILE *f = fopen(fifo_path, "r");
        if (!f) {
            perror("fopen fifo");
            usleep(500000); // wait 0.5s and retry
            continue;
        }

        char buf[256];
        // Read commands until writer closes (EOF)
        while (fgets(buf, sizeof(buf), f)) {

            // Trim newline
            buf[strcspn(buf, "\n")] = 0;

            if (strncmp(buf, "moveto", 6) == 0) {
                double nx = 0.0, ny = 0.0;

                // Parse floating point args
                if (sscanf(buf, "moveto %lf %lf", &nx, &ny) != 2) {
                    std::cout << "ERR moveto requires two floats 0..1\n";
                    std::cout.flush();
                    continue;
                }

                // Clamp
                if (nx < 0) nx = 0; else if (nx > 1) nx = 1;
                if (ny < 0) ny = 0; else if (ny > 1) ny = 1;

                int x = static_cast<int>(nx * precision);
                int y = static_cast<int>(ny * precision);

                move_to(fd, x, y, true);
                std::cout << "OK\n";
                std::cout.flush();
            }
            else if (strcmp(buf, "movetocenter") == 0) {
                int x = precision / 2;
                int y = precision / 2;

                move_to(fd, x, y, true);
                std::cout << "OK\n";
                std::cout.flush();
            }
            else if (strcmp(buf, "exit") == 0 || strcmp(buf, "quit") == 0) {
                fclose(f);
                goto shutdown;
            }
            else if (buf[0] != '\0') {
                std::cout << "ERR unknown command\n";
                std::cout.flush();
            }
        }

        // Writer closed FIFO — clean up and reopen
        fclose(f);
    }

shutdown:
    ioctl(fd, UI_DEV_DESTROY);
    close(fd);
    std::cout << "Goodbye.\n";
    return 0;
}
