#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>

#define EVENT_DEV "/dev/input/event5" // Thay thế bằng số thiết bị sự kiện của bạn
#define KEY_D 32 // Key code for 'D'

void send_led_event(int fd, int led_code, int led_state) {
    struct input_event ev;

    ev.type = EV_LED;
    ev.code = led_code;
    ev.value = led_state;

    if (write(fd, &ev, sizeof(struct input_event)) == -1) {
        perror("Failed to write LED event");
        exit(EXIT_FAILURE);
    }
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

        if (ev.type == EV_KEY && ev.code == KEY_D && ev.value == 1) {
            // D key pressed, toggle LED state (example with NUMLOCK LED)
            printf("Toggling NUMLOCK LED...\n");
            send_led_event(fd, LED_NUML, 1); // Turn NUMLOCK LED on
            sleep(1); // Wait for a moment
            send_led_event(fd, LED_NUML, 0); // Turn NUMLOCK LED off
        }
    }

    close(fd);
    return 0;
}

