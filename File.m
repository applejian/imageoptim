//
//  File.m
//
//  Created by porneL on 8.wrz.07.
//

#import "File.h"

#import "AdvCompWorker.h"
#import "PngoutWorker.h"
#import "OptiPngWorker.h"
#import "PngCrushWorker.h"
#import "JpegoptimWorker.h"
#import "JpegtranWorker.h"
//#import "Dupe.h"

@implementation File

@synthesize byteSize, byteSizeOptimized, filePath, displayName, statusText, statusImage, filePath, percentDone;

-(id)initWithFilePath:(NSString *)name;
{
	if (self = [self init])
	{	
		[self setFilePath:name];
		[self setStatus:@"wait" text:@"New file"];
		
		workersTotal = 0;
		workersActive = 0;
		workersFinished = 0;
//		NSLog(@"Created new");
	}
	return self;	
}

-(NSString *)fileName
{
	if (displayName) return displayName;
	if (filePath) return filePath;
	return @"N/A";
}

-(void)setFilePath:(NSString *)s
{
	if (filePath != s)
	{
		filePath = [s copy];
		
        self.displayName = [[NSFileManager defaultManager] displayNameAtPath:filePath];		
	}
}

- (id)copyWithZone:(NSZone *)zone
{
	File *f = [[File allocWithZone:zone] init];
	[f setByteSize:byteSize];
	[f setByteSizeOptimized:byteSizeOptimized];
	[f setFilePath:filePath];
//	NSLog(@"copied");
	return f;
}

-(void)setByteSize:(long)size
{
    @synchronized(self) 
    {        
        if (!byteSize && size > 10)
        {
    //		NSLog(@"setting file size of %@ to %d",self,size);
            byteSize = size;
            if (!byteSizeOptimized || byteSizeOptimized > byteSize) [self setByteSizeOptimized:size];		
        }
        else if (byteSize != size)
        {
    //		NSLog(@"crappy size given! %d, have %d",size,byteSize);
        }
    }
}

-(double)percentOptimized
{
	if (![self isOptimized]) return 0.0;
	double p = 100.0 - 100.0* (double)byteSizeOptimized/(double)byteSize;
	if (p<0) return 0.0;
	return p;
}

-(void)setPercentOptimized:(double)f
{
	// just for KVO
}
-(BOOL)isOptimized
{
	return byteSizeOptimized!=0;
}

-(void)setByteSizeOptimized:(long)size
{
    @synchronized(self) 
    {        
        if ((!byteSizeOptimized || size < byteSizeOptimized) && size > 30)
        {
    //		NSLog(@"We've got a new winner. old %d new %d",byteSizeOptimized,size);
            byteSizeOptimized = size;
            [self setPercentOptimized:0.0]; //just for KVO
        }
    }
}

-(void)removeOldFilePathOptimized
{
	if (filePathOptimized)
	{
        if ([filePathOptimized length])
        {
            [[NSFileManager defaultManager] removeFileAtPath:filePathOptimized handler:nil];
        }
        filePathOptimized = nil;
	}
}

-(void)setFilePathOptimized:(NSString *)path size:(long)size
{
    @synchronized(self) 
    {        
        NSLog(@"File %@ optimized from %d down to %d in %@",filePath?filePath:filePathOptimized,byteSizeOptimized,size,path);        
        if (size <= byteSizeOptimized)
        {
            [self removeOldFilePathOptimized];
            filePathOptimized = [path copy];
            [self setByteSizeOptimized:size];
        }
    //	NSLog(@"Got optimized %db path %@",size,path);
    }
}

-(BOOL)saveResult
{
	if (!filePathOptimized) 
	{
		NSLog(@"WTF? save without filePathOptimized? for %@", filePath);
		return NO;
	}
	
	@try
	{
		NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
		BOOL preserve = [defs boolForKey:@"PreservePermissions"];
		BOOL backup = [defs boolForKey:@"BackupFiles"];
		NSFileManager *fm = [NSFileManager defaultManager];
		
		if (backup)
		{
			NSString *backupPath = [filePath stringByAppendingString:@"~"];
			
			[fm removeFileAtPath:backupPath handler:nil];
			
			BOOL res;
			if (preserve)
			{
				res = [fm copyPath:filePath toPath:backupPath handler:nil];
			}
			else
			{
				res = [fm movePath:filePath toPath:backupPath handler:nil];
			}
			
			if (!res)
			{
				NSLog(@"failed to save backup as %@ (preserve = %d)",backupPath,preserve);
				return NO;
			}
		}
		
		if (preserve)
		{		
			NSFileHandle *read = [NSFileHandle fileHandleForReadingAtPath:filePathOptimized];
			NSFileHandle *write = [NSFileHandle fileHandleForWritingAtPath:filePath];
			NSData *data = [read readDataToEndOfFile];
			
			if ([data length] == byteSizeOptimized && [data length] > 30)
			{
				[write writeData:data];
				[write truncateFileAtOffset:[data length]];
                [read closeFile];
                [write closeFile];
                [self removeOldFilePathOptimized];
			}
			else 
			{
				NSLog(@"Temp file size %d does not match expected %d in %@ for %@",[data length],byteSizeOptimized,filePathOptimized,filePath);
				return NO;				
			}
		}
		else
		{
			if (!backup) {[fm removeFileAtPath:filePath handler:nil];}
			
			if ([fm movePath:filePathOptimized toPath:filePath handler:nil]) 
			{
                filePathOptimized = nil;
            }            
            else
            {
                NSLog(@"Failed to move from %@ to %@",filePathOptimized, filePath);
				return NO;				
			}
		}
	}
	@catch(NSException *e)
	{
		NSLog(@"Exception thrown %@",e);
		return NO;
	}
	
	return YES;
}

-(void)workerHasStarted:(Worker *)worker
{
	@synchronized(self)
    {
        workersActive++;
        [self setStatus:@"progress" text:[NSString stringWithFormat:@"Started %@",[worker className]]];        
    }
}

-(void)saveResultAndUpdateStatus {
    if ([self saveResult])
    {
        [self setStatus:@"ok" text:@"Optimized successfully"];						
    }
    else 
    {
        NSLog(@"saveResult failed");
        [self setStatus:@"err" text:@"Optimized file could not be saved"];				
    }
}

-(void)workerHasFinished:(Worker *)worker
{
	@synchronized(self) 
    {
        workersActive--;
        workersFinished++;
        
        if (!workersActive)
        {
            if (!byteSize || !byteSizeOptimized)
            {
                NSLog(@"worker %@ finished, but result file has 0 size",worker);
                [self setStatus:@"err" text:@"Size of optimized file is 0"];
            }
            else if (workersFinished == workersTotal)
            {
                if (byteSize > byteSizeOptimized)
                {
                    NSOperation *saveOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(saveResultAndUpdateStatus) object:nil];
                    [workers addObject:saveOp];
                    [fileIOQueue addOperation:saveOp];                    
                }
                else
                {
                    [self setStatus:@"noopt" text:@"File cannot be optimized any further"];	
//                    if (dupe) [Dupe addDupe:dupe];
                }
            }
            else
            {
                [self setStatus:@"wait" text:@"Waiting to start more optimisations"];
            }
        }
    }	    
}

//-(void)checkDupe:(NSData *)data {
//    Dupe *d = [[Dupe alloc] initWithData:data];
//    @synchronized(self) {
//        dupe = d;        
//    }
//    if ([Dupe isDupe:dupe])
//    {
//        [self cleanup];
//        [self setStatus:@"noopt" text:@"File was already optimized by ImageOptim"];
//    }
//    
//}

#define FILETYPE_PNG 1
#define FILETYPE_JPEG 2

-(int)fileType:(NSData *)data
{
	const unsigned char pngheader[] = {0x89,0x50,0x4e,0x47,0x0d,0x0a};
    const unsigned char jpegheader[] = {0xff,0xd8,0xff,0xe0};
    char filedata[6];

    [data getBytes:filedata length:sizeof(filedata)];
    
	if (0==memcmp(filedata, pngheader, sizeof(pngheader)))
	{
		return FILETYPE_PNG;
	}
    else if (0==memcmp(filedata, jpegheader, sizeof(jpegheader)))
    {
        return FILETYPE_JPEG;
    }
	return 0;
}

-(void)enqueueWorkersInCPUQueue:(NSOperationQueue *)queue fileIOQueue:(NSOperationQueue *)aFileIOQueue
{
    fileIOQueue = aFileIOQueue; // will be used for saving
    
    //NSLog(@"%@ add",filePath);
    [self setStatus:@"wait" text:@"Waiting in queue"];
    
    @synchronized(self)
    {
        workersActive++; // isBusy must say yes!
    }
    
    workers = [[NSMutableArray alloc] initWithCapacity:10];
    
    NSOperation *actualEnqueue = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(doEnqueueWorkersInCPUQueue:) object:queue];
    [workers addObject:actualEnqueue];
    [fileIOQueue addOperation:actualEnqueue];        
}

-(void)doEnqueueWorkersInCPUQueue:(NSOperationQueue *)queue {  

    //NSLog(@"%@ inspect",filePath);
    [self setStatus:@"progress" text:@"Inspecting file"];        

    @synchronized(self)
    {
        workersActive--;        
        byteSize=0; // reset to allow restart
        byteSizeOptimized=0;
    }
    	
	Worker *w = NULL;
	NSMutableArray *runFirst = [NSMutableArray new];
	NSMutableArray *runLater = [NSMutableArray new];
		
	NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
	
    NSData *fileData = [NSData dataWithContentsOfMappedFile:filePath];
    NSUInteger length = [fileData length];
    if (!fileData || !length)
    {
        [self setStatus:@"err" text:@"Can't map file into memory"]; 
        return;
    }
    [self setByteSize:length];

//    if (length > 800) // don't bother with tiny files
//    {
//       NSOperation *checkDupe = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(checkDupe:) object:fileData];
//       // largeish files are best to skip
//        if (length > 10000) [checkDupe setQueuePriority:NSOperationQueuePriorityHigh];
//        else if (length < 3000) [checkDupe setQueuePriority:NSOperationQueuePriorityLow];
//        [workers addObject:checkDupe];
//        [fileIOQueue addOperation:checkDupe];
//    }
    
    int fileType = [self fileType:fileData];
    
	if (fileType == FILETYPE_PNG)
	{
		//NSLog(@"%@ is png",filePath);
		if ([defs boolForKey:@"PngCrush.Enabled"])
		{
			w = [[PngCrushWorker alloc] initWithFile:self];
			if ([w makesNonOptimizingModifications]) [runFirst addObject:w];
			else [runLater addObject:w];
		}
		if ([defs boolForKey:@"PngOut.Enabled"])
		{
			w = [[PngoutWorker alloc] initWithFile:self];
			if ([w makesNonOptimizingModifications]) [runFirst addObject:w];
			else [runLater addObject:w];
		}
		if ([defs boolForKey:@"OptiPng.Enabled"])
		{
			w = [[OptiPngWorker alloc] initWithFile:self];
			if ([w makesNonOptimizingModifications]) [runFirst addObject:w];
			else [runLater addObject:w];
		}
		if ([defs boolForKey:@"AdvPng.Enabled"])
		{
			w = [[AdvCompWorker alloc] initWithFile:self];
			if ([w makesNonOptimizingModifications]) [runFirst addObject:w];
			else [runLater addObject:w];
		}
	}
	else if (fileType == FILETYPE_JPEG)
    {
        if ([defs boolForKey:@"JpegOptim.Enabled"])
        {
            //NSLog(@"%@ is jpeg",filePath);
            w = [[JpegoptimWorker alloc] initWithFile:self];
            [runLater addObject:w];
        }
        if ([defs boolForKey:@"JpegTran.Enabled"])
        {
            //NSLog(@"%@ is jpeg",filePath);
            w = [[JpegtranWorker alloc] initWithFile:self];
            [runLater addObject:w];
        }
    }
	else {
        [self setStatus:@"err" text:@"File is neither PNG nor JPEG"];
		//NSBeep();
        [self cleanup];
        return;
    }
    
	Worker *lastWorker = nil;
	
//	NSLog(@"file %@ has workers first %@ and later %@",self,runFirst,runLater);
		
	workersTotal += [runFirst count] + [runLater count];

	for(Worker *w in runFirst)
	{
        if (lastWorker) 
        {
            [w addDependency:lastWorker];            
        }
        else {
            [w setQueuePriority:NSOperationQueuePriorityLow]; // finish first!
        }
		[queue addOperation:w];
		lastWorker = w;
	}
	
    lastWorker = [runFirst lastObject];
	for(Worker *w in runLater)
	{
        if (lastWorker) [w addDependency:lastWorker];
		[queue addOperation:w];
	}	
	
    [workers addObjectsFromArray:runFirst];
    [workers addObjectsFromArray:runLater];
    
	if (!workersTotal) 
	{
		//NSLog(@"all relevant tools are unavailable/disabled - nothing to do!");
		[self setStatus:@"err" text:@"All neccessary tools have been disabled in Preferences"];
        [self cleanup];
	}
    else {
        [self setStatus:@"wait" text:@"Waiting to be optimized"];
    }
}

-(void)cleanup
{
    @synchronized(self)
    {
        for(NSOperation *w in workers)
        {
            [w cancel]; 
        }
        [workers removeAllObjects];
        [self removeOldFilePathOptimized];
    }
}

-(BOOL)isBusy
{
    BOOL isit;
    @synchronized(self)
    {
        isit = workersActive || workersTotal != workersFinished;        
    }
    return isit;
}

-(void)setStatus:(NSString *)imageName text:(NSString *)text
{
    @synchronized(self) 
    {
        if (statusText == text) return;        
        self.statusText = text;
        self.statusImage = [NSImage imageNamed:imageName];
    }
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ %d/%d (workers active %d, finished %d, total %d)", self.filePath,self.byteSize,self.byteSizeOptimized, workersActive, workersFinished, workersTotal];
}

+(long)fileByteSize:(NSString *)afile
{
	NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:afile traverseLink:NO];
	if (attr) return [[attr objectForKey:NSFileSize] longValue];
	return 0;
}

@end