#ifndef CONFIG_H
#define CONFIG_H

#include <glib.h>

/**
 * Encoder type enumeration
 */
typedef enum {
    ENCODER_GPU,    // NVIDIA hardware encoder (nvh264enc)
    ENCODER_CPU     // Software encoder (x264enc)
} EncoderType;

/**
 * Configuration structure for the screen capture application.
 * Contains authentication and endpoint information for WHIP streaming.
 */
typedef struct {
    gchar *auth_token;      // IVS authentication token
    gchar *whip_endpoint;   // WHIP endpoint URL
    EncoderType encoder;    // Encoder type (GPU or CPU)
    gboolean enable_audio;  // Enable audio capture (default: TRUE)
    gboolean debug_pipeline; // Print pipeline string for debugging (default: FALSE)
    gint width;             // Video width (default: 1280)
    gint height;            // Video height (default: 720)
    gint framerate;         // Video framerate (default: 30)
    gint video_bitrate;     // Video bitrate in kbps (default: 8000)
    gint audio_bitrate;     // Audio bitrate in bps (default: 128000)
} Config;

/**
 * Parse configuration from environment variables and command-line arguments.
 * 
 * Priority order:
 * 1. Command-line arguments (highest priority)
 * 2. Environment variables (fallback)
 * 
 * Environment variables:
 * - IVS_STAGE_TOKEN: Authentication token
 * - IVS_WHIP_ENDPOINT: WHIP endpoint URL
 * - ENCODER_TYPE: Encoder type ("gpu" or "cpu", default: "gpu")
 * 
 * Command-line arguments:
 * - --auth-token <token>: Authentication token
 * - --whip-endpoint <url>: WHIP endpoint URL
 * - --encoder <type>: Encoder type ("gpu" or "cpu")
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
