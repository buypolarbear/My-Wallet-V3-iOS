//
//  AppDelegate.m
//  Blockchain
//
//  Created by Ben Reeves on 05/01/2012.
//  Copyright (c) 2012 Qkos Services Ltd. All rights reserved.
//
#import <QuartzCore/QuartzCore.h>

#import "AppDelegate.h"
#import "TransactionsViewController.h"
#import "RemoteDataSource.h"
#import "Wallet.h"
#import "UIFadeView.h"
#import "WebSocketNSStream.h"
#import "TabViewController.h"
#import "ReceiveCoinsViewController.h"
#import "SendViewController.h"
#import "AccountViewController.h"
#import "TransactionsViewController.h"
#import "WebViewController.h"
#import "NewAccountView.h"
#import "NSString+SHA256.h"
#import "JSONKit.h"
#import "Transaction.h"
#import "Input.h"
#import "Output.h"
#import "UIDevice+Hardware.h"

AppDelegate * app;

@implementation AppDelegate

@synthesize window = _window;
@synthesize wallet;
@synthesize webSocket;
@synthesize reachability;
@synthesize modalView;
@synthesize modalContentView;
@synthesize latestResponse;
@synthesize modalDelegate;
@synthesize readerView;

-(RemoteDataSource*)dataSource {
    return dataSource;
}

-(NSString*)formatMoney:(uint64_t)value {   
    
    if (symbolLocal && latestResponse.symbol.conversion) {
        @try {
            NSDecimalNumber * number = [(NSDecimalNumber*)[NSDecimalNumber numberWithLongLong:value] decimalNumberByDividingBy:(NSDecimalNumber*)[NSDecimalNumber numberWithDouble:(double)latestResponse.symbol.conversion]];
            
            return [latestResponse.symbol.symbol stringByAppendingString:[btcFromatter stringFromNumber:number]];
        } @catch (NSException * e) {
            NSLog(@"%@", e);
        }
    }
    
    NSDecimalNumber * number = [(NSDecimalNumber*)[NSDecimalNumber numberWithLongLong:value] decimalNumberByDividingBy:(NSDecimalNumber*)[NSDecimalNumber numberWithDouble:(double)SATOSHI]];
    
    return [[btcFromatter stringFromNumber:number] stringByAppendingString:@" BTC"];
}

-(id)init {
    if (self = [super init]) {
         
        btcFromatter = [[NSNumberFormatter alloc] init];  
    
        [btcFromatter setNumberStyle:NSNumberFormatterDecimalStyle];

        app = self;
        tasks = 0;
        dataSource = [[RemoteDataSource alloc] init];
        
        dataSource.delegate = self;
        
    }
    return self;
}


-(void)toggleSymbol {
    symbolLocal = !symbolLocal;
    
    transactionsViewController.data = latestResponse;
}

-(void)showBusy {
    if (tasks == 0) {
        [_window addSubview:busyView];
        [busyView fadeIn];
    }
}

-(void)startTask:(Task)task {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        switch (task) {
            case TaskGeneratingWallet:
                [self showBusy];
                
                [busyLabel setText:@"generating wallet"];
                break;
            case TaskSaveWallet:
                [self showBusy];

                [busyLabel setText:@"saving wallet"];

                break;
            case TaskGetWallet:
                if (wallet == NULL) {
                    [self showBusy];
                }
                
                [busyLabel setText:@"downloading wallet"];

                break;
                
            case TaskGetMultiAddr:
                if (transactionsViewController.data == NULL) {
                    [self showBusy];
                }

                [busyLabel setText:@"downloading transactions"];

                break;
            case TaskLoadExternalURL:
                [self showBusy];
                
                [busyLabel setText:@"loading page"];

                break;
        }
        
        if (tasks == 0) {
            [activity startAnimating];
        }
        
        ++tasks;
        
        [self setStatus];
    });
}
-(void)finishTask {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (tasks > 0) {
            --tasks;
        }
        
        if (tasks == 0) {
            [busyView fadeOut];
            
            [activity stopAnimating];
        }
        
        [self setStatus];
    });
}

-(void)setStatus {
    [powerButton setHighlighted:FALSE];

    if (tasks > 0) {
        [powerButton setEnabled:FALSE];
    } else {
        [powerButton setEnabled:TRUE];

        if ([webSocket readyState] != ReadyStateOpen) {
            [powerButton setHighlighted:TRUE];
        }
    }
}


-(NSData*)readFromFileName:(NSString *)fileName  {
        
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
    // the path to write file
    NSString * documentPath = [documentsDirectory stringByAppendingPathComponent:fileName];
        
    
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath])  {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:NULL];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:documentPath]) {
        return [[[NSData alloc] initWithContentsOfFile:documentPath] autorelease];
    }

    return NULL;
}

- (BOOL)writeToFile:(NSData *)data fileName:(NSString *)fileName 
{   
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
    // the path to write file
    NSString *documentPath = [documentsDirectory stringByAppendingPathComponent:fileName];
    
    
    NSLog(@"Write to bytes %d file %@", [data length], documentPath);
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentPath])  {
        [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:NULL];
    }
    
    NSError * error = nil;
    
    [data writeToFile:documentPath options:0 error:&error];
    
    if (error) {
        NSLog(@"Error writing file %@", error);
        
        return FALSE;
    }
    
    return TRUE;
}

- (void)standardNotify:(NSString*)message
{
	[self standardNotify:message title:@"Error" delegate:nil];	
}

- (void)standardNotify:(NSString*)message delegate:(id)fdelegate
{
	[self standardNotify:message title:@"Error" delegate:fdelegate];	
}

- (void)standardNotify:(NSString*)message title:(NSString*)title delegate:(id)fdelegate
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message  delegate:fdelegate cancelButtonTitle:@"OK" otherButtonTitles: nil];
            [alert show];	
            [alert release]; 
        }
    });	
}

-(void)subscribeWalletAndToKeys {
    NSString * msg = [NSString stringWithFormat:@"{\"op\":\"wallet_sub\",\"guid\":\"%@\"}", [self guid]];
    
    for (Key * key in [wallet.keys allValues]) {        
        msg = [msg stringByAppendingFormat:@"{\"op\":\"addr_sub\", \"addr\":\"%@\"}", key.addr];
    }
    
    NSLog(@"%@", msg);
    
    [webSocket send:msg];
}

-(void)webSocketOnOpen:(WebSocket*)_webSocket {
    NSLog(@"Websocket on open");
    
    webScoketFailures = 0;
    
    [self setStatus];
    
    NSString * msg = @"{\"op\":\"blocks_sub\"}";
            
    [webSocket send:msg];

    if ([self guid])
        [self subscribeWalletAndToKeys];
}

-(void)webSocketOnClose:(WebSocket*)_webSocket {
    NSLog(@"Websocket on close");
        
    [self setStatus];
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        if (webScoketFailures < 5) {
            [webSocket connect:WebSocketURL];
            ++webScoketFailures;
        }
    }
}

-(void)webSocket:(WebSocket*)_webSocket onError:(NSError*)error {
    NSLog(@"Websocket on error");
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        if (webScoketFailures < 5) {
            [webSocket connect:WebSocketURL];
            ++webScoketFailures;
        }
    }
}

-(void)webSocket:(WebSocket*)webSocket onReceive:(NSData*)data {
    NSLog(@"Websocket on data");
    
    JSONDecoder * json = [[[JSONDecoder alloc] init] autorelease];
    
    NSDictionary * document = [json objectWithData:data];
    
    NSString * op = [document objectForKey:@"op"];
    
    if ([op isEqualToString:@"block"]) {
        
        [self playDingSound];
        
        NSDictionary * block = [document objectForKey:@"x"];
        
        LatestBlock * latest = [[LatestBlock alloc] init];
      
        latest.height =  [[block objectForKey:@"height"] intValue];
        latest.hash = [block objectForKey:@"hash"];
        latest.blockIndex = [[block objectForKey:@"blockIndex"] intValue];
        latest.time = [[block objectForKey:@"time"] longLongValue];
        
        [latestResponse setLatestBlock:latest];
        
        transactionsViewController.data = latestResponse;
        
        [latest release];
    } else if ([op isEqualToString:@"utx"]) {
        NSLog(@"New Transaction");
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        
        Transaction * transaction = [[Transaction fromJSONDict:[document objectForKey:@"x"]] autorelease];
        
        if (transaction == NULL)
            return;
        
        /* Calculate the result */
        uint64_t result = 0;
        
        for (Input * input in transaction.inputs) {
            
            //If it is our address then subtract the value
            if ([wallet.keys objectForKey:input.prev_out.addr]) {
                result -= input.prev_out.value;
                latestResponse.final_balance -= input.prev_out.value;
                latestResponse.total_sent += input.prev_out.value;
            }
        }
        
        for (Output * output in transaction.outputs) {
            if ([wallet.keys objectForKey:output.addr]) {
                result += output.value;
                latestResponse.final_balance += output.value;
                latestResponse.total_received += output.value;
            }
        }
    
        transaction->result = result;
        
        [latestResponse.transactions insertObject:transaction atIndex:0];
        
        transactionsViewController.data = latestResponse;
        
        [self playBeepSound];
    } else if ([op isEqualToString:@"on_change"]) {
        
        NSString * newChecksum = [document objectForKey:@"checksum"];
        NSString * oldChecksum = [self checksumCache];

        NSLog(@"Caught on_change %@ == %@", newChecksum, oldChecksum);

        //Wallet changed - Need to refresh the wallet data
        if (oldChecksum && oldChecksum && ![newChecksum isEqualToString:oldChecksum]) {
            
            //Fetch the wallet data
            [dataSource getWallet:[self guid] sharedKey:[self sharedKey] checksum:[self checksumCache]];
        }
    }
}

-(void)didGenerateNewWallet:(Wallet*)_wallet password:(NSString*)password {
    
    [self forgetWallet];

    self.wallet = _wallet;
    
    [[NSUserDefaults standardUserDefaults] setObject:wallet.guid forKey:@"guid"];
    [[NSUserDefaults standardUserDefaults] setObject:wallet.sharedKey forKey:@"sharedKey"];
    [[NSUserDefaults standardUserDefaults] setObject:password forKey:@"password"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [dataSource multiAddr:_wallet.guid addresses:[_wallet.keys allKeys]];

    receiveViewController.wallet = _wallet;
    sendViewController.wallet = _wallet;
    
    //Disconnect and it will reconnect automatically
    [webSocket disconnect];
}

-(void)walletDidLoad:(Wallet *)_wallet {      
    
    [self subscribeWalletAndToKeys];
    
    _tempLastKeyCount = [_wallet.keys count];
    
    receiveViewController.wallet = _wallet;
    sendViewController.wallet = _wallet;
        
    [dataSource multiAddr:_wallet.guid addresses:[_wallet.keys allKeys]];
}

-(void)walletDataNotModified {    
    [dataSource multiAddr:wallet.guid addresses:[wallet.keys allKeys]];
}

-(void)didGetMultiAddr:(MulitAddressResponse *)response {
        
    self.latestResponse = response;
    
    transactionsViewController.data = response;
}

-(void)walletFailedToDecrypt:(Wallet*)wallet {    
    
    //Clear the password and refetch the wallet data
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"password"];
    
    //Cleare the checksum cache incase it has
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"checksum_cache"];

    [self showModal:mainPasswordView];
    
    [mainPasswordTextField becomeFirstResponder];
}

-(IBAction)mainPasswordClicked:(id)sender {
    
    if ([mainPasswordTextField.text length] < 10) {
        [app standardNotify:@"Passowrd must be 10 or more characters in length"];
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:mainPasswordTextField.text forKey:@"password"];

    [dataSource getWallet:[self guid] sharedKey:[self sharedKey] checksum:[self checksumCache]];
    
    [app closeModal];
}

-(void)didGetWalletData:(NSData *)data  {
    if ([self password]) {
        self.wallet = [[[Wallet alloc] initWithData:data password:[self password]] autorelease];

        wallet.delegate = self;
    } else {
        [self showModal:mainPasswordView];
        
        [mainPasswordTextField becomeFirstResponder];
    }
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    
    NSLog(@"Foreground");
    
    if ([reachability currentReachabilityStatus] != NotReachable) {        
        //If not connected to websocket recall multiaddr
        if ([webSocket readyState] == ReadyStateClosed || [webSocket readyState] == ReadyStateClosing) {
            [webSocket connect:WebSocketURL];
            
            printf("%f\n", time(NULL) - dataSource.lastWalletSync);
            
            if (time(NULL) - dataSource.lastWalletSync > MULTI_ADDR_TIME) {
                //Fetch the wallet data
                [dataSource getWallet:[self guid] sharedKey:[self sharedKey] checksum:[self checksumCache]];
            }
        }
    }
}

-(void)playBeepSound {
    
	if (beepSoundID == 0) {
		AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"beep" ofType:@"wav"]], &beepSoundID);
	}
	
	AudioServicesPlaySystemSound(beepSoundID);		
}

-(void)playDingSound {
    
	if (dingSoundID == 0) {
		AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"ding" ofType:@"wav"]], &dingSoundID);
	}
	
	AudioServicesPlaySystemSound(dingSoundID);		
}

-(void)playAlertSound {
    
	if (alertSoundID == 0) {
		//Find the Alert Sound
		NSString * alert_sound = [[NSBundle mainBundle] pathForResource:@"alert-received" ofType:@"wav"];
		
		//Create the system sound
		AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath: alert_sound], &alertSoundID);
	}
	
	AudioServicesPlaySystemSound(alertSoundID);		
}

//Called by Reachability whenever status changes.
- (void) reachabilityChanged: (NSNotification* )note
{	
    if ([reachability currentReachabilityStatus] != NotReachable) {
        
        //Reconnect to the websocket
        if (([webSocket readyState] == ReadyStateClosed || [webSocket readyState] == ReadyStateClosing)) {
            [webSocket connect:WebSocketURL];
        }
        
        if (time(NULL) - dataSource.lastWalletSync > MULTI_ADDR_TIME) {
            //Fetch the wallet data
            [dataSource getWallet:[self guid] sharedKey:[self sharedKey] checksum:[self checksumCache]];
        }
    }
}

-(void)pushWebViewController:(NSString*)url {
    if (webViewController == nil) {
        webViewController = [[WebViewController alloc] initWithNibName:@"WebView" bundle:[NSBundle mainBundle]];
        
        [webViewController viewDidLoad];
    }

    [tabViewController setActiveViewController:webViewController animated:TRUE index:-1];

    [webViewController loadURL:url];
}

-(NSString*)checksumCache {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"checksum_cache"];
}

-(void)writeWalletCacheToDisk:(NSString*)payload {
    
    NSData * data = [payload dataUsingEncoding:NSUTF8StringEncoding];
    
    [app writeToFile:data fileName:WalletCachefile];
    
    NSLog(@"%@", [payload SHA256]);
    
    [[NSUserDefaults standardUserDefaults] setObject:[payload SHA256] forKey:@"checksum_cache"];

}

- (NSMutableDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[[NSMutableDictionary alloc] initWithCapacity:6] autorelease];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

-(NSDictionary*)parseURI:(NSString*)urlString {
    
    if (![urlString hasPrefix:@"bitcoin:"]) {
        return [NSDictionary dictionaryWithObject:urlString forKey:@"address"];
    }
        
    NSString * replaced = [[urlString stringByReplacingOccurrencesOfString:@"bitcoin:" withString:@"bitcoin://"] stringByReplacingOccurrencesOfString:@"////" withString:@"//"];
    
    NSLog(@"%@", replaced);
    
    NSURL * url = [NSURL URLWithString:replaced];
    
    NSMutableDictionary *dict = [self parseQueryString:[url query]];

    if ([url host] != NULL)
        [dict setObject:[url host] forKey:@"address"];
    
    return dict;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{

    NSDictionary *dict = [self parseURI:[url absoluteString]];
        
    NSString * addr = [dict objectForKey:@"address"];
    NSString * amount = [dict objectForKey:@"amount"];

    [self showSendCoins];
    
    [sendViewController setToAddress:addr];
    
    [sendViewController setAmount:amount];

    return YES;
}

-(void)didSubmitTransaction {
    [app closeModal];
    
    [dataSource multiAddr:wallet.guid addresses:[wallet.keys allKeys]];
}

-(void)checkStatus {
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        if ([reachability currentReachabilityStatus] != NotReachable && ([webSocket readyState] == ReadyStateClosed || [webSocket readyState] == ReadyStateClosing)) {
            [webSocket connect:WebSocketURL];
            
            if (wallet) {
                [dataSource multiAddr:wallet.guid addresses:[wallet.keys allKeys]];
            }
        }
    }
    
    [self performSelector:@selector(checkStatus) withObject:nil afterDelay:120.0f];
}

-(TabViewcontroller*)tabViewController {
    return tabViewController;
}

-(IBAction)closeModalClicked:(id)sender {
    [self closeModal];
}

-(void)closeModal {
    
    [modalView removeFromSuperview]; 
    [modalContentView removeFromSuperview]; 

    CATransition *animation = [CATransition animation]; 
    [animation setDuration:0.6f]; 
    [animation setType:kCATransitionFade]; 
        
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    
    [[_window layer] addAnimation:animation forKey:@"HideModal"]; 
        
    if ([modalDelegate respondsToSelector:@selector(didDismissModal)])
        [modalDelegate didDismissModal];
        
    self.modalContentView = nil;
    self.modalView = nil;
    self.modalDelegate = nil;
}

-(IBAction)secondPasswordClicked:(id)sender {
    NSString * password = secondPasswordTextField.text;
        
    if (![[[wallet.sharedKey stringByAppendingString:password] SHA256:10] isEqualToString:wallet.dPasswordHash]) {
        [app standardNotify:@"Second Password Incorrect"];
    } else {
        wallet.secondPassword = password;
        
        [app closeModal];
    }
    
    secondPasswordTextField.text = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField*)aTextField
{
    [aTextField resignFirstResponder];
    
    return YES;
}

-(BOOL)getSecondPasswordBlocking {
    
    if (!wallet.doubleEncryption)
        return YES;
    
    if (wallet.secondPassword)
        return YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [app showModal:secondPasswordView];
    });
    
    usleep(20000);

    while (app.modalView) {
        usleep(20000);
    }
    
    if (wallet.secondPassword)
        return TRUE;
    
    return FALSE;
}

-(void)showModal:(UIView*)contentView {
    
    if (modalView) {
        [self closeModal];
    }
    
    [[NSBundle mainBundle] loadNibNamed:@"ModalView" owner:self options:nil];
    
    [modalContentView addSubview:contentView];
    
    contentView.frame = CGRectMake(0, 0, modalContentView.frame.size.width, modalContentView.frame.size.height);
    
    [_window addSubview:modalView];
    [_window endEditing:TRUE];
    
    CATransition *animation = [CATransition animation]; 
    [animation setDuration:0.6f]; 
    [animation setType:kCATransitionFade]; 
    
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
    
    [[_window layer] addAnimation:animation forKey:@"ShowModal"]; 
}

-(void)parseAccountQRCodeData:(NSString*)data {
    NSArray * components = [data componentsSeparatedByString:@"|"];
    
    if ([components count] != 3) {
        [app standardNotify:@"Invalid QR Code String"];
        return;
    }
    
    NSString * guid = [components objectAtIndex:0];
    NSString * sharedKey = [components objectAtIndex:1];
    NSString * password = [components objectAtIndex:2];
    
    
    [self setAccountData:guid sharedKey:sharedKey password:password];
}



-(void)setAccountData:(NSString*)guid sharedKey:(NSString*)sharedKey password:(NSString*)password {

    if ([guid length] != 36) {
        [app standardNotify:@"Invalid GUID"];
        return;
    }
    
    if ([sharedKey length] != 36) {
        [app standardNotify:@"Invalid Shared Key"];
        return;
    }
    
    if ([password length] < 10) {
        [app standardNotify:@"Password should be 10 characters in length or more"];
        return;
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:guid forKey:@"guid"];
    [[NSUserDefaults standardUserDefaults] setObject:sharedKey forKey:@"sharedKey"];
    [[NSUserDefaults standardUserDefaults] setObject:password forKey:@"password"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"Fetch Wallet");
    
    //Fetch the wallet data
    [dataSource getWallet:[self guid] sharedKey:[self sharedKey] checksum:nil];
    
    [app closeModal];
}

-(void)didDismissModal {
    [readerView stop];
    
    self.readerView = nil;
}

-(BOOL)isZBarSupported {
    NSUInteger platformType = [[UIDevice currentDevice] platformType];
    
    if (platformType ==  UIDeviceiPhoneSimulator || platformType ==  UIDeviceiPhoneSimulatoriPhone  || platformType ==  UIDeviceiPhoneSimulatoriPhone || platformType ==  UIDevice1GiPhone || platformType ==  UIDevice3GiPhone || platformType ==  UIDevice1GiPod || platformType ==  UIDevice2GiPod || ![UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        return FALSE;
    }
    
    return TRUE;
}

-(IBAction)manualPairClicked:(id)sender {
    
    NSDictionary * data = [dataSource resolveAlias:manualIdentifier.text];
    
    if (data == nil)
        return;
    
    [self setAccountData:[data objectForKey:@"guid"]  sharedKey:[data objectForKey:@"sharedKey"] password:manualPAssword.text];
}

- (void) readerView: (ZBarReaderView*) view didReadSymbols: (ZBarSymbolSet*) syms fromImage: (UIImage*) img
{
    
    printf("Did read\n");
    
    // do something useful with results
    for(ZBarSymbol *sym in syms) {        
        [self parseAccountQRCodeData:sym.data];
        
        [readerView stop];
        
        [app closeModal];
        
        break;
    }
    
    self.readerView = nil;
}

-(IBAction)scanAccountQRCodeclicked:(id)sender {
    
    if ([self isZBarSupported]) {
        self.readerView = [[ZBarReaderView new] autorelease];
        
        [app showModal:readerView];

        self.modalDelegate = self;
        
        [readerView start];
        
        [readerView setReaderDelegate:self];
    } else {
        [self showModal:manualView];
    }
}

-(void)forgetWallet {
    NSLog(@"Forget");
    
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"guid"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"sharedKey"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"password"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
    self.wallet = nil;
    self.latestResponse = nil;
    [transactionsViewController setData:nil];
    [receiveViewController setWallet:nil];
}

-(void)showWelcome {
    if (wallet) {
        [pairLogoutButton setTitle:@"Forget Details" forState:UIControlStateNormal];
    } else {
        [pairLogoutButton setTitle:@"Pair Device" forState:UIControlStateNormal];
    }
    
    [app showModal:welcomeView];
}

-(IBAction)logoutClicked:(id)sender {
    [self showWelcome];
}

-(IBAction)signupClicked:(id)sender {
    
    [newAccountView refreshCaptcha];
    
    [app showModal:newAccountView];
}

-(IBAction)loginClicked:(id)sender {
    
    if (wallet) {
    
        [self forgetWallet];
        
        [app closeModal];
        
        return;
    } else {
        [app showModal:pairingInstructionsView];
    }
}

-(IBAction)receiveCoinClicked:(UIButton *)sender {
    if (!receiveViewController) {
        receiveViewController = [[ReceiveCoinsViewController alloc] initWithNibName:@"ReceiveCoins" bundle:[NSBundle mainBundle]];
        
        [receiveViewController viewDidLoad];
    }
    
    receiveViewController.wallet = wallet;
    
    [tabViewController setActiveViewController:receiveViewController animated:TRUE index:1];
}

-(IBAction)transactionsClicked:(UIButton *)sender {
    [tabViewController setActiveViewController:transactionsViewController animated:TRUE index:0];
}

-(void)showSendCoins {
    
    if (!sendViewController) {
        sendViewController = [[SendViewController alloc] initWithNibName:@"SendForm" bundle:[NSBundle mainBundle]];
        
        [sendViewController viewDidLoad];
    }
    
    sendViewController.wallet = wallet;
    
    [tabViewController setActiveViewController:sendViewController  animated:TRUE index:2];
}

-(IBAction)sendCoinsClicked:(UIButton *)sender {
    [self showSendCoins];
}

-(IBAction)infoClicked:(UIButton *)sender {
    if (!accountViewController) {
        accountViewController = [[AccountViewController alloc] initWithNibName:@"AccountViewController" bundle:[NSBundle mainBundle]];
        
        [accountViewController viewDidLoad];
    }
    
    [tabViewController setActiveViewController:accountViewController animated:TRUE index:3];
}

-(NSString*)password {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"password"];
}

-(NSString*)guid {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"guid"];
}

-(NSString*)sharedKey {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"sharedKey"];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{         
    
    // Override point for customization after application launch.
    _window.backgroundColor = [UIColor whiteColor];
    
    [_window makeKeyAndVisible];
    
    //Netowrk status updates
    self.reachability = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(reachabilityChanged:) name:kReachabilityChangedNotification object: nil];
    [reachability startNotifer];
    
    //Connect to websocket
    self.webSocket = [[[WebSocketNSStream alloc] init] autorelease];
    webSocket.delegate = self;
    [webSocket connect:WebSocketURL];
    
    
    NSLog(@"Saved GUID: %@", [self guid]);
    
    if (![self guid] || ![self sharedKey]) {
       
        [self showWelcome];
    
    } else if (![self password]) {
      
        [self showModal:mainPasswordView];
        
        [mainPasswordTextField becomeFirstResponder];
        
    } else {
        
        //Restore the wallet cache
        NSData * walletCache = [app readFromFileName:WalletCachefile];
        if (walletCache != NULL) {        
            self.wallet = [[[Wallet alloc] initWithData:walletCache password:[self password]] autorelease];
            
            wallet.delegate = self;
        } else {
            
            NSLog(@"Null wallet cache");
            
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"checksum_cache"];
        }
        
        [dataSource getWallet:[self guid] sharedKey:[self sharedKey] checksum:[self checksumCache]];
        
        //Restore the transactions cache
        NSData * multiAddrCache = [app readFromFileName:MultiaddrCacheFile];
        if (multiAddrCache != NULL) {        
            self.latestResponse = [dataSource parseMultiAddr:multiAddrCache];
            transactionsViewController.data = latestResponse;
        }
    }
               
    [_window insertSubview:tabViewController.view atIndex:0];
    
    [tabViewController setActiveViewController:transactionsViewController];

    [self performSelector:@selector(checkStatus) withObject:nil afterDelay:120.0f];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    wallet.secondPassword  = nil;
    
    [webSocket disconnect];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

@end
