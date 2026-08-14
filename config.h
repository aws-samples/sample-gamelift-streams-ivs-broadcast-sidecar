#ifndef CONFIG_H
#define CONFIG_H

#include <glib.h>

/**
 * Encoder type enumeration
 */
typedef enum {
    ENCODER_GPU,    // NVIDIA hardware encoder (nvcudah264enc)
    ENCODER_CPU     // Software encoder (x264enc)
} EncoderType;

/**
 * Ingest type enumeration - determines the streaming protocol.
 */
typedef enum {
    INGEST_WHIP,    // Default - WHIP protocol (WebRTC-HTTP Ingestion Protocol)
    INGEST_RTMP     // RTMP protocol
} IngestType;

/**
 * Configuration structure for the screen capture application.
 * Contains authentication and endpoint information for WHIP or RTMP streaming.
 */
typedef struct {
    gchar *auth_token;      // IVS authentication token (WHIP)
    gchar *whip_endpoint;   // WHIP endpoint URL (WHIP)
    EncoderType encoder;    // Encoder type (GPU or CPU)
    gboolean enable_audio;  // Enable audio capture (default: TRUE)
    gboolean debug_pipeline; // Print pipeline string for debugging (default: FALSE)
    gint width;             // Video width (default: 1280)
    gint height;            // Video height (default: 720)
    gint framerate;         // Video framerate (default: 30)
    gint video_bitrate;     // Video bitrate in kbps (default: 4000)
    gint audio_bitrate;     // Audio bitrate in bps (default: 128000)
    gint queue_buffer_size; // Queue max-size-buffers for video pipeline (default: 5, 0=unlimited)

    // Ingest type selection
    IngestType ingest_type; // Ingest protocol (default: INGEST_WHIP)

    // RTMP-specific fields
    gchar *rtmp_endpoint;   // RTMP endpoint URL (e.g., "rtmp://ingest.example.com/app")
    gchar *stream_key;      // RTMP stream key
} Config;

/**
 * Parse configuration from environment variables and command-line arguments.
 * 
 * Priority order:
 * 1. Command-line arguments (highest priority)
 * 2. Environment variables (fallback)
 * 
 * Environment variables:
 * - IVS_STAGE_TOKEN: Authentication token (WHIP)
 * - IVS_WHIP_ENDPOINT: WHIP endpoint URL (WHIP)
 * - ENCODER_TYPE: Encoder type ("gpu" or "cpu", default: "gpu")
 * - QUEUE_BUFFER_SIZE: Video queue max-size-buffers (default: 5, 0=unlimited)
 * - INGEST_TYPE: Ingest protocol ("whip" or "rtmp", default: "whip")
 * - RTMP_ENDPOINT: RTMP ingest server URL (RTMP)
 * - STREAM_KEY: RTMP stream key (RTMP)
 * 
 * Command-line arguments:
 * - --auth-token <token>: Authentication token (WHIP)
 * - --whip-endpoint <url>: WHIP endpoint URL (WHIP)
 * - --encoder <type>: Encoder type ("gpu" or "cpu")
 * - --ingest-type <type>: Ingest protocol ("whip" or "rtmp")
 * - --rtmp-endpoint <url>: RTMP ingest server URL (RTMP)
 * - --stream-key <key>: RTMP stream key (RTMP)
 * 
 * @param argc Argument count from main()
 * @param argv Argument vector from main()
 * @param config Pointer to Config structure to populate
 * @return TRUE if configuration is valid and complete, FALSE otherwise
 */
gboolean parse_configuration(int argc, char *argv[], Config *config);

/**
 * Free memory allocated for configuration strings.
 * 
 * @param config Pointer to Config structure to clean up
 */
void free_configuration(Config *config);

/**
 * Print usage information to stderr.
 * 
 * @param program_name Name of the program (argv[0])
 */
void print_usage(const char *program_name);

#endif // CONFIG_H
