//
//  MCLogger.m
//  Mousecape
//
//  Debug logging system for Mousecape.
//  Only active when DEBUG macro is defined.
//

#import "MCLogger.h"

#ifdef DEBUG

#include <stdarg.h>
#include <unistd.h>
#import <AppKit/AppKit.h>

static FILE *logFile = NULL;
static NSString *logFilePath = nil;
static NSDateFormatter *timestampFormatter = nil;
static id workspaceNotificationObserver = nil;

// Forward declarations
static void MCLoggerCleanOldLogs(void);
static void MCLoggerRegisterForShutdown(void);

void MCLoggerInit(void) {
    // Initialize timestamp formatter (only once)
    static dispatch_once_t formatterOnce;
    dispatch_once(&formatterOnce, ^{
        timestampFormatter = [[NSDateFormatter alloc] init];
        [timestampFormatter setDateFormat:@"HH:mm:ss.SSS"];
    });

    // Log file path: ~/Library/Logs/Mousecape/mousecloak_YYYY-MM-DD_HH-MM-SS.log
    NSString *logsDir = [@"~/Library/Logs/Mousecape" stringByExpandingTildeInPath];

    // Create directory
    [[NSFileManager defaultManager] createDirectoryAtPath:logsDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    // Clean old logs (keep only last 24 hours)
    MCLoggerCleanOldLogs();

    // Generate timestamped filename
    NSDateFormatter *fileFormatter = [[NSDateFormatter alloc] init];
    [fileFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
    NSString *timestamp = [fileFormatter stringFromDate:[NSDate date]];

    logFilePath = [logsDir stringByAppendingPathComponent:
                   [NSString stringWithFormat:@"mousecloak_%@.log", timestamp]];

    logFile = fopen([logFilePath UTF8String], "a");

    if (logFile) {
        // Redirect stderr to log file to capture system framework errors
        dup2(fileno(logFile), STDERR_FILENO);

        // Write header information
        NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
        MCLoggerWrite("=== Mousecape Debug Log ===");
        MCLoggerWrite("Time: %s", [[NSDate date] description].UTF8String);
        MCLoggerWrite("macOS: %ld.%ld.%ld", (long)ver.majorVersion, (long)ver.minorVersion, (long)ver.patchVersion);
        MCLoggerWrite("User: %s", NSUserName().UTF8String);
        MCLoggerWrite("Home: %s", NSHomeDirectory().UTF8String);
        MCLoggerWrite("Process: %s (PID: %d)",
                      [[[NSProcessInfo processInfo] processName] UTF8String],
                      [[NSProcessInfo processInfo] processIdentifier]);
        MCLoggerWrite("Log file: %s", logFilePath.UTF8String);

        // Log user preferences
        MCLoggerWrite("--- User Preferences ---");

        // Read MCAppliedCursor from CFPreferences
        CFStringRef appliedCursor = CFPreferencesCopyValue(
            CFSTR("MCAppliedCursor"),
            CFSTR("com.alexzielenski.Mousecape"),
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        );
        if (appliedCursor) {
            MCLoggerWrite("  MCAppliedCursor: %s", [(__bridge NSString *)appliedCursor UTF8String]);
            CFRelease(appliedCursor);
        } else {
            MCLoggerWrite("  MCAppliedCursor: (not set)");
        }

        // Read MCCursorScale from CFPreferences
        CFPropertyListRef cursorScale = CFPreferencesCopyValue(
            CFSTR("MCCursorScale"),
            CFSTR("com.alexzielenski.Mousecape"),
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        );
        if (cursorScale) {
            if (CFGetTypeID(cursorScale) == CFNumberGetTypeID()) {
                double scale = 0;
                CFNumberGetValue(cursorScale, kCFNumberDoubleType, &scale);
                MCLoggerWrite("  MCCursorScale: %.2f", scale);
            }
            CFRelease(cursorScale);
        } else {
            MCLoggerWrite("  MCCursorScale: (not set)");
        }

        MCLoggerWrite("=============================");

        // Register for shutdown notification to save logs
        MCLoggerRegisterForShutdown();
    }
}

void MCLoggerWrite(const char *format, ...) {
    va_list args;

    // Output to stdout
    va_start(args, format);
    vfprintf(stdout, format, args);
    fprintf(stdout, "\n");
    fflush(stdout);
    va_end(args);

    // Output to file
    if (logFile) {
        // Add timestamp prefix
        NSString *timestamp = [timestampFormatter stringFromDate:[NSDate date]];
        fprintf(logFile, "[%s] ", timestamp.UTF8String);

        va_start(args, format);
        vfprintf(logFile, format, args);
        fprintf(logFile, "\n");
        va_end(args);

        fflush(logFile);  // Ensure immediate write
    }
}

NSString *MCLoggerGetLogPath(void) {
    return logFilePath;
}

void MCLoggerClose(void) {
    if (logFile) {
        MCLoggerWrite("=== Log End ===");
        fflush(logFile);
        fclose(logFile);
        logFile = NULL;
    }

    // Remove shutdown observer
    if (workspaceNotificationObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:workspaceNotificationObserver];
        workspaceNotificationObserver = nil;
    }
}

// Clean logs older than 24 hours
static void MCLoggerCleanOldLogs(void) {
    NSString *logsDir = [@"~/Library/Logs/Mousecape" stringByExpandingTildeInPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:logsDir error:nil];

    if (!files) return;

    NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-24 * 60 * 60]; // 24 hours ago

    for (NSString *filename in files) {
        if (![filename hasSuffix:@".log"]) continue;

        NSString *fullPath = [logsDir stringByAppendingPathComponent:filename];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        NSDate *modDate = attrs[NSFileModificationDate];

        if (modDate && [modDate compare:cutoffDate] == NSOrderedAscending) {
            // File is older than 24 hours, delete it
            [fm removeItemAtPath:fullPath error:nil];
        }
    }
}

// Register for system shutdown/logout notification to flush logs
static void MCLoggerRegisterForShutdown(void) {
    // Use NSWorkspace notifications for shutdown/logout
    NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];

    workspaceNotificationObserver = [center addObserverForName:NSWorkspaceWillPowerOffNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note) {
        MCLoggerWrite("=== System Shutdown/Logout Detected ===");
        MCLoggerClose();
    }];
}

#endif /* DEBUG */
