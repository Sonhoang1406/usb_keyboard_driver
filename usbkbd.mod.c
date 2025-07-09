#include <linux/module.h>
#define INCLUDE_VERMAGIC
#include <linux/build-salt.h>
#include <linux/elfnote-lto.h>
#include <linux/export-internal.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

#ifdef CONFIG_UNWINDER_ORC
#include <asm/orc_header.h>
ORC_HEADER;
#endif

BUILD_SALT;
BUILD_LTO_INFO;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(".gnu.linkonce.this_module") = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif



static const struct modversion_info ____versions[]
__used __section("__versions") = {
	{ 0x37a0cba, "kfree" },
	{ 0x84cd9e22, "usb_submit_urb" },
	{ 0x6cbabeb1, "_dev_warn" },
	{ 0x34db050b, "_raw_spin_lock_irqsave" },
	{ 0xd35cce70, "_raw_spin_unlock_irqrestore" },
	{ 0x74bc459a, "usb_deregister" },
	{ 0x122c3a7e, "_printk" },
	{ 0x54b1fac6, "__ubsan_handle_load_invalid_value" },
	{ 0xf812cff6, "memscan" },
	{ 0x1735b994, "input_event" },
	{ 0x5981fc21, "_dev_err" },
	{ 0xb940ca68, "_dev_info" },
	{ 0xb88db70c, "kmalloc_caches" },
	{ 0x4454730e, "kmalloc_trace" },
	{ 0x8ee56139, "input_allocate_device" },
	{ 0xb8d6ea64, "usb_alloc_coherent" },
	{ 0x2ec9681e, "usb_alloc_urb" },
	{ 0x656e4a6e, "snprintf" },
	{ 0xa916b694, "strnlen" },
	{ 0x58e81630, "input_register_device" },
	{ 0x815c57ac, "input_free_device" },
	{ 0xcbd4898c, "fortify_panic" },
	{ 0xbdfb6dbb, "__fentry__" },
	{ 0x4523577f, "usb_register_driver" },
	{ 0x5b8239ca, "__x86_return_thunk" },
	{ 0x58a3832d, "usb_kill_urb" },
	{ 0xe1bd6f9b, "input_unregister_device" },
	{ 0x9fe19262, "usb_free_urb" },
	{ 0x2421d970, "usb_free_coherent" },
	{ 0x2fa5cadd, "module_layout" },
};

MODULE_INFO(depends, "");

MODULE_ALIAS("usb:v*p*d*dc*dsc*dp*ic03isc01ip01in*");

MODULE_INFO(srcversion, "BC5D03B09D13C206BF90069");
