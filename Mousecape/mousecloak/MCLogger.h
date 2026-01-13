//
//  MCLogger.h
//  Mousecape
//
//  Debug logging system for Mousecape.
//  Only active when DEBUG macro is defined.
//

#ifndef MCLogger_h
#define MCLogger_h

#import <Foundation/Foundation.h>

#ifdef DEBUG

/// Initialize the logging system, create log file
void MCLoggerInit(void);

/// Write to log (outputs to both stdout and file)
void MCLoggerWrite(const char *format, ...) __attribute__((format(printf, 1, 2)));

/// Get the log file path
NSString *MCLoggerGetLogPath(void);

/// Close the log file
void MCLoggerClose(void);

#else

// No-op macros for Release builds
#define MCLoggerInit() ((void)0)
#define MCLoggerWrite(...) ((void)0)
#define MCLoggerGetLogPath() (nil)
#define MCLoggerClose() ((void)0)

#endif

#endif /* MCLogger_h */
