#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>

#define EVENT_DEV "/dev/input/event5" // Thay thế bằng số thiết bị sự kiện của bạn
#define KEY_K 37 // Key code for 'K'

int main() {
    int fd = open(EVENT_DEV, O_RDONLY);
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

        if (ev.type == EV_KEY && ev.code == KEY_K && ev.value == 1) {
            // K key pressed, exit the program
            printf("Exiting program...\n");
            break;
        }
    }

    close(fd);
    return 0;
}

