/**
* @File Name : AccountContactWizardController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : March 14, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | March 14, 2025 |   | Initial Version
**/

public with sharing class AccountContactWizardController {
  @AuraEnabled
  public static void createContact(Contact ContactRecord) {
    //Insert the contacts
    insert ContactRecord;
  }
}