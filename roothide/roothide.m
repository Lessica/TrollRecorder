#import <Foundation/Foundation.h>

FOUNDATION_EXTERN const char *jbroot(const char *path);

const char *jbroot(const char *path)
{
    static NSMutableDictionary <NSString *, NSString *> *pathCaches = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pathCaches = [NSMutableDictionary dictionary];
    });

    NSString *pathKey = [NSString stringWithUTF8String:path];
    NSString *cachedPath = pathCaches[pathKey];
    if (cachedPath) {
        return [cachedPath UTF8String];
    }

    NSString *realPath = [NSString stringWithFormat:@"/var/jb%@", pathKey];
    pathCaches[pathKey] = realPath;
    return [realPath UTF8String];
}
