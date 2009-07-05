#import "ImageOptim.h"
#import "FilesQueue.h"
#import "Worker.h"
#import "PrefsController.h"
#include <mach/mach_host.h>
#include <mach/host_info.h>
//#import "Dupe.h";

@implementation ImageOptim

+(void)initialize
{
	//srandom(random() ^ time(NULL));

	NSMutableDictionary *defs = [NSMutableDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"]];
	
	int maxTasks = [self numberOfCPUs]+1;
	if (maxTasks > 6) maxTasks++;
	
	[defs setObject:[NSNumber numberWithInt:maxTasks] forKey:@"RunConcurrentTasks"];
	[defs setObject:[NSNumber numberWithInt:(int)ceil((double)maxTasks/3.9)] forKey:@"RunConcurrentDirscans"];
	
	[[NSUserDefaults standardUserDefaults] registerDefaults:defs];
}

-(id)init
{
	if (self = [super init])
	{
		fileTypes = [[NSArray alloc] initWithObjects:@"png",@"PNG",NSFileTypeForHFSTypeCode( 'PNGf' ),@"public.png",@"image/png",
			@"jpg",@"jpeg",@"JPG",@"JPEG",NSFileTypeForHFSTypeCode( 'JPEG' ),@"public.jpeg",@"image/jpeg",nil];
	}
	return self;
}

//-(void)loadDupes {
//    [Dupe loadDupes];
//}

-(void)awakeFromNib
{		
	filesQueue = [[FilesQueue alloc] initWithTableView:tableView progressBar:progressBar andController:filesController];
//    [self performSelectorInBackground:@selector(loadDupes) withObject:nil];
}

+(int)numberOfCPUs
{
	host_basic_info_data_t hostInfo;
	mach_msg_type_number_t infoCount;	
	infoCount = HOST_BASIC_INFO_COUNT;
	host_info(mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount);
	return MIN(32,MAX(1,(hostInfo.max_cpus)));
}

// invoked by Dock
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)path
{
    [filesQueue addPath:path dirs:YES];
	[filesQueue runAdded];
	return YES;
}

- (IBAction)startAgain:(id)sender
{
	[filesQueue startAgain];
}

- (IBAction)showPrefs:(id)sender
{
//	NSLog(@"show prefs");

//    [Dupe resetDupes]; // changes in prefs invalidate dupes database; FIXME: this is inaccurate and lame
    
	if (!prefsController)
	{
		prefsController = [PrefsController new];
//		NSLog(@"new prefs = %@",prefsController);
	}
	[prefsController showWindow:self];
}

-(void)openURL:(NSString *)stringURL
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:stringURL]];
}

-(IBAction)openPngOutHomepage:(id)sender
{
	[self openURL:@"http://www.advsys.net/ken/utils.htm"];
}
-(IBAction)openPngOutDownload:(id)sender
{
	[self openURL:@"http://www.jonof.id.au/pngout"];
}

-(IBAction)browseForFiles:(id)sender
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	
    [oPanel setAllowsMultipleSelection:YES];
	[oPanel setCanChooseDirectories:YES];
	[oPanel setResolvesAliases:YES];

    [oPanel beginSheetForDirectory:nil file:nil types:fileTypes modalForWindow:[tableView window] modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:nil];		
}

- (void)openPanelDidEnd:(NSOpenPanel *)oPanel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	if (returnCode == NSOKButton) {
        [filesQueue addPaths:[oPanel filenames]];
    }
}

- (void)windowWillClose:(NSNotification *)aNotification
{
//	NSLog(@"window close!");
	[application terminate:self];
}

-(void)applicationWillTerminate:(NSNotification*)n {    
    [filesQueue cleanup];
//    [Dupe saveDupes];
}

-(NSString*)version {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleGetInfoString"];
}

@synthesize tableView;
@synthesize filesController;
@synthesize filesQueue;
@synthesize application;
@synthesize prefsController;
@synthesize progressBar;
@synthesize fileTypes;
@end
