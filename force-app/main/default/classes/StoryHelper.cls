public class StoryHelper {
/**
//APEX-1447 - Method to create payment methods based on the Offerings records
    public static void createPaymentMethods(List<OTR_Offering__c> lstOfferings){
        Map<String, blng__PaymentMethod__c> paymentMethodMap = new Map<String, blng__PaymentMethod__c>();
        Map<String, blng__PaymentMethod__c> existingPaymentMethodsMap = new Map<String, blng__PaymentMethod__c>();
        Set<Id> offeringIds = new Set<Id>();
        try{
            
            for (OTR_Offering__c offering : lstOfferings) {
                offeringIds.add(offering.Id);
            }
            
            List<blng__PaymentMethod__c> existingPaymentMethods = [
                SELECT Id, QuoteNumber, Type__c
                FROM blng__PaymentMethod__c
                WHERE OfferingLookup IN :offeringIds
            ];
            for (blng__PaymentMethod__c existingPM : existingPaymentMethods) {
                String existingKey = existingPM.QuoteNumber + existingPM.Type__c; // Adjust field names as necessary
                existingPaymentMethodsMap.put(existingKey, existingPM);
            }
            
            for(OTR_Offering__c offeringTypeRec: lstOfferings){
                if(offeringTypeRec.type_c !=null && !offeringTypeRec.toLowerCase().contains('discount')){
                    String key = offeringTypeRec.QuoteNumber+offeringTypeRec.type_c;
                    if(!paymentMethodMap.containsKey(key) && !existingPaymentMethodsMap.containsKey(key)){
                        blng__PaymentMethod__c newPaymentMethod = new blng__PaymentMethod__c(
                            //Assign Field Values
                        );
                        paymentMethodMap.put(key,newPaymentMethod);
                    }
                }
            }
            if(!paymentMethodMap.isEmpty()){
                Database.SaveResult[] pmsr = Database.insert(paymentMethodMap.values, false);
                for (Database.SaveResult result : pmsr) {
                    if (!result.isSuccess()) {
                        errorMessages += 'Payment Method Creation failed:' + result.getErrors()[0].getMessage() + '<br/>';
                    }
                }
            }
            
        }
        catch (Exception e) {
            errorMessages += 'An unexpected error occurred: ' + e.getMessage() + '<br/>';
        }
    }

User Story - 2
A--
 
tier
retail
 
payments record
 
A
b
 
vender id
 
1)
 
   vender id = 1234
   status = active
   quote attached
   query rebate offering records and store in collection
   My Payment method is retail
   whatver retail offerig records
   look up populate that particular record
2) vender id tier = 1245
   same logics
3) tier vender =1234
   if(vender id same also activated){
     yes
   }else if(vender id same but not active){
   attach activating payment menthod on offering
   }

List<Payment_Method__c> paymentMethodsToUpdate = [
    SELECT Id 
    FROM Payment_Method__c 
    WHERE Id IN ('a02dL00000CUYWnQAP', 'a02dL00000CUYWpQAP', 'a02dL00000CUYWoQAP')
];

for (Payment_Method__c pm : paymentMethodsToUpdate) {
    pm.Status__c = 'Active';
}

if (!paymentMethodsToUpdate.isEmpty()) {
    update paymentMethodsToUpdate;
    System.debug('Payment Methods updated successfully.');
} else {
    System.debug('No records found with the given Ids.');
}

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
                when 'false' {
                    
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
}


For creating 1000 records similar to a lookup object without creating custom objects, Custom Metadata Types are generally the better choice over Custom Settings. Here are the reasons why:

Custom Metadata Types:

Storage and Limits:
You can store up to 10 million characters.
Each organization can have up to 200 custom metadata types, with an additional 150 allowed from certified managed packages, for a total of 350.
Each custom metadata type can have up to 100 fields.
Records returned per transaction: 50,000.
Usage:
Custom metadata types are ideal for storing configuration and application metadata that needs to be packaged and deployed across different environments.
They are cached, making access efficient and not counting against SOQL query limits.
Migration and Deployment:
Custom metadata types can be migrated using second-generation packages or Metadata API tools.
They are suitable for scenarios where you need to deploy metadata across multiple orgs.
Custom Settings:

Storage and Limits:
The total amount of cached data allowed is the lesser of 10 MB or 1 MB multiplied by the number of full-featured user licenses in your org.
Each record in the cache counts towards this limit based on the size of the data contained in each row.
Usage:
Custom settings are ideal for storing application-level data that needs to be accessed frequently and does not vary by user or profile.
They are cached, making access efficient and not counting against SOQL query limits.
Migration and Deployment:
Custom settings are not as easily migrated as custom metadata types.
They are suitable for scenarios where the data is more static and does not need to be deployed across multiple orgs.
Recommendation:

For creating 1000 records, Custom Metadata Types are generally better due to their higher storage limits, efficient caching, and ease of migration and deployment across different environments. They are especially useful if you need to package and deploy the data as part of managed packages.

https://help.salesforce.com/s/articleView?id=platform.custommetadatatypes_limits.htm&type=5
https://help.salesforce.com/s/articleView?id=platform.cs_limits.htm&type=5

Disadvantages of Using Custom Settings in Salesforce

When considering the use of Custom Settings in Salesforce, especially for deployment and other aspects, there are several disadvantages to be aware of:

Limited Storage:
The total amount of cached data allowed is the lesser of 10 MB or 1 MB multiplied by the number of full-featured user licenses in your org. This can be restrictive if you have a large amount of data to store.
Migration and Deployment:
Custom Settings are not as easily migrated as Custom Metadata Types. While Custom Metadata Types can be included in managed packages and deployed across different environments, Custom Settings require more manual intervention during deployment.
Custom Settings data is not included in change sets, which means you need to manually migrate the data or use tools like Data Loader.
No Version Control:
Custom Settings do not support versioning. This means that any changes made to the settings are immediately applied, which can lead to issues if changes are made inadvertently.
Access Control:
Custom Settings do not have the same level of access control as Custom Metadata Types. While Custom Metadata Types can be protected and included in managed packages, Custom Settings are more exposed and can be accessed by users with the appropriate permissions.
Performance Considerations:
Although Custom Settings are cached, they are not as efficient as Custom Metadata Types in terms of performance. Custom Metadata Types are specifically designed to be highly performant and are optimized for frequent access.
Example Scenario

Scenario: You have a Salesforce org where you need to store configuration data for an application. This data includes various settings that need to be accessed frequently by the application logic.

Using Custom Settings:

You create a List Custom Setting to store the configuration data.
During deployment, you realize that the data in Custom Settings is not included in the change set. You need to manually export the data from the source org and import it into the target org using Data Loader.
After deployment, you need to make a change to one of the settings. Since there is no version control, the change is immediately applied, and if there is an issue, you need to manually revert the change.
You also notice that the performance is not as optimal as expected, especially when accessing the settings frequently.
Using Custom Metadata Types:

You create a Custom Metadata Type to store the configuration data.
During deployment, you include the Custom Metadata Type in a managed package, which allows you to easily deploy the data across different environments.
The Custom Metadata Type supports versioning, so any changes made can be tracked and reverted if necessary.
The performance is optimized, and the application logic can access the settings efficiently.
Conclusion

For scenarios where you need to store configuration data that needs to be frequently accessed and deployed across different environments, Custom Metadata Types are generally a better choice due to their higher storage limits, efficient caching, ease of migration, and version control capabilities.

SELECT Id, IsDeleted, Name, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastViewedDate, LastReferencedDate, blng__Account__c, blng__BankAccountType__c, blng__BillingCountry__c, blng__CardExpirationMonth__c, blng__CardExpirationYear__c, blng__CardType__c, blng__PaymentType__c, blng__Active__c, blng__AutoPay__c, blng__BankAccountName__c, blng__BankAccountNumber__c, blng__BankName__c, blng__BankRoutingCode__c, blng__BillingAddress__c, blng__BillingCity__c, blng__BillingCompany__c, blng__BillingEmail__c, blng__BillingFax__c, blng__BillingFirstName__c, blng__BillingLastName__c, blng__BillingPhone__c, blng__BillingStateProvince__c, blng__BillingStreet__c, blng__BillingZipPostal__c, blng__CVV__c, blng__CardBIN__c, blng__CardLastFour__c, blng__CardNumber__c, blng__GLRule__c, blng__GLTreatment__c, blng__GatewayResponse__c, blng__LegalEntity__c, blng__Nameoncard__c, blng__NickName__c, blng__Notes__c, blng__PaymentGatewayToken__c, blng__PaymentGateway__c, blng__StreetAddress2__c, OTR_Rebate_Offering_Record__c, OTR_Status__c, OTR_Deal__c, OTR_Comments__c, OTR_FSM_Vendor_ID__c FROM blng__PaymentMethod__c
 
SELECT Id, OwnerId, IsDeleted, Name, RecordTypeId, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById, SystemModstamp, LastActivityDate, LastViewedDate, LastReferencedDate, OTR_Payout_Calculation_Frequency__c, OTR_Status__c, OTR_Type__c, OTR_Account__c, OTR_Applied_Benefit__c, OTR_Billing_Account__c, OTR_Break_Amount__c, OTR_Compliance_Percentage__c, OTR_Cost_Based_Rate__c, OTR_Effective_End_Date__c, OTR_Effective_Start_Date__c, OTR_Payback_to_Account__c, OTR_Quote_Line_Item__c, OTR_Quote__c, OTR_Rebate_Program__c, OTR_Retail_Minus_Rate__c, OTR_Site_Group_Details__c, OTR_Site__c, OTR_Special_Point_Multiplier__c, OTR_Start_Amount__c, OTR_Tier_Name__c, OTR_Product__c, OTR_Offering_Pricing_Index__c, OTR_Site_Mapping_Code__c, OTR_Fixed_Price__c, OTR_Payment_Method__c FROM OTR_Offering__c

public static Id rebateRecordtypeId = Schema.SObjectType.OTR_Offering__c.getRecordTypeInfosByDeveloperName().get(OTR_Constants.OTR_REBATE).getRecordTypeId();
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
    Set<Id> dealsId = new Set<Id>();

    try {
        for (OTR_Offering__c offering : lstOfferingsForPaymentMethods) {
            dealsId.add(offering.OTR_Quote__c);
        }

        List<blng__PaymentMethod__c> queriedPaymentMethods = [
            SELECT Id, OTR_Deal__c, OTR_Rebate_Offering_Record__c
            FROM blng__PaymentMethod__c
            WHERE OTR_Deal__c IN :dealsId
        ];
        for (blng__PaymentMethod__c existingPM : queriedPaymentMethods) {
            String existingKey = existingPM.OTR_Deal__c + existingPM.OTR_Rebate_Offering_Record__c;
            existingPaymentMethods.put(existingKey, existingPM);
        }

        List<OTR_Offering__c> filteredOfferings = new List<OTR_Offering__c>();
        for (OTR_Offering__c offering : lstOfferingsForPaymentMethods) {
            String key = offering.OTR_Quote__c + offering.OTR_Type__c;
            if (!existingPaymentMethods.containsKey(key)) {
                filteredOfferings.add(offering);
            }
        }
        lstOfferingsForPaymentMethods.clear();
        lstOfferingsForPaymentMethods.addAll(filteredOfferings);

        for (OTR_Offering__c offeringTypeRec : lstOfferingsForPaymentMethods) {
            if (offeringTypeRec.OTR_Type__c != null && !offeringTypeRec.OTR_Type__c.toLowerCase().contains('discount')) {
                String key = offeringTypeRec.OTR_Quote__c + offeringTypeRec.OTR_Type__c;
                if (!newPaymentMethods.containsKey(key) && !existingPaymentMethods.containsKey(key)) {
                    blng__PaymentMethod__c newPaymentMethod = new blng__PaymentMethod__c(
                        OTR_Deal__c = offeringTypeRec.OTR_Quote__c,
                        OTR_Rebate_Offering_Record__c = offeringTypeRec.OTR_Type__c,
                        Status__c = 'Draft'
                    );
                    newPaymentMethods.put(key, newPaymentMethod);
                }
            }
        }

        // Insert new PaymentMethods
        if (!newPaymentMethods.isEmpty()) {
            Database.SaveResult[] pmsr = Database.insert(newPaymentMethods.values(), false);
            for (Database.SaveResult result : pmsr) {
                if (!result.isSuccess()) {
                    errorMessages += 'Payment Method Creation failed: ' + result.getErrors()[0].getMessage() + '<br/>';
                }
            }
        }

    } catch (Exception e) {
        errorMessages += 'An unexpected error occurred: ' + e.getMessage() + '<br/>';
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
}


**/
}