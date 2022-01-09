//
//  main.m
//  CAStreamFormatTester
//
//  Created by jeff Omidvaran on 1/8/22.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        // for use with kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat
        AudioFileTypeAndFormatID fileTypeAndFormat;
        // find constants in AudioFile.h and AudioFormat.h
        fileTypeAndFormat.mFileType = kAudioFileAIFFType;
        fileTypeAndFormat.mFormatID = kAudioFormatLinearPCM;
        
        
        OSStatus audioErr = noErr;
        // specify size of audio info
        UInt32 infoSize = 0;
        
        
        // get the size and store result
        audioErr = AudioFileGetGlobalInfoSize(
                               kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                               sizeof (fileTypeAndFormat),
                               &fileTypeAndFormat,
                               &infoSize);
        assert (audioErr == noErr);
        
        
        // allocate memory for info
        AudioStreamBasicDescription *asbds = malloc(infoSize);
        
        
        audioErr = AudioFileGetGlobalInfo(
                         kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                         sizeof (fileTypeAndFormat),
                         &fileTypeAndFormat,
                         &infoSize, //  how many bytes are writen
                         asbds);
        assert (audioErr == noErr);
        
        
        // get lenth of audio stream basic descriptions array
        int asbdCount = infoSize / sizeof (AudioStreamBasicDescription);
        
        
        /*
            ASBD fields
                mFormatID
                mFormatFlags
                mBitsPerChannel
        */
        for (int i=0; i<asbdCount; i++) {
            // convert formatID to big Endian
            UInt32 format4cc = CFSwapInt32HostToBig(asbds[i].mFormatID);
            NSLog (@"%d: mFormatId: %4.4s, mFormatFlags: %d, mBitsPerChannel: %d",
                    i,
                    (char*)&format4cc,
                    asbds[i].mFormatFlags,
                    asbds[i].mBitsPerChannel);
        }
        //  malloc followed by free
        free (asbds);
    }
    return 0;
}
