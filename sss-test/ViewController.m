//
//  ViewController.m
//  sss-test
//
//  Created by Scott Lee on 5/7/15.
//  Copyright (c) 2015 Scott Lee. All rights reserved.
//

#import "ViewController.h"
#import <SIOSocket/SIOSocket.h>
#import <NKOColorPickerView.h>
#import <QuartzCore/QuartzCore.h>
#import "MBProgressHUD.h"

@interface ViewController ()
{
    SIOSocket *_socket;
}

@property (weak, nonatomic) IBOutlet NKOColorPickerView *colorPickerView;
@property (weak, nonatomic) IBOutlet UIView *resultView;
@property (weak, nonatomic) IBOutlet UILabel *lb_hexCode;
@property (weak, nonatomic) MBProgressHUD *busyIndicator;
@property (nonatomic) BOOL hasConnected;

@end

#define SOCKET_SERVER @"http://color-vn.cloudapp.net"
#define MAX_ATTEMPTS 5

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set border for result view
    self.resultView.layer.borderColor = [UIColor blackColor].CGColor;
    self.resultView.layer.borderWidth = 1.0f;
    self.resultView.layer.cornerRadius = 5.0f;
    
    UIColor *initColor = [UIColor colorWithRed:0.0/255.0 green:153.0/255.0 blue:204.0/255.0 alpha:1.0];
    self.colorPickerView.color = initColor;
    [self setColor:initColor];
    
    self.colorPickerView.didChangeColorBlock = ^(UIColor *color){
        [self setColor:color];
    };
    
    self.busyIndicator = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    self.busyIndicator.labelText = @"Connecting";
    
    [SIOSocket socketWithHost: SOCKET_SERVER reconnectAutomatically:YES attemptLimit:MAX_ATTEMPTS withDelay:1 maximumDelay:5 timeout:20 response: ^(SIOSocket *socket)
     {
         _socket = socket;
         
         __weak typeof(self) weakSelf = self;
         __block int _attempts = 0;
         _socket.onConnect = ^() {
             weakSelf.hasConnected = YES;
             [weakSelf.busyIndicator hide:NO];
             [weakSelf setColor:initColor];
         };
         
         _socket.onError = ^(NSDictionary *error) {
             [weakSelf.busyIndicator hide:NO];
             weakSelf.hasConnected = NO;
             
             UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection error" message: @"Cannot connect to socket server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
             [alert show];
         };
         
         _socket.onReconnect = ^(NSInteger attemps) {
             weakSelf.hasConnected = YES;
             [weakSelf.busyIndicator hide:NO];
             [weakSelf setColor:initColor];
         };
         
         
         _socket.onReconnectionAttempt = ^(NSInteger attemps) {
             weakSelf.busyIndicator.detailsLabelText = [NSString stringWithFormat:@"reconnecting (%d attempts)", (int)attemps];
             _attempts = (int)attemps;
         };
         
         _socket.onReconnectionError = ^(NSDictionary *error) {
             if (_attempts == MAX_ATTEMPTS) {
                 [weakSelf.busyIndicator hide:NO];
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection error" message: @"Cannot connect to socket server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
                 [alert show];
             }
             
             weakSelf.hasConnected = NO;
         };
         
         [_socket on:@"get-ios-background" callback:^(SIOParameterArray  *args) {
             NSLog(@"in get-ios-background");
             NSString *currentBgHex = [self hexStringForColor:self.colorPickerView.color];
             [_socket emit:@"set-background" args:@[currentBgHex]];
         }];
     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) setColor: (UIColor *) bgColor {
    self.resultView.backgroundColor = bgColor;
    NSString *bgColorText = [self hexStringForColor:bgColor];
    
    self.lb_hexCode.textColor = [self getForegroundColor:bgColor];
    if (self.hasConnected) {
        self.lb_hexCode.text = bgColorText;
        [_socket emit:@"set-background" args:@[bgColorText]];
    }
    else {
        self.lb_hexCode.text = @"no connection";
    }
    
}

- (UIColor *) getForegroundColor: (UIColor *)backgroundColor {
    const CGFloat *components = CGColorGetComponents(backgroundColor.CGColor);
    CGFloat r = components[0] * 255.0;
    CGFloat g = components[1] * 255.0;
    CGFloat b = components[2] * 255.0;
    
    CGFloat yiq = ((r*299)+(g*587)+(b*114))/1000;
    return yiq >= 128 ? [UIColor blackColor] : [UIColor whiteColor];
}

- (NSString *)hexStringForColor:(UIColor *)color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    NSString *hexString=[NSString stringWithFormat:@"#%02X%02X%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];
    return hexString;
}

@end
