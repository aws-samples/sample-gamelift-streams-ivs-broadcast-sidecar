#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Parse configuration from environment variables and command-line arguments.
 */
gboolean parse_configuration(int argc, char *argv[], Config *config) {
    if (!config) {
        return FALSE;
    }

    // Initialize config structure with defaults
    config->auth_token = NULL;
    config->whip_endpoint = NULL;
    config->encoder = ENCODER_GPU;      // Default to GPU encoding
    config->enable_audio = TRUE;        // Audio enabled by default
    config->debug_pipeline = FALSE;     // Debug disabled by default
    config->width = 1280;               // Default resolution
    config->height = 720;
    config->framerate = 30;             // Default framerate
    config->video_bitrate = 4000;       // Default video bitrate (kbps)
    config->audio_bitrate = 128000;     // Default audio bitrate (bps)

    // First, try to read from environment variables
    const char *env_token = g_getenv("IVS_STAGE_TOKEN");
    const char *env_endpoint = g_getenv("IVS_WHIP_ENDPOINT");
    const char *env_encoder = g_getenv("ENCODER_TYPE");
    const char *env_audio = g_getenv("ENABLE_AUDIO");
    const char *env_debug = g_getenv("DEBUG_PIPELINE");
    const char *env_width = g_getenv("VIDEO_WIDTH");
    const char *env_height = g_getenv("VIDEO_HEIGHT");
    const char *env_framerate = g_getenv("VIDEO_FRAMERATE");
    const char *env_video_bitrate = g_getenv("VIDEO_BITRATE");
    const char *env_audio_bitrate = g_getenv("AUDIO_BITRATE");

    if (env_token) {
        config->auth_token = g_strdup(env_token);
    }
    if (env_endpoint) {
        config->whip_endpoint = g_strdup(env_endpoint);
    }
    if (env_encoder) {
        if (g_ascii_strcasecmp(env_encoder, "cpu") == 0) {
            config->encoder = ENCODER_CPU;
        } else if (g_ascii_strcasecmp(env_encoder, "gpu") == 0) {
            config->encoder = ENCODER_GPU;
        } else {
            fprintf(stderr, "Warning: Invalid ENCODER_TYPE '%s', using default (gpu)\n", env_encoder);
        }
    }
    if (env_audio) {
        config->enable_audio = (g_ascii_strcasecmp(env_audio, "true") == 0 || 
                                g_ascii_strcasecmp(env_audio, "1") == 0);
    }
    if (env_debug) {
        config->debug_pipeline = (g_ascii_strcasecmp(env_debug, "true") == 0 || 
                                  g_ascii_strcasecmp(env_debug, "1") == 0);
    }
    if (env_width) {
        config->width = atoi(env_width);
    }
    if (env_height) {
        config->height = atoi(env_height);
    }
    if (env_framerate) {
        config->framerate = atoi(env_framerate);
    }
    if (env_video_bitrate) {
        config->video_bitrate = atoi(env_video_bitrate);
    }
    if (env_audio_bitrate) {
        config->audio_bitrate = atoi(env_audio_bitrate);
    }

    // Parse command-line arguments (these override environment variables)
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--auth-token") == 0 && i + 1 < argc) {
            // Free existing value if set from environment
            if (config->auth_token) {
                g_free(config->auth_token);
            }
            config->auth_token = g_strdup(argv[i + 1]);
            i++; // Skip the next argument since we consumed it
        } else if (strcmp(argv[i], "--whip-endpoint") == 0 && i + 1 < argc) {
            // Free existing value if set from environment
            if (config->whip_endpoint) {
                g_free(config->whip_endpoint);
            }
            config->whip_endpoint = g_strdup(argv[i + 1]);
            i++; // Skip the next argument since we consumed it
        } else if (strcmp(argv[i], "--encoder") == 0 && i + 1 < argc) {
            if (g_ascii_strcasecmp(argv[i + 1], "cpu") == 0) {
                config->encoder = ENCODER_CPU;
            } else if (g_ascii_strcasecmp(argv[i + 1], "gpu") == 0) {
                config->encoder = ENCODER_GPU;
            } else {
                fprintf(stderr, "Error: Invalid encoder type '%s'. Must be 'cpu' or 'gpu'\n", argv[i + 1]);
                print_usage(argv[0]);
                return FALSE;
            }
            i++; // Skip the next argument since we consumed it
        } else if (strcmp(argv[i], "--no-audio") == 0) {
            config->enable_audio = FALSE;
        } else if (strcmp(argv[i], "--debug") == 0) {
            config->debug_pipeline = TRUE;
        } else if (strcmp(argv[i], "--width") == 0 && i + 1 < argc) {
            config->width = atoi(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--height") == 0 && i + 1 < argc) {
            config->height = atoi(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--framerate") == 0 && i + 1 < argc) {
            config->framerate = atoi(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--video-bitrate") == 0 && i + 1 < argc) {
            config->video_bitrate = atoi(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--audio-bitrate") == 0 && i + 1 < argc) {
            config->audio_bitrate = atoi(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            return FALSE;
        } else {
            fprintf(stderr, "Unknown argument: %s\n", argv[i]);
            print_usage(argv[0]);
            return FALSE;
        }
    }

    // Validate that required configuration is present
    if (!config->auth_token || strlen(config->auth_token) == 0) {
        fprintf(stderr, "ERROR: Missing authentication token\n");
        fprintf(stderr, "  Set IVS_STAGE_TOKEN environment variable or use --auth-token argument\n");
        print_usage(argv[0]);
        free_configuration(config);
        return FALSE;
    }

    if (!config->whip_endpoint || strlen(config->whip_endpoint) == 0) {
        fprintf(stderr, "ERROR: Missing WHIP endpoint URL\n");
        fprintf(stderr, "  Set IVS_WHIP_ENDPOINT environment variable or use --whip-endpoint argument\n");
        print_usage(argv[0]);
        free_configuration(config);
        return FALSE;
    }

    return TRUE;
}

/**
 * Free memory allocated for configuration strings.
 */
void free_configuration(Config *config) {
    if (!config) {
        return;
    }

    if (config->auth_token) {
        g_free(config->auth_token);
        config->auth_token = NULL;
    }

    if (config->whip_endpoint) {
        g_free(config->whip_endpoint);
        config->whip_endpoint = NULL;
    }
}

/**
 * Print usage information to stderr.
 */
void print_usage(const char *program_name) {
    fprintf(stderr, "\nUsage: %s [OPTIONS]\n", program_name);
    fprintf(stderr, "\nRequired (via argument or environment variable):\n");
    fprintf(stderr, "  --auth-token <token>     Authentication token (or IVS_STAGE_TOKEN)\n");
    fprintf(stderr, "  --whip-endpoint <url>    WHIP endpoint URL (or IVS_WHIP_ENDPOINT)\n");
    fprintf(stderr, "\nEncoder options:\n");
    fprintf(stderr, "  --encoder <type>         Encoder: 'gpu' (NVIDIA) or 'cpu' (x264) [default: gpu]\n");
    fprintf(stderr, "\nVideo options:\n");
    fprintf(stderr, "  --width <pixels>         Video width [default: 1280]\n");
    fprintf(stderr, "  --height <pixels>        Video height [default: 720]\n");
    fprintf(stderr, "  --framerate <fps>        Video framerate [default: 30]\n");
    fprintf(stderr, "  --video-bitrate <kbps>   Video bitrate in kbps [default: 4000]\n");
    fprintf(stderr, "\nAudio options:\n");
    fprintf(stderr, "  --no-audio               Disable audio capture\n");
    fprintf(stderr, "  --audio-bitrate <bps>    Audio bitrate in bps [default: 128000]\n");
    fprintf(stderr, "\nDebug options:\n");
    fprintf(stderr, "  --debug                  Print pipeline string for debugging\n");
    fprintf(stderr, "  --help, -h               Show this help message\n");
    fprintf(stderr, "\nEnvironment variables:\n");
    fprintf(stderr, "  IVS_STAGE_TOKEN, IVS_WHIP_ENDPOINT, ENCODER_TYPE, ENABLE_AUDIO,\n");
    fprintf(stderr, "  DEBUG_PIPELINE, VIDEO_WIDTH, VIDEO_HEIGHT, VIDEO_FRAMERATE,\n");
    fprintf(stderr, "  VIDEO_BITRATE, AUDIO_BITRATE\n\n");
}
