//
//  NCQViewController.m
//  NetChequer
//
//  Created by Steve Sparks on 12/8/13.
//  Copyright (c) 2013 SOG. All rights reserved.
//

#import "NCQViewController.h"
#import "AFNetworking.h"
#include <arpa/inet.h>
#include <sys/types.h>
#include <netinet/in.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import "SimplePing.h"
#include <netdb.h> 

static NSString * DisplayAddressForAddress(NSData * address);

@interface NCQViewController () <NSNetServiceBrowserDelegate, NSNetServiceDelegate, SimplePingDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *correctLanImage;
@property (weak, nonatomic) IBOutlet UIImageView *seeAmburHubImage;
@property (weak, nonatomic) IBOutlet UIImageView *seeInternetImage;
@property (weak, nonatomic) IBOutlet UILabel *correctLanLabel;
@property (weak, nonatomic) IBOutlet UILabel *seeAmburHubLabel;
@property (weak, nonatomic) IBOutlet UILabel *seeInternetLabel;
@property (weak, nonatomic) IBOutlet UILabel *canSeeModemLabel;
@property (weak, nonatomic) IBOutlet UIImageView *canSeeModemImage;

@property (strong, nonatomic) AFHTTPClient *internetClient;

@property (strong, nonatomic) SimplePing *ping;
@property (strong, nonatomic) NSTimer *pingTimer;
@property (nonatomic) int pingTimerCounter;

@property (strong, nonatomic) NSNetServiceBrowser *browser;
@property (strong, nonatomic) NSNetService *foundService;

@end

NSString * const PaymentHostName = @"MercuryPay.com";
NSString * const PaymentHostURL = @"http://www.mercurypay.com/";
NSString * const LocalLANPrefix = @"Pallookaville";
NSString * const AmburHostName = @"Pallookaville Fine Foods";

NSString * const ComcastModemIP = @"24.30.102.58";
//NSString * const ComcastModemIP = @"10.1.10.1";

// cuz i'm lazy
#define YELLOW [UIImage imageNamed:@"yellow"]
#define RED    [UIImage imageNamed:@"red"]
#define GREEN  [UIImage imageNamed:@"green"]

@implementation NCQViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

	self.internetClient = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:PaymentHostURL]];
	__block __weak typeof (self) weakSelf = self;
	[self.internetClient setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status){
		typeof(self) strongSelf = weakSelf;
		[strongSelf checkStatuses:nil];
	}];
	NSNetServiceBrowser *browser = [[NSNetServiceBrowser alloc] init];
	[browser setDelegate:self];
	self.browser = browser;

}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self checkStatuses:nil];
}

// Pad rotates. Nothing else.
- (BOOL)shouldAutorotate {
	return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
}

// ---------------------------------------------------------- TESTS

- (IBAction)checkStatuses:(id)sender {
	[self checkCorrectLan];
	[self checkForAmbur];
	[self checkWan];
	[self checkModemPing];
}

#pragma mark - Checks the network name for the expected value.
- (void) checkCorrectLan {
	self.correctLanLabel.text = @"Cannot detect LAN name.";
	self.correctLanLabel.textColor = [UIColor redColor];
	self.correctLanImage.image = RED;

	NSArray *interfaces = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
	NSString *searchString = LocalLANPrefix;

	if(interfaces.count) {
		BOOL onLocalLan = NO;
		NSString *trimmed = nil;

		for (NSString *interface in interfaces) {
			NSDictionary *info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interface);
			NSString *SSID = info[@"SSID"];
			trimmed = [SSID stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

			if ([trimmed hasPrefix:searchString]) {
				self.correctLanImage.image = GREEN;
				self.correctLanLabel.text = [NSString stringWithFormat:@"We're on the right LAN."];
				self.correctLanLabel.textColor = [UIColor blackColor];
				onLocalLan = YES;
			}
		}
		if(!onLocalLan && trimmed) {
			self.correctLanLabel.text = [NSString stringWithFormat:@"LAN '%@' is wrong! Should start with '%@')", trimmed, searchString];
		}
	}
}

#pragma mark - Check connectivity to the payment processor.

- (void)checkWan {
	self.seeInternetLabel.text = [NSString stringWithFormat:@"%@ available?", PaymentHostName];
	self.seeInternetImage.image = YELLOW;

	[self.internetClient getPath:@"/" parameters:Nil success:^(AFHTTPRequestOperation *op, id response) {
		self.seeInternetLabel.text = [NSString stringWithFormat:@"%@ is online!", PaymentHostName];
		self.seeInternetLabel.textColor = [UIColor blackColor];
		self.seeInternetImage.image = GREEN;
	} failure:^(AFHTTPRequestOperation *op, NSError *err){
		self.seeInternetLabel.text = [NSString stringWithFormat:@"%@ is OFFLINE!", PaymentHostName];
		self.seeInternetLabel.textColor = [UIColor redColor];
		self.seeInternetImage.image = RED;
	}];
}

#pragma mark - Use Bonjour to find AMBUR.

- (void) checkForAmbur {
	[self.browser stop];
	self.seeAmburHubLabel.text = @"I do not see the AMBUR host.";
	self.seeAmburHubLabel.textColor = [UIColor redColor];
	self.seeAmburHubImage.image = RED;
	[self.browser searchForServicesOfType:@"_restaurant._tcp." inDomain:@""];

}

#pragma mark - Bonjour delegate methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
	if([aNetService.name isEqualToString:AmburHostName]) {
		self.seeAmburHubLabel.text = [NSString stringWithFormat:@"Ambur host \"%@\" found.", aNetService.name];
		self.seeAmburHubLabel.textColor = [UIColor blackColor];
		self.seeAmburHubImage.image = GREEN;
		aNetService.delegate = self;
		self.foundService = aNetService;
		[aNetService resolveWithTimeout:10.0];
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
	if([aNetService.name isEqualToString:AmburHostName]) {
		self.seeAmburHubLabel.text = @"Ambur service went offline!";
		self.seeAmburHubLabel.textColor = [UIColor redColor];
		self.seeAmburHubImage.image = RED;
	}

}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing {
	NSLog(@"Domain %@", domainString);
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
	NSLog(@"Broke! %@", errorDict);
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
	struct sockaddr_in *socketAddress = (struct sockaddr_in *) [[service.addresses firstObject] bytes];
	NSString *ipString = [NSString stringWithFormat: @"%s", inet_ntoa(socketAddress->sin_addr)];
	int16_t port = socketAddress->sin_port;

	self.seeAmburHubLabel.text = [NSString stringWithFormat:@"Ambur hub \"%@\" found at %@:%d.", service.name, ipString, port];
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
	self.seeAmburHubLabel.text = [NSString stringWithFormat:@"Ambur hub \"%@\" found but did not resolve.", service.name    ];
	self.seeAmburHubLabel.textColor = [UIColor redColor];
	self.foundService = nil;
}

#pragma mark - Actions.

- (IBAction) networkHintTapped:(id)sender {
	//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network Hint" message:@"Go to Settings and join 'Pallookaville POS' or 'Pallookaville POS 2' wireless networks." delegate:nil cancelButtonTitle:@"OK Geez" otherButtonTitles:nil];
	//	[alert show];
}

- (IBAction) amburHintTapped:(id)sender {

}

- (IBAction) internetHintTapped:(id)sender {

}

- (IBAction) comcastHintTapped:(id)sender {

}

#pragma mark - ICMP ping

- (void) checkModemPing {
	self.canSeeModemImage.image = YELLOW;
	self.canSeeModemLabel.text = @"Can we ping the Comcast modem?";
	[self startPingingAddress:ComcastModemIP];
}

- (void) startPingingAddress:(NSString*)addressStr {
	if(!self.ping) {
		struct sockaddr_in address;
		[self addressFromString:addressStr address:&address];

		NSData *addr = [NSData dataWithBytes:&address length:sizeof(struct sockaddr_in)];
		
		self.ping = [SimplePing simplePingWithHostAddress:addr];
		self.ping.delegate = self;
		[self.ping start];

		NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(pingTimerFired:) userInfo:nil repeats:YES];
		self.pingTimer = t;
	}
}

- (void) comcastFailed {
	self.canSeeModemImage.image = RED;
	self.canSeeModemLabel.text = [NSString stringWithFormat:@"Cannot see the Comcast modem at %@", ComcastModemIP];
	self.canSeeModemLabel.textColor = [UIColor redColor];
}

- (void) pingTimerStop {
	[self.pingTimer invalidate];
	self.pingTimer = nil;
	[self.ping stop];
	self.ping = nil;
}

- (void) pingTimerFired:(NSTimer *)timer {
	_pingTimerCounter ++;
	if(_pingTimerCounter > 10) {
		[self comcastFailed];
		[self pingTimerStop];
		return;
	}

	self.canSeeModemLabel.text = [NSString stringWithFormat:@"Can we ping the Comcast modem? (try #%d)", _pingTimerCounter];

	[self.ping sendPingWithData:nil];
}


- (void)simplePing:(SimplePing *)pinger didFailToSendPacket:(NSData *)packet error:(NSError *)error {
	NSLog(@"Fail %@", error);
	[self comcastFailed];
	[self pingTimerStop];
}

- (void)simplePing:(SimplePing *)pinger didFailWithError:(NSError *)error {
	NSLog(@"Fail %@", error);
	[self comcastFailed];
	[self pingTimerStop];
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet {
	self.canSeeModemImage.image = GREEN;
	self.canSeeModemLabel.text = [NSString stringWithFormat:@"I can ping the Comcast modem at %@.", ComcastModemIP];
	[self pingTimerStop];
}

- (void)simplePing:(SimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
	[self comcastFailed];
	[self pingTimerStop];
}

- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet {
}

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
}

- (BOOL)addressFromString:(NSString *)IPAddress address:(struct sockaddr_in *)address
{
	if (!IPAddress || ![IPAddress length]) return NO;

	memset((char *) address, sizeof(struct sockaddr_in), 0);
	address->sin_family = AF_INET;
	address->sin_len = sizeof(struct sockaddr_in);

	int conversionResult = inet_aton([IPAddress UTF8String], &address->sin_addr);
	if (conversionResult == 0)
    {
		NSAssert1(conversionResult != 1, @"Failed to convert the IP address string into a sockaddr_in: %@", IPAddress);
		return NO;
	}

	return YES;
}

- (NSString *) DisplayAddressForAddress:(NSData *) address
// Returns a dotted decimal string for the specified address (a struct sockaddr)
// within the address NSData).
{
    int         err;
    NSString *  result;
    char        hostStr[NI_MAXHOST];

    result = nil;

    if (address != nil) {
        err = getnameinfo([address bytes], (socklen_t) [address length], hostStr, sizeof(hostStr), NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            result = [NSString stringWithCString:hostStr encoding:NSASCIIStringEncoding];
            assert(result != nil);
        }
    }

    return result;
}

@end
