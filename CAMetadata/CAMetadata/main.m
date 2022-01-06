//
//  main.m
//  CAMetadata
//
//  Created by jeff Omidvaran on 1/5/22.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printf ("Usage: CAMetadata /full/path/to/audiofile\n");
            return -1;
        }                                                             // 1
        
        // CONVERT C-STRING FOR AUDIOFILEOPENURL
        NSString *audioFilePath = [[NSString stringWithUTF8String:argv[1]] stringByExpandingTildeInPath];
        NSLog(@"path = %@", audioFilePath);
        NSURL *audioURL = [NSURL fileURLWithPath:audioFilePath];
        
        // OPEN AUDIO FILE
        AudioFileID audioFile;
        OSStatus theErr = noErr;
        theErr = AudioFileOpenURL((__bridge CFURLRef _Nonnull)(audioURL),
                                  kAudioFileReadPermission, // permission
                                  0,  // make coreaudio configures itself
                                  &audioFile);
        assert (theErr == noErr);
        
        //  GET THE SIZE OF THE METADATA
        UInt32 dictionarySize = 0;
        theErr = AudioFileGetPropertyInfo (audioFile,
                                           kAudioFilePropertyInfoDictionary,
                                           &dictionarySize,
                                           0); // indicate the property is not writeable
        assert (theErr == noErr);
        
        
        // GET AUDIO PROPERTIES
        CFDictionaryRef dictionary;
        theErr = AudioFileGetProperty (audioFile,
                                       kAudioFilePropertyInfoDictionary, // type of data we want to get
                                       &dictionarySize, // # of bytes to read and then updated with # of bytes written
                                       &dictionary); // which dictionary to populate
        assert (theErr == noErr);
        
        
        NSLog (@"dictionary: %@", dictionary);
        /*
            If you create, copy, or explicitly retain (see the CFRetain function)
            a Core Foundation object, you are responsible for releasing it
         */
        CFRelease (dictionary);
        
        //  close AudioFileID
        theErr = AudioFileClose (audioFile);
        assert (theErr == noErr);
    }
    return 0;
}
