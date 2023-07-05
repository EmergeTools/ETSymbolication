//
//  EMGThread.h
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMGThread : NSThread
@property (copy) void (^completionBlock)(void);
@property (nonatomic, assign) NSInteger startingIndex;
@property (nonatomic, assign) uint64_t *addresses;
@end

NS_ASSUME_NONNULL_END
