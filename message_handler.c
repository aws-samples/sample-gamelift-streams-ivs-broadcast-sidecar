#include "message_handler.h"
#include <stdio.h>

/**
 * Get the factory (element type) name for a bus message source.
 *
 * Prefer this over GST_OBJECT_NAME for dispatching troubleshooting guidance:
 * instance names come from the pipeline description, so "flvmux name=mux" yields
 * the instance name "mux" and would silently stop matching a check written
 * against "flvmux". The factory name is stable regardless of how the pipeline
 * description names the element.
 *
 * Returns NULL if the source is not an element or has no factory (e.g. a pad,
 * or an element created without a factory).
 */
static const gchar* get_factory_name(GstObject *src) {
    if (!GST_IS_ELEMENT(src)) {
        return NULL;
    }
    GstElementFactory *factory = gst_element_get_factory(GST_ELEMENT(src));
    return factory ? GST_OBJECT_NAME(factory) : NULL;
}

gboolean bus_message_handler(GstBus *bus, GstMessage *message, gpointer user_data) {
    GMainLoop *loop = (GMainLoop *)user_data;
    
    switch (GST_MESSAGE_TYPE(message)) {
        case GST_MESSAGE_ERROR: {
            GError *error = NULL;
            gchar *debug_info = NULL;
            
            // Extract error information
            gst_message_parse_error(message, &error, &debug_info);
            
            // Print descriptive error message to console
            fprintf(stderr, "\n========================================\n");
            fprintf(stderr, "PIPELINE ERROR DETECTED\n");
            fprintf(stderr, "========================================\n");
            // Dispatch on the factory name so renaming an element in the pipeline
            // description cannot silently disable the matching guidance below.
            const gchar *instance_name = GST_OBJECT_NAME(message->src);
            const gchar *factory_name = get_factory_name(message->src);
            const gchar *match_name = factory_name ? factory_name : instance_name;

            fprintf(stderr, "Source Element: %s", instance_name);
            if (factory_name) {
                fprintf(stderr, " (%s)", factory_name);
            }
            fprintf(stderr, "\n");
            fprintf(stderr, "Error Message: %s\n", error->message);
            fprintf(stderr, "Error Domain: %s\n", g_quark_to_string(error->domain));
            fprintf(stderr, "Error Code: %d\n", error->code);

            if (debug_info) {
                fprintf(stderr, "Debug Information:\n%s\n", debug_info);
            }

            fprintf(stderr, "\nTroubleshooting:\n");

            if (g_str_has_prefix(match_name, "d3d12")) {
                fprintf(stderr, "  - Check that Direct3D 12 is available on your system\n");
                fprintf(stderr, "  - Verify screen capture permissions\n");
                fprintf(stderr, "  - Ensure no other application is blocking screen capture\n");
            } else if (g_str_has_prefix(match_name, "x264") ||
                       g_strrstr(match_name, "h264enc") != NULL) {
                // Covers the CPU encoder (x264enc) and the NVIDIA encoders
                // (nvcudah264enc, nvh264enc) - the GPU encoder is the default.
                fprintf(stderr, "  - Verify the encoder plugin is installed (x264 for CPU, nvcodec for GPU)\n");
                fprintf(stderr, "  - For GPU encoding, check the NVIDIA driver is loaded (nvidia-smi)\n");
                fprintf(stderr, "  - Try --encoder cpu to rule out a GPU/driver problem\n");
                fprintf(stderr, "  - Check system resources (CPU/memory)\n");
                fprintf(stderr, "  - Verify input video format is compatible\n");
            } else if (g_str_has_prefix(match_name, "whip")) {
                fprintf(stderr, "  - Verify WHIP endpoint URL is correct and reachable\n");
                fprintf(stderr, "  - Check authentication token is valid\n");
                fprintf(stderr, "  - Ensure network connectivity to the endpoint\n");
                fprintf(stderr, "  - Verify firewall settings allow outbound connections\n");
            } else if (g_str_has_prefix(match_name, "rtmp")) {
                fprintf(stderr, "  - Verify the RTMP endpoint URL is correct and reachable\n");
                fprintf(stderr, "  - Check that the stream key is valid\n");
                fprintf(stderr, "  - Check the outbound port is not blocked by a firewall\n");
                fprintf(stderr, "    (IVS uses RTMPS on port 443; plain RTMP typically uses 1935)\n");
                fprintf(stderr, "  - Ensure network connectivity to the RTMP ingest server\n");
            } else if (g_str_has_prefix(match_name, "flvmux")) {
                fprintf(stderr, "  - Check that the video stream is H.264 encoded\n");
                fprintf(stderr, "  - Check that the audio stream is AAC encoded\n");
                fprintf(stderr, "  - Verify audio/video format compatibility with FLV container\n");
            } else {
                fprintf(stderr, "  - Check GStreamer installation and plugins\n");
                fprintf(stderr, "  - Verify system resources are available\n");
                fprintf(stderr, "  - Review pipeline configuration\n");
            }
            
            fprintf(stderr, "========================================\n\n");
            
            // Clean up
            g_clear_error(&error);
            g_free(debug_info);
            
            // Stop the main loop on error
            if (loop) {
                g_main_loop_quit(loop);
            }
            
            return FALSE;
        }
        
        case GST_MESSAGE_EOS: {
            // End-of-stream reached
            printf("End-of-stream reached.\n");
            
            // Stop the main loop
            if (loop) {
                g_main_loop_quit(loop);
            }
            
            return FALSE;
        }
        
        case GST_MESSAGE_STATE_CHANGED: {
            // Only report state changes from the pipeline itself (not individual elements)
            if (GST_IS_PIPELINE(GST_MESSAGE_SRC(message))) {
                GstState old_state, new_state, pending_state;
                gst_message_parse_state_changed(message, &old_state, &new_state, &pending_state);
                
                printf("Pipeline state changed from %s to %s\n",
                       gst_element_state_get_name(old_state),
                       gst_element_state_get_name(new_state));
            }
            break;
        }
        
        case GST_MESSAGE_WARNING: {
            GError *warning = NULL;
            gchar *debug_info = NULL;
            
            // Extract warning information
            gst_message_parse_warning(message, &warning, &debug_info);
            
            // Print warning message to console with more context
            const gchar *warn_factory = get_factory_name(message->src);
            fprintf(stderr, "\n--- PIPELINE WARNING ---\n");
            fprintf(stderr, "Source Element: %s", GST_OBJECT_NAME(message->src));
            if (warn_factory) {
                fprintf(stderr, " (%s)", warn_factory);
            }
            fprintf(stderr, "\n");
            fprintf(stderr, "Warning: %s\n", warning->message);
            
            if (debug_info) {
                fprintf(stderr, "Debug info: %s\n", debug_info);
            }
            
            fprintf(stderr, "Note: Pipeline continues running, but performance may be affected\n");
            fprintf(stderr, "------------------------\n\n");
            
            // Clean up
            g_clear_error(&warning);
            g_free(debug_info);
            break;
        }
        
        default:
            // Ignore other message types
            break;
    }
    
    return TRUE;
}
