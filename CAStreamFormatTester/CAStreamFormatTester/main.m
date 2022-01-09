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
//        fileTypeAndFormat.mFileType = kAudioFileAIFFType;
//        fileTypeAndFormat.mFileType = kAudioFileWAVEType;
        fileTypeAndFormat.mFileType = kAudioFileCAFType;
        
//        fileTypeAndFormat.mFormatID = kAudioFormatLinearPCM;
        fileTypeAndFormat.mFormatID = kAudioFormatMPEG4AAC;
        
        
        // // settings leading to error
        // fileTypeAndFormat.mFileType = kAudioFileMP3Type;
        // fileTypeAndFormat.mFormatID = kAudioFormatMPEG4AAC;
        
        
        OSStatus audioErr = noErr;
        // specify size of audio info
        UInt32 infoSize = 0;
        
        
        // get the size and store result
        audioErr = AudioFileGetGlobalInfoSize(
                               kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                               sizeof (fileTypeAndFormat),
                               &fileTypeAndFormat,
                               &infoSize);
        // assert (audioErr == noErr);
        if (audioErr != noErr) {
            UInt32 err4cc = CFSwapInt32HostToBig(audioErr);
            NSLog (@"audioErr = %4.4s",  (char*)&err4cc);
        }
        
        
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

/*
 
 mFormatFlags 0x2 + 0x4 + 0x8 = 0xe = 14
 
 AIFF
    0: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 8
    1: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 16
    2: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 24
    3: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 32
 
 
 WAV (always uses little Endian PCM) (0x2 bit never set)
     0: mFormatId: lpcm, mFormatFlags: 8, mBitsPerChannel: 8
     1: mFormatId: lpcm, mFormatFlags: 12, mBitsPerChannel: 16
     2: mFormatId: lpcm, mFormatFlags: 12, mBitsPerChannel: 24
     3: mFormatId: lpcm, mFormatFlags: 12, mBitsPerChannel: 32
     4: mFormatId: lpcm, mFormatFlags: 9, mBitsPerChannel: 32
     5: mFormatId: lpcm, mFormatFlags: 9, mBitsPerChannel: 64
 
 CAF (0x1 is set therfore int and float samples)
     0: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 8
     1: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 16
     2: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 24
     3: mFormatId: lpcm, mFormatFlags: 14, mBitsPerChannel: 32
     4: mFormatId: lpcm, mFormatFlags: 11, mBitsPerChannel: 32
     5: mFormatId: lpcm, mFormatFlags: 11, mBitsPerChannel: 64
     6: mFormatId: lpcm, mFormatFlags: 12, mBitsPerChannel: 16
     7: mFormatId: lpcm, mFormatFlags: 12, mBitsPerChannel: 24
     8: mFormatId: lpcm, mFormatFlags: 12, mBitsPerChannel: 32
     9: mFormatId: lpcm, mFormatFlags: 9, mBitsPerChannel: 32
     10: mFormatId: lpcm, mFormatFlags: 9, mBitsPerChannel: 64
 
 CAF ACC
                                          variable bit rate
     0: mFormatId: aac , mFormatFlags: 0, mBitsPerChannel: 0

 
 
*/
