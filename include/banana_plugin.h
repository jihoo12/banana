/*
 * Banana plugin interface.
 *
 * A plugin is a shared library that Banana loads with dlopen(). It must export
 * banana_plugin_init; every other entry point is optional. Banana calls
 * plugins from its main thread only, and never concurrently.
 *
 *     cc -shared -fPIC -I include my_plugin.c -o my_plugin.so
 *
 * Load it from ~/.config/banana/banana.conf:
 *
 *     plugin = my_plugin              # ~/.config/banana/plugins/my_plugin.so
 *     plugin = /abs/path/x.so arg     # text after the path is passed to init
 */
#ifndef BANANA_PLUGIN_H
#define BANANA_PLUGIN_H

#include <stdint.h>

#define BANANA_PLUGIN_ABI 1

/* GLFW modifier bits passed to banana_plugin_key. */
#define BANANA_MOD_SHIFT 1
#define BANANA_MOD_CONTROL 2
#define BANANA_MOD_ALT 4
#define BANANA_MOD_SUPER 8

/*
 * Services Banana offers a plugin. The table and `ctx` stay valid until
 * banana_plugin_destroy returns, so a plugin may keep the pointer. Calls are
 * queued and applied after the plugin's entry point returns.
 */
typedef struct BananaHost {
    uint32_t abi;  /* BANANA_PLUGIN_ABI */
    uint32_t reserved;
    void *ctx;     /* Pass back as the first argument of every call. */
    /* Writes bytes to the shell, as if typed. */
    void (*send)(void *ctx, const char *bytes, int64_t length);
    /* Shows bytes in the terminal, as if the shell printed them. */
    void (*feed)(void *ctx, const char *bytes, int64_t length);
    /* Sets this plugin's status bar segment (UTF-8, NUL-terminated); "" hides it. */
    void (*set_status)(void *ctx, const char *text);
    /* Writes a line to Banana's standard error, prefixed with the plugin name. */
    void (*log)(void *ctx, const char *text);
    /* Sets iParam[index] (0..7) in every post-processing shader. */
    void (*set_param)(void *ctx, int32_t index, float value);
    /* Asks for another frame even when the terminal has not changed. */
    void (*request_redraw)(void *ctx);
} BananaHost;

/* Returns 0 on success and may store a state pointer passed to every hook. */
int32_t banana_plugin_init(const BananaHost *host, const char *args, void **state);

/* Bytes the shell wrote, before the terminal parses them. */
void banana_plugin_output(void *state, const char *bytes, int64_t length);

/* A key press (GLFW key code and modifiers). Return 1 to consume it. */
int32_t banana_plugin_key(void *state, int32_t key, int32_t mods);

/* Called about every 16 ms with seconds since Banana started. */
void banana_plugin_tick(void *state, double time);

/* The terminal grid changed size. */
void banana_plugin_resize(void *state, int32_t cols, int32_t rows);

/* Called before the library is unloaded. */
void banana_plugin_destroy(void *state);

#endif
