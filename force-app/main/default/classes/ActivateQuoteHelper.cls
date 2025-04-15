public with sharing class ActivateQuoteHelper {
    /**public static Id discountRecordtypeId = Schema.SObjectType.OTR_Offering__c.getRecordTypeInfosByDeveloperName().get(OTR_Constants.OTR_DISCOUNT).getRecordTypeId();
    public static Id spPtsRecordtypeId = Schema.SObjectType.OTR_Offering__c.getRecordTypeInfosByDeveloperName().get(OTR_Constants.OTR_SPECIAL_POINTS).getRecordTypeId();
    public static String strQuoteIdCustObjName;
    public static List<SObject> lstSobjectUpdate = new List<SObject>();
    public static List<OTR_Offering__c> lstOfferings = new List<OTR_Offering__c>();
    public static List<OTR_Offering__c> lstOfferingUpdate = new List<OTR_Offering__c>();
    public static Set<Id> invalidDtQuoteIdSet = new Set<Id>(); 
    public static Map<Id,String> mapQuoteIdInReason = new Map<Id,String>();
    public static List<Quote> lstQuoteToUpdate = new List<Quote>();
    public static String errorMessages;
    // APEX-1244 - Method to handle deal activation logic
    public static void activateDeal(List<Quote> quoteList){
        try{ 
            lstOfferings = new List<OTR_Offering__c>([SELECT Id, RecordTypeId, OTR_Status__c, OTR_Billing_Account__c, OTR_Billing_Account__r.OTR_Billing_Type__c,
                                                      OTR_Billing_Account__r.Status__c, OTR_Effective_Start_Date__c, OTR_Effective_End_Date__c, Name, 
                                                      OTR_Quote_Line_Item__c, OTR_Quote_Line_Item__r.QuoteId FROM OTR_Offering__c
                                                      WHERE OTR_Quote_Line_Item__r.QuoteId IN: quoteList 
													  AND OTR_Billing_Account__c != NULL
                                                      AND OTR_Billing_Account__r.Status__c != NULL 
                                                      AND ((RecordTypeId =: discountRecordtypeId AND OTR_Billing_Account__r.OTR_Billing_Type__c =: OTR_Constants.BILLING_TYPE_DIRECT)
													  OR RecordTypeId =: spPtsRecordtypeId)]);
            if(!lstOfferings.isEmpty()){
                checkValidOrInvalidOfferings(lstOfferings);
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
            if(invalidDtQuoteIdSet.contains(quoteRecord.Id)){
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
            else if(!invalidDtQuoteIdSet.contains(quoteRecord.Id)){
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
	}**/
}