public class createPaymentMethods{
   /**     Map<String, blng__PaymentMethod__c> paymentMethodMap = new Map<String, blng__PaymentMethod__c>();
        for(OTR_Offering__c offeringTypeRec: lstOfferings){
            if(offeringTypeRec.type_c !=null && !offeringTypeRec.toLowerCase().contains('discount')){
                String key = offeringTypeRec.QuoteNumber+offeringTypeRec.type_c;
                if(!paymentMethodMap.containsKey(key)){
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
        }**/
    }