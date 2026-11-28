#import "../Shared/MYBLoopback.h"
int main(int argc,const char *argv[]){@autoreleasepool{if(argc!=3)return 64;NSData *data=MYBLoopbackGET(atoi(argv[1]),[NSString stringWithUTF8String:argv[2]]);if(!data)return 1;fwrite(data.bytes,1,data.length,stdout);}return 0;}
