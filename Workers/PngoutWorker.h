//
//  PngoutWorker.h
//  ImageOptim
//
//  Created by porneL on 29.wrz.07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CommandWorker.h"

@interface PngoutWorker : CommandWorker {
	int fileSizeOptimized;
}


-(BOOL)makesNonOptimizingModifications;

@end
