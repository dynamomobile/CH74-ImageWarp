#import "MyView.h"
#import "imageUtil.h"
#import <OpenGL/gl.h>

typedef struct {
    GLfloat org_x, org_y;
    GLfloat new_x, new_y;
} point;

#define NUM_POINTS_X 9
#define NUM_POINTS_Y 9

point points[NUM_POINTS_X][NUM_POINTS_Y];

@implementation MyView {
    BOOL clearBackground;
    GLuint texFaceGrid;
    GLuint texImage;
    int dragged_px;
    int dragged_py;
}

- (void)setPreparePoints:(BOOL)preparePoints
{
    _preparePoints = preparePoints;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    NSPoint pt = [theEvent locationInWindow];
    pt.x /= 512.0;
    pt.y /= 512.0;
    dragged_px = -1;
    dragged_py = -1;
    for (int x=0; x<NUM_POINTS_X; x++) {
        for (int y=0; y<NUM_POINTS_X; y++) {
            if (20/512.0 > fabs(pt.x - points[x][y].org_x) &&
                20/512.0 > fabs(pt.y - points[x][y].org_y)) {
                dragged_px = x;
                dragged_py = y;
            }
        }
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint pt = [theEvent locationInWindow];
    pt.x /= 512.0;
    pt.y /= 512.0;
    if (dragged_px > -1 && dragged_py > -1) {
        if (dragged_px > 0 && dragged_px < NUM_POINTS_X-1) {
            points[dragged_px][dragged_py].org_x = pt.x;
        }
        if (dragged_py > 0 && dragged_py < NUM_POINTS_Y-1) {
            points[dragged_px][dragged_py].org_y = pt.y;
        }
        if (_preparePoints) {
            [self copyOrgToNew];
        }
        [self setNeedsDisplay:YES];
    }
}

- (GLuint)loadTexture:(const char*)path
{
    demoImage *image = imgLoadImage(path, 1);

    GLuint texName;

    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    // Set up filter and wrap modes for this texture object
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    
    // Indicate that pixel rows are tightly packed
    //  (defaults to stride of 4 which is kind of only good for
    //  RGBA or FLOAT data types)
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    // Allocate and load image data into texture
    glTexImage2D(GL_TEXTURE_2D, 0, image->format, image->width, image->height, 0,
                 image->format, image->type, image->data);
    
    // Create mipmaps for this texture for better image quality
    glGenerateMipmap(GL_TEXTURE_2D);
    
    imgDestroyImage(image);
    
    return texName;
}

- (void)prepareOpenGL
{
    texFaceGrid = [self loadTexture:[[NSBundle mainBundle] pathForResource:@"mask-i" ofType:@"png"].UTF8String];
    texImage = [self loadTexture:[[NSBundle mainBundle] pathForResource:@"maori" ofType:@"png"].UTF8String];
    clearBackground = YES;
    for (int x=0; x<NUM_POINTS_X; x++) {
        for (int y=0; y<NUM_POINTS_X; y++) {
            points[x][y].org_x = ((float)x)/(NUM_POINTS_X-1);
            points[x][y].org_y = ((float)y)/(NUM_POINTS_Y-1);
        }
    }
    [self copyOrgToNew];
    _preparePoints = YES;
}

- (void)save
{
    NSImage *image = [self image];
    CGImageRef cgRef = [image CGImageForProposedRect:NULL
                                             context:nil
                                               hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    [newRep setSize:[image size]];   // if you want the same resolution
    NSData *pngData = [newRep representationUsingType:NSPNGFileType properties:@{}];
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = @"maori-modded.png";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [pngData writeToURL:panel.URL atomically:YES];
            system([NSString stringWithFormat:@"open \"%@\"", panel.URL.path].UTF8String);
        }
    }];
}

- (void)copyOrgToNew
{
    for (int x=0; x<NUM_POINTS_X; x++) {
        for (int y=0; y<NUM_POINTS_X; y++) {
            points[x][y].new_x = points[x][y].org_x;
            points[x][y].new_y = points[x][y].org_y;
        }
    }
}

- (void)clearGLContext
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (NSImage*)image
{
    clearBackground = NO;

    NSRect bounds = [self bounds];
    int height = bounds.size.height;
    int width = bounds.size.width;
    
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:NULL
                                  pixelsWide:width
                                  pixelsHigh:height
                                  bitsPerSample:8
                                  samplesPerPixel:4
                                  hasAlpha:YES
                                  isPlanar:NO
                                  colorSpaceName:NSDeviceRGBColorSpace
                                  bytesPerRow:4 * width
                                  bitsPerPixel:0];
    
    // This call is crucial, to ensure we are working with the correct context
    [self.openGLContext makeCurrentContext];
    
    GLuint framebuffer, renderbuffer;
    GLenum status;
    
    //Set up a FBO with one renderbuffer attachment
    glGenFramebuffersEXT(1, &framebuffer);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, framebuffer);
    glGenRenderbuffersEXT(1, &renderbuffer);
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderbuffer);
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_RGBA8, width, height);
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT,
                                 GL_RENDERBUFFER_EXT, renderbuffer);
    status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
    if (status != GL_FRAMEBUFFER_COMPLETE_EXT){
        // Handle errors
    }

    glViewport(0, 0, 512, 512);
    
    //Your code to draw content to the renderbuffer
    [self drawRect:[self bounds]];
    
    //Your code to use the contents
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, [imageRep bitmapData]);
    
    // Make the window the target
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

    // Delete the renderbuffer attachment
    glDeleteRenderbuffersEXT(1, &renderbuffer);
    
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width,height)];
    [image lockFocus];
    NSAffineTransform* t = [NSAffineTransform transform];
    [t translateXBy:0 yBy:imageRep.pixelsHigh];
    [t scaleXBy:1 yBy:-1];
    [t concat];
    [imageRep drawInRect:NSMakeRect(0, 0, width, height)];
    [image unlockFocus];
    
    clearBackground = YES;

    glViewport(0, 0, 1024, 1024);

    return image;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (clearBackground) {
        glClearColor(0.85, 0.85, 0.85, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
    } else {
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    glEnable(GL_TEXTURE_2D);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_CULL_FACE);
    glColor3f(1, 1, 1);
    
    glBindTexture(GL_TEXTURE_2D, texImage);

#if 0
    glBegin(GL_TRIANGLE_STRIP);
    {
        glTexCoord2f( 0, 0);
        glVertex3f( -1,  -1, 0);
        
        glTexCoord2f( 1, 0);
        glVertex3f( 1, -1, 0);
        
        glTexCoord2f( 0, 1);
        glVertex3f( -1, 1, 0);
        
        glTexCoord2f( 1, 1);
        glVertex3f( 1, 1, 0);
    }
    glEnd();
#else
    glBegin(GL_QUADS);
    for (int x=0; x<NUM_POINTS_X-1; x++) {
        for (int y=0; y<NUM_POINTS_Y-1; y++) {
#define VERTEX(_x, _y) \
glVertex3f( -1 + (_x)*2.0 - 1/1024.0,  -1 + (_y)*2.0 - 1/1024.0, 0)
            glTexCoord2f(points[x][y].new_x, points[x][y].new_y);
            VERTEX(points[x][y].org_x, points[x][y].org_y);
            
            glTexCoord2f(points[x+1][y].new_x, points[x+1][y].new_y);
            VERTEX(points[x+1][y].org_x, points[x+1][y].org_y);
            
            glTexCoord2f(points[x+1][y+1].new_x, points[x+1][y+1].new_y);
            VERTEX(points[x+1][y+1].org_x, points[x+1][y+1].org_y);
            
            glTexCoord2f(points[x][y+1].new_x, points[x][y+1].new_y);
            VERTEX(points[x][y+1].org_x, points[x][y+1].org_y);
#undef VERTEX
        }
    }
    glEnd();
#endif
    
    if (!clearBackground) {
        return;
    }
    
    glBindTexture(GL_TEXTURE_2D, texFaceGrid);

    glBegin(GL_TRIANGLE_STRIP);
    {
#define VERTEX(_x, _y) \
    glTexCoord2f( _x, _y); \
    glVertex3f( -1 + (_x)*2.0,  -1 + (_y)*2.0, 0)
        VERTEX(0,0);
        VERTEX(1,0);
        VERTEX(0,1);
        VERTEX(1,1);
#undef VERTEX
    }
    glEnd();
    glBindTexture(GL_TEXTURE_2D, 0);

    if (_preparePoints) {
        glColor3f(0, 1, 0);
    } else {
        glColor3f(1, 0, 0);
    }

    glBegin(GL_LINES);
    for (int x=0; x<NUM_POINTS_X-1; x++) {
        for (int y=0; y<NUM_POINTS_Y-1; y++) {
#define VERTEX(_x, _y) \
glVertex3f( -1 + (_x)*2.0,  -1 + (_y)*2.0, 0)
            VERTEX(points[x][y].org_x, points[x][y].org_y);
            VERTEX(points[x+1][y].org_x, points[x+1][y].org_y);
            VERTEX(points[x][y].org_x, points[x][y].org_y);
            VERTEX(points[x][y+1].org_x, points[x][y+1].org_y);
        }
    }
    glEnd();
    
    glPointSize(15);

    glBegin(GL_POINTS);
    for (int x=0; x<NUM_POINTS_X; x++) {
        for (int y=0; y<NUM_POINTS_Y; y++) {
            VERTEX(points[x][y].org_x, points[x][y].org_y);
        }
    }
    glEnd();
    
    [self.openGLContext flushBuffer];
}

@end
