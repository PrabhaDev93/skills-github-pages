public class createPaymentMethod {
public static void createPaymentMethods(List<Offering__c> lstOfferings){
        Map<String, Payment_Method__c> paymentMethodMap = new Map<String, Payment_Method__c>();
        Map<String, Payment_Method__c> existingPaymentMethodsMap = new Map<String, Payment_Method__c>();
        Set<Id> accountIds = new Set<Id>();
    	String errorMessages = '';
        try{
            
            for (Offering__c offering : lstOfferings) {
                accountIds.add(offering.Account__c);
            }
            
            List<Payment_Method__c> existingPaymentMethods = [
                SELECT Id, Account__c, Type__c
                FROM Payment_Method__c
                WHERE Account__c IN :accountIds
            ];
            for (Payment_Method__c existingPM : existingPaymentMethods) {
                String existingKey = existingPM.Account__c + existingPM.Type__c; // Adjust field names as necessary
                existingPaymentMethodsMap.put(existingKey, existingPM);
            }
            
            for(Offering__c offeringTypeRec: lstOfferings){
                if(offeringTypeRec.Type__c !=null && !offeringTypeRec.Type__c.toLowerCase().contains('discount')){
                    String key = offeringTypeRec.Account__c+offeringTypeRec.Type__c;
                    if(!paymentMethodMap.containsKey(key) && !existingPaymentMethodsMap.containsKey(key)){
                        Payment_Method__c newPaymentMethod = new Payment_Method__c(
                            Account__c = offeringTypeRec.Account__c,
                            Type__c = offeringTypeRec.Type__c,
                            Status__c = 'Draft'
                        );
                        paymentMethodMap.put(key,newPaymentMethod);
                    }
                }
            }
            if(!paymentMethodMap.isEmpty()){
                Database.SaveResult[] pmsr = Database.insert(paymentMethodMap.values(), false);
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
}