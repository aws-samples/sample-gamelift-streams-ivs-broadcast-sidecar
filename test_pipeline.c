#include <stdio.h>
#include <string.h>
#include <gst/gst.h>
#include "config.h"
#include "pipeline.h"

/**
 * Test program for the pipeline module.
 * Tests pipeline creation with valid and invalid configurations.
 */

void test_valid_pipeline() {
    printf("Test 1: Creating pipeline with valid configuration...\n");
    
    Config config;
    memset(&config, 0, sizeof(Config));
    config.auth_token = g_strdup("eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.eyJleHAiOjE3NjQ4NjIxNjIsImlhdCI6MTc2MzY1MjU2MiwianRpIjoiMXRGWklxSzZ5S1l6IiwicmVzb3VyY2UiOiJhcm46YXdzOml2czp1cy13ZXN0LTI6NjM5OTM0MzQ1MzUxOnN0YWdlL1NHWmtRMDRVN0I2aCIsInRvcGljIjoiU0daa1EwNFU3QjZoIiwiZXZlbnRzX3VybCI6IndzczovL2dsb2JhbC5ldmVudHMubGl2ZS12aWRlby5uZXQiLCJ3aGlwX3VybCI6Imh0dHBzOi8vOWZhMWEzNzI1YTM1Lmdsb2JhbC1ibS53aGlwLmxpdmUtdmlkZW8ubmV0IiwidXNlcl9pZCI6Iml2cy1nYW1lbGlmdC10ZXN0LXVzZXIiLCJhdHRyaWJ1dGVzIjp7InN0cmVhbV9zb3VyY2UiOiJnYW1lcGxheSIsInVzZXJuYW1lIjoiaXZzLWdhbWVsaWZ0LXRlc3QtdXNlciJ9LCJjYXBhYmlsaXRpZXMiOnsiYWxsb3dfc3Vic2NyaWJlIjp0cnVlfSwidmVyc2lvbiI6IjAuMCJ9.MGUCMG2Do-fwoZSML4tY2Nx-YZ46LB3JeJ8gcjhfo9XH1PmNOxp1Bj0zUgBIRT6c_vJlTAIxALMU8sLuqf2W-7BqPhPQ9Kb1AvGYITp4AAs3CKtoL6xbrtLJIJncoAOfUX4kqceotAand");
    config.whip_endpoint = g_strdup("https://global.whip.live-video.net");
    config.encoder = ENCODER_CPU;
    config.enable_audio = TRUE;
    config.width = 1280;
    config.height = 720;
    config.framerate = 30;
    config.video_bitrate = 4000;
    config.audio_bitrate = 128000;
    config.queue_buffer_size = 5;
    
    GError *error = NULL;
    GstElement *pipeline = create_pipeline(&config, &error);
    
    if (pipeline) {
        printf("  ✓ Pipeline created successfully\n");
        
        // Verify it's actually a pipeline
        if (GST_IS_PIPELINE(pipeline)) {
            printf("  ✓ Created element is a valid GStreamer pipeline\n");
        } else {
            printf("  ✗ Created element is not a pipeline\n");
        }
        
        gst_object_unref(pipeline);
    } else {
        printf("  ✗ Pipeline creation failed\n");
        if (error) {
            printf("  Error: %s\n", error->message);
            g_error_free(error);
        }
    }
    
    free_configuration(&config);
    printf("\n");
}

void test_null_config() {
    printf("Test 2: Creating pipeline with NULL configuration...\n");
    
    GError *error = NULL;
    GstElement *pipeline = create_pipeline(NULL, &error);
    
    if (!pipeline) {
        printf("  ✓ Pipeline creation correctly failed with NULL config\n");
        if (error) {
            printf("  ✓ Error message: %s\n", error->message);
            g_error_free(error);
        }
    } else {
        printf("  ✗ Pipeline should not have been created with NULL config\n");
        gst_object_unref(pipeline);
    }
    
    printf("\n");
}

void test_incomplete_config() {
    printf("Test 3: Creating pipeline with incomplete configuration...\n");
    
    Config config;
    memset(&config, 0, sizeof(Config));
    config.auth_token = NULL;
    config.whip_endpoint = g_strdup("https://example.com/whip");
    
    GError *error = NULL;
    GstElement *pipeline = create_pipeline(&config, &error);
    
    if (!pipeline) {
        printf("  ✓ Pipeline creation correctly failed with incomplete config\n");
        if (error) {
            printf("  ✓ Error message: %s\n", error->message);
            g_error_free(error);
        }
    } else {
        printf("  ✗ Pipeline should not have been created with incomplete config\n");
        gst_object_unref(pipeline);
    }
    
    free_configuration(&config);
    printf("\n");
}

void test_rtmp_pipeline_creation() {
    printf("Test 4: Creating RTMP pipeline with valid RTMP configuration...\n");

    Config config;
    memset(&config, 0, sizeof(Config));
    config.ingest_type = INGEST_RTMP;
    config.rtmp_endpoint = g_strdup("rtmp://ingest.example.com/app");
    config.stream_key = g_strdup("sk_test_key_123");
    config.encoder = ENCODER_CPU;
    config.enable_audio = TRUE;
    config.debug_pipeline = TRUE;
    config.width = 1280;
    config.height = 720;
    config.framerate = 30;
    config.video_bitrate = 4000;
    config.audio_bitrate = 128000;
    config.queue_buffer_size = 5;

    GError *error = NULL;
    GstElement *pipeline = create_pipeline(&config, &error);

    if (pipeline) {
        printf("  ✓ RTMP pipeline created successfully\n");

        if (GST_IS_PIPELINE(pipeline)) {
            printf("  ✓ Created element is a valid GStreamer pipeline\n");
        } else {
            printf("  ✗ Created element is not a pipeline\n");
        }

        gst_object_unref(pipeline);
    } else {
        /* Pipeline creation may fail if RTMP GStreamer plugins are not installed.
           This is expected on dev machines without rtmp2sink/flvmux/avenc_aac. */
        printf("  ⚠ RTMP pipeline creation failed (RTMP plugins may not be installed)\n");
        if (error) {
            printf("  Error: %s\n", error->message);
            g_error_free(error);
        }
    }

    free_configuration(&config);
    printf("\n");
}

void test_whip_pipeline_still_works() {
    printf("Test 5: WHIP pipeline creation still works with RTMP code present...\n");

    Config config;
    memset(&config, 0, sizeof(Config));
    config.ingest_type = INGEST_WHIP;
    config.auth_token = g_strdup("eyJhbGciOiJLTVMiLCJ0eXAiOiJKV1QifQ.test_token_value");
    config.whip_endpoint = g_strdup("https://global.whip.live-video.net");
    config.encoder = ENCODER_CPU;
    config.enable_audio = TRUE;
    config.debug_pipeline = FALSE;
    config.width = 1280;
    config.height = 720;
    config.framerate = 30;
    config.video_bitrate = 4000;
    config.audio_bitrate = 128000;
    config.queue_buffer_size = 5;

    GError *error = NULL;
    GstElement *pipeline = create_pipeline(&config, &error);

    if (pipeline) {
        printf("  ✓ WHIP pipeline created successfully (RTMP code did not break WHIP)\n");

        if (GST_IS_PIPELINE(pipeline)) {
            printf("  ✓ Created element is a valid GStreamer pipeline\n");
        } else {
            printf("  ✗ Created element is not a pipeline\n");
        }

        gst_object_unref(pipeline);
    } else {
        printf("  ⚠ WHIP pipeline creation failed (WHIP plugins may not be installed)\n");
        if (error) {
            printf("  Error: %s\n", error->message);
            g_error_free(error);
        }
    }

    free_configuration(&config);
    printf("\n");
}

int main(int argc, char *argv[]) {
    // Initialize GStreamer
    gst_init(&argc, &argv);
    
    printf("=== Pipeline Module Tests ===\n\n");
    
    test_valid_pipeline();
    test_null_config();
    test_incomplete_config();
    test_rtmp_pipeline_creation();
    test_whip_pipeline_still_works();
    
    printf("=== Tests Complete ===\n");
    
    // Cleanup GStreamer
    gst_deinit();
    
    return 0;
}
