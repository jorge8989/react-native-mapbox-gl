//
//  RCTMGLLocationManager.m
//  RCTMGL
//
//  Created by Nick Italiano on 6/21/18.
//  Copyright © 2018 Mapbox Inc. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "RCTMGLLocationManager.h"

@interface RCTMGLLocationManager()<CLLocationManagerDelegate>
@end

@implementation RCTMGLLocationManager
{
    CLLocationManager *locationManager;
    CLLocation *lastKnownLocation;
    CLHeading *lastKnownHeading;
    NSMutableArray<RCTMGLLocationBlock> *listeners;
    BOOL isListening;
}

+ (id)sharedInstance
{
    static RCTMGLLocationManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[self alloc] init]; });
    return manager;
}

- (instancetype)init
{
    if (self = [super init]) {
        [self _setupLocationManager];
        listeners = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    locationManager.delegate = nil;
    [self stop];
}

- (void)start
{
    if ([self isEnabled]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [locationManager requestWhenInUseAuthorization];
        [locationManager startUpdatingLocation];
        [locationManager startUpdatingHeading];
        isListening = YES;
    });
}

- (void)stop
{
    if (![self isEnabled]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [locationManager stopUpdatingLocation];
        [locationManager stopUpdatingHeading];
        isListening = NO;
    });
}

- (BOOL)isEnabled
{
    return isListening;
}

- (RCTMGLLocation *)getLastKnownLocation
{
    lastKnownLocation = locationManager.location;
    RCTMGLLocation *location = [self _convertToMapboxLocation:lastKnownLocation];
    return location;
}

- (void)addListener:(RCTMGLLocationBlock)listener
{
    if (![listeners containsObject:listener]) {
        [listeners addObject:listener];
    }
}

- (void)removeListener:(RCTMGLLocationBlock)listener
{
    NSUInteger indexOf = [listeners indexOfObject:listener];
    
    if (indexOf == NSNotFound) {
        return;
    }

    [listeners removeObjectAtIndex:indexOf];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading
{
    lastKnownHeading = heading;
    [self _updateDelegate];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    lastKnownLocation = [locations lastObject];
    [self _updateDelegate];
}

- (void)_setupLocationManager
{
    __weak RCTMGLLocationManager *weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = weakSelf;
    });
}

- (void)_updateDelegate
{
    if (_delegate == nil) {
        return;
    }
    
    RCTMGLLocation *userLocation = [self _convertToMapboxLocation:lastKnownLocation];
    
    if (listeners.count > 0) {
        for (int i = 0; i < listeners.count; i++) {
            RCTMGLLocationBlock listener = listeners[i];
            listener(userLocation);
        }
    }
    
    [_delegate locationManager:self didUpdateLocation:userLocation];
}

- (RCTMGLLocation *)_convertToMapboxLocation:(CLLocation *)location
{
    if (location == nil) {
        return nil;
    }

    RCTMGLLocation *userLocation = [[RCTMGLLocation alloc] init];
    userLocation.location = location;
    userLocation.heading = lastKnownHeading;
    return userLocation;
}

@end
