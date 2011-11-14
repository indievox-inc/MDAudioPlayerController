//
//  RootViewController.m
//  MDAudioPlayerSample
//
//  Created by Matt Donnelly on 03/08/2010.
//  Copyright 2010 Matt Donnelly. All rights reserved.
//

#import "RootViewController.h"
#import "MDAudioFile.h"
#import "MDAudioPlayerController.h"
#import "MDAudio.h"

@implementation RootViewController

@synthesize fileArray;

#pragma mark -
#pragma mark UIViewController

- (void)loadView {
  [super loadView];
  fileArray = [[NSMutableArray alloc] init];
}

- (void)viewDidLoad {
  [super viewDidLoad];

  MDAudio *audioA = [[MDAudio alloc] init];
  audioA.title = @"Audio A";
  audioA.artist = @"Artist A";
  audioA.album = @"Album A";
  audioA.durationInMinutes = @"4:00";
  audioA.url = [NSURL URLWithString:@"Your URL here"];
  [fileArray addObject:audioA];
  [audioA release];
  audioA = nil;
  
  MDAudio *audioB = [[MDAudio alloc] init];
  audioB.title = @"Audio B";
  audioB.artist = @"Artist B";
  audioB.album = @"Album B";
  audioB.durationInMinutes = @"3:30";
  audioB.url = [NSURL URLWithString:@"Your URL here"];
  [fileArray addObject:audioB];
  [audioB release];
  audioB = nil;
  
  MDAudio *audioC = [[MDAudio alloc] init];
  audioC.title = @"Audio C";
  audioC.artist = @"Artist C";
  audioC.album = @"Album C";
  audioC.durationInMinutes = @"1:30";
  audioC.url = [NSURL URLWithString:@"Your URL here"];
  [fileArray addObject:audioC];
  [audioC release];
  audioC = nil;
  
  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
}

- (void)viewDidUnload {
  [super viewDidUnload];
  [fileArray release];
  fileArray = nil;
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  // Return YES for supported orientations.
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -
#pragma mark UITableViewDataSource

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [fileArray count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  
  static NSString *CellIdentifier = @"Cell";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
  }
  MDAudio *audio = [self.fileArray objectAtIndex:indexPath.row];
  cell.textLabel.text = audio.title;
  
  return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  // Return NO if you do not want the specified item to be editable.
  return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    // Delete the row from the data source.
    [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
  }   
  else if (editingStyle == UITableViewCellEditingStyleInsert) {
    // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
  }   
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}

// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
  // Return NO if you do not want the item to be re-orderable.
  return YES;
}


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    

  MDAudioPlayerController *audioPlayer = [[MDAudioPlayerController alloc] initWithSoundFiles:fileArray andSelectedIndex:indexPath.row];
  [self.navigationController presentModalViewController:audioPlayer animated:YES];
  [audioPlayer release];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)dealloc {
  [super dealloc];
}


@end

