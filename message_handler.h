#ifndef MESSAGE_HANDLER_H
#define MESSAGE_HANDLER_H

#include <gst/gst.h>

/**
 * GStreamer bus message handler callback.
 * 
 * Processes messages from the GStreamer pipeline message bus and handles:
 * - GST_MESSAGE_ERROR: Pipeline errors with descriptive console output
 * - GST_MESSAGE_EOS: End-of-stream notifications
 * - GST_MESSAGE_STATE_CHANGED: Pipeline state transitions
 * - GST_MESSAGE_WARNING: Pipeline warnings
 * 
 * This function is designed to be used with g_bus_add_watch() or similar
 * GStreamer bus monitoring mechanisms.
 * 
 * @param bus The GStreamer message bus
 * @param message The message received from the bus
 * @param user_data User data pointer (typically the main loop or pipeline)
 * @return TRUE to continue receiving messages, FALSE to stop
 */
gboolean bus_message_handler(GstBus *bus, GstMessage *message, gpointer user_data);

#endif // MESSAGE_HANDLER_H
