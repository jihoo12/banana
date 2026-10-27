/* FreeType exposes structs and macros; keep that ABI out of the jihoo core. */
#define _XOPEN_SOURCE 700
#include <ft2build.h>
#include FT_FREETYPE_H
#include <fontconfig/fontconfig.h>
#include <locale.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

typedef struct {
    unsigned char *pixels;
    int32_t width, height, left, top;
} BananaGlyph;

typedef struct {
    FT_Library library;
    FT_Face faces[32];
    char *paths[32];
    int indices[32], count, size;
    unsigned char *pixels;
    size_t capacity;
} BananaFont;

static FT_Face load_face(BananaFont *font, FcPattern *pattern) {
    FcChar8 *path = NULL;
    int index = 0;
    if (FcPatternGetString(pattern, FC_FILE, 0, &path) != FcResultMatch)
        return NULL;
    FcPatternGetInteger(pattern, FC_INDEX, 0, &index);
    for (int i = 0; i < font->count; i++)
        if (font->indices[i] == index && !strcmp(font->paths[i], (char *)path))
            return font->faces[i];
    if (font->count == 32) return NULL;
    FT_Face face;
    if (FT_New_Face(font->library, (char *)path, index, &face)) return NULL;
    if (FT_Set_Pixel_Sizes(face, 0, font->size)) {
        FT_Done_Face(face);
        return NULL;
    }
    char *copy = strdup((char *)path);
    if (!copy) { FT_Done_Face(face); return NULL; }
    int n = font->count++;
    font->faces[n] = face;
    font->paths[n] = copy;
    font->indices[n] = index;
    return face;
}

void *banana_font_open(const char *family, int32_t size) {
    setlocale(LC_CTYPE, "");
    BananaFont *font = calloc(1, sizeof(*font));
    if (!font) return NULL;
    font->size = size;
    if (FT_Init_FreeType(&font->library)) { free(font); return NULL; }
    FcPattern *request = FcNameParse((const FcChar8 *)family);
    if (!request) { FT_Done_FreeType(font->library); free(font); return NULL; }
    FcConfigSubstitute(NULL, request, FcMatchPattern);
    FcDefaultSubstitute(request);
    FcResult result;
    FcPattern *match = FcFontMatch(NULL, request, &result);
    FT_Face face = match ? load_face(font, match) : NULL;
    if (match) FcPatternDestroy(match);
    FcPatternDestroy(request);
    if (!face) { FT_Done_FreeType(font->library); free(font); return NULL; }
    return font;
}

int32_t banana_font_width(void *handle) {
    BananaFont *font = handle;
    if (FT_Load_Char(font->faces[0], 'M', FT_LOAD_DEFAULT)) return font->size;
    return (font->faces[0]->glyph->advance.x + 63) / 64;
}

int32_t banana_font_ascent(void *handle) {
    BananaFont *font = handle;
    return (font->faces[0]->size->metrics.ascender + 63) / 64;
}

BananaGlyph banana_font_glyph(void *handle, uint32_t codepoint) {
    BananaFont *font = handle;
    FT_Face face = font->faces[0];
    if (!FT_Get_Char_Index(face, codepoint)) {
        FcPattern *request = FcPatternCreate();
        FcCharSet *chars = FcCharSetCreate();
        if (request && chars) {
            FcCharSetAddChar(chars, codepoint);
            FcPatternAddCharSet(request, FC_CHARSET, chars);
            FcPatternAddString(request, FC_FAMILY, (const FcChar8 *)"monospace");
            FcConfigSubstitute(NULL, request, FcMatchPattern);
            FcDefaultSubstitute(request);
            FcResult result;
            FcPattern *match = FcFontMatch(NULL, request, &result);
            FT_Face fallback = match ? load_face(font, match) : NULL;
            if (fallback) face = fallback;
            if (match) FcPatternDestroy(match);
        }
        if (chars) FcCharSetDestroy(chars);
        if (request) FcPatternDestroy(request);
    }
    BananaGlyph glyph = {0};
    if (FT_Load_Char(face, codepoint, FT_LOAD_RENDER | FT_LOAD_TARGET_NORMAL))
        return glyph;
    FT_GlyphSlot slot = face->glyph;
    FT_Bitmap *bitmap = &slot->bitmap;
    glyph.width = bitmap->width;
    glyph.height = bitmap->rows;
    glyph.left = slot->bitmap_left;
    glyph.top = slot->bitmap_top;
    size_t needed = (size_t)glyph.width * glyph.height;
    if (!needed) return glyph;
    if (needed > font->capacity) {
        unsigned char *buffer = realloc(font->pixels, needed);
        if (!buffer) return (BananaGlyph){0};
        font->pixels = buffer;
        font->capacity = needed;
    }
    for (int y = 0; y < glyph.height; y++) {
        const unsigned char *row = bitmap->buffer +
            (bitmap->pitch >= 0 ? y : glyph.height - 1 - y) * abs(bitmap->pitch);
        for (int x = 0; x < glyph.width; x++) {
            font->pixels[y * glyph.width + x] = bitmap->pixel_mode == FT_PIXEL_MODE_MONO
                ? ((row[x / 8] & (0x80 >> (x % 8))) ? 255 : 0) : row[x];
        }
    }
    glyph.pixels = font->pixels;
    return glyph;
}

int32_t banana_char_width(uint32_t codepoint) {
    int width = wcwidth((wchar_t)codepoint);
    return width < 0 ? 1 : width;
}

void banana_font_close(void *handle) {
    BananaFont *font = handle;
    for (int i = 0; i < font->count; i++) {
        FT_Done_Face(font->faces[i]);
        free(font->paths[i]);
    }
    FT_Done_FreeType(font->library);
    free(font->pixels);
    free(font);
}
