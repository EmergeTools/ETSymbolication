//
//  FunctionStarts.h
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

#ifndef FunctionStarts_h
#define FunctionStarts_h

#include <stdio.h>
struct FunctionStartsResult {
    uint64_t *functionsPointers;
    int functionsCount;
};

extern struct FunctionStartsResult get_function_starts(const char *imagePath);

#endif /* FunctionStarts_h */
