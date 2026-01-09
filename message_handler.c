#include "message_handler.h"
#include <stdio.h>

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
            fprintf(stderr, "Source Element: %s\n", GST_OBJECT_NAME(message->src));
            fprintf(stderr, "Error Message: %s\n", error->message);
            fprintf(stderr, "Error Domain: %s\n", g_quark_to_string(error->domain));
            fprintf(stderr, "Error Code: %d\n", error->code);
            
            if (debug_info) {
                fprintf(stderr, "Debug Information:\n%s\n", debug_info);
            }
            
            // Provide context-specific guidance based on element name
            const gchar *element_name = GST_OBJECT_NAME(message->src);
            fprintf(stderr, "\nTroubleshooting:\n");
            
            if (g_str_has_prefix(element_name, "d3d12")) {
                fprintf(stderr, "  - Check that Direct3D 12 is available on your system\n");
                fprintf(stderr, "  - Verify screen capture permissions\n");
                fprintf(stderr, "  - Ensure no other application is blocking screen capture\n");
            } else if (g_str_has_prefix(element_name, "x264")) {
                fprintf(stderr, "  - Verify x264 encoder plugin is installed\n");
                fprintf(stderr, "  - Check system resources (CPU/memory)\n");
                fprintf(stderr, "  - Verify input video format is compatible\n");
            } else if (g_str_has_prefix(element_name, "whip")) {
                fprintf(stderr, "  - Verify WHIP endpoint URL is correct and reachable\n");
                fprintf(stderr, "  - Check authentication token is valid\n");
                fprintf(stderr, "  - Ensure network connectivity to the endpoint\n");
                fprintf(stderr, "  - Verify firewall settings allow outbound connections\n");
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
            fprintf(stderr, "\n--- PIPELINE WARNING ---\n");
            fprintf(stderr, "Source Element: %s\n", GST_OBJECT_NAME(message->src));
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
