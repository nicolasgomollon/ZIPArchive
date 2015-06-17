//
//  ZipArchive.mm
//  ZipArchive
//
//  Objective-C code Copyright (c) 2008 aish (acsolu@gmail.com). All rights reserved.
//

#import "ZipArchive.h"
#import "zconf.h"
#import "zlib.h"


@interface ZipArchive (Private)

- (void)outputErrorMessage:(NSString *)msg;
- (BOOL)overwrite:(NSString *)file;
- (NSDate *)date1980;
@end


@implementation ZipArchive
@synthesize delegate = _delegate;

- (id)init {
	if (self = [super init]) {
		_zipFile = NULL;
	}
	return self;
}

- (void)dealloc {
	[self closeZipFile];
}

- (BOOL)createZipFile:(NSString *)zipFile {
	_zipFile = zipOpen((const char *)[zipFile UTF8String], 0);
	if (!_zipFile) {
		return NO;
	}
	return YES;
}

- (BOOL)createZipFile:(NSString *)zipFile password:(NSString *)password {
	_password = password;
	return [self createZipFile:zipFile];
}

- (BOOL)addFileToZip:(NSString *)file newname:(NSString *)newname {
	if (!_zipFile) {
		return NO;
	}
	
//	tm_zip filetime;
	time_t current;
	time(&current);
	
	zip_fileinfo zipInfo = {0};
	zipInfo.dosDate = (unsigned long)current;
	
	NSError *error = nil;
	NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:&error];
	if ((error == nil) && attr) {
		NSDate *fileDate = (NSDate *)[attr objectForKey:NSFileModificationDate];
		if (fileDate) {
			zipInfo.dosDate = [fileDate timeIntervalSinceDate:[self date1980]];
		}
	}
	
	int ret;
	NSData *data = nil;
	if ([_password length] == 0) {
		ret = zipOpenNewFileInZip(_zipFile,
								  (const char *)[newname UTF8String],
								  &zipInfo,
								  NULL, 0,
								  NULL, 0,
								  NULL,
								  Z_DEFLATED,
								  Z_DEFAULT_COMPRESSION);
	} else {
		data = [NSData dataWithContentsOfFile:file];
		uLong crcValue = crc32(0L, NULL, 0L);
		crcValue = crc32(crcValue, (const Bytef *)[data bytes], (unsigned int)[data length]);
		ret = zipOpenNewFileInZip3(_zipFile,
								   (const char *)[newname UTF8String],
								   &zipInfo,
								   NULL, 0,
								   NULL, 0,
								   NULL,
								   Z_DEFLATED,
								   Z_DEFAULT_COMPRESSION,
								   0,
								   15,
								   8,
								   Z_DEFAULT_STRATEGY,
								   [_password cStringUsingEncoding:NSASCIIStringEncoding],
								   crcValue);
	}
	if (ret != Z_OK) {
		return NO;
	}
	if (data == nil) {
		data = [NSData dataWithContentsOfFile:file];
	}
	unsigned int dataLen = (unsigned int)[data length];
	ret = zipWriteInFileInZip(_zipFile, (const void *)[data bytes], dataLen);
	if (ret != Z_OK) {
		return NO;
	}
	ret = zipCloseFileInZip(_zipFile);
	if (ret != Z_OK) {
		return NO;
	}
	return YES;
}

- (BOOL)closeZipFile {
	_password = nil;
	if (_zipFile == NULL) {
		return NO;
	}
	BOOL ret = (zipClose(_zipFile, NULL) == Z_OK);
	_zipFile = NULL;
	return ret;
}

- (BOOL)unzipOpenFile:(NSString *)zipFile {
	_unzFile = unzOpen((const char *)[zipFile UTF8String]);
	if (_unzFile) {
		unz_global_info globalInfo = {0};
		if (unzGetGlobalInfo(_unzFile, &globalInfo) == UNZ_OK) {
			NSLog(@"%lu entries in the zip file.", globalInfo.number_entry);
		}
	}
	return (_unzFile != NULL);
}

- (BOOL)unzipOpenFile:(NSString *)zipFile password:(NSString *)password {
	_password = password;
	return [self unzipOpenFile:zipFile];
}

- (BOOL)unzipFileTo:(NSString *)path overwrite:(BOOL)overwrite {
	BOOL success = YES;
	int ret = unzGoToFirstFile(_unzFile);
	unsigned char buffer[4096] = {0};
	NSFileManager *fman = [NSFileManager defaultManager];
	if (ret != UNZ_OK) {
		[self outputErrorMessage:@"Failed."];
	}
	
	do {
		if ([_password length] == 0) {
			ret = unzOpenCurrentFile(_unzFile);
		} else {
			ret = unzOpenCurrentFilePassword(_unzFile, [_password cStringUsingEncoding:NSASCIIStringEncoding]);
		}
		if (ret != UNZ_OK) {
			[self outputErrorMessage:@"Error occurred."];
			success = NO;
			break;
		}
		
		// Read data and write to file.
		int read;
		unz_file_info fileInfo = {0};
		ret = unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
		if (ret != UNZ_OK) {
			[self outputErrorMessage:@"Error occurred while getting file info."];
			success = NO;
			unzCloseCurrentFile(_unzFile);
			break;
		}
		char *filename = (char *)malloc(fileInfo.size_filename + 1);
		unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
		filename[fileInfo.size_filename] = '\0';
		
		// Check if it contains a directory.
		NSString *strPath = [NSString stringWithCString:filename encoding:NSUTF8StringEncoding];
		BOOL isDirectory = NO;
		if ((filename[fileInfo.size_filename - 1] == '/') || (filename[fileInfo.size_filename - 1] == '\\')) {
			isDirectory = YES;
		}
		free(filename);
		if ([strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location != NSNotFound) {
			// Contains a path.
			strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
		}
		NSString *fullPath = [path stringByAppendingPathComponent:strPath];
		
		if (isDirectory) {
			[fman createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:nil];
		} else {
			[fman createDirectoryAtPath:[fullPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		}
		if ([fman fileExistsAtPath:fullPath] && !isDirectory && !overwrite) {
			if (![self overwrite:fullPath]) {
				unzCloseCurrentFile(_unzFile);
				ret = unzGoToNextFile(_unzFile);
				continue;
			}
		}
		FILE *fp = fopen((const char *)[fullPath UTF8String], "wb");
		while (fp) {
			read = unzReadCurrentFile(_unzFile, buffer, 4096);
			if (read > 0) {
				fwrite(buffer, read, 1, fp);
			} else if (read < 0) {
				[self outputErrorMessage:@"Failed to read zip file."];
				break;
			} else {
				break;
			}
		}
		if (fp) {
			fclose(fp);
			// Set the original datetime property.
			if (fileInfo.dosDate != 0) {
				NSDate *origDate = [[NSDate alloc] initWithTimeInterval:(NSTimeInterval)fileInfo.dosDate sinceDate:[self date1980]];
				
				NSDictionary *attr = [NSDictionary dictionaryWithObject:origDate forKey:NSFileModificationDate]; //[[NSFileManager defaultManager] fileAttributesAtPath:fullPath traverseLink:YES];
				if (attr) {
					// [attr setValue:origDate forKey:NSFileCreationDate];
					if (![[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:fullPath error:nil]) {
						// Can't set attributes.
						NSLog(@"Failed to set attributes.");
					}
				}
				
				origDate = nil;
			}
			
		}
		unzCloseCurrentFile( _unzFile );
		ret = unzGoToNextFile( _unzFile );
	} while ((ret == UNZ_OK) && (UNZ_OK != UNZ_END_OF_LIST_OF_FILE));
	return success;
}

- (BOOL)unzipCloseFile {
	_password = nil;
	if (_unzFile) {
		return (unzClose( _unzFile ) == UNZ_OK);
	}
	return YES;
}


#pragma mark Delegate Wrapper

- (void)outputErrorMessage:(NSString *)msg {
	if (_delegate && [_delegate respondsToSelector:@selector(errorMessage:)]) {
		[_delegate errorMessage:msg];
	}
}

- (BOOL)overwrite:(NSString *)file {
	if (_delegate && [_delegate respondsToSelector:@selector(overwriteOperation:)]) {
		return [_delegate overwriteOperation:file];
	}
	return YES;
}

#pragma mark get NSDate object for 1980-01-01
- (NSDate *)date1980 {
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	[comps setDay:1];
	[comps setMonth:1];
	[comps setYear:1980];
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSDate *date = [gregorian dateFromComponents:comps];
	return date;
}


@end
