#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>

/**
 * Simple test program for the configuration module.
 * Tests various scenarios for parsing configuration.
 */

/* Helper to clear all env vars between tests to prevent leakage */
static void clear_all_env_vars() {
    g_unsetenv("IVS_STAGE_TOKEN");
    g_unsetenv("IVS_WHIP_ENDPOINT");
    g_unsetenv("INGEST_TYPE");
    g_unsetenv("RTMP_ENDPOINT");
    g_unsetenv("STREAM_KEY");
    g_unsetenv("ENCODER_TYPE");
    g_unsetenv("ENABLE_AUDIO");
    g_unsetenv("DEBUG_PIPELINE");
    g_unsetenv("VIDEO_WIDTH");
    g_unsetenv("VIDEO_HEIGHT");
    g_unsetenv("VIDEO_FRAMERATE");
    g_unsetenv("VIDEO_BITRATE");
    g_unsetenv("AUDIO_BITRATE");
    g_unsetenv("QUEUE_BUFFER_SIZE");
}

void test_env_variables() {
    printf("Test 1: Environment variables only\n");
    clear_all_env_vars();
    
    // Set environment variables
    g_setenv("IVS_STAGE_TOKEN", "test_token_123", TRUE);
    g_setenv("IVS_WHIP_ENDPOINT", "https://test.example.com/whip", TRUE);
    
    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;
    
    if (parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration parsed successfully\n");
        printf("  Auth token: %s\n", config.auth_token);
        printf("  WHIP endpoint: %s\n", config.whip_endpoint);
        
        if (strcmp(config.auth_token, "test_token_123") == 0 &&
            strcmp(config.whip_endpoint, "https://test.example.com/whip") == 0) {
            printf("  ✓ Values match expected\n");
        } else {
            printf("  ✗ Values do not match expected\n");
        }
        
        free_configuration(&config);
    } else {
        printf("  ✗ Configuration parsing failed\n");
    }
    
    printf("\n");
}

void test_command_line_args() {
    printf("Test 2: Command-line arguments only\n");
    clear_all_env_vars();
    
    Config config;
    char *argv[] = {
        "test_program",
        "--auth-token", "cmdline_token_456",
        "--whip-endpoint", "https://cmdline.example.com/whip"
    };
    int argc = 5;
    
    if (parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration parsed successfully\n");
        printf("  Auth token: %s\n", config.auth_token);
        printf("  WHIP endpoint: %s\n", config.whip_endpoint);
        
        if (strcmp(config.auth_token, "cmdline_token_456") == 0 &&
            strcmp(config.whip_endpoint, "https://cmdline.example.com/whip") == 0) {
            printf("  ✓ Values match expected\n");
        } else {
            printf("  ✗ Values do not match expected\n");
        }
        
        free_configuration(&config);
    } else {
        printf("  ✗ Configuration parsing failed\n");
    }
    
    printf("\n");
}

void test_override() {
    printf("Test 3: Command-line arguments override environment variables\n");
    clear_all_env_vars();
    
    // Set environment variables
    g_setenv("IVS_STAGE_TOKEN", "env_token", TRUE);
    g_setenv("IVS_WHIP_ENDPOINT", "https://env.example.com/whip", TRUE);
    
    Config config;
    char *argv[] = {
        "test_program",
        "--auth-token", "override_token",
        "--whip-endpoint", "https://override.example.com/whip"
    };
    int argc = 5;
    
    if (parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration parsed successfully\n");
        printf("  Auth token: %s\n", config.auth_token);
        printf("  WHIP endpoint: %s\n", config.whip_endpoint);
        
        if (strcmp(config.auth_token, "override_token") == 0 &&
            strcmp(config.whip_endpoint, "https://override.example.com/whip") == 0) {
            printf("  ✓ Command-line arguments correctly override environment variables\n");
        } else {
            printf("  ✗ Override failed\n");
        }
        
        free_configuration(&config);
    } else {
        printf("  ✗ Configuration parsing failed\n");
    }
    
    printf("\n");
}

void test_missing_config() {
    printf("Test 4: Missing configuration (should fail)\n");
    clear_all_env_vars();
    
    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;
    
    if (!parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration correctly rejected (missing parameters)\n");
    } else {
        printf("  ✗ Configuration should have failed but didn't\n");
        free_configuration(&config);
    }
    
    printf("\n");
}

void test_partial_config() {
    printf("Test 5: Partial configuration - only token (should fail)\n");
    clear_all_env_vars();
    
    // Set only token
    g_setenv("IVS_STAGE_TOKEN", "test_token", TRUE);
    
    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;
    
    if (!parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration correctly rejected (missing endpoint)\n");
    } else {
        printf("  ✗ Configuration should have failed but didn't\n");
        free_configuration(&config);
    }
    
    printf("\n");
}

void test_rtmp_env_var_parsing() {
    printf("Test 6: RTMP environment variable parsing\n");
    clear_all_env_vars();

    g_setenv("INGEST_TYPE", "rtmp", TRUE);
    g_setenv("RTMP_ENDPOINT", "rtmp://ingest.example.com/app", TRUE);
    g_setenv("STREAM_KEY", "sk_test_key_123", TRUE);

    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;

    if (parse_configuration(argc, argv, &config)) {
        printf("  ✓ RTMP configuration parsed successfully\n");

        if (config.ingest_type == INGEST_RTMP) {
            printf("  ✓ Ingest type is INGEST_RTMP\n");
        } else {
            printf("  ✗ Ingest type should be INGEST_RTMP\n");
        }

        if (config.rtmp_endpoint && strcmp(config.rtmp_endpoint, "rtmp://ingest.example.com/app") == 0) {
            printf("  ✓ RTMP endpoint matches\n");
        } else {
            printf("  ✗ RTMP endpoint does not match\n");
        }

        if (config.stream_key && strcmp(config.stream_key, "sk_test_key_123") == 0) {
            printf("  ✓ Stream key matches\n");
        } else {
            printf("  ✗ Stream key does not match\n");
        }

        free_configuration(&config);
    } else {
        printf("  ✗ RTMP configuration parsing failed\n");
    }

    printf("\n");
}

void test_default_ingest_type() {
    printf("Test 7: Default ingest type when INGEST_TYPE is not set\n");
    clear_all_env_vars();

    g_setenv("IVS_STAGE_TOKEN", "test_token", TRUE);
    g_setenv("IVS_WHIP_ENDPOINT", "https://test.example.com/whip", TRUE);

    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;

    if (parse_configuration(argc, argv, &config)) {
        if (config.ingest_type == INGEST_WHIP) {
            printf("  ✓ Default ingest type is INGEST_WHIP\n");
        } else {
            printf("  ✗ Default ingest type should be INGEST_WHIP\n");
        }
        free_configuration(&config);
    } else {
        printf("  ✗ Configuration parsing failed\n");
    }

    printf("\n");
}

void test_invalid_ingest_type_defaults_to_whip() {
    printf("Test 8: Invalid INGEST_TYPE defaults to whip\n");
    clear_all_env_vars();

    g_setenv("INGEST_TYPE", "invalid_protocol", TRUE);
    g_setenv("IVS_STAGE_TOKEN", "test_token", TRUE);
    g_setenv("IVS_WHIP_ENDPOINT", "https://test.example.com/whip", TRUE);

    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;

    if (parse_configuration(argc, argv, &config)) {
        if (config.ingest_type == INGEST_WHIP) {
            printf("  ✓ Invalid ingest type correctly defaults to INGEST_WHIP\n");
        } else {
            printf("  ✗ Should have defaulted to INGEST_WHIP\n");
        }
        free_configuration(&config);
    } else {
        printf("  ✗ Configuration parsing failed\n");
    }

    printf("\n");
}

void test_missing_rtmp_endpoint_rejection() {
    printf("Test 9: Missing RTMP endpoint rejection\n");
    clear_all_env_vars();

    g_setenv("INGEST_TYPE", "rtmp", TRUE);
    g_setenv("STREAM_KEY", "sk_test_key", TRUE);
    /* RTMP_ENDPOINT intentionally not set */

    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;

    if (!parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration correctly rejected (missing RTMP endpoint)\n");
    } else {
        printf("  ✗ Configuration should have failed without RTMP endpoint\n");
        free_configuration(&config);
    }

    printf("\n");
}

void test_missing_stream_key_rejection() {
    printf("Test 10: Missing stream key rejection\n");
    clear_all_env_vars();

    g_setenv("INGEST_TYPE", "rtmp", TRUE);
    g_setenv("RTMP_ENDPOINT", "rtmp://ingest.example.com/app", TRUE);
    /* STREAM_KEY intentionally not set */

    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;

    if (!parse_configuration(argc, argv, &config)) {
        printf("  ✓ Configuration correctly rejected (missing stream key)\n");
    } else {
        printf("  ✗ Configuration should have failed without stream key\n");
        free_configuration(&config);
    }

    printf("\n");
}

void test_rtmp_cli_overrides() {
    printf("Test 11: CLI overrides for RTMP fields\n");
    clear_all_env_vars();

    g_setenv("INGEST_TYPE", "whip", TRUE);
    g_setenv("RTMP_ENDPOINT", "rtmp://env.example.com/app", TRUE);
    g_setenv("STREAM_KEY", "env_key", TRUE);

    Config config;
    char *argv[] = {
        "test_program",
        "--ingest-type", "rtmp",
        "--rtmp-endpoint", "rtmp://cli.example.com/app",
        "--stream-key", "cli_key"
    };
    int argc = 7;

    if (parse_configuration(argc, argv, &config)) {
        int pass = 1;

        if (config.ingest_type == INGEST_RTMP) {
            printf("  ✓ CLI --ingest-type overrides env INGEST_TYPE\n");
        } else {
            printf("  ✗ CLI --ingest-type did not override env\n");
            pass = 0;
        }

        if (config.rtmp_endpoint && strcmp(config.rtmp_endpoint, "rtmp://cli.example.com/app") == 0) {
            printf("  ✓ CLI --rtmp-endpoint overrides env RTMP_ENDPOINT\n");
        } else {
            printf("  ✗ CLI --rtmp-endpoint did not override env\n");
            pass = 0;
        }

        if (config.stream_key && strcmp(config.stream_key, "cli_key") == 0) {
            printf("  ✓ CLI --stream-key overrides env STREAM_KEY\n");
        } else {
            printf("  ✗ CLI --stream-key did not override env\n");
            pass = 0;
        }

        if (pass) {
            printf("  ✓ All CLI overrides work correctly\n");
        }

        free_configuration(&config);
    } else {
        printf("  ✗ Configuration parsing failed\n");
    }

    printf("\n");
}

void test_whip_config_unchanged() {
    printf("Test 12: WHIP config still works unchanged with RTMP code present\n");
    clear_all_env_vars();

    g_setenv("INGEST_TYPE", "whip", TRUE);
    g_setenv("IVS_STAGE_TOKEN", "whip_token", TRUE);
    g_setenv("IVS_WHIP_ENDPOINT", "https://whip.example.com/whip", TRUE);

    Config config;
    char *argv[] = {"test_program"};
    int argc = 1;

    if (parse_configuration(argc, argv, &config)) {
        int pass = 1;

        if (config.ingest_type == INGEST_WHIP) {
            printf("  ✓ Ingest type is INGEST_WHIP\n");
        } else {
            printf("  ✗ Ingest type should be INGEST_WHIP\n");
            pass = 0;
        }

        if (config.auth_token && strcmp(config.auth_token, "whip_token") == 0) {
            printf("  ✓ Auth token matches\n");
        } else {
            printf("  ✗ Auth token does not match\n");
            pass = 0;
        }

        if (config.whip_endpoint && strcmp(config.whip_endpoint, "https://whip.example.com/whip") == 0) {
            printf("  ✓ WHIP endpoint matches\n");
        } else {
            printf("  ✗ WHIP endpoint does not match\n");
            pass = 0;
        }

        if (pass) {
            printf("  ✓ WHIP configuration works correctly alongside RTMP code\n");
        }

        free_configuration(&config);
    } else {
        printf("  ✗ WHIP configuration parsing failed\n");
    }

    printf("\n");
}

int main(int argc, char *argv[]) {
    printf("=== Configuration Module Tests ===\n\n");
    
    test_env_variables();
    test_command_line_args();
    test_override();
    test_missing_config();
    test_partial_config();

    /* RTMP configuration tests */
    test_rtmp_env_var_parsing();
    test_default_ingest_type();
    test_invalid_ingest_type_defaults_to_whip();
    test_missing_rtmp_endpoint_rejection();
    test_missing_stream_key_rejection();
    test_rtmp_cli_overrides();
    test_whip_config_unchanged();
    
    printf("=== Tests Complete ===\n");
    
    return 0;
}
