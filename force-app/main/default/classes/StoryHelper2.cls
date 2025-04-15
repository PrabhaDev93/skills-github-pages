public class StoryHelper2 {
/**********************************************************************************
Description : APEX-1244 : Helper class for OTR_ActivateDealBatch
Created by :  Kanika Bhatt
Created Date : 03-12-2025
Last Modified : 03-17-2025
**********************************************************************************
public with sharing class OTR_ActivateDealHelper {
    
    public static Id discountRecordtypeId = Schema.SObjectType.OTR_Offering__c.getRecordTypeInfosByDeveloperName().get(OTR_Constants.OTR_DISCOUNT).getRecordTypeId();
    public static Id spPtsRecordtypeId = Schema.SObjectType.OTR_Offering__c.getRecordTypeInfosByDeveloperName().get(OTR_Constants.OTR_SPECIAL_POINTS).getRecordTypeId();
    public static Id rebateRecordtypeId = Schema.SObjectType.OTR_Offering__c.getRecordTypeInfosByDeveloperName().get(OTR_Constants.OTR_REBATE).getRecordTypeId();
    
    public static String strQuoteIdCustObjName;
    public static List<SObject> lstSobjectUpdate = new List<SObject>();
    public static List<OTR_Offering__c> lstOfferings = new List<OTR_Offering__c>();
    public static List<OTR_Offering__c> lstOfferingUpdate = new List<OTR_Offering__c>();
    public static Set<Id> invalidDtQuoteIdSet = new Set<Id>(); 
    public static Map<Id,String> mapQuoteIdInReason = new Map<Id,String>();
    public static List<Quote> lstQuoteToUpdate = new List<Quote>();
    public static String errorMessages;
    public static List<OTR_Offering__c> lstOfferingsForPaymentMethods = new List<OTR_Offering__c>();
    
    // APEX-1244 - Method to handle deal activation logic
    public static void activateDeal(List<Quote> quoteList){
        try{ 
            lstOfferings = new List<OTR_Offering__c>([SELECT Id, RecordTypeId, OTR_Status__c, OTR_Billing_Account__c, OTR_Billing_Account__r.OTR_Billing_Type__c,
                                                      OTR_Billing_Account__r.Status__c, OTR_Effective_Start_Date__c, OTR_Effective_End_Date__c, Name, 
                                                      OTR_Quote_Line_Item__c, OTR_Quote_Line_Item__r.QuoteId FROM OTR_Offering__c
                                                      WHERE OTR_Quote_Line_Item__r.QuoteId IN: quoteList AND
													  ((OTR_Billing_Account__c != NULL
                                                      AND OTR_Billing_Account__r.Status__c != NULL 
                                                      AND ((RecordTypeId =: discountRecordtypeId AND OTR_Billing_Account__r.OTR_Billing_Type__c =: OTR_Constants.BILLING_TYPE_DIRECT)
													  OR RecordTypeId =: spPtsRecordtypeId)) OR (RecordTypeId =: rebateRecordtypeId))]);
            if(!lstOfferings.isEmpty()){
                checkValidOrInvalidOfferings(lstOfferings);
            }
            if(!lstOfferingsForPaymentMethods.isEmpty()){
                createPaymentMethods(lstOfferingsForPaymentMethods){
            }
            updateQuoteAndOfferings(quoteList);
            lstSobjectUpdate.addAll(lstOfferingUpdate);
            lstSobjectUpdate.addAll(lstQuoteToUpdate);
            lstSobjectUpdate.sort();
            if(!lstSobjectUpdate.isEmpty()){
                Database.SaveResult[] lsr = Database.update(lstSobjectUpdate, false);
                for (Database.SaveResult result : lsr) {
                    if (!result.isSuccess()) {
                        errorMessages += 'Deal Activation failed:' + result.getErrors()[0].getMessage() + '<br/>';
                    }
                }
            }
        }
        catch(Exception ex){
            //Logic to log the exception record if any.
            pfj_Exception__c exceptionLog = efw_Utility.createExceptionLog(ex.getMessage(), null, 'OTR_OfferingsBatch', OTR_Constants.DEAL_BATCH_FAILED);
            if(Schema.sObjectType.pfj_Exception__c.isCreateable()) {
                insert exceptionLog;
            }
        }
    }

//APEX-1447 - Method to create payment methods from Offering records when the customer signs the quote
public static void createPaymentMethods(List<OTR_Offering__c> lstOfferingsForPaymentMethods) {
    Map<String, blng__PaymentMethod__c> newPaymentMethods = new Map<String, blng__PaymentMethod__c>();
    Map<String, blng__PaymentMethod__c> existingPaymentMethods = new Map<String, blng__PaymentMethod__c>();
    Set<Id> dealIds = new Set<Id>();
    try {
        for (OTR_Offering__c offering : lstOfferingsForPaymentMethods) {
            dealIds.add(offering.OTR_Quote__c);
        }

        List<blng__PaymentMethod__c> lstPaymentMethods = [
            SELECT Id, OTR_Deal__c, OTR_Rebate_Offering_Record__c
            FROM blng__PaymentMethod__c
            WHERE OTR_Deal__c IN :dealIds
        ];
        for (blng__PaymentMethod__c existingPM : lstPaymentMethods) {
            String existingKey = existingPM.OTR_Deal__c;
            existingPaymentMethods.put(existingKey, existingPM);
        }

        for (OTR_Offering__c offering : lstOfferingsForPaymentMethods) {
            String deal = offering.OTR_Quote__c;
            if (!existingPaymentMethods.containsKey(deal) && offering.OTR_Type__c != null && !offering.OTR_Type__c.toLowerCase().contains('discount')) {
                String dealWithType = key + offering.OTR_Type__c;
                if (!newPaymentMethods.containsKey(dealWithType)) {
                    blng__PaymentMethod__c newPaymentMethod = new blng__PaymentMethod__c(
                        OTR_Deal__c = offering.OTR_Quote__c,
                        OTR_Rebate_Offering_Record__c = offering.OTR_Type__c,
                        Status__c = 'Draft'
                    );
                    newPaymentMethods.put(dealWithType, newPaymentMethod);
                }
            }
        }

        // Insert New Payment Methods
        if (!newPaymentMethods.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(newPaymentMethods.values(), false);
            for (Database.SaveResult result : saveResults) {
                if (!result.isSuccess()) {
                    errorMessages.add('Payment Method Creation failed: ' + result.getErrors()[0].getMessage());
                }
            }
        }
    } catch (Exception e) {
        errorMessages.add('An unexpected error occurred: ' + e.getMessage());
    }
}


    
    // APEX-1244 - Method to handle Deal Activation Logic based on the end dates and valid/invalid billing account status in Offerings records
    public static void checkValidOrInvalidOfferings(List<OTR_Offering__c> lstOfferings){
		
        for(OTR_Offering__c offeringTypeRec: lstOfferings){		
            String invalidOffering = (offeringTypeRec.RecordTypeId == discountRecordtypeId || offeringTypeRec.RecordTypeId == spPtsRecordtypeId) ?  'true' : 'false';
            switch on invalidOffering{
                WHEN 'true' {
                    if(offeringTypeRec.OTR_Effective_End_Date__c < Date.TODAY()){  
                        mapQuoteIdInReason.put(offeringTypeRec.OTR_Quote_Line_Item__r.QuoteId, 'Deal incentives contain End Dates that are in the past. This will need to be adjusted by the credit coordinator');
                    	offeringTypeRec.OTR_Status__c = OTR_Constants.STATUS_REVIEW_REQ;
            			lstOfferingUpdate.add(offeringTypeRec);
            			invalidDtQuoteIdSet.add(offeringTypeRec.OTR_Quote_Line_Item__r.QuoteId);
                    }
                    else if(offeringTypeRec.OTR_Billing_Account__r.Status__c == OTR_Constants.STATUS_INACTIVE || offeringTypeRec.OTR_Billing_Account__r.Status__c == ''){
                        mapQuoteIdInReason.put(offeringTypeRec.OTR_Quote_Line_Item__r.QuoteId, 'Deal contains one or more billing account(s) that have been either inactivated or removed from Salesforce.');
                    	offeringTypeRec.OTR_Status__c = OTR_Constants.STATUS_REVIEW_REQ;
            			lstOfferingUpdate.add(offeringTypeRec);
            			invalidDtQuoteIdSet.add(offeringTypeRec.OTR_Quote_Line_Item__r.QuoteId);
                    }
                }
                WHEN 'false' {
                    lstOfferingsForPaymentMethods.add(offeringTypeRec);
                }
            }
        }
    }
    
    // APEX-1244 - Method to perform following operations -
    //				1. Activate Quote records when a deal is successfully activated
    // 				2. Activate status and start dated on Offering records
    //				3. Send Email to Sales Rep when deal activation fails
    public static void updateQuoteAndOfferings(List<Quote> quoteList){
        
		Map<Id, RecordType> mapOfIdRecordType = new Map<Id, RecordType>([SELECT Name FROM RecordType WHERE sObjectType = 'OTR_Offering__c' WITH SECURITY_ENFORCED ]);
        List<Messaging.SingleEmailMessage> mailList =  new List<Messaging.SingleEmailMessage>();
        for(Quote quoteRecord: quoteList){
            if(!invalidDtQuoteIdSet.isEmpty() && invalidDtQuoteIdSet.contains(quoteRecord.Id)){
                quoteRecord.OTR_Activation_Failed__c = true;
                Messaging.SingleEmailMessage newMail = new Messaging.SingleEmailMessage();
                List<String> sendToAddressesList = new List<String>();
                sendToAddressesList.add(quoteRecord.OTR_Sales_Rep__r.Email);
                newMail.setToAddresses(sendToAddressesList);
                String accName = quoteRecord.Account.Name;
                String strQtNameURL = '<a href=' +System.URL.getOrgDomainUrl().toExternalForm()+'/'+quoteRecord.Id+' >'+ quoteRecord.Name+'</a>';
                String strAccNameURL = '<a href=' +System.URL.getOrgDomainUrl().toExternalForm()+'/'+quoteRecord.AccountId+' >'+ quoteRecord.Account.Name +'</a>';
                // Set the attributes of the email.
                String emailSubject = 'Deal for '+ accName + ' cannot be activated';
                String emailBody = 'Could not activate '+strQtNameURL+' for '+strAccNameURL+ ' due to following reasons <br/> <br/>';
                emailBody += mapQuoteIdInReason.get(quoteRecord.Id) + ' . <br/> <br/>';
                emailBody += 'If you feel you have received this email in error, please contact Salesforce System Admin support.';
                newMail.setSubject(emailSubject);
                newMail.setHtmlBody(emailBody);
                // Add the email to the list
                mailList.add(newMail);
            }
            
            else if(!invalidDtQuoteIdSet.isEmpty() && !invalidDtQuoteIdSet.contains(quoteRecord.Id)){
                
				quoteRecord.OTR_Activation_Failed__c = false;
                quoteRecord.Status = OTR_Constants.STATUS_DEAL_ACTIVATED;
                
                if(lstOfferings != null) {
                    for(OTR_Offering__c offeringTypeRec : lstOfferings){
                        if(mapOfIdRecordType.containsKey(offeringTypeRec.RecordTypeId)){
                        	offeringTypeRec = checkOfferingDates(offeringTypeRec, mapOfIdRecordType);
							lstOfferingUpdate.add(offeringTypeRec);
                        }
                    }
                }
            }
            lstQuoteToUpdate.add(quoteRecord);
        }
        if(!mailList.isEmpty()){
            Messaging.sendEmail(mailList);
        }
    }
	
    // APEX-1244 - Method to check the start dates for Offerings and make the updates 
	public static OTR_Offering__c checkOfferingDates(OTR_Offering__c offeringTypeRec, Map<Id, RecordType> mapOfIdRecordType){
		switch on mapOfIdRecordType.get(offeringTypeRec.RecordTypeId)?.Name {
			when 'Discount' {
				if(offeringTypeRec.OTR_Effective_Start_Date__c <= Date.TODAY()){
					offeringTypeRec.OTR_Effective_Start_Date__c = Date.TODAY();
					offeringTypeRec.OTR_Status__c = OTR_Constants.STATUS_ACTIVE;
				}
			}
			when 'Special Points' {
				if(offeringTypeRec.OTR_Effective_Start_Date__c <= Date.TODAY() && (Date.TODAY().Day() == 1 || Date.TODAY().Day() == 15)){
					offeringTypeRec.OTR_Effective_Start_Date__c = Date.TODAY();
					offeringTypeRec.OTR_Status__c = OTR_Constants.STATUS_ACTIVE;
				}
				
				else if(offeringTypeRec.OTR_Effective_Start_Date__c.Day() > 1 && offeringTypeRec.OTR_Effective_Start_Date__c.Day() < 15){
					offeringTypeRec.OTR_Effective_Start_Date__c = Date.newInstance(offeringTypeRec.OTR_Effective_Start_Date__c.Year(), offeringTypeRec.OTR_Effective_Start_Date__c.Month(), 15);
				}

				else if(offeringTypeRec.OTR_Effective_Start_Date__c.Day() > 15){
					offeringTypeRec.OTR_Effective_Start_Date__c = Date.newInstance(offeringTypeRec.OTR_Effective_Start_Date__c.Year(), offeringTypeRec.OTR_Effective_Start_Date__c.Month()+ 1, 1);
				}
			}
		}		
		return offeringTypeRec;
	}
}**/
}