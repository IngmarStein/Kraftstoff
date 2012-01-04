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

@property (nonatomic, strong) UITextField              *editingTextField;
@property (nonatomic, strong) IBOutlet UIImageView     *backgroundImageView;
@property (nonatomic, strong) IBOutlet UINavigationBar *navBar;

@property (nonatomic, strong) NSString        *name;
@property (nonatomic, strong) NSString        *plate;
@property (nonatomic, strong) NSNumber        *odometerUnit;
@property (nonatomic, strong) NSDecimalNumber *odometer;
@property (nonatomic, strong) NSNumber        *fuelUnit;
@property (nonatomic, strong) NSNumber        *fuelConsumptionUnit;

@property (nonatomic, getter=isEditing) BOOL editing;

@property (nonatomic, unsafe_unretained) id<CarConfigurationControllerDelegate> delegate;

- (IBAction)handleCancel: (id)sender;
- (IBAction)handleSave: (id)sender;

@end
