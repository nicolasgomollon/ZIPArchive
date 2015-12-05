//
//  ZIPArchive.mm
//  ZIPArchive
//
//  Original code Copyright (c) 2008 Aish (acsolu@gmail.com). All rights reserved.
//  Re-adaptation Copyright (c) 2015 Nicolas Gomollon. All rights reserved.
//

#import "ZIPArchive.h"
#include "zip.h"
#include "unzip.h"
#import "zlib.h"
#import "zconf.h"

NS_ASSUME_NONNULL_BEGIN


@implementation ZIPArchive {
	zipFile zipArchive;
}


#pragma mark - Instance Methods

- (instancetype)init {
	return nil;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL {
	if (self = [super init]) {
		zipArchive = zipOpen(fileURL.path.UTF8String, 0);
		if (zipArchive == NULL) { return nil; }
	}
	return self;
}

- (void)dealloc {
	[self writeToFile];
}

- (BOOL)addFileToArchive:(NSURL *)fileURL {
	return [self addFileToArchive:fileURL directoryPath:nil];
}

- (BOOL)addFileToArchive:(NSURL *)fileURL directoryPath:(nullable NSString *)path {
	if (zipArchive == NULL) { return NO; }
	
	time_t current;
	time(&current);
	
	zip_fileinfo zipInfo = {0};
	zipInfo.dosDate = (unsigned long)current;
	
	NSError *error = nil;
	NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:&error];
	if ((error == nil) && attr) {
		NSDate *fileDate = (NSDate *)attr[NSFileModificationDate];
		if (fileDate) {
			zipInfo.dosDate = [fileDate timeIntervalSinceDate:[ZIPArchive date1980]];
		}
	}
	
	if (path != nil) {
		path = [path stringByAppendingPathComponent:fileURL.lastPathComponent];
	} else {
		path = fileURL.lastPathComponent;
	}
	
	int result = zipOpenNewFileInZip(zipArchive, path.UTF8String, &zipInfo,
									 NULL, 0,
									 NULL, 0,
									 NULL, Z_DEFLATED, Z_DEFAULT_COMPRESSION);
	if (result != Z_OK) { return NO; }
	
	NSData *data = [NSData dataWithContentsOfURL:fileURL];
	result = zipWriteInFileInZip(zipArchive, data.bytes, (unsigned int)data.length);
	if (result != Z_OK) { return NO; }
	
	return (zipCloseFileInZip(zipArchive) == Z_OK);
}

- (NSUInteger)addDirectoryToArchive:(NSURL *)directoryURL {
	return [self addDirectoryToArchive:directoryURL directoryPath:nil];
}

- (NSUInteger)addDirectoryToArchive:(NSURL *)directoryURL directoryPath:(nullable NSString *)path {
	NSUInteger fileCount = 0;
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:directoryURL includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey] options:0 error:nil];
	for (NSURL *fileURL in directoryContents) {
		NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:nil];
		if ([attr.fileType isEqualToString:NSFileTypeDirectory] || [attr.fileType isEqualToString:NSFileTypeSymbolicLink]) {
			// Recursively do subdirectories.
			NSString *subpath = fileURL.lastPathComponent;
			if (path != nil) {
				subpath = [path stringByAppendingPathComponent:subpath];
			}
			fileCount += [self addDirectoryToArchive:fileURL directoryPath:subpath];
		} else {
			// Count if added successfully.
			fileCount += [self addFileToArchive:fileURL directoryPath:path];
		}
	}
	return fileCount;
}

- (BOOL)writeToFile {
	if (zipArchive == NULL) { return NO; }
	BOOL result = (zipClose(zipArchive, NULL) == Z_OK);
	zipArchive = NULL;
	return result;
}


#pragma mark - Class Methods

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL {
	return [ZIPArchive extractArchiveAtURL:fileURL toDestination:destinationURL error:nil];
}

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL error:(NSError **)error {
	return [ZIPArchive extractArchiveAtURL:fileURL toDestination:destinationURL overwrite:YES password:nil error:error];
}

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL overwrite:(BOOL)overwrite {
	return [ZIPArchive extractArchiveAtURL:fileURL toDestination:destinationURL overwrite:overwrite error:nil];
}

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL overwrite:(BOOL)overwrite error:(NSError **)error {
	return [ZIPArchive extractArchiveAtURL:fileURL toDestination:destinationURL overwrite:overwrite password:nil error:error];
}

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL password:(NSString *)password {
	return [ZIPArchive extractArchiveAtURL:fileURL toDestination:destinationURL password:password error:nil];
}

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL password:(NSString *)password error:(NSError **)error {
	return [ZIPArchive extractArchiveAtURL:fileURL toDestination:destinationURL overwrite:YES password:password error:error];
}

+ (BOOL)extractArchiveAtURL:(NSURL *)fileURL toDestination:(NSURL *)destinationURL overwrite:(BOOL)overwrite password:(nullable NSString *)password error:(NSError **)error {
	
	unzFile zipArchive = unzOpen(fileURL.path.UTF8String);
	if (zipArchive == NULL) {
		if (error) {
			*error = [NSError errorWithDomain:@"ZIPArchiveErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to open zip file."}];
		}
		return NO;
	}
	
	unz_global_info globalInfo = {0ul, 0ul};
	unzGetGlobalInfo(zipArchive, &globalInfo);
	
	// Begin unzipping
	if (unzGoToFirstFile(zipArchive) != UNZ_OK) {
		if (error) {
			*error = [NSError errorWithDomain:@"ZIPArchiveErrorDomain" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Failed to open first file in zip file."}];
		}
		return NO;
	}
	
	BOOL success = YES;
	int result;
	unsigned char buffer[4096] = {0};
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDate *nineteenEighty = [ZIPArchive date1980];
	
	do {
		if ((password == nil) || (password.length == 0)) {
			result = unzOpenCurrentFile(zipArchive);
		} else {
			result = unzOpenCurrentFilePassword(zipArchive, [password cStringUsingEncoding:NSASCIIStringEncoding]);
		}
		
		if (result != UNZ_OK) {
			success = NO;
			break;
		}
		
		// Read data and write to file.
		unz_file_info fileInfo;
		memset(&fileInfo, 0, sizeof(unz_file_info));
		
		result = unzGetCurrentFileInfo(zipArchive, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
		if (result != UNZ_OK) {
			success = NO;
			unzCloseCurrentFile(zipArchive);
			break;
		}
		
		char *filename = (char *)malloc(fileInfo.size_filename + 1);
		unzGetCurrentFileInfo(zipArchive, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
		filename[fileInfo.size_filename] = '\0';
		
		// Check if it contains a directory.
		NSString *strPath = [NSString stringWithCString:filename encoding:NSUTF8StringEncoding];
		BOOL isDirectory = NO;
		if ((filename[fileInfo.size_filename - 1] == '/') || (filename[fileInfo.size_filename - 1] == '\\')) {
			isDirectory = YES;
		}
		free(filename);
		
		// Contains a path.
		if ([strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location != NSNotFound) {
			strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
		}
		
		NSString *fullPath = [destinationURL.path stringByAppendingPathComponent:strPath];
		if (isDirectory) {
			[fileManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:nil];
		} else {
			[fileManager createDirectoryAtPath:fullPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
		}
		
		if ([fileManager fileExistsAtPath:fullPath] && !isDirectory && !overwrite) {
			unzCloseCurrentFile(zipArchive);
			result = unzGoToNextFile(zipArchive);
			continue;
		}
		
		FILE *fp = fopen(fullPath.UTF8String, "wb");
		while (fp) {
			int readBytes = unzReadCurrentFile(zipArchive, buffer, 4096);
			if (readBytes > 0) {
				fwrite(buffer, readBytes, 1, fp);
			} else {
				break;
			}
		}
		
		if (fp) {
			fclose(fp);
			// Set the original datetime property.
			if (fileInfo.dosDate != 0) {
				NSDate *origDate = [[NSDate alloc] initWithTimeInterval:(NSTimeInterval)fileInfo.dosDate sinceDate:nineteenEighty];
				if (![fileManager setAttributes:@{NSFileModificationDate: origDate} ofItemAtPath:fullPath error:nil]) {
					// Can't set attributes.
					NSLog(@"Failed to set attributes.");
				}
			}
		}
		
		unzCloseCurrentFile(zipArchive);
		result = unzGoToNextFile(zipArchive);
	} while ((result == UNZ_OK) && (UNZ_OK != UNZ_END_OF_LIST_OF_FILE));
	
	unzClose(zipArchive);
	return success;
}


#pragma mark - Class Helper Methods

+ (NSDate *)date1980 {
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	[comps setYear:1980];
	[comps setMonth:1];
	[comps setDay:1];
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSDate *date = [gregorian dateFromComponents:comps];
	return date;
}


@end


NS_ASSUME_NONNULL_END
