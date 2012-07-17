//
//  ATSurveysBackend.m
//  ApptentiveSurveys
//
//  Created by Andrew Wooster on 11/4/11.
//  Copyright (c) 2011 Apptentive. All rights reserved.
//

#import "ATSurveysBackend.h"
#import "ATSurvey.h"
#import "ATSurveyMetrics.h"
#import "ATSurveys.h"
#import "ATSurveyParser.h"
#import "ATSurveyViewController.h"
#import "JSONKit.h"

NSString *const ATSurveySentSurveysPreferenceKey = @"ATSurveySentSurveysPreferenceKey";

@interface ATSurveysBackend (Private)
- (BOOL)surveyAlreadySubmitted:(ATSurvey *)survey;
@end

@implementation ATSurveysBackend

+ (ATSurveysBackend *)sharedBackend {
	static ATSurveysBackend *sharedBackend = nil;
	@synchronized(self) {
		if (sharedBackend == nil) {
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSDictionary *defaultPreferences = [NSDictionary dictionaryWithObject:[NSArray array] forKey:ATSurveySentSurveysPreferenceKey];
			[defaults registerDefaults:defaultPreferences];
			
			sharedBackend = [[ATSurveysBackend alloc] init];
		}
	}
	return sharedBackend;
}

-(id) init {
	if( (self = [super init]) ) {
		pendingSurveysToBeDisplayed = [[NSMutableDictionary alloc] init];
	}
	return self;
}
- (void)dealloc {
	checkSurveyRequest.delegate = nil;
	particularSurveyRequest.delegate = nil;
	[checkSurveyRequest release], checkSurveyRequest = nil;
	[particularSurveyRequest release], particularSurveyRequest = nil;
	[pendingSurveysToBeDisplayed release], pendingSurveysToBeDisplayed = nil;
	[super dealloc];
}

- (void)checkForAvailableSurveys {
	if (checkSurveyRequest == nil) {
		ATWebClient *client = [ATWebClient sharedClient];
		checkSurveyRequest = [[client requestForGettingSurvey] retain];
		checkSurveyRequest.delegate = self;
		[checkSurveyRequest start];
	}
}
- (void) requestSurvey:(NSString *)tag {
	if (particularSurveyRequest == nil) {
		ATWebClient *client = [ATWebClient sharedClient];
		particularSurveyRequest = [[client requestForGettingParticularSurveyTag:tag] retain];
		particularSurveyRequest.delegate = self;
		[particularSurveyRequest start];
	}
}

- (ATSurvey *)currentSurvey {
	return currentSurvey;
}

- (void)resetSurvey {
	[currentSurvey release], currentSurvey = nil;
}

- (void)presentSurveyControllerFromViewController:(UIViewController *)viewController {
	if (currentSurvey == nil) {
		return;
	}
	ATSurveyViewController *vc = [[ATSurveyViewController alloc] initWithSurvey:currentSurvey];
	UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		[viewController presentModalViewController:nc animated:YES];
	} else {
		nc.modalPresentationStyle = UIModalPresentationFormSheet;
		[viewController presentModalViewController:nc animated:YES];
	}
	[nc release];
	[vc release];
	
	NSDictionary *metricsInfo = [[NSDictionary alloc] initWithObjectsAndKeys:currentSurvey.identifier, ATSurveyMetricsSurveyIDKey, [NSNumber numberWithInt:ATSurveyWindowTypeSurvey], ATSurveyWindowTypeKey, nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:ATSurveyDidShowWindowNotification object:nil userInfo:metricsInfo];
	[metricsInfo release], metricsInfo = nil;
}
- (void)presentSurvey:(NSString *)tag fromViewController:(UIViewController *)viewController {
	[pendingSurveysToBeDisplayed setObject:viewController forKey:tag];
	[self requestSurvey:tag];
}

- (void)setDidSendSurvey:(ATSurvey *)survey {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *sentSurveys = [defaults objectForKey:ATSurveySentSurveysPreferenceKey];
	if (![sentSurveys containsObject:survey.identifier] && ![survey multipleResponsesAllowed]) {
		NSMutableArray *replacementSurveys = [sentSurveys mutableCopy];
		[replacementSurveys addObject:survey.identifier];
		[defaults setObject:replacementSurveys forKey:ATSurveySentSurveysPreferenceKey];
		[defaults synchronize];
		[replacementSurveys release], replacementSurveys = nil;
	}
}

#pragma mark ATAPIRequestDelegate
- (void)at_APIRequestDidFinish:(ATAPIRequest *)request result:(NSObject *)result {
	if (request == checkSurveyRequest || request == particularSurveyRequest) {
		ATSurveyParser *parser = [[ATSurveyParser alloc] init];
		ATSurvey *survey = [parser parseSurvey:(NSData *)result];
		if (survey == nil) {
			NSLog(@"An error occurred parsing survey: %@", [parser parserError]);
		} else if (![self surveyAlreadySubmitted:survey]) {
			[currentSurvey release], currentSurvey = nil;
			currentSurvey = [survey retain];
			[[NSNotificationCenter defaultCenter] postNotificationName:ATSurveyNewSurveyAvailableNotification object:nil];
		}
		if(request == checkSurveyRequest) {
			checkSurveyRequest.delegate = nil;
			[checkSurveyRequest release], checkSurveyRequest = nil;
		}
		if(request == particularSurveyRequest) {
			particularSurveyRequest.delegate = nil;
			[particularSurveyRequest release], particularSurveyRequest = nil;
			
			NSString *key = [[currentSurvey tags] componentsJoinedByString:@","];
			if([pendingSurveysToBeDisplayed objectForKey:key]) {
				UIViewController *viewController = [pendingSurveysToBeDisplayed objectForKey:key];
				[pendingSurveysToBeDisplayed removeObjectForKey:key];
				[self presentSurveyControllerFromViewController:viewController];
			}
		}
		[parser release], parser = nil;
	}
}

- (void)at_APIRequestDidFail:(ATAPIRequest *)request {
	if (request == checkSurveyRequest) {
		NSLog(@"Survey request failed: %@: %@", request.errorTitle, request.errorMessage);
		checkSurveyRequest.delegate = nil;
		[checkSurveyRequest release], checkSurveyRequest = nil;
	}
}
@end


@implementation ATSurveysBackend (Private)
- (BOOL)surveyAlreadySubmitted:(ATSurvey *)survey {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL sentSurvey = NO;
	if ([[defaults objectForKey:ATSurveySentSurveysPreferenceKey] containsObject:survey.identifier]) {
		sentSurvey = YES;
	}
	return sentSurvey;
}
@end
