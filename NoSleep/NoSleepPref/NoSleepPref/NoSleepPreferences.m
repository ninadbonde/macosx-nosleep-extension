//
//  nosleep_preferences.m
//  nosleep-preferences
//
//  Created by Pavel Prokofiev on 4/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NoSleepPreferences.h"
#import <IOKit/IOMessage.h>
#import <NoSleep/GlobalConstants.h>

@implementation NoSleepPreferences

typedef enum {
    kLICheck    = 0,
    kLIRegister,
    kLIUnregister,
} LoginItemAction;

- (BOOL)loginItem:(LoginItemAction)action {
    UInt32 seedValue;
    
    LSSharedFileListRef loginItemsRefs = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    
    NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItemsRefs, &seedValue);  
    for (id item in loginItemsArray) {    
        LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
        CFURLRef path;
        if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*)&path, NULL) == noErr) {
            if ([[(NSURL *)path path] isEqualToString:@NOSLEEP_HELPER_PATH]) {
                // if exists
                if(action == kLIUnregister) {
                    LSSharedFileListItemRemove(loginItemsRefs, itemRef);
                }
                
                return YES;
            }
            CFRelease(path);
        }
    }
    
    if(action == kLIRegister) {
        //CFURLRef url1 = (CFURLRef)[[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:NOSLEEP_HELPER_IDENTIFIER];
        //NSURL *url11 = (NSURL*)url1;
        NSURL *url = [[NSURL alloc] initFileURLWithPath:@NOSLEEP_HELPER_PATH];
        
        LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItemsRefs, kLSSharedFileListItemLast,
                                                                     NULL, NULL, (CFURLRef)url, NULL, NULL);
        
        if (item) {
            CFRelease(item);
        }
    }
    
    return NO;
}

- (id)initWithBundle:(NSBundle *)bundle
{
    // Initialize the location of our preferences
    if ((self = [super initWithBundle:bundle]) != nil) {
        m_noSleepInterface = nil;
    }
    
    return self;
}

- (void)notificationReceived:(uint32_t)messageType :(void *)messageArgument
{
    [self updateEnableState];
}

- (void)updateEnableState
{
    stateAC = [m_noSleepInterface stateForMode:kNoSleepModeAC];
    stateBattery = [m_noSleepInterface stateForMode:kNoSleepModeBattery];
    [m_checkBoxEnableAC setState:stateAC];
    [m_checkBoxEnableBattery setState:stateBattery];
}

- (void)willSelect
{
    if(m_noSleepInterface == nil) {
         m_noSleepInterface = [[NoSleepInterfaceWrapper alloc] init];   
    }
    
    if([[NSFileManager defaultManager] fileExistsAtPath:@NOSLEEP_HELPER_PATH]) {
        [m_checkBoxShowIcon setEnabled:YES];
        [m_checkBoxShowIcon setState:[self loginItem:kLICheck]];
        
        [m_checkBoxShowIcon setToolTip:@""];
    } else {
        [m_checkBoxShowIcon setEnabled:NO];
        [m_checkBoxShowIcon setState:NO];
        
        [m_checkBoxShowIcon setToolTip:@"("@NOSLEEP_HELPER_PATH@" not found)"];
    }
    
    if(!m_noSleepInterface) {
        [m_checkBoxEnableAC setEnabled:NO];
        [m_checkBoxEnableAC setState:NO];
        [m_checkBoxEnableBattery setEnabled:NO];
        [m_checkBoxEnableBattery setState:NO];
    } else {
        [m_checkBoxEnableAC setEnabled:YES];
        [m_checkBoxEnableBattery setEnabled:YES];
        [m_noSleepInterface setNotificationDelegate:self];
        [self updateEnableState];
    }
}

- (void)didSelect {
    if(!m_noSleepInterface) {
        SHOW_UI_ALERT_KEXT_NOT_LOADED();           
    }
}

- (void)didUnselect {
    if(!m_noSleepInterface) {
        [m_noSleepInterface release];
        m_noSleepInterface = nil;
    }
}

- (IBAction)checkboxEnableACClicked:(id)sender {
    BOOL newState = [m_checkBoxEnableAC state];
    if(newState != stateAC) {
        [m_noSleepInterface setState:newState forMode:kNoSleepModeAC];
        stateAC = newState;
    }
}

- (IBAction)checkboxEnableBatteryClicked:(id)sender {
    BOOL newState = [m_checkBoxEnableBattery state];
    if(newState != stateBattery) {
        [m_noSleepInterface setState:newState forMode:kNoSleepModeBattery];
        stateBattery = newState;
    }
}

/*
#define kAgentActionLoad "load"
#define kAgentActionUnload "unload"
static void performAgentAction(const char *action)
{
    if (fork() == 0) {
        execlp("launchctl", action, "", NULL);
    }
}
*/

- (void)checkboxShowIconClicked:(id)sender {
    BOOL showIconState = [m_checkBoxShowIcon state];
    if(showIconState) {
        [self loginItem:kLIRegister];
    } else {
        [self loginItem:kLIUnregister];
    }
}

@end
