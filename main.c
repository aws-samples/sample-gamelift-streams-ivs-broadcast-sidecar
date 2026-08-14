#include <gst/gst.h>
#include <glib.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include "config.h"
#include "pipeline.h"
#include "message_handler.h"

// Global variables for signal handling
static GMainLoop *main_loop = NULL;
static GstElement *pipeline = NULL;

/**
 * Signal handler for Ctrl+C (SIGINT) and other termination signals.
 * Initiates graceful shutdown of the pipeline and main loop.
 * 
 * @param signum Signal number received
 */
static void signal_handler(int signum) {
    g_print("\nReceived signal %d, shutting down gracefully...\n", signum);
    
    if (main_loop) {
        g_main_loop_quit(main_loop);
    }
}

/**
 * Cleanup function to properly shut down the pipeline and free resources.
 */
static void cleanup_pipeline(GstElement *pipeline) {
    if (pipeline) {
        set_pipeline_state(pipeline, GST_STATE_NULL);
        gst_object_unref(pipeline);
    }
}

/**
 * Main application entry point.
 * Initializes GStreamer, parses configuration, creates pipeline,
 * sets up message bus monitoring, and handles lifecycle management.
 */
int main(int argc, char *argv[]) {
    Config config = {0};
    GError *error = NULL;
    GstBus *bus = NULL;
    
    // Initialize GStreamer
    gst_init(&argc, &argv);
    
    // Rescan plugins if GST_PLUGIN_PATH is set
    const char *plugin_path = g_getenv("GST_PLUGIN_PATH");
    if (plugin_path) {
        GstRegistry *registry = gst_registry_get();
        if (registry) {
            g_print("Rescanning GStreamer plugins from: %s\n", plugin_path);
            gst_registry_scan_path(registry, plugin_path);
        }
    } else {
        g_print("Note: GST_PLUGIN_PATH not set. Using system GStreamer plugins.\n");
    }
    
    // Parse configuration
    if (!parse_configuration(argc, argv, &config)) {
        gst_deinit();
        return 1;
    }
    
    // Create pipeline
    pipeline = create_pipeline(&config, &error);
    if (!pipeline) {
        g_printerr("ERROR: Failed to create pipeline\n");
        if (error) {
            g_printerr("  %s\n", error->message);
            g_error_free(error);
        }
        free_configuration(&config);
        gst_deinit();
        return 1;
    }
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Create main loop and set up message bus
    main_loop = g_main_loop_new(NULL, FALSE);
    bus = gst_element_get_bus(pipeline);
    gst_bus_add_watch(bus, bus_message_handler, main_loop);
    gst_object_unref(bus);
    
    // Start streaming
    if (!set_pipeline_state(pipeline, GST_STATE_PLAYING)) {
        g_printerr("ERROR: Failed to start pipeline\n");
        cleanup_pipeline(pipeline);
        g_main_loop_unref(main_loop);
        free_configuration(&config);
        gst_deinit();
        return 1;
    }
    
    if (config.ingest_type == INGEST_RTMP) {
        g_print("Streaming to RTMP endpoint. Press Ctrl+C to stop.\n");
    } else {
        g_print("Streaming to WHIP endpoint. Press Ctrl+C to stop.\n");
    }
    
    // Run main loop
    g_main_loop_run(main_loop);
    
    // Cleanup
    cleanup_pipeline(pipeline);
    g_main_loop_unref(main_loop);
    free_configuration(&config);
    gst_deinit();
    
    return 0;
}
