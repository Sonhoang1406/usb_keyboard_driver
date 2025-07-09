#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>

#define KEY_A 30
#define KEY_B 48

int main() {
    const char *dev = "/dev/input/event5"; // Change to your event device number if different

    int fd = open(dev, O_RDWR);
    if (fd == -1) {
        perror("Cannot open device");
        exit(EXIT_FAILURE);
    }

    struct input_event ev;
    while (1) {
        if (read(fd, &ev, sizeof(struct input_event)) == -1) {
            perror("Failed to read device");
            exit(EXIT_FAILURE);
        }

        if (ev.type == EV_KEY && ev.code == KEY_A) {
            // Swap 'a' with 'b'
            if (ev.value == 0) {
                // Key release event, send 'b'
                ev.code = KEY_B;
                ev.value = 1; // Key press
                write(fd, &ev, sizeof(struct input_event));
                ev.value = 0; // Key release
                write(fd, &ev, sizeof(struct input_event));
            } else if (ev.value == 1) {
                // Key press event, send 'b'
                ev.code = KEY_B;
                write(fd, &ev, sizeof(struct input_event));
            }
        } else if (ev.type == EV_KEY && ev.code == KEY_B) {
            // Swap 'b' with 'a'
            if (ev.value == 0) {
                // Key release event, send 'a'
                ev.code = KEY_A;
                ev.value = 1; // Key press
                write(fd, &ev, sizeof(struct input_event));
                ev.value = 0; // Key release
                write(fd, &ev, sizeof(struct input_event));
            } else if (ev.value == 1) {
                // Key press event, send 'a'
                ev.code = KEY_A;
                write(fd, &ev, sizeof(struct input_event));
            }
        }

        // Exit when ESC is pressed
        if (ev.type == EV_KEY && ev.code == KEY_ESC && ev.value == 1) {
            break;
        }
    }

    close(fd);
    return 0;
}

