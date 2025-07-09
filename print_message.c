#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>

#define EVENT_DEV "/dev/input/event5" // Thay thế bằng số thiết bị sự kiện của bạn
#define KEY_U 22 // Key code for 'U'

void print_message() {
    printf("Toi Yeu Driver\n");
}

int main() {
    int fd = open(EVENT_DEV, O_RDWR);
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

        if (ev.type == EV_KEY && ev.code == KEY_U && ev.value == 1) {
            // U key pressed, print message
            print_message();
        }
    }

    close(fd);
    return 0;
}

