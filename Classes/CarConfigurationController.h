// CarConfigurationController.h
//
// Kraftstoff


#import "PageViewController.h"


@class CarConfigurationController;

typedef enum
{
    CarConfigurationCanceled,
    CarConfigurationCreateSucceded,
    CarConfigurationEditSucceded,
    CarConfigurationAborted,
} CarConfigurationResult;


@protocol CarConfigurationControllerDelegate

- (void)carConfigurationController:(CarConfigurationController*)controller didFinishWithResult:(CarConfigurationResult)result;

@end


@interface CarConfigurationController : PageViewController <UIViewControllerRestoration, UIActionSheetDelegate>
{
    BOOL         isShowingCancelSheet;

    BOOL         dataChanged;
    NSIndexPath *previousSelectionIndex;
}

@property (nonatomic, strong) NSString        *name;
@property (nonatomic, strong) NSString        *plate;
@property (nonatomic, strong) NSNumber        *odometerUnit;
@property (nonatomic, strong) NSDecimalNumber *odometer;
@property (nonatomic, strong) NSNumber        *fuelUnit;
@property (nonatomic, strong) NSNumber        *fuelConsumptionUnit;

@property (nonatomic) BOOL editingExistingObject;

@property (nonatomic, weak) id<CarConfigurationControllerDelegate> delegate;

- (IBAction)handleCancel:(id)sender;
- (IBAction)handleSave:(id)sender;

@end
