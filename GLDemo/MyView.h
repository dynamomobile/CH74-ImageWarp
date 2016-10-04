#import <Cocoa/Cocoa.h>

@interface MyView : NSOpenGLView

@property (nonatomic, readwrite) BOOL preparePoints;

- (void)save;

@end
