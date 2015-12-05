# ZIPArchive

This is a cleaned up and modernized fork of [ZipArchive by Aish](https://code.google.com/p/ziparchive/), a class to simplify compressing and decompressing ZIP files in Objective-C.


## Adding to Your Project

1. Add the **ZIPArchive** folder to your project.
2. In the _Build Phases_ tab for your target, under the _Link Binary With Libraries_ section, add `libz.dylib` to the list of frameworks.
3. `#import "ZIPArchive.h"`


## Usage

Objective-C:
```objective-c
// Create ZIP file.
ZipArchive *zipArchive = [[ZipArchive alloc] initWithFileURL:myZipFileURL];

[zipArchive addFileToArchive:someFileURL];
[zipArchive addFileToArchive:anotherFileURL directoryPath:@"Some Folder"];
[zipArchive addDirectoryToArchive:someFolderURL directoryPath:@"Some Folder"];

[zipArchive writeToFile];

// Extract contents of ZIP file.
[ZIPArchive extractArchiveAtURL:myZipFileURL toDestination:aFolderURL];
```

Swift:
```swift
// Create ZIP file.
var zipArchive = ZIPArchive(fileURL: myZipFileURL)

zipArchive.addFileToArchive(someFileURL)
zipArchive.addFileToArchive(anotherFileURL, directoryPath: "Some Folder")
zipArchive.addDirectoryToArchive(someFolderURL, directoryPath: "Some Folder")

zipArchive.writeToFile()

// Extract contents of ZIP file.
ZIPArchive.extractArchiveAtURL(myZipFileURL, toDestination: aFolderURL)
```


## License

ZIPArchive is released under the MIT License.