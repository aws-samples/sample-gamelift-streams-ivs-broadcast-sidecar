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
    config->queue_buffer_size = 5;      // Default queue depth (buffers)
    config->ingest_type = INGEST_WHIP;  // Default to WHIP protocol
    config->rtmp_endpoint = NULL;
    config->stream_key = NULL;

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
    const char *env_queue_buffer_size = g_getenv("QUEUE_BUFFER_SIZE");
    const char *env_ingest_type = g_getenv("INGEST_TYPE");
    const char *env_rtmp_endpoint = g_getenv("RTMP_ENDPOINT");
    const char *env_stream_key = g_getenv("STREAM_KEY");

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
    if (env_queue_buffer_size) {
        int qsize = atoi(env_queue_buffer_size);
        if (qsize < 0) {
            // A negative value would wrap when assigned to the queue's unsigned
            // max-size-buffers property, silently making the queue unbounded.
            fprintf(stderr, "Warning: QUEUE_BUFFER_SIZE '%s' is negative, using default (%d)\n",
                    env_queue_buffer_size, config->queue_buffer_size);
        } else {
            config->queue_buffer_size = qsize;
        }
    }

    // Parse ingest type from environment
    if (env_ingest_type) {
        if (g_ascii_strcasecmp(env_ingest_type, "rtmp") == 0) {
            config->ingest_type = INGEST_RTMP;
        } else if (g_ascii_strcasecmp(env_ingest_type, "whip") == 0) {
            config->ingest_type = INGEST_WHIP;
        } else {
            fprintf(stderr, "Warning: Unrecognized INGEST_TYPE '%s', defaulting to 'whip'\n", env_ingest_type);
            config->ingest_type = INGEST_WHIP;
        }
    }

    // Read RTMP-specific env vars
    if (env_rtmp_endpoint) {
        config->rtmp_endpoint = g_strdup(env_rtmp_endpoint);
    }
    if (env_stream_key) {
        config->stream_key = g_strdup(env_stream_key);
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
                free_configuration(config);
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
        } else if (strcmp(argv[i], "--queue-buffer-size") == 0 && i + 1 < argc) {
            int qsize = atoi(argv[i + 1]);
            if (qsize < 0) {
                // Reject rather than clamp: a negative value would wrap when assigned
                // to the queue's unsigned max-size-buffers property, silently making
                // the queue unbounded instead of bounded as the user intended.
                fprintf(stderr, "Error: Invalid queue buffer size '%s'. Must be >= 0 (0 = unlimited)\n",
                        argv[i + 1]);
                print_usage(argv[0]);
                free_configuration(config);
                return FALSE;
            }
            config->queue_buffer_size = qsize;
            i++;
        } else if (strcmp(argv[i], "--ingest-type") == 0 && i + 1 < argc) {
            if (g_ascii_strcasecmp(argv[i + 1], "rtmp") == 0) {
                config->ingest_type = INGEST_RTMP;
            } else if (g_ascii_strcasecmp(argv[i + 1], "whip") == 0) {
                config->ingest_type = INGEST_WHIP;
            } else {
                fprintf(stderr, "Warning: Unrecognized ingest type '%s', defaulting to 'whip'\n", argv[i + 1]);
                config->ingest_type = INGEST_WHIP;
            }
            i++;
        } else if (strcmp(argv[i], "--rtmp-endpoint") == 0 && i + 1 < argc) {
            if (config->rtmp_endpoint) {
                g_free(config->rtmp_endpoint);
            }
            config->rtmp_endpoint = g_strdup(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--stream-key") == 0 && i + 1 < argc) {
            if (config->stream_key) {
                g_free(config->stream_key);
            }
            config->stream_key = g_strdup(argv[i + 1]);
            i++;
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            print_usage(argv[0]);
            free_configuration(config);
            return FALSE;
        } else {
            fprintf(stderr, "Unknown argument: %s\n", argv[i]);
            print_usage(argv[0]);
            free_configuration(config);
            return FALSE;
        }
    }

    // Validate required configuration based on ingest type
    if (config->ingest_type == INGEST_RTMP) {
        // RTMP mode: require rtmp_endpoint and stream_key, skip WHIP fields
        if (!config->rtmp_endpoint || strlen(config->rtmp_endpoint) == 0) {
            fprintf(stderr, "ERROR: Missing RTMP endpoint URL\n");
            fprintf(stderr, "  Set RTMP_ENDPOINT environment variable or use --rtmp-endpoint argument\n");
            print_usage(argv[0]);
            free_configuration(config);
            return FALSE;
        }

        if (!config->stream_key || strlen(config->stream_key) == 0) {
            fprintf(stderr, "ERROR: Missing RTMP stream key\n");
            fprintf(stderr, "  Set STREAM_KEY environment variable or use --stream-key argument\n");
            print_usage(argv[0]);
            free_configuration(config);
            return FALSE;
        }
    } else {
        // WHIP mode (default): require auth_token and whip_endpoint, skip RTMP fields
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

    if (config->rtmp_endpoint) {
        g_free(config->rtmp_endpoint);
        config->rtmp_endpoint = NULL;
    }

    if (config->stream_key) {
        g_free(config->stream_key);
        config->stream_key = NULL;
    }
}

/**
 * Print usage information to stderr.
 */
void print_usage(const char *program_name) {
    fprintf(stderr, "\nUsage: %s [OPTIONS]\n", program_name);
    fprintf(stderr, "\nIngest type:\n");
    fprintf(stderr, "  --ingest-type <type>     Protocol: 'whip' or 'rtmp' [default: whip]\n");
    fprintf(stderr, "\nWHIP options (required when ingest type is 'whip'):\n");
    fprintf(stderr, "  --auth-token <token>     Authentication token (or IVS_STAGE_TOKEN)\n");
    fprintf(stderr, "  --whip-endpoint <url>    WHIP endpoint URL (or IVS_WHIP_ENDPOINT)\n");
    fprintf(stderr, "\nRTMP options (required when ingest type is 'rtmp'):\n");
    fprintf(stderr, "  --rtmp-endpoint <url>    RTMP ingest server URL (or RTMP_ENDPOINT)\n");
    fprintf(stderr, "  --stream-key <key>       RTMP stream key (or STREAM_KEY)\n");
    fprintf(stderr, "\nEncoder options:\n");
    fprintf(stderr, "  --encoder <type>         Encoder: 'gpu' (NVIDIA) or 'cpu' (x264) [default: gpu]\n");
    fprintf(stderr, "\nVideo options:\n");
    fprintf(stderr, "  --width <pixels>         Video width [default: 1280]\n");
    fprintf(stderr, "  --height <pixels>        Video height [default: 720]\n");
    fprintf(stderr, "  --framerate <fps>        Video framerate [default: 30]\n");
    fprintf(stderr, "  --video-bitrate <kbps>   Video bitrate in kbps [default: 4000]\n");
    fprintf(stderr, "  --queue-buffer-size <n>  Video queue depth in buffers [default: 5, 0=unlimited]\n");
    fprintf(stderr, "\nAudio options:\n");
    fprintf(stderr, "  --no-audio               Disable audio capture\n");
    fprintf(stderr, "  --audio-bitrate <bps>    Audio bitrate in bps [default: 128000]\n");
    fprintf(stderr, "\nDebug options:\n");
    fprintf(stderr, "  --debug                  Print pipeline string for debugging\n");
    fprintf(stderr, "  --help, -h               Show this help message\n");
    fprintf(stderr, "\nEnvironment variables:\n");
    fprintf(stderr, "  INGEST_TYPE, IVS_STAGE_TOKEN, IVS_WHIP_ENDPOINT, RTMP_ENDPOINT,\n");
    fprintf(stderr, "  STREAM_KEY, ENCODER_TYPE, ENABLE_AUDIO, DEBUG_PIPELINE,\n");
    fprintf(stderr, "  VIDEO_WIDTH, VIDEO_HEIGHT, VIDEO_FRAMERATE, VIDEO_BITRATE,\n");
    fprintf(stderr, "  AUDIO_BITRATE, QUEUE_BUFFER_SIZE\n\n");
}
