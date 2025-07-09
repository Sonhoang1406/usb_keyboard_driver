#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/module.h>
#include <linux/init.h>
#include <linux/usb/input.h>
#include <linux/hid.h>

#define DRIVER_VERSION "v1.0"
#define DRIVER_AUTHOR "Kma software developer"
#define DRIVER_DESC "USB HID Boot Protocol keyboard driver"
#define DRIVER_LICENSE "GPL"
#define USB_VENDOR_ID 0x0C45  // Vendor ID từ Hardware Ids
#define USB_PRODUCT_ID 0x760A // Product ID từ Hardware Ids
MODULE_AUTHOR(DRIVER_AUTHOR);
MODULE_DESCRIPTION(DRIVER_DESC);
MODULE_LICENSE(DRIVER_LICENSE);

static const unsigned char usb_kbd_keycode[256] = {
    0, 0, 0, 0, 30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38,
    50, 49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44, 2, 3,
    4, 5, 6, 7, 8, 9, 10, 11, 28, 1, 14, 15, 57, 12, 13, 26,
    27, 43, 43, 39, 40, 41, 51, 52, 53, 58, 59, 60, 61, 62, 63, 64,
    65, 66, 67, 68, 87, 88, 99, 70, 119, 110, 102, 104, 111, 107, 109, 106,
    105, 108, 103, 69, 98, 55, 74, 78, 96, 79, 80, 81, 75, 76, 77, 71,
    72, 73, 82, 83, 86, 127, 116, 117, 183, 184, 185, 186, 187, 188, 189, 190,
    191, 192, 193, 194, 134, 138, 130, 132, 128, 129, 131, 137, 133, 135, 136, 113,
    115, 114, 0, 0, 0, 121, 0, 89, 93, 124, 92, 94, 95, 0, 0, 0,
    122, 123, 90, 91, 85, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    29, 42, 56, 125, 97, 54, 100, 126, 164, 166, 165, 163, 161, 115, 114, 113,
    150, 158, 159, 128, 136, 177, 178, 176, 142, 152, 173, 140};

struct usb_kbd
{
    struct input_dev *dev;
    struct usb_device *usbdev;
    unsigned char old[8];
    struct urb *irq, *led;
    unsigned char newleds;
    char name[128];
    char phys[64];
    unsigned char *new;
    struct usb_ctrlrequest *cr;
    unsigned char *leds;
    dma_addr_t new_dma;
    dma_addr_t leds_dma;
    spinlock_t leds_lock;
    bool led_urb_submitted;
    bool mode;
};

static void usb_kbd_irq(struct urb *urb)
{
    struct usb_kbd *kbd = urb->context;
    int i;

    switch (urb->status)
    {
    case 0: /* success */
        break;
    case -ECONNRESET: /* unlink */
    case -ENOENT:
    case -ESHUTDOWN:
        return;
    default: /* error */
        goto resubmit;
    }

    for (i = 2; i < 8; i++)
    {
        if (kbd->new[i] > 3 && memscan(kbd->old + 2, kbd->new[i], 6) == kbd->old + 8)
        {
            unsigned char keycode = usb_kbd_keycode[kbd->new[i]];
            if (keycode == KEY_A)
                keycode = KEY_B;
            else if (keycode == KEY_B)
                keycode = KEY_A;

            if (keycode)
                input_report_key(kbd->dev, keycode, 1);
            else
                printk(KERN_INFO "usbkbd: Unknown key (scancode %#x) pressed.\n", kbd->new[i]);
        }
    }

    input_sync(kbd->dev);
    memcpy(kbd->old, kbd->new, 8);

resubmit:
    i = usb_submit_urb(urb, GFP_ATOMIC);
    if (i)
        hid_err(urb->dev, "can't resubmit intr, %s-%s/input0, status %d",
                kbd->usbdev->bus->bus_name,
                kbd->usbdev->devpath, i);
}

static int usb_kbd_event(struct input_dev *dev, unsigned int type, unsigned int code, int value)
{
    unsigned long flags;
    struct usb_kbd *kbd = input_get_drvdata(dev);

    if (type != EV_LED)
        return -1;

    spin_lock_irqsave(&kbd->leds_lock, flags);
    if (kbd->mode == 0)
    {
        if (((!!test_bit(LED_NUML, dev->led)) != (*(kbd->leds) & 1)) && ((!!test_bit(LED_CAPSL, dev->led)) == 0))
        {
            kbd->mode = 1;
            kbd->newleds = (!!test_bit(LED_KANA, dev->led) << 3) | (!!test_bit(LED_COMPOSE, dev->led) << 3) |
                           (!!test_bit(LED_SCROLLL, dev->led) << 2) | (1 << 1) |
                           (!!test_bit(LED_NUML, dev->led));
            printk("Now change to MODE 2.\n");
        }
        else
        {
            kbd->newleds = (!!test_bit(LED_KANA, dev->led) << 3) | (!!test_bit(LED_COMPOSE, dev->led) << 3) |
                           (!!test_bit(LED_SCROLLL, dev->led) << 2) | (!!test_bit(LED_CAPSL, dev->led) << 1) |
                           (!!test_bit(LED_NUML, dev->led));
        }
    }
    else
    {
        if ((!!test_bit(LED_NUML, dev->led)) != (*(kbd->leds) & 1))
        {
            kbd->mode = 0;
            kbd->newleds = (!!test_bit(LED_KANA, dev->led)
                            << 3) |
                           (!!test_bit(LED_COMPOSE, dev->led) << 3) |
                           (!!test_bit(LED_SCROLLL, dev->led) << 2) | (!!test_bit(LED_CAPSL, dev->led) << 1) |
                           (!!test_bit(LED_NUML, dev->led));
            printk("Now change to MODE 1.\n");
        }
        else
        {
            kbd->newleds = (!!test_bit(LED_KANA, dev->led) << 3) | (!!test_bit(LED_COMPOSE, dev->led) << 3) |
                           (!!test_bit(LED_SCROLLL, dev->led) << 2) | (1 << 1) |
                           (!!test_bit(LED_NUML, dev->led));
        }
    }

    if (kbd->newleds != *kbd->leds)
    {
        *kbd->leds = kbd->newleds;
        if (!kbd->led_urb_submitted)
        {
            kbd->led_urb_submitted = 1;
            usb_submit_urb(kbd->led, GFP_ATOMIC);
        }
    }
    spin_unlock_irqrestore(&kbd->leds_lock, flags);
    return 0;
}

static void usb_kbd_led(struct urb *urb)
{
    unsigned long flags;
    struct usb_kbd *kbd = urb->context;

    switch (urb->status)
    {
    case 0: /* success */
        break;
    case -ECONNRESET: /* unlink */
    case -ENOENT:
    case -ESHUTDOWN:
        return;
    default: /* error */
        printk(KERN_WARNING "usbkbd: led urb status %d received\n", urb->status);
        break;
    }

    spin_lock_irqsave(&kbd->leds_lock, flags);
    kbd->led_urb_submitted = 0;
    spin_unlock_irqrestore(&kbd->leds_lock, flags);
}

static int usb_kbd_open(struct input_dev *dev)
{
    struct usb_kbd *kbd = input_get_drvdata(dev);

    kbd->irq->dev = kbd->usbdev;
    if (usb_submit_urb(kbd->irq, GFP_KERNEL))
        return -EIO;

    return 0;
}

static void usb_kbd_close(struct input_dev *dev)
{
    struct usb_kbd *kbd = input_get_drvdata(dev);

    usb_kill_urb(kbd->irq);
}

static int usb_kbd_probe(struct usb_interface *iface, const struct usb_device_id *id)
{
    struct usb_device *dev = interface_to_usbdev(iface);
    struct usb_host_interface *interface = iface->cur_altsetting;
    struct usb_endpoint_descriptor *endpoint;
    struct usb_kbd *kbd;
    struct input_dev *input_dev;
    int pipe, maxp;
    int error = -ENOMEM;

    if (interface->desc.bNumEndpoints != 1)
        return -ENODEV;

    endpoint = &interface->endpoint[0].desc;
    if (!usb_endpoint_is_int_in(endpoint))
        return -ENODEV;

    pipe = usb_rcvintpipe(dev, endpoint->bEndpointAddress);
    maxp = usb_maxpacket(dev, pipe, 0);

    kbd = kzalloc(sizeof(struct usb_kbd), GFP_KERNEL);
    input_dev = input_allocate_device();
    if (!kbd || !input_dev)
        goto fail1;

    kbd->usbdev = dev;
    kbd->dev = input_dev;
    spin_lock_init(&kbd->leds_lock);

    if (!(kbd->new = usb_buffer_alloc(dev, 8, GFP_ATOMIC, &kbd->new_dma)))
        goto fail1;
    if (!(kbd->leds = usb_buffer_alloc(dev, 1, GFP_ATOMIC, &kbd->leds_dma)))
        goto fail2;

    kbd->irq = usb_alloc_urb(0, GFP_KERNEL);
    if (!kbd->irq)
        goto fail3;

    kbd->led = usb_alloc_urb(0, GFP_KERNEL);
    if (!kbd->led)
        goto fail4;

    kbd->cr = kmalloc(sizeof(struct usb_ctrlrequest), GFP_KERNEL);
    if (!kbd->cr)
        goto fail5;

    usb_fill_int_urb(kbd->irq, dev, pipe,
                     kbd->new, (maxp > 8 ? 8 : maxp),
                     usb_kbd_irq, kbd, endpoint->bInterval);
    kbd->irq->transfer_dma = kbd->new_dma;
    kbd->irq->transfer_flags |= URB_NO_TRANSFER_DMA_MAP;

    usb_fill_control_urb(kbd->led, dev, usb_sndctrlpipe(dev, 0),
                         (void *)kbd->cr, kbd->leds, 1,
                         usb_kbd_led, kbd);
    kbd->led->transfer_dma = kbd->leds_dma;
    kbd->led->transfer_flags |= URB_NO_TRANSFER_DMA_MAP;

    usb_make_path(dev, kbd->phys, sizeof(kbd->phys));
    strlcat(kbd->phys, "/input0", sizeof(kbd->phys));

    input_dev->name = "USB HIDBP Keyboard";
    input_dev->phys = kbd->phys;
    usb_to_input_id(dev, &input_dev->id);
    input_dev->dev.parent = &iface->dev;

    input_set_drvdata(input_dev, kbd);

    input_dev->evbit[0] = BIT_MASK(EV_KEY) | BIT_MASK(EV_LED) | BIT_MASK(EV_REP);
    input_dev->ledbit[0] = BIT_MASK(LED_NUML) | BIT_MASK(LED_CAPSL) | BIT_MASK(LED_SCROLLL) |
                           BIT_MASK(LED_COMPOSE) | BIT_MASK(LED_KANA);
    input_dev->keybit[BIT_WORD(KEY_ESC)] = BIT_MASK(KEY_ESC) | BIT_MASK(KEY_1) | BIT_MASK(KEY_2) |
                                           BIT_MASK(KEY_3) | BIT_MASK(KEY_4) | BIT_MASK(KEY_5) |
                                           BIT_MASK(KEY_6) | BIT_MASK(KEY_7) | BIT_MASK(KEY_8) |
                                           BIT_MASK(KEY_9) | BIT_MASK(KEY_0) | BIT_MASK(KEY_MINUS) |
                                           BIT_MASK(KEY_EQUAL) | BIT_MASK(KEY_BACKSPACE) | BIT_MASK(KEY_TAB) |
                                           BIT_MASK(KEY_Q) | BIT_MASK(KEY_W) | BIT_MASK(KEY_E) |
                                           BIT_MASK(KEY_R) | BIT_MASK(KEY_T) | BIT_MASK(KEY_Y) |
                                           BIT_MASK(KEY_U) | BIT_MASK(KEY_I) | BIT_MASK(KEY_O) |
                                           BIT_MASK(KEY_P) | BIT_MASK(KEY_LEFTBRACE) | BIT_MASK(KEY_RIGHTBRACE) |
                                           BIT_MASK(KEY_ENTER) | BIT_MASK(KEY_LEFTCTRL) | BIT_MASK(KEY_A) |
                                           BIT_MASK(KEY_S) | BIT_MASK(KEY_D) | BIT_MASK(KEY_F) |
                                           BIT_MASK(KEY_G) | BIT_MASK(KEY_H) | BIT_MASK(KEY_J) |
                                           BIT_MASK(KEY_K) | BIT_MASK(KEY_L) | BIT_MASK(KEY_SEMICOLON) |
                                           BIT_MASK(KEY_APOSTROPHE) | BIT_MASK(KEY_GRAVE) | BIT_MASK(KEY_LEFTSHIFT) |
                                           BIT_MASK(KEY_BACKSLASH) | BIT_MASK(KEY_Z) | BIT_MASK(KEY_X) |
                                           BIT_MASK(KEY_C) | BIT_MASK(KEY_V) | BIT_MASK(KEY_B) |
                                           BIT_MASK(KEY_N) | BIT_MASK(KEY_M) | BIT_MASK(KEY_COMMA) |
                                           BIT_MASK(KEY_DOT) | BIT_MASK(KEY_SLASH) | BIT_MASK(KEY_RIGHTSHIFT) |
                                           BIT_MASK(KEY_KPASTERISK) | BIT_MASK(KEY_LEFTALT) | BIT_MASK(KEY_SPACE) |
                                           BIT_MASK(KEY_CAPSLOCK) | BIT_MASK(KEY_F1) | BIT_MASK(KEY_F2) |
                                           BIT_MASK(KEY_F3) | BIT_MASK(KEY_F4) | BIT_MASK(KEY_F5) |
                                           BIT_MASK(KEY_F6) | BIT_MASK(KEY_F7) | BIT_MASK(KEY_F8) |
                                           BIT_MASK(KEY_F9) | BIT_MASK(KEY_F10) | BIT_MASK(KEY_NUMLOCK) |
                                           BIT_MASK(KEY_SCROLLLOCK) | BIT_MASK(KEY_KP7) | BIT_MASK(KEY_KP8) |
                                           BIT_MASK(KEY_KP9) | BIT_MASK(KEY_KPMINUS) | BIT_MASK(KEY_KP4) |
                                           BIT_MASK(KEY_KP5) | BIT_MASK(KEY_KP6) | BIT_MASK(KEY_KPPLUS) |
                                           BIT_MASK(KEY_KP1) | BIT_MASK(KEY_KP2) | BIT_MASK(KEY_KP3) |
                                           BIT_MASK(KEY_KP0) | BIT_MASK(KEY_KPDOT);

    input_dev->keybit[BIT_WORD(KEY_F11)] = BIT_MASK(KEY_F11) | BIT_MASK(KEY_F12) | BIT_MASK(KEY_RO) |
                                           BIT_MASK(KEY_KATAKANA) | BIT_MASK(KEY_YEN) | BIT_MASK(KEY_HENKAN) |
                                           BIT_MASK(KEY_MUHENKAN) | BIT_MASK(KEY_KPJPCOMMA) | BIT_MASK(KEY_KPENTER) |
                                           BIT_MASK(KEY_RIGHTCTRL) | BIT_MASK(KEY_KPSLASH) | BIT_MASK(KEY_SYSRQ) |
                                           BIT_MASK(KEY_RIGHTALT) | BIT_MASK(KEY_LINEFEED) | BIT_MASK(KEY_HOME) |
                                           BIT_MASK(KEY_UP) | BIT_MASK(KEY_PAGEUP) | BIT_MASK(KEY_LEFT) |
                                           BIT_MASK(KEY_RIGHT) | BIT_MASK(KEY_END) | BIT_MASK(KEY_DOWN) |
                                           BIT_MASK(KEY_PAGEDOWN) | BIT_MASK(KEY_INSERT) | BIT_MASK(KEY_DELETE) |
                                           BIT_MASK(KEY_MACRO) | BIT_MASK(KEY_MUTE) | BIT_MASK(KEY_VOLUMEDOWN) |
                                           BIT_MASK(KEY_VOLUMEUP) | BIT_MASK(KEY_POWER) | BIT_MASK(KEY_KPEQUAL) |
                                           BIT_MASK(KEY_KPPLUSMINUS) | BIT_MASK(KEY_PAUSE);

    input_dev->keybit[BIT_WORD(KEY_SCALE)] = BIT_MASK(KEY_SCALE);

    input_dev->open = usb_kbd_open;
    input_dev->close = usb_kbd_close;
    input_dev->event = usb_kbd_event;

    error = input_register_device(kbd->dev);
    if (error)
        goto fail6;

    usb_set_intfdata(iface, kbd);
    return 0;

fail6:
    kfree(kbd->cr);
fail5:
    usb_free_urb(kbd->led);
fail4:
    usb_free_urb(kbd->irq);
fail3:
    usb_buffer_free(dev, 1, kbd->leds, kbd->leds_dma);
fail2:
    usb_buffer_free(dev, 8, kbd->new, kbd->new_dma);
fail1:
    input_free_device(input_dev);
    kfree(kbd);
    return error;
}

static void usb_kbd_disconnect(struct usb_interface *intf)
{
    struct usb_kbd *kbd = usb_get_intfdata(intf);

    usb_set_intfdata(intf, NULL);
    if (kbd)
    {
        usb_kill_urb(kbd->irq);
        usb_kill_urb(kbd->led);
        input_unregister_device(kbd->dev);
        usb_free_urb(kbd->irq);
        usb_free_urb(kbd->led);
        usb_buffer_free(kbd->usbdev, 8, kbd->new, kbd->new_dma);
        usb_buffer_free(kbd->usbdev, 1, kbd->leds, kbd->leds_dma);
        kfree(kbd->cr);
        kfree(kbd);
    }
}

static const struct usb_device_id usb_kbd_id_table[] = {
    {USB_INTERFACE_INFO(USB_INTERFACE_CLASS_HID, USB_INTERFACE_SUBCLASS_BOOT, USB_INTERFACE_PROTOCOL_KEYBOARD)},
    {}};

MODULE_DEVICE_TABLE(usb, usb_kbd_id_table);

static struct usb_driver usb_kbd_driver = {
    .name = "usbkbd",
    .probe = usb_kbd_probe,
    .disconnect = usb_kbd_disconnect,
    .id_table = usb_kbd_id_table,
};

module_usb_driver(usb_kbd_driver);
