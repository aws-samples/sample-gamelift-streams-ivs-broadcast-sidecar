#include "pipeline.h"
#include <stdio.h>
#include <string.h>

// Maximum allowed length for auth token and endpoint to prevent buffer overflow
#define MAX_TOKEN_LENGTH 1024
#define MAX_ENDPOINT_LENGTH 1024
#define PIPELINE_BUFFER_SIZE 4096

// State change timeout in seconds
#define STATE_CHANGE_TIMEOUT_SEC 10

/**
 * Encoder configuration structure
 */
typedef struct {
    const char *element;
    const char *props_format;  // Format string for properties (bitrate placeholder)
    const char *format;
} EncoderConfig;

// GPU encoder configuration
// GStreamer 1.24+ uses nvcudah264enc (CUDA mode) which is more compatible
// than the older nvh264enc with newer NVIDIA drivers
static const EncoderConfig GPU_CONFIG = {
    .element = "nvcudah264enc",
    .props_format = "bitrate=%d",
    .format = "NV12"
};

// CPU encoder configuration (x264 software encoder) - cross-platform
// key-int-max controls GOP size (keyframe interval)
static const EncoderConfig CPU_CONFIG = {
    .element = "x264enc",
    .props_format = "bframes=0 bitrate=%d key-int-max=%d speed-preset=1 tune=4",
    .format = "I420"
};

/**
 * Check if a GStreamer element is available on the system.
 */
static gboolean is_element_available(const char *element_name) {
    GstElementFactory *factory = gst_element_factory_find(element_name);
    if (factory) {
        gst_object_unref(factory);
        return TRUE;
    }
    return FALSE;
}

/**
 * Escape special characters in a string for use in pipeline description.
 * Caller must free the returned string with g_free().
 */
static gchar* escape_pipeline_string(const char *input) {
    if (!input) return NULL;
    
    GString *escaped = g_string_new(NULL);
    for (const char *p = input; *p; p++) {
        switch (*p) {
            case '"':
                g_string_append(escaped, "\\\"");
                break;
            case '\\':
                g_string_append(escaped, "\\\\");
                break;
            default:
                g_string_append_c(escaped, *p);
                break;
        }
    }
    return g_string_free(escaped, FALSE);
}


/**
 * Validate configuration parameters.
 */
static gboolean validate_config(const Config *config, GError **error) {
    if (!config) {
        g_set_error(error, 
                   g_quark_from_static_string("pipeline-config"),
                   1,
                   "Configuration is NULL");
        return FALSE;
    }
    
    if (!config->auth_token || strlen(config->auth_token) == 0) {
        g_set_error(error, 
                   g_quark_from_static_string("pipeline-config"),
                   2,
                   "Missing authentication token");
        return FALSE;
    }
    
    if (!config->whip_endpoint || strlen(config->whip_endpoint) == 0) {
        g_set_error(error, 
                   g_quark_from_static_string("pipeline-config"),
                   3,
                   "Missing WHIP endpoint");
        return FALSE;
    }
    
    if (strlen(config->auth_token) > MAX_TOKEN_LENGTH) {
        g_set_error(error, 
                   g_quark_from_static_string("pipeline-config"),
                   4,
                   "Authentication token exceeds maximum length (%d)", MAX_TOKEN_LENGTH);
        return FALSE;
    }
    
    if (strlen(config->whip_endpoint) > MAX_ENDPOINT_LENGTH) {
        g_set_error(error, 
                   g_quark_from_static_string("pipeline-config"),
                   5,
                   "WHIP endpoint exceeds maximum length (%d)", MAX_ENDPOINT_LENGTH);
        return FALSE;
    }
    
    return TRUE;
}

/**
 * Get the GPU encoder element name.
 * GStreamer 1.24+ uses nvcudah264enc which is more compatible with newer NVIDIA drivers.
 */
static const char* get_gpu_encoder_name(void) {
    return "nvcudah264enc";
}

/**
 * Select the appropriate encoder configuration.
 * Falls back to CPU encoder if GPU encoder is requested but not available.
 */
static const EncoderConfig* select_encoder(const Config *config, EncoderType *actual_encoder) {
    *actual_encoder = config->encoder;
    
    if (config->encoder == ENCODER_GPU) {
        const char *gpu_encoder = get_gpu_encoder_name();
        if (is_element_available(gpu_encoder)) {
            return &GPU_CONFIG;
        }
        g_warning("GPU encoder (%s) not available, falling back to CPU encoder", gpu_encoder);
        *actual_encoder = ENCODER_CPU;
    }
    
    return &CPU_CONFIG;
}


/**
 * Build the video pipeline string.
 * Uses platform-specific capture elements:
 * - Windows: d3d12screencapturesrc with D3D12 processing
 * - Linux: ximagesrc with videoconvert for format conversion
 */
static void build_video_pipeline(GString *pipeline, const Config *config, 
                                  const EncoderConfig *enc, EncoderType actual_encoder) {
    // Get video parameters with defaults
    int width = config->width > 0 ? config->width : 1280;
    int height = config->height > 0 ? config->height : 720;
    int framerate = config->framerate > 0 ? config->framerate : 30;
    int bitrate = config->video_bitrate > 0 ? config->video_bitrate : 4000;
    int gop_size = framerate * 2;  // 2 second GOP
    
    // Build encoder properties string
    // GPU encoder only uses bitrate, CPU encoder uses bitrate and gop_size
    char enc_props[256];
    if (actual_encoder == ENCODER_GPU) {
        snprintf(enc_props, sizeof(enc_props), enc->props_format, bitrate);
    } else {
        snprintf(enc_props, sizeof(enc_props), enc->props_format, bitrate, gop_size);
    }
    
#ifdef PLATFORM_WINDOWS
    // Windows: Use D3D12 for hardware-accelerated screen capture
    // whipsink uses sink_0 for video and expects RTP payloaded streams
    g_string_append_printf(pipeline,
        "d3d12screencapturesrc ! "
        "d3d12convert ! "
        "d3d12download ! "
        "video/x-raw,format=%s,width=%d,height=%d,framerate=%d/1 ! "
        "queue max-size-buffers=2 leaky=2 ! "
        "%s %s ! "
        "video/x-h264,stream-format=byte-stream,alignment=au,profile=baseline ! "
        "rtph264pay config-interval=1 pt=96 ! "
        "whip.sink_0 ",
        enc->format, width, height, framerate,
        enc->element, enc_props);
#else
    // Linux: Use ximagesrc for X11-based screen capture
    // whipclientsink expects encoded video directly (handles RTP internally)
    // Use video_%u pad template as per whipclientsink documentation
    g_string_append_printf(pipeline,
        "ximagesrc use-damage=false ! "
        "videoconvert ! "
        "videoscale ! "
        "videorate ! "
        "video/x-raw,format=%s,width=%d,height=%d,framerate=%d/1 ! "
        "queue max-size-buffers=2 leaky=2 ! "
        "%s %s ! "
        "h264parse ! "
        "whip.video_0 ",
        enc->format, width, height, framerate,
        enc->element, enc_props);
#endif
}

/**
 * Build the audio pipeline string.
 * Uses platform-specific audio capture elements:
 * - Windows: wasapi2src with loopback mode for system audio capture
 * - Linux: autoaudiosrc which automatically selects PulseAudio or ALSA
 * 
 * Note: For loopback capture to work on Windows, audio must be actively playing.
 * On headless/RDP sessions, a virtual audio device may be needed.
 * 
 * Audio smoothing strategy:
 * - Use audiobuffersplit to ensure consistent frame boundaries for Opus
 * - Larger queues with time-based limits to absorb timing jitter
 * - audioresample with better quality for smoother resampling
 */
static void build_audio_pipeline(GString *pipeline, const Config *config) {
    int audio_bitrate = config->audio_bitrate > 0 ? config->audio_bitrate : 128000;
    
#ifdef PLATFORM_WINDOWS
    // Windows: Use WASAPI2 in loopback mode for system audio capture
    // whipsink uses sink_1 for audio and expects RTP payloaded streams
    const char *audio_src = "wasapi2src loopback=true";
    g_string_append_printf(pipeline,
        "%s ! "
        "queue max-size-buffers=0 max-size-bytes=0 max-size-time=300000000 ! "
        "audioconvert ! "
        "audioresample quality=4 ! "
        "audio/x-raw,rate=48000,channels=2,format=S16LE ! "
        "audiobuffersplit output-buffer-duration=20/1000 ! "
        "queue max-size-buffers=0 max-size-bytes=0 max-size-time=500000000 ! "
        "opusenc bitrate=%d frame-size=20 ! "
        "rtpopuspay pt=97 ! "
        "whip.sink_1",
        audio_src, audio_bitrate);
#else
    // Linux: Use pulsesrc to capture system audio via PulseAudio monitor
    // The monitor source captures all audio output (game sounds, etc.)
    // whipclientsink handles opus encoding internally - send raw audio directly
    // Use audio_%u pad template as per whipclientsink documentation
    (void)audio_bitrate;  // Not used - whipclientsink handles encoding
    g_string_append_printf(pipeline,
        "pulsesrc ! "
        "audioconvert ! "
        "audioresample ! "
        "audio/x-raw,rate=48000,channels=2,format=S16LE ! "
        "queue max-size-buffers=0 max-size-bytes=0 max-size-time=500000000 ! "
        "whip.audio_0");
#endif
}


/**
 * Create a GStreamer pipeline for screen capture and WHIP streaming using gst-parse-launch.
 * 
 * The pipeline captures screen content using platform-specific elements, encodes it with H.264,
 * optionally captures audio, encodes it with Opus, and streams to a WHIP endpoint.
 * 
 * Pipeline structure (Windows):
 * VIDEO: d3d12screencapturesrc → d3d12convert → d3d12download → 
 *        video/x-raw → queue → encoder → video/x-h264 → 
 *        rtph264pay → whipsink.sink_0
 * AUDIO (optional): wasapi2src → audioconvert → audioresample → opusenc → 
 *        rtpopuspay → whipsink.sink_1
 * 
 * Pipeline structure (Linux):
 * VIDEO: ximagesrc → videoconvert → 
 *        video/x-raw → queue → encoder → video/x-h264 → 
 *        rtph264pay → whipsink.sink_0
 * AUDIO (optional): autoaudiosrc → audioconvert → audioresample → opusenc → 
 *        rtpopuspay → whipsink.sink_1
 * 
 * WHIP: whipsink (handles WebRTC and WHIP protocol)
 * 
 * Encoder selection:
 * - GPU (Windows): nvh264enc (NVIDIA)
 * - GPU (Linux): nvenc_h264 (NVIDIA)
 * - CPU (cross-platform): x264enc
 * - Automatic fallback from GPU to CPU if hardware not available
 */
GstElement* create_pipeline(const Config *config, GError **error) {
    // Validate configuration
    if (!validate_config(config, error)) {
        return NULL;
    }

    // Escape special characters in auth token and endpoint
    gchar *escaped_token = escape_pipeline_string(config->auth_token);
    gchar *escaped_endpoint = escape_pipeline_string(config->whip_endpoint);
    
    if (!escaped_token || !escaped_endpoint) {
        g_free(escaped_token);
        g_free(escaped_endpoint);
        g_set_error(error,
                   g_quark_from_static_string("pipeline-config"),
                   6,
                   "Failed to escape configuration strings");
        return NULL;
    }

    // Select encoder with automatic fallback
    EncoderType actual_encoder;
    const EncoderConfig *enc = select_encoder(config, &actual_encoder);
    
    if (actual_encoder != config->encoder) {
        g_message("Encoder fallback: requested %s, using %s",
                  config->encoder == ENCODER_GPU ? "GPU" : "CPU",
                  actual_encoder == ENCODER_GPU ? "GPU" : "CPU");
    }

    // Build pipeline string dynamically
    GString *pipeline_str = g_string_sized_new(PIPELINE_BUFFER_SIZE);
    
    // WHIP sink configuration
    // Windows: whipsink works correctly
    // Linux: whipclientsink is required (whipsink doesn't trigger WebRTC offer in GStreamer 1.24+)
    // Note: whipclientsink uses signaller:: prefix for properties
#ifdef PLATFORM_WINDOWS
    g_string_append_printf(pipeline_str,
        "whipsink name=whip auth-token=\"%s\" whip-endpoint=\"%s\" ",
        escaped_token, escaped_endpoint);
#else
    g_string_append_printf(pipeline_str,
        "whipclientsink name=whip signaller::auth-token=\"%s\" signaller::whip-endpoint=\"%s\" ",
        escaped_token, escaped_endpoint);
#endif
    
    g_free(escaped_token);
    g_free(escaped_endpoint);
    
    // Add video pipeline
    build_video_pipeline(pipeline_str, config, enc, actual_encoder);
    
    // Add audio pipeline if enabled
    if (config->enable_audio) {
        build_audio_pipeline(pipeline_str, config);
    }
    
    // Debug output if requested
    if (config->debug_pipeline) {
        g_print("Pipeline: %s\n", pipeline_str->str);
    }

    // Parse the pipeline string
    GstElement *pipeline = gst_parse_launch(pipeline_str->str, error);
    
    if (!pipeline) {
        if (error && !*error) {
            g_set_error(error,
                       g_quark_from_static_string("pipeline-creation"),
                       1,
                       "Failed to parse pipeline string");
        }
        g_string_free(pipeline_str, TRUE);
        return NULL;
    }
    
    g_string_free(pipeline_str, TRUE);
    return pipeline;
}


/**
 * Set pipeline state and wait for completion with timeout.
 */
gboolean set_pipeline_state(GstElement *pipeline, GstState state) {
    if (!pipeline) {
        g_warning("set_pipeline_state: pipeline is NULL");
        return FALSE;
    }

    GstStateChangeReturn ret = gst_element_set_state(pipeline, state);
    
    if (ret == GST_STATE_CHANGE_FAILURE) {
        g_warning("Failed to set pipeline state to %s",
                  gst_element_state_get_name(state));
        return FALSE;
    }
    
    if (ret == GST_STATE_CHANGE_ASYNC) {
        // Wait for async state change with timeout
        GstState current_state, pending_state;
        GstClockTime timeout = STATE_CHANGE_TIMEOUT_SEC * GST_SECOND;
        
        ret = gst_element_get_state(pipeline, &current_state, &pending_state, timeout);
        
        if (ret == GST_STATE_CHANGE_FAILURE) {
            g_warning("Async state change to %s failed",
                      gst_element_state_get_name(state));
            return FALSE;
        }
        
        if (ret == GST_STATE_CHANGE_ASYNC) {
            g_warning("State change to %s timed out after %d seconds",
                      gst_element_state_get_name(state), STATE_CHANGE_TIMEOUT_SEC);
            return FALSE;
        }
    }
    
    return TRUE;
}

/**
 * Check if GPU encoder is available on the system.
 * Useful for UI or configuration to determine available options.
 * Uses platform-specific GPU encoder:
 * - Windows: nvh264enc
 * - Linux: nvenc_h264
 */
gboolean is_gpu_encoder_available(void) {
    return is_element_available(get_gpu_encoder_name());
}

/**
 * Get the name of the encoder that will be used based on configuration.
 * Returns a static string, do not free.
 */
const char* get_encoder_name(const Config *config) {
    if (config->encoder == ENCODER_GPU && is_element_available(get_gpu_encoder_name())) {
        return "nvcudah264enc (NVIDIA GPU)";
    }
    return "x264enc (CPU)";
}
