#pragma once
// Mikey's own bulk "Known Junk Callers" dataset -- roughly 1.1 million numbers from a spam-caller list he aggregated separately (tools/data/junk-callers-
// source.txt), shipped as a compact, sorted, fixed-width binary file rather than plist records: at this scale a property-list array would be both
// enormous on disk and far too slow to read-merge-write on every change, the way the Call Firewall's own small, hand-curated Numbers list works.
// Format (written by tools/generate-junk-callers.py): an 8-byte little-endian record count, then that many 15-byte, zero-padded, digit-only records
// with no delimiters, sorted ascending. Fixed width keeps numeric order identical to byte order, so a lookup is a classic binary search -- no
// parsing, no per-record allocation. Always built and read on little-endian arm64(e), so the header's bytes are used as-is, with no byte-swap.
// Kept entirely separate from and read-only with respect to the user's own Call Firewall list: this dataset is never edited, only consulted, and
// only as the last-resort fallback once every one of the user's own rules has had nothing to say about a call.
#import <Foundation/Foundation.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdint.h>
#import <string.h>

#define MYB_JC_RECORD_LEN 15
#define MYB_JC_HEADER_LEN 8
// The on-device path, relative to the RootHide jbroot -- the caller (the call service hook, which already links against the real RootHide SDK)
// resolves it with jbroot(MYB_JC_DATASET_PATH) before passing it to MYBJCLoad below. Kept out of this header so it stays plain Foundation: the
// same file is compiled as-is by the desktop tests, which have no RootHide SDK and never need the real on-device path.
#define MYB_JC_DATASET_PATH @"/usr/share/mybloxx/junk-callers/JunkCallers.dat"

// Zero-pads an MYBPCKey-style "+digits" phone key's digits on the left to the dataset's fixed record width, or nil if it is not a plain digit string
// or would not fit (longer than the widest entry the dataset can hold -- never true for a real phone number, but checked rather than assumed).
static inline NSString *MYBJCPaddedDigits(NSString *key){
 if(![key isKindOfClass:NSString.class])return nil;
 NSString *digits=[key hasPrefix:@"+"]?[key substringFromIndex:1]:key;
 if(!digits.length||digits.length>MYB_JC_RECORD_LEN)return nil;
 for(NSUInteger i=0;i<digits.length;i++){unichar c=[digits characterAtIndex:i];if(c<'0'||c>'9')return nil;}
 NSMutableString *padded=[NSMutableString string];
 for(NSUInteger i=digits.length;i<MYB_JC_RECORD_LEN;i++)[padded appendString:@"0"];
 [padded appendString:digits];
 return padded;
}
// Binary search over a raw buffer of sorted, fixed-width records, exactly as MYBJCPaddedDigits produces and the generator writes. Pure pointer and
// length arithmetic -- no file I/O, no UIKit -- so this is the part the desktop tests exercise directly against a small in-memory buffer.
static inline BOOL MYBJCBufferContains(const char *records,size_t recordCount,NSString *paddedDigits){
 if(!records||!recordCount||paddedDigits.length!=MYB_JC_RECORD_LEN)return NO;
 char target[MYB_JC_RECORD_LEN];
 for(NSUInteger i=0;i<MYB_JC_RECORD_LEN;i++)target[i]=(char)[paddedDigits characterAtIndex:i];
 size_t lo=0,hi=recordCount;
 while(lo<hi){
  size_t mid=lo+(hi-lo)/2;
  int cmp=memcmp(records+mid*MYB_JC_RECORD_LEN,target,MYB_JC_RECORD_LEN);
  if(cmp==0)return YES;
  if(cmp<0)lo=mid+1;else hi=mid;
 }
 return NO;
}
// Opens and memory-maps the dataset file read-only. The OS pages it in lazily as the binary search touches it, so this never costs the full file
// size in resident memory -- only the handful of pages a given lookup's comparisons actually land on. Call once (e.g. at hook install time) and
// keep the mapping for the process lifetime; there is nothing to unmap on an ordinary exit.
static inline BOOL MYBJCLoad(NSString *path,const char **outRecords,size_t *outCount){
 if(outRecords)*outRecords=NULL;if(outCount)*outCount=0;
 if(![path isKindOfClass:NSString.class]||!path.length)return NO;
 int fd=open(path.fileSystemRepresentation,O_RDONLY);
 if(fd<0)return NO;
 struct stat st;
 if(fstat(fd,&st)!=0||st.st_size<MYB_JC_HEADER_LEN){close(fd);return NO;}
 void *map=mmap(NULL,(size_t)st.st_size,PROT_READ,MAP_PRIVATE,fd,0);
 close(fd);
 if(map==MAP_FAILED)return NO;
 uint64_t count=0;memcpy(&count,map,MYB_JC_HEADER_LEN);
 size_t expected=MYB_JC_HEADER_LEN+(size_t)count*MYB_JC_RECORD_LEN;
 if((size_t)st.st_size<expected){munmap(map,(size_t)st.st_size);return NO;}
 if(outRecords)*outRecords=((const char *)map)+MYB_JC_HEADER_LEN;
 if(outCount)*outCount=(size_t)count;
 return YES;
}
// Whether `key` (an MYBPCKey-style "+digits" string) is in the loaded dataset. NO for anything that is not a usable phone key, never a crash.
static inline BOOL MYBJCIsListed(const char *records,size_t count,NSString *key){
 NSString *padded=MYBJCPaddedDigits(key);
 if(!padded)return NO;
 return MYBJCBufferContains(records,count,padded);
}
