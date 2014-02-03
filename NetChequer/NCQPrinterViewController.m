//
//  NCQPrinterViewController.m
//  NetChequer
//
//  Created by Steve Sparks on 12/19/13.
//  Copyright (c) 2013 SOG. All rights reserved.
//

#import "NCQPrinterViewController.h"
#import <StarIO/SMPort.h>
#import "PrinterFunctions.h"

// cuz i'm lazy
#define YELLOW [UIImage imageNamed:@"yellow"]
#define RED    [UIImage imageNamed:@"red"]
#define GREEN  [UIImage imageNamed:@"green"]

NSString * const PrinterListUpdatedNotification = @"PrinterListUpdatedNotification";

@interface NCQPrinterViewController ()
@property (strong, nonatomic) NSArray *printerList;
@property (strong, nonatomic) NSMutableDictionary *printerPorts;
@property (strong, nonatomic) NSDictionary *macLookup;

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;

@property (weak, nonatomic) IBOutlet UIImageView *hubPrinterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *barPrinterImageView;
@property (weak, nonatomic) IBOutlet UIImageView *kitchenPrinterImageView;

@property (weak, nonatomic) IBOutlet UIButton *hubPrinterTestButton;
@property (weak, nonatomic) IBOutlet UIButton *barPrinterTestButton;
@property (weak, nonatomic) IBOutlet UIButton *kitchenPrinterTestButton;

@property (weak, nonatomic) IBOutlet UILabel *hubLabel;
@property (weak, nonatomic) IBOutlet UILabel *barLabel;
@property (weak, nonatomic) IBOutlet UILabel *kitchenLabel;
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeGR;

@property (weak, nonatomic) IBOutlet UIButton *recheckButton;

+ (NSArray *) printerList;

@end

@implementation NCQPrinterViewController

static NSArray *internalPrinterList;

+ (NSArray *)printerList {
	return [internalPrinterList copy];
}

+ (void) refreshPrinters {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		internalPrinterList = [SMPort searchPrinter:@"TCP:"];
		NSLog(@" Search complete.");
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:PrinterListUpdatedNotification object:self];
		});
	});
}



NSString * const PrinterIdentityHub = @"Hub";
NSString * const PrinterIdentityBar = @"Bar";
NSString * const PrinterIdentityKitchen = @"Kitchen";

// Pad rotates. Nothing else.
- (BOOL)shouldAutorotate {
	return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

	self.navigationItem.title = @"PRINTERS";

	self.macLookup = @{
					   @"00:11:62:07:24:6e": PrinterIdentityHub,
					   @"00:11:62:07:24:3f": PrinterIdentityBar,
					   @"00:11:62:06:7e:18": PrinterIdentityKitchen,
					   };
	self.printerPorts = [[NSMutableDictionary alloc] initWithCapacity:3];


	UIImage *allImage = YELLOW;
	self.hubPrinterImageView.image = allImage;
	self.barPrinterImageView.image = allImage;
	self.kitchenPrinterImageView.image = allImage;

	self.hubPrinterTestButton.hidden = YES;
	self.barPrinterTestButton.hidden = YES;
	self.kitchenPrinterTestButton.hidden = YES;

	UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss:)];
	swipe.direction = UISwipeGestureRecognizerDirectionRight;
	[self.view addGestureRecognizer:swipe];
	self.swipeGR = swipe;

	// Do any additional setup after loading the view.
}

- (void) dismiss:(id)sender {
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
	[self.activityIndicator startAnimating];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadPrinters) name:PrinterListUpdatedNotification object:nil];
	[self loadPrinters];
}

- (void)viewWillDisappear:(BOOL)animated {

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) identifiedPrinter:(NSString*)identity asPort:(PortInfo*)port {
	UIImageView *imgV = nil;
	UIButton *btn = nil;
	UILabel *lbl = nil;

	if([identity isEqualToString:PrinterIdentityHub]) {
		imgV = self.hubPrinterImageView;
		btn = self.hubPrinterTestButton;
		lbl = self.hubLabel;
	} else if([identity isEqualToString:PrinterIdentityBar]) {
		imgV = self.barPrinterImageView;
		btn = self.barPrinterTestButton;
		lbl = self.barLabel;
	} else if([identity isEqualToString:PrinterIdentityKitchen]) {
		imgV = self.kitchenPrinterImageView;
		btn = self.kitchenPrinterTestButton;
		lbl = self.kitchenLabel;
	} else
		return;

	self.printerPorts[identity] = port;
	dispatch_async(dispatch_get_main_queue(), ^{
		imgV.image = GREEN;
		btn.hidden = NO;
		lbl.text = [NSString stringWithFormat:@"%@ is a %@", identity, port.modelName];
	});
}

- (void) loadPrinters {

	self.recheckButton.hidden = YES;
	UIImage *allImage = RED;
	self.hubPrinterImageView.image = allImage;
	self.barPrinterImageView.image = allImage;
	self.kitchenPrinterImageView.image = allImage;

	self.hubLabel.text = @"Searching for Hub printer...";
	self.hubPrinterTestButton.hidden = YES;
	self.barLabel.text = @"Searching for Bar printer...";
	self.barPrinterTestButton.hidden = YES;
	self.kitchenLabel.text = @"Searching for Kitchen printer...";
	self.kitchenPrinterTestButton.hidden = YES;


	NSArray *searchResults = self.printerList;

	[self.activityIndicator stopAnimating];
	self.recheckButton.hidden = NO;
	self.hubLabel.text = @"Hub printer not found!";
	self.barLabel.text = @"Bar printer not found!";
	self.kitchenLabel.text = @"Kitchen printer not found!";

	if(!searchResults.count) return;

	NSLog(@" FOUND PRINTERS! ");
	NSLog(@"-------------------------------------------------");
	for(PortInfo *printer in searchResults) {
		NSLog(@"       PortName   %@", printer.portName);
		NSLog(@"       MacAddress %@", printer.macAddress);
		NSLog(@"       ModelName  %@", printer.modelName);

		NSString *ident = self.macLookup[printer.macAddress];
		if(ident) {
			NSLog(@"   *** This is the %@ Printer", ident);
			[self identifiedPrinter:ident asPort:printer];
		}

		NSLog(@"-------------------------------------------------");
	}

}

- (IBAction)dismissButtonPressed:(id)sender {
	[self.activityIndicator startAnimating];

	[NCQPrinterViewController refreshPrinters];
}

- (void) print:(PortInfo*)p raster:(BOOL)raster button:(UIButton*)button{
	[button setTitle:@"Testing" forState:UIControlStateNormal];
	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		if(raster)
			[PrinterFunctions PrintRasterSampleReceipt3InchWithPortname:p.portName portSettings:@"9100"];
		else
			[PrinterFunctions PrintSampleReceipt3InchWithPortname:p.portName portSettings:@"9100"];
		[button setTitle:@"TEST" forState:UIControlStateNormal];

	});

}

- (IBAction)testHubPrinter:(UIButton*)sender {
	PortInfo *p = self.printerPorts[PrinterIdentityHub];
	[self print:p raster:YES button:sender];
}

- (IBAction)testBarPrinter:(UIButton*)sender {
	PortInfo *p = self.printerPorts[PrinterIdentityBar];
	[self print:p raster:YES button:sender];
}

- (IBAction)testKitchenPrinter:(UIButton*)sender {
	PortInfo *p = self.printerPorts[PrinterIdentityKitchen];
	[self print:p raster:NO button:sender];
}

@end















