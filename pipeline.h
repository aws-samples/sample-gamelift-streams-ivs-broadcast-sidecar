#ifndef PIPELINE_H
#define PIPELINE_H

#include <gst/gst.h>
#include "config.h"

/**
 * Create a GStreamer pipeline for screen capture and WHIP streaming using gst-parse-launch.
 * 
 * The pipeline captures screen content using platform-specific elements, encodes it with H.264,
 * captures audio, encodes it with Opus, and streams both to a WHIP endpoint.
 * 
 * Pipeline structure (Windows):
 * VIDEO: d3d12screencapturesrc → d3d12convert → d3d12download → 
 *        video/x-raw → queue → encoder → video/x-h264 → 
 *        rtph264pay → whipsink.sink_0
 * AUDIO: wasapi2src → audioconvert → audioresample → opusenc → 
 *        rtpopuspay → whipsink.sink_1
 * 
 * Pipeline structure (Linux):
 * VIDEO: ximagesrc → videoconvert → 
 *        video/x-raw → queue → encoder → video/x-h264 → 
 *        rtph264pay → whipsink.sink_0
 * AUDIO: autoaudiosrc → audioconvert → audioresample → opusenc → 
 *        rtpopuspay → whipsink.sink_1
 * 
 * WHIP: whipsink (handles WebRTC negotiation and WHIP protocol)
 * 
 * Encoder selection:
 * - GPU (Windows): nvh264enc (NVIDIA)
 * - GPU (Linux): nvenc_h264 (NVIDIA)
 * - CPU (cross-platform): x264enc
 * - Automatic fallback from GPU to CPU if hardware not available
 * 
 * @param config Pointer to Config structure containing auth token, endpoint, and encoder type
 * @param error Pointer to GError pointer for error reporting (can be NULL)
 * @return GstElement pointer to the created pipeline, or NULL on failure
 */
GstElement* create_pipeline(const Config *config, GError **error);

/**
 * Set pipeline state and wait for completion with timeout.
 * 
 * @param pipeline The pipeline element
 * @param state The desired state
 * @return TRUE if state change succeeded, FALSE otherwise
 */
gboolean set_pipeline_state(GstElement *pipeline, GstState state);

/**
 * Check if GPU encoder (nvh264enc) is available on the system.
 * 
 * @return TRUE if GPU encoder is available, FALSE otherwise
 */
gboolean is_gpu_encoder_available(void);

/**
 * Get the name of the encoder that will be used based on configuration.
 * 
 * @param config Pointer to Config structure
 * @return Static string describing the encoder (do not free)
 */
const char* get_encoder_name(const Config *config);

#endif // PIPELINE_H
