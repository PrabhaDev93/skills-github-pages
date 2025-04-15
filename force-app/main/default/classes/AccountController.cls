/**
* @File Name : AccountController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : March 17, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | March 17, 2025 |   | Initial Version
**/

public with sharing class AccountController {
  @AuraEnabled(cacheable=true)
  public static List<Account> getAccounts() {
    return [SELECT Id, Name, Phone, Industry FROM Account LIMIT 5];
  }
  @AuraEnabled(cacheable=true)
  public static List<Contact> getContacts() {
    return [SELECT Id, Name, Phone, Email FROM Contact LIMIT 5];
  }
}