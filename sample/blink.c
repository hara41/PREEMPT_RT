/* blink.c - Blink an LED on BCM17 using libgpiod

   Build on Raspberry Pi:
     gcc -o blink blink.c $(pkg-config --cflags --libs libgpiod)
   Run:
     sudo ./blink
*/

#include <gpiod.h>
#include <stdio.h>
#include <unistd.h>

int main(void)
{
    const char *chipname = "gpiochip0";
    unsigned int line_num = 17; /* BCM17 */
    struct gpiod_chip *chip;
    struct gpiod_line *line;

    chip = gpiod_chip_open_by_name(chipname);
    if (!chip) {
        perror("gpiod_chip_open_by_name");
        return 1;
    }

    line = gpiod_chip_get_line(chip, line_num);
    if (!line) {
        perror("gpiod_chip_get_line");
        gpiod_chip_close(chip);
        return 1;
    }

    if (gpiod_line_request_output(line, "blink", 0) < 0) {
        perror("gpiod_line_request_output");
        gpiod_chip_close(chip);
        return 1;
    }

    for (int i = 0; i < 20; ++i) {
        gpiod_line_set_value(line, 1);
        usleep(200000);
        gpiod_line_set_value(line, 0);
        usleep(200000);
    }

    gpiod_line_release(line);
    gpiod_chip_close(chip);
    return 0;
}
