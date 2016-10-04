#import "ViewController.h"
#import "MyView.h"

@implementation ViewController {
    IBOutlet __weak MyView *myview;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];
}

- (IBAction)preparePoints:(id)sender
{
    myview.preparePoints = !myview.preparePoints;
}

- (IBAction)saveDocument:(id)sender
{
    [myview save];
}

@end
