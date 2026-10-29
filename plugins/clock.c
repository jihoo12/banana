/* A status bar clock. Arguments: a strftime(3) format, "%H:%M" by default. */
#define _POSIX_C_SOURCE 200809L
#include <banana_plugin.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    const BananaHost *host;
    char format[64];
    char shown[128];
} Clock;

int32_t banana_plugin_init(const BananaHost *host, const char *args, void **state) {
    if (host->abi != BANANA_PLUGIN_ABI) return 1;
    Clock *clock = calloc(1, sizeof(*clock));
    if (!clock) return 1;
    clock->host = host;
    snprintf(clock->format, sizeof clock->format, "%s", args && *args ? args : "%H:%M");
    *state = clock;
    return 0;
}

void banana_plugin_tick(void *state, double now) {
    (void)now;
    Clock *clock = state;
    char text[128];
    time_t t = time(NULL);
    struct tm local;
    localtime_r(&t, &local);
    char body[100];
    if (!strftime(body, sizeof body, clock->format, &local)) return;
    snprintf(text, sizeof text, "◷ %s", body);
    if (strcmp(text, clock->shown)) {
        memcpy(clock->shown, text, sizeof text);
        clock->host->set_status(clock->host->ctx, text);
    }
}

void banana_plugin_destroy(void *state) { free(state); }
