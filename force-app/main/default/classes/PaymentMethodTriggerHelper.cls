public class PaymentMethodTriggerHelper {
    public static void updateOfferingHelper(Set<Id> paymentMethodIds) {
        try {
            List<Payment_Method__c> paymentMethods = [
                SELECT Id, Status__c, Vendor__c, Account__c, Type__c
                FROM Payment_Method__c
                WHERE Id IN :paymentMethodIds
            ];

            Set<String> vendorIds = new Set<String>();
            for (Payment_Method__c paymentMethod : paymentMethods) {
                if (paymentMethod.Vendor__c != null) {
                    vendorIds.add(paymentMethod.Vendor__c);
                }
            }

            Map<String, Payment_Method__c> vendorToActivePaymentMethodMap = new Map<String, Payment_Method__c>();
            if (!vendorIds.isEmpty()) {
                try {
                    List<Payment_Method__c> activePaymentMethods = [
                        SELECT Id, Status__c, Vendor__c, Account__c, Type__c
                        FROM Payment_Method__c
                        WHERE Status__c = 'Active' AND Vendor__c IN :vendorIds
                    ];

                    for (Payment_Method__c paymentMethod : activePaymentMethods) {
                        vendorToActivePaymentMethodMap.put(paymentMethod.Vendor__c, paymentMethod);
                    }
                } catch (Exception ex) {
                    System.debug('Error while fetching active payment methods: ' + ex.getMessage());
                }
            }

            try {
                for (Payment_Method__c paymentMethod : paymentMethods) {
                    if (vendorToActivePaymentMethodMap.containsKey(paymentMethod.Vendor__c)) {
                        Payment_Method__c activePaymentMethod = vendorToActivePaymentMethodMap.get(paymentMethod.Vendor__c);
                        paymentMethod.Id = activePaymentMethod.Id;
                        paymentMethod.Status__c = activePaymentMethod.Status__c;
                        paymentMethod.Account__c = activePaymentMethod.Account__c;
                        paymentMethod.Type__c = paymentMethod.Type__c;
                    }
                }

                System.debug('Updated Payment_Method Records: ' + paymentMethods);
            } catch (Exception ex) {
                System.debug('Error while updating payment method records: ' + ex.getMessage());
            }

            Map<Id, Map<String, Payment_Method__c>> accountToTypeToPaymentMethodMap = new Map<Id, Map<String, Payment_Method__c>>();
            for (Payment_Method__c paymentMethod : paymentMethods) {
                if (paymentMethod.Account__c != null && paymentMethod.Status__c.equalsIgnoreCase('Active')) {
                    if (!accountToTypeToPaymentMethodMap.containsKey(paymentMethod.Account__c)) {
                        accountToTypeToPaymentMethodMap.put(paymentMethod.Account__c, new Map<String, Payment_Method__c>());
                    }
                    if (paymentMethod.Type__c != null) {
                        accountToTypeToPaymentMethodMap.get(paymentMethod.Account__c).put(paymentMethod.Type__c, paymentMethod);
                    }
                }
            }

            System.debug('Account to Type to Payment_Method Map: ' + accountToTypeToPaymentMethodMap);

            try {
                List<Offering__c> offeringsToUpdate = [
                    SELECT Id, Type__c, Payment_Method__c, Vendor__c, Account__c
                    FROM Offering__c
                    WHERE Account__c IN :accountToTypeToPaymentMethodMap.keySet()
                ];

                List<Offering__c> updatedOfferings = new List<Offering__c>();
                for (Offering__c offering : offeringsToUpdate) {
                    if (offering.Account__c != null && offering.Type__c != null &&
                        accountToTypeToPaymentMethodMap.containsKey(offering.Account__c)) {
                        Map<String, Payment_Method__c> typeToPaymentMethodMap = accountToTypeToPaymentMethodMap.get(offering.Account__c);

                        Payment_Method__c relatedPaymentMethod = null;

                        if (typeToPaymentMethodMap.containsKey(offering.Type__c)) {
                            relatedPaymentMethod = typeToPaymentMethodMap.get(offering.Type__c);
                        }

                        if (relatedPaymentMethod != null) {
                            offering.Payment_Method__c = relatedPaymentMethod.Id;
                            offering.Vendor__c = relatedPaymentMethod.Vendor__c;
                            updatedOfferings.add(offering);
                        }
                    }
                }

                if (!updatedOfferings.isEmpty()) {
                    try {
                        update updatedOfferings;
                        System.debug('Updated Offering Records: ' + updatedOfferings);
                    } catch (Exception ex) {
                        System.debug('Error while updating offering records: ' + ex.getMessage());
                    }
                }
            } catch (Exception ex) {
                System.debug('Error while processing offerings to update: ' + ex.getMessage());
            }
        } catch (Exception ex) {
            System.debug('Error in updateOfferingHelper: ' + ex.getMessage());
        }
    }
}