//
//  RootViewController.h
//  RawRESTOAuth
//
//  Created by Jon Mountjoy on 31/05/2011.
//

#import <UIKit/UIKit.h>

@interface RootViewController : UITableViewController {
    
    NSMutableArray *dataRows;
    IBOutlet UITableView *tableView;    

}

@property (nonatomic, retain) NSMutableArray *dataRows;
@property (nonatomic, retain) UITableView *tableView;

@end
