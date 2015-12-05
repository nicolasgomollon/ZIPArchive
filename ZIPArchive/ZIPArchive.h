//
//  ZIPArchive.h
//  ZIPArchive
//
//  Original code Copyright (c) 2008 Aish (acsolu@gmail.com). All rights reserved.
//  Re-adaptation Copyright (c) 2015 Nicolas Gomollon. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZIPArchive : NSObject

// Instance Methods

- (instancetype)initWithFileURL:(NSURL *)fileURL;
- (BOOL)addFileToArchive:(NSURL *)fileURL;
- (BOOL)addFileToArchive:(NSURL *)fileURL directoryPath:(nullable NSString *)path;
- (NSUInteger)addDirectoryToArchive:(NSURL *)directoryURL;
- (NSUInteger)addDirectoryToArchive:(NSURL *)directoryURL directoryPath:(nullable NSString *)path;
- (BOOL)writeToFile;

// Class Methods

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL;
+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL error:(NSError **)error;

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL overwrite:(BOOL)overwrite;
+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL overwrite:(BOOL)overwrite error:(NSError **)error;

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL password:(NSString *)password;
+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL password:(NSString *)password error:(NSError **)error;

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL overwrite:(BOOL)overwrite password:(nullable NSString *)password error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
