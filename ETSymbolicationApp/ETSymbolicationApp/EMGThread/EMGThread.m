//
//  EMGThread.m
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

#import "EMGThread.h"
#import "Constants.h"
#import <pthread.h>
#import <pthread/stack_np.h>

#define    INSTACK(a)    ((a) >= stackbot && (a) <= stacktop)
#define    ISALIGNED(a)    ((((uintptr_t)(a)) & 0x1) == 0)

typedef uintptr_t frame_data_addr_t;

struct frame_data {
    frame_data_addr_t frame_addr_next;
    frame_data_addr_t ret_addr;
};

@interface EMGThread ()
@property (nonatomic, assign) NSInteger threadLoopCounter;
@end

@implementation EMGThread

-(void) main {
    if (_threadLoopCounter < MAX_FRAMES) {
        _threadLoopCounter++;
        [self main];
    }
    
    [self modifyFrameAndWait];
}

- (void) modifyFrameAndWait {
    // Number of frames to print
    int max = MAX_FRAMES;
    
    void *frame, *next;
    pthread_t thisThread = pthread_self();
    void *stacktop = pthread_get_stackaddr_np(thisThread);
    void *stackbot = stacktop - pthread_get_stacksize_np(thisThread);

    // Rely on the fact that our caller has an empty stackframe (no local vars)
    // to determine the minimum size of a stackframe (frame ptr & return addr)
    frame = __builtin_frame_address(0);
    next = (void*)pthread_stack_frame_decode_np((uintptr_t)frame, NULL);
    
    /* make sure return address is never out of bounds */
    stacktop -= (next - frame);
    
    int counter = 0;

    if(!INSTACK(frame) || !ISALIGNED(frame))
        return;
    
    // Skip one frame so we can return to the calling function if needed
    frame = next;
    
    while (max--) {
        uintptr_t retaddr;
        next = (void*)pthread_stack_frame_decode_np((uintptr_t)frame, &retaddr);
        
        // Attempt to overwrite
        struct frame_data *frameModifier = (struct frame_data *)frame;
        
        // Add +2 so address is AFTER the function start
        frameModifier->ret_addr = self.addresses[self.startingIndex + counter++];
        
        if(!INSTACK(next) || !ISALIGNED(next) || next <= frame)
            return;
        frame = next;
    }
    
    // Notify of completion
    self.completionBlock();
    
    // Sleep this thread but keep it alive for the stacktrace
    while(true) {
        [NSThread sleepForTimeInterval:0.01];
    }
}
@end
