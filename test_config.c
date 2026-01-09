#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>

/**
 * Simple test program for the configuration module.
 * Tests various scenarios for parsing configuration.
 */

void test_env_variables() {
    printf("Test 1: Environment variables only\n");
    
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
    
    // Clear environment variables
    g_unsetenv("IVS_STAGE_TOKEN");
    g_unsetenv("IVS_WHIP_ENDPOINT");
    
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
    
    // Clear environment variables
    g_unsetenv("IVS_STAGE_TOKEN");
    g_unsetenv("IVS_WHIP_ENDPOINT");
    
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
    
    // Set only token
    g_setenv("IVS_STAGE_TOKEN", "test_token", TRUE);
    g_unsetenv("IVS_WHIP_ENDPOINT");
    
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

int main(int argc, char *argv[]) {
    printf("=== Configuration Module Tests ===\n\n");
    
    test_env_variables();
    test_command_line_args();
    test_override();
    test_missing_config();
    test_partial_config();
    
    printf("=== Tests Complete ===\n");
    
    return 0;
}
