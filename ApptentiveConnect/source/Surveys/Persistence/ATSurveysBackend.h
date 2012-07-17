//
//  ATSurveysBackend.h
//  ApptentiveSurveys
//
//  Created by Andrew Wooster on 11/4/11.
//  Copyright (c) 2011 Apptentive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATAPIRequest.h"
#import "ATWebClient+SurveyAdditions.h"

@class ATSurvey;

@interface ATSurveysBackend : NSObject <ATAPIRequestDelegate> {
@private
	ATAPIRequest *checkSurveyRequest;
	ATSurvey *currentSurvey;
	ATAPIRequest *particularSurveyRequest;
	NSMutableDictionary *pendingSurveysToBeDisplayed;
}
+ (ATSurveysBackend *)sharedBackend;
- (void)checkForAvailableSurveys;
- (ATSurvey *)currentSurvey;
- (void)resetSurvey;
- (void)presentSurveyControllerFromViewController:(UIViewController *)viewController;
- (void)presentSurvey:(NSString *)tag fromViewController:(UIViewController *)viewController;
- (void)setDidSendSurvey:(ATSurvey *)survey;
@end
