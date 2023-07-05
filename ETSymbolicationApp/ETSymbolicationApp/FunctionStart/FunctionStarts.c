//
//  FunctionStarts.c
//  ETSymbolicationApp
//
//  Created by Itay Brenner on 30/6/23.
//

#import "FunctionStarts.h"
#import "Constants.h"
#import <assert.h>
#import <mach-o/dyld.h>
#import <string.h>
#import <stdlib.h>

uint64_t *get_function_starts(const char *imagePath) {
    uint64_t* list = malloc(sizeof(uint64_t) * INITIAL_CAPACITY);

    int capacity = INITIAL_CAPACITY;
    int counter = 0;
    
    const uint32_t image_count = _dyld_image_count();
    for (uint32_t image_index = 0; image_index < image_count; image_index++) {
        const char *imageName = _dyld_get_image_name(image_index);
        
        if (strcmp(imageName, imagePath) != 0) {
            continue;
        }
        
        const struct mach_header_64 *header = (const void *)_dyld_get_image_header(image_index);
        
        intptr_t slide = _dyld_get_image_vmaddr_slide(image_index);
        
        uint64_t linkedit_seg_start = 0;
        uint64_t linkedit_seg_end = 0;
        uint64_t linkedit_seg_fileoff = 0;
        
        uint64_t text_seg_start = 0;
        uint64_t text_sect_start = 0;
        uint64_t text_sect_end = 0;
        
        const struct load_command *load_cmd = (const void *)(header + 1);
        for (uint32_t i = 0; i < header->ncmds; ++i) {
            switch (load_cmd->cmd) {
                case LC_SEGMENT_64: {
                    const struct segment_command_64 *seg_cmd = (const void *)load_cmd;
                    
                    // The __LINKEDIT info is needed to compute the address of the Function Starts data
                    if (strncmp(seg_cmd->segname, SEG_LINKEDIT, sizeof(seg_cmd->segname)) == 0) {
                        linkedit_seg_fileoff = seg_cmd->fileoff;
                        linkedit_seg_start = seg_cmd->vmaddr + slide;
                        linkedit_seg_end = linkedit_seg_start + seg_cmd->vmsize;
                    }
                    
                    if (strncmp(seg_cmd->segname, SEG_TEXT, sizeof(seg_cmd->segname)) == 0) {
                        text_seg_start = seg_cmd->vmaddr + slide;
                        // Get the __text section info so that we can verify the function addresses parsed later
                        for (uint32_t sect_idx = 0; sect_idx < seg_cmd->nsects; sect_idx++) {
                            const struct section_64 *section = (const struct section_64 *)(seg_cmd + 1) + sect_idx;
                            if (strncmp(section->sectname, SECT_TEXT, sizeof(section->sectname)) == 0) {
                                text_sect_start = section->addr + slide;
                                text_sect_end = text_sect_start + section->size;
                                break;
                            }
                        }
                    }
                    
                    break;
                }
                case LC_FUNCTION_STARTS: {
                    const struct linkedit_data_command *data_cmd = (const void *)load_cmd;
                    assert(data_cmd->dataoff > linkedit_seg_fileoff);
                    const uint32_t offset_from_linkedit = data_cmd->dataoff - (uint32_t) linkedit_seg_fileoff;
                    const uint8_t *start = (const uint8_t *)linkedit_seg_start + offset_from_linkedit;
                    const uint8_t *end = start + data_cmd->datasize;
                    assert((uintptr_t)end < linkedit_seg_end);
                    
                    uint64_t address = text_seg_start;
                    
                    // Function starts are stored as a series of offsets encoded as LEB128.
                    // Adapted from DyldInfoPrinter<A>::printFunctionStartsInfo() in ld64-127.2/src/other/dyldinfo.cpp
                    for (const uint8_t *p = start; (*p != 0) && (p < end); ) {
                        if (counter == capacity) {
                            capacity *= 2;
                            list = realloc(list, sizeof(uint64_t) * capacity);

                            if (list == NULL) {
                                fprintf(stderr, "Memory reallocation failed\n");
                                exit(1);
                            }
                        }
                        
                        uint64_t delta = 0;
                        uint32_t shift = 0;
                        bool more = true;
                        do {
                            uint8_t byte = *p++;
                            delta |= ((byte & 0x7F) << shift);
                            shift += 7;
                            if (byte < 0x80) {
                                address += delta;
                                assert(// Function address resides in the __text section
                                       address >= text_sect_start && address < text_sect_end);
                                
                                list[counter++] = address;
                                
                                more = false;
                            }
                        } while (more);
                    }
                    break;
                }
            }
            load_cmd = (const void *)((const char *)load_cmd) + load_cmd->cmdsize;
        }
    }
    return list;
}
