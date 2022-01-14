#include <AudioToolbox/AudioToolbox.h>
#define kNumberRecordBuffers 3

#pragma mark user data struct
typedef struct MyRecorder {
    AudioFileID            recordFile;
    SInt64                 recordPacket;
    Boolean                running;
} MyRecorder;


#pragma mark utility functions
static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    char errorString[20];
    
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else { // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    }
    
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}

OSStatus MyGetDefaultInputDeviceSampleRate(Float64 *outSampleRate) {
    OSStatus error;
    AudioDeviceID deviceID = 0;
    AudioObjectPropertyAddress propertyAddress;
    UInt32 propertySize;
    propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = 0;
    propertySize = sizeof(AudioDeviceID);
    
    // GET INPUT DEVICE IN PROPERTY ADDRESS
    error = AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject,
                                                &propertyAddress,
                                                0,
                                                NULL,
                                                &propertySize,
                                                &deviceID);
    if (error) return error;
    
    
    propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate;
    propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propertyAddress.mElement = 0;
    propertySize = sizeof(Float64);
    error = AudioHardwareServiceGetPropertyData(deviceID,
                                                &propertyAddress,
                                                0,
                                                NULL,
                                                &propertySize,
                                                outSampleRate);
    return error;
}


static void MyCopyEncoderCookieToFile(AudioQueueRef queue, AudioFileID theFile) {
    /*
     copy magic cookie to audio file
     used for encoded formats like AAC when the
     AudioStreamBasicDescription cannot describe the audio file alone
     */
    OSStatus error;
    UInt32 propertySize;
    // GET SIZE OF MAGIC COOKIE
    error = AudioQueueGetPropertySize(queue,
                                      kAudioConverterCompressionMagicCookie,
                                      &propertySize);
    if (error == noErr && propertySize > 0) {
        Byte *magicCookie = (Byte *)malloc(propertySize);
        // COPY MAGIC COOKIE TO BYTE BUFFER
        CheckError(AudioQueueGetProperty(queue,
                                         kAudioQueueProperty_MagicCookie,
                                         magicCookie,
                                         &propertySize),
                   "Couldn't get audio queue's magic cookie");
        // AUDIO MAGIC COOKING TO AUDIOFILE
        CheckError(AudioFileSetProperty(theFile,
                                        kAudioFilePropertyMagicCookieData,
                                        propertySize,
                                        magicCookie),
                   "Couldn't set audio file's magic cookie");
        free(magicCookie);
    }
}



static int MyComputeRecordBufferSize(const AudioStreamBasicDescription *format,
                                     AudioQueueRef queue,
                                     float seconds) {
    /*
     RETURN THE NUMBER OF BYTES
     */
    int packets, frames, bytes;
    
    // CALULATE NUMBER OF AUDIO FRAMES
    //     You will need one sample per channel
    frames = (int)ceil(seconds * format->mSampleRate);
    
    /*
     if myBytesPerFrame has a value
     you can just multipy frames * bytesPerFrame
     This will be true for PCM
     */
    if (format->mBytesPerFrame > 0)
        bytes = frames * format->mBytesPerFrame;
    
    else {  //  WORK AT THE PACKET LEVEL
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0) {
            // CONSTANT PACKET SIZE
            maxPacketSize = format->mBytesPerPacket;
        } else {
            // GET THE UPPER BOUND ON PACKET SIZE
            UInt32 propertySize = sizeof(maxPacketSize);
            CheckError(AudioQueueGetProperty(queue,
                                             kAudioConverterPropertyMaximumOutputPacketSize,
                                             &maxPacketSize,
                                             &propertySize),
                       "Couldn't get queue's maximum output packet size");
        }
        
        
        // frame = audio slice with all channels
        // packet =  multiple frames
        
        /*
         GET NUMBER OF PACKETS
         */
        if (format->mFramesPerPacket > 0)
            packets = frames / format->mFramesPerPacket;          // 4
        else
            // Worst-case scenario: 1 frame in a packet
            packets = frames;                                     // 5
        // Sanity check
        if (packets == 0)
            packets = 1;
        bytes = packets * maxPacketSize;                          // 6
    }
    return bytes;
}


#pragma mark record callback function
static void MyAQInputCallback(void *inUserData,
                              AudioQueueRef inQueue,
                              AudioQueueBufferRef inBuffer, // holds audio data
                              const AudioTimeStamp *inStartTime, // starting time stamp
                              // last 2 parameters are for variable bit rates
                              UInt32 inNumPackets,
                              // pointer to packet descriptions
                              const AudioStreamPacketDescription *inPacketDesc)
{
    /*
     Called everytime the queue fills one of the buffers with
     new audio data
     */
    
    // CAST DATA BACK TO A MYRECORDER OBJECT
    MyRecorder *recorder = (MyRecorder *)inUserData;
    
    if (inNumPackets > 0) {
        // Write packets to a file
        CheckError(AudioFileWritePackets(recorder->recordFile,
                                         FALSE, // bool indicate to cache data
                                         inBuffer->mAudioDataByteSize, //size of data to write
                                         inPacketDesc, // packet description
                                         recorder->recordPacket, // index of which packet to write to
                                         &inNumPackets, // number of packets to write
                                         inBuffer->mAudioData), // pointer to audio data
                   "AudioFileWritePackets failed");
        // Increment the packet index
        recorder->recordPacket += inNumPackets;
    }
    
    
    if (recorder->running) {
        CheckError(AudioQueueEnqueueBuffer(inQueue,
                                           inBuffer,
                                           0,
                                           NULL),
                   "AudioQueueEnqueueBuffer failed");
    }
}

#pragma mark main function
int main(int argc, const char *argv[]) {
    
    // SET UP FORMAT
    MyRecorder recorder = {0};
    AudioStreamBasicDescription recordFormat;
    memset(&recordFormat, 0, sizeof(recordFormat));
    recordFormat.mFormatID = kAudioFormatMPEG4AAC;
    recordFormat.mChannelsPerFrame = 2;
    // MyGetDefaultInputDeviceSampleRate(&recordFormat.mSampleRate);
    UInt32 propSize = sizeof(recordFormat);
    CheckError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                      0,
                                      NULL,
                                      &propSize,
                                      &recordFormat),
               "AudioFormatGetProperty failed");
    
    // SET UP AUDIO QUEUE
    AudioQueueRef queue = {0};
    CheckError(AudioQueueNewInput(&recordFormat,
                                  MyAQInputCallback,
                                  &recorder, // user data to provide to callback
                                  NULL, // defaults for run loop behavior
                                  NULL,
                                  0,
                                  &queue), // update audioQueueRef
               "AudioQueueNewInput failed");
    
    // GET MORE INFO FILLED OUT ABOUT THE ASBD FROM THE QUEUE
    // gives us all the data needed to create a file
    UInt32 size = sizeof(recordFormat);
    CheckError(AudioQueueGetProperty(queue,
                                     kAudioConverterCurrentOutputStreamDescription,
                                     &recordFormat,
                                     &size),
               "Couldn't get queue's format");
    
    // SET UP FILE
    CFURLRef myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                       CFSTR("output.caf"),
                                                       kCFURLPOSIXPathStyle,
                                                       false);
    CheckError(AudioFileCreateWithURL(myFileURL,
                                      kAudioFileCAFType,
                                      &recordFormat,
                                      kAudioFileFlags_EraseFile,
                                      &recorder.recordFile),
               "AudioFileCreateWithURL failed");
    CFRelease(myFileURL);
    
    MyCopyEncoderCookieToFile(queue, recorder.recordFile);
    int bufferByteSize = MyComputeRecordBufferSize(&recordFormat, queue, 0.5);
    
    
    int bufferIndex;
    for (bufferIndex = 0; bufferIndex < kNumberRecordBuffers; ++bufferIndex) {
        AudioQueueBufferRef buffer;
        
        // allocate memory for buffer
        CheckError(AudioQueueAllocateBuffer(queue,
                                            bufferByteSize,
                                            &buffer),
                   "AudioQueueAllocateBuffer failed");
        // add buffer to the queue
        CheckError(AudioQueueEnqueueBuffer(queue,
                                           buffer,
                                           0,
                                           NULL),
                   "AudioQueueEnqueueBuffer failed");
    }
    // START QUEUE
    recorder.running = TRUE;
    CheckError(AudioQueueStart(queue, NULL), "AudioQueueStart failed");
    printf("Recording, press <return> to stop:\n");
    getchar();
    
    // STOP QUEUE
    printf("* recording done *\n");
    recorder.running = FALSE;
    CheckError(AudioQueueStop(queue, TRUE), "AudioQueueStop failed");
    MyCopyEncoderCookieToFile(queue, recorder.recordFile);
    
    // CLEAN UP AUDIO QUEUE AND FILE
    AudioQueueDispose(queue, TRUE);
    AudioFileClose(recorder.recordFile);
    return 0;
}

