//
//  main.m
//  CAToneFileGenerator
//
//  Created by jeff Omidvaran on 1/6/22.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define SAMPLE_RATE 44100
#define DURATION 5.0 // how many seconds of audio to create
//#define FILENAME_FORMAT @"%0.3f-square.aif"
//#define FILENAME_FORMAT @"%0.3f-saw.aif"
#define FILENAME_FORMAT @"%0.3f-sine.aif"



int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printf ("Usage: CAToneFileGenerator n\n(where n is tone in Hz)");
            return -1;
        }
        
        double hz = atof(argv[1]);  //  convert frequency from command line arg
        assert (hz > 0);
        NSLog (@"generating %f hz tone", hz);
        
        NSString *fileName = [NSString stringWithFormat: FILENAME_FORMAT, hz];
        // get current directory
        NSString *filePath = [[[NSFileManager defaultManager] currentDirectoryPath]
                              stringByAppendingPathComponent: fileName];
        NSURL *fileURL = [NSURL fileURLWithPath: filePath];
        NSLog(@"%@", filePath);
        
        // initilize audio format struct (channels, format bit rate etc.)
        AudioStreamBasicDescription asbd;
        // initilize all fields to 0 (always do this)
        memset(&asbd, 0, sizeof(asbd));
        
        asbd.mSampleRate = SAMPLE_RATE;
        asbd.mFormatID = kAudioFormatLinearPCM;
        asbd.mFormatFlags = kAudioFormatFlagIsBigEndian |
        kAudioFormatFlagIsSignedInteger |
        kAudioFormatFlagIsPacked; // use all bits avalible in byte
        asbd.mBitsPerChannel = 16; // 16 bit
        asbd.mChannelsPerFrame = 1;
        asbd.mFramesPerPacket = 1;
        asbd.mBytesPerFrame = 2; // non-variable bit rateencoding
        asbd.mBytesPerPacket = 2;
        
        // Set up the file
        AudioFileID audioFile;
        OSStatus audioErr = noErr;
        audioErr = AudioFileCreateWithURL((__bridge CFURLRef)fileURL,
                                          kAudioFileAIFFType, // AIFF file type
                                          &asbd,
                                          kAudioFileFlags_EraseFile, // overwrite file with the same name
                                          &audioFile);
        assert (audioErr == noErr);
        
        // Start writing samples
        long maxSampleCount = SAMPLE_RATE * DURATION;
        long sampleCount = 0;
        UInt32 bytesToWrite = 2; // set up as inout variable for AudioFileWriteBytes
        
        
        double wavelengthInSamples = SAMPLE_RATE / hz;  // # of samples in a wave length
        while (sampleCount < maxSampleCount) {
            for (int i=0; i<wavelengthInSamples; i++) {
                //                                                               convert to radians
                //                                                                        i percent of wavelength
                // SIN WAVE
                SInt16 sample = CFSwapInt16HostToBig ((SInt16) SHRT_MAX * sin(2 * M_PI * (i / wavelengthInSamples)));
                
//                // SAW WAVE
//                SInt16 sample = CFSwapInt16HostToBig (((i / wavelengthInSamples) * SHRT_MAX *2) - SHRT_MAX);
//
//                // SQUARE WAVE
//                SInt16 sample;
//                if (i < wavelengthInSamples/2) {
//                    // 1st half
//                    sample = CFSwapInt16HostToBig (SHRT_MAX); // swap from little to Big Endian unsigned ints
//                } else {
//                    // 2nd half
//                    sample = CFSwapInt16HostToBig (SHRT_MIN);
//                }
                audioErr = AudioFileWriteBytes(audioFile,
                                               false,
                                               sampleCount*2,
                                               &bytesToWrite,
                                               &sample);
                assert (audioErr == noErr);
                sampleCount++;
            }
        }
        audioErr = AudioFileClose(audioFile);
        assert (audioErr == noErr);
        NSLog (@"wrote %ld samples", sampleCount);
    }
    return 0;
}
