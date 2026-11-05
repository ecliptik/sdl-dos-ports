/*
 * gus_pcm_stream_test.c -- host-side test of shared/audio/gus_pcm_stream.c.
 *
 * Builds the module VERBATIM on the host (any C99 compiler, no SDL, no DOS)
 * against stub SDL_DOSGus* primitives that model the GF1 in simulated time:
 * a small bump-allocated DRAM, a voice that sounds for (end-start+1)/rate
 * seconds after StartVoice and then reads back as stopped, and the reserved
 * SFX partition (5 voices, the sdl3-dos driver's default) behind
 * SDL_DOSGusAllocVoiceSfx. Every StartVoice snapshots the DRAM range it
 * plays, so the test can check exactly which bytes became audible, in order.
 *
 * What it asserts (each failed against the module as of hub 20f16f1):
 *   T1  a clip shorter than one chunk (4096 B) plays, all of it
 *   T2  a clip of 4096*n + k bytes plays all n*4096 + k bytes, in order
 *   T3  after a clip has played out, more pump calls add no underruns and
 *       the stream reports itself drained
 *
 * The flush/drained API is used when the header advertises it
 * (GUS_PCM_STREAM_HAS_FLUSH); without it the test drives the stream the way
 * a caller had to before (write everything, then pump), so the same test
 * runs -- and fails -- against the older module.
 *
 * Run: ./run.sh   (exit 0 = all pass). ASCII-only.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include "gus_pcm_stream.h"
#include "gus_dram_floor.h"

/* ---- simulated GF1 ------------------------------------------------------ */
#define SIM_RATE        11025.0
#define SIM_VOICES      20
#define SIM_SFX_FIRST   15            /* 15 music + 5 SFX, the driver default */
#define SIM_DRAM_MAX    (1u << 20)
#define BAD_ADDR        0xFFFFFFFFu

static double   g_now_ms;
static uint8_t  g_dram[SIM_DRAM_MAX];
static uint32_t g_dram_used, g_dram_cap = SIM_DRAM_MAX;
static bool     g_busy[SIM_VOICES];
static struct { bool on; double t0, dur_ms; } g_v[SIM_VOICES];
static uint8_t  g_played[1 << 20];    /* bytes snapshotted at each StartVoice */
static size_t   g_played_len;

struct gus_hw_state { bool valid; uint16_t base_port; uint8_t gf1_irq, play_dma, num_voices, pad0;
                      uint32_t output_rate, dram_size, dram_used, voice_active_mask, abi_version; };

bool SDL_DOSGusInit(void) { return true; }
bool SDL_DOSGusGetState(struct gus_hw_state *o) { memset(o, 0, sizeof(*o)); o->valid = true; return true; }
bool SDL_DOSGusVoiceActive(int v)
{
  if (v < 0 || v >= SIM_VOICES || !g_busy[v] || !g_v[v].on) return false;
  if (g_now_ms - g_v[v].t0 >= g_v[v].dur_ms) { g_v[v].on = false; return false; }
  return true;
}
uint32_t SDL_DOSGusUploadSample(const void *d, uint32_t len, int is16)
{
  uint32_t a;
  (void)is16;
  if (g_dram_used + len > g_dram_cap) return BAD_ADDR;
  a = g_dram_used; memcpy(g_dram + a, d, len); g_dram_used += len; return a;
}
bool SDL_DOSGusOverwriteSample(uint32_t a, const void *d, uint32_t len, int is16)
{
  (void)is16; memcpy(g_dram + a, d, len); return true;
}
int SDL_DOSGusAllocVoiceSfx(void)
{
  int v;
  for (v = SIM_SFX_FIRST; v < SIM_VOICES; v++)
    if (!g_busy[v]) { g_busy[v] = true; return v; }
  return -1;
}
void SDL_DOSGusStartVoice(int v, uint32_t start, uint32_t end, uint32_t loop, uint32_t flags)
{
  uint32_t n = end - start + 1u;
  (void)loop; (void)flags;
  g_v[v].on = true; g_v[v].t0 = g_now_ms; g_v[v].dur_ms = n / SIM_RATE * 1000.0;
  if (g_played_len + n <= sizeof(g_played)) { memcpy(g_played + g_played_len, g_dram + start, n); g_played_len += n; }
}
void SDL_DOSGusStopVoice(int v) { if (v >= 0 && v < SIM_VOICES) { g_v[v].on = false; g_busy[v] = false; } }
void SDL_DOSGusSetVoiceFreq(int v, uint32_t hz) { (void)v; (void)hz; }
void SDL_DOSGusSetVoiceVol(int v, int vol) { (void)v; (void)vol; }
void SDL_DOSGusSetVoicePan(int v, int pan) { (void)v; (void)pan; }
const char *SDL_GetHint(const char *n) { (void)n; return "0"; }
bool SDL_SetHint(const char *n, const char *v) { (void)n; (void)v; return true; }

/* ---- helpers ------------------------------------------------------------ */
static int g_fail;
#define CHECK(cond, ...) do { if (!(cond)) { g_fail++; printf("  FAIL: "); printf(__VA_ARGS__); printf("\n"); } \
                              else { printf("  ok:   "); printf(__VA_ARGS__); printf("\n"); } } while (0)

static void sim_reset(void)
{
  g_now_ms = 0; g_dram_used = 0; g_dram_cap = SIM_DRAM_MAX; g_played_len = 0;
  memset(g_busy, 0, sizeof(g_busy)); memset(g_v, 0, sizeof(g_v));
  gus_dram_floor_reset();
}
static int sfx_busy(void) { int v, n = 0; for (v = SIM_SFX_FIRST; v < SIM_VOICES; v++) n += g_busy[v]; return n; }
static void make_clip(uint8_t *c, size_t n, unsigned seed)
{
  size_t i; for (i = 0; i < n; i++) c[i] = (uint8_t)(1u + ((i * 7u + seed) % 254u)); /* never 0x80-only */
}

/* Feeds `clip` the way an engine's per-frame poll does (2048 B per poll,
 * "accepted > 0" consumes the buffer), pumping once per simulated ms, until
 * the stream reports drained (or `max_ms`). Returns ms taken, -1 on timeout. */
static double play_clip(gus_pcm_stream *s, const uint8_t *clip, size_t n, double max_ms)
{
  size_t off = 0;
  gus_pcm_stream_set_active(s, true);
  for (; g_now_ms < max_ms; g_now_ms += 1.0)
  {
    if (off < n)
    {
      size_t take = (n - off < 2048u) ? n - off : 2048u;
      if (gus_pcm_stream_write(s, clip + off, take) > 0) off += take;
    }
#ifdef GUS_PCM_STREAM_HAS_FLUSH
    if (off >= n) gus_pcm_stream_flush(s);
    gus_pcm_stream_pump(s);
    if (off >= n && gus_pcm_stream_drained(s)) return g_now_ms;
#else
    gus_pcm_stream_pump(s);
    if (off >= n && gus_pcm_stream_queued(s) == 0 && !SDL_DOSGusVoiceActive(SIM_SFX_FIRST)) return g_now_ms;
#endif
  }
  return -1.0;
}
static bool played_whole(const uint8_t *clip, size_t n)
{
  size_t i;
  if (g_played_len < n || memcmp(g_played, clip, n) != 0) return false;
  for (i = n; i < g_played_len; i++) if (g_played[i] != 0x80) return false; /* only silence after */
  return true;
}

static void test_clip(const char *name, size_t n)
{
  uint8_t *clip = (uint8_t *)malloc(n);
  gus_pcm_stream *s;
  double t; int u0, k;
  printf("%s (%u bytes)\n", name, (unsigned)n);
  sim_reset(); make_clip(clip, n, (unsigned)n);
  s = gus_pcm_stream_open(11025, 1, 4096);
  CHECK(s != NULL, "open");
  if (!s) { free(clip); return; }
  t = play_clip(s, clip, n, 60000.0);
  CHECK(t >= 0, "stream reports drained after the clip (%.0f ms)", t);
  CHECK(played_whole(clip, n), "all %u clip bytes played in order (%u bytes reached the voice)", (unsigned)n, (unsigned)g_played_len);
  u0 = gus_pcm_stream_underrun_count(s);
  for (k = 0; k < 2000; k++) { g_now_ms += 1.0; gus_pcm_stream_pump(s); }
  CHECK(gus_pcm_stream_underrun_count(s) == u0, "2000 pumps after the end add no underruns (%d -> %d)", u0, gus_pcm_stream_underrun_count(s));
  CHECK(u0 == 0, "no underruns while a fully fed clip plays (%d)", u0);
  gus_pcm_stream_close(s);
  CHECK(sfx_busy() == 0, "close returns the SFX voice (busy=%d)", sfx_busy());
  free(clip);
}

int main(void)
{
  test_clip("T1 short clip", 3893);
  test_clip("T2/T3 clip 4096*4+1757", 4096u * 4u + 1757u);
  test_clip("T2/T3 clip 4096*26+1085", 4096u * 26u + 1085u);

  printf("%s (%d failure%s)\n", g_fail ? "FAIL" : "PASS", g_fail, g_fail == 1 ? "" : "s");
  return g_fail ? 1 : 0;
}
