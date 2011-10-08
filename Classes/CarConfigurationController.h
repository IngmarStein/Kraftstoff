// CarConfigurationController.h
//
// Kraftstoff


#import "PageViewController.h"


@class CarConfigurationController;


@protocol CarConfigurationControllerDelegate

typedef enum
{
    CarConfigurationCanceled,
    CarConfigurationCreateSucceded,
    CarConfigurationEditSucceded,
    CarConfigurationAborted,
} CarConfigurationResult;

- (void)carConfigurationController: (CarConfigurationController*)controller didFinishWithResult: (CarConfigurationResult)result;

@end



@interface CarConfigurationController : PageViewController <UIActionSheetDelegate>
{
    BOOL      dataChanged;
    NSInteger mostRecentSelectedRow;
}

@property (nonatomic, retain) UITextField              *editingTextField;
@property (nonatomic, retain) IBOutlet UINavigationBar *navBar;

@property (nonatomic, retain) NSString        *name;
@property (nonatomic, retain) NSString        *plate;
@property (nonatomic, retain) NSNumber        *odometerUnit;
@property (nonatomic, retain) NSDecimalNumber *odometer;
@property (nonatomic, retain) NSNumber        *fuelUnit;
@property (nonatomic, retain) NSNumber        *fuelConsumptionUnit;

@property (nonatomic, getter=isEditing) BOOL editing;

@property (nonatomic, assign) id<CarConfigurationControllerDelegate> delegate;

- (IBAction)handleCancel: (id)sender;
- (IBAction)handleSave: (id)sender;

@end
