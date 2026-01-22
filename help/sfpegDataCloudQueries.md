# ![Logo](/media/Logo.png) &nbsp; **sfpegDataCloudQueries_SVC** Query Extension

This component is part of the **[PEG_DC](/README.md)** repository.


## Introduction

The **sfpegDataCloudQueries_SVC** Apex Class is an extension to the
**[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** 
component capabilities. It basically enables to execute an ANSI SQL query on **Data Cloud**
data via the **ConnectApi** Apex class.

Typical use case is to fetch contextualised detailed information available in **Data Cloud** and display
it as a related list in a record page.


## Configuration

ℹ️ Please refer to the [PEG_LIST Component Configuration](https://github.com/pegros/PEG_LIST/blob/master/help/configuration.md)
dedicated page to get more general information about the way the included components may be configured. 

This Apex class may be leveraged within standard **[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** configuration.
In order to use it, the `sfpegList` metadata record should be configured as follows:
* `Query Type` should be set to `Apex`
* `Query Class` should be set to `sfpegDataCloudQueries_SVC` 
* `Query Input` set to fetch the proper context information
* `Query Template` should contain a the ANSI SQL query contextualized with
the `{{{xxxx}}}` merge tags provided by the `Query Input`

⚠️ Please pay attention to the `Bypass Escaping` which should preferably
remain unchecked to ensure better protection against _code injection_.


## Configuration Example

The following example shows a **[sfpegListCmp](/help/sfpegListCmp.md)** in a
standard Lightning App page (`DMO Lists`) listing the latest records created 
in the Account DMO.

![DataCloud Queries](/media/sfpegDataCloudQueries.png)

For this result, the **sfpegList** metadata record should be configured as follows:
* `Scope`set to `GLOBAL`
* `Query Type`set to `Apex`
* `Query Input` set to 
```
{
    "LIMIT":"100"
}
```
* `Query Class` set to `sfpegDataCloudQueries_SVC`
* `Query Template` set to
```
SELECT ssot__Id__c, ssot__Name__c, ssot__DataSourceId__c, Global_Account_Parent_ID__c, City__c FROM ssot__Account__dlm LIMIT {{{LIMIT}}}
```
* `Display Type` set to `DataTable`
* `Flatten Results?` set to `false`
* `Display Configuration` set to 
```
{
    "keyField":"ssot__Id__c",
    "widthMode":"auto",
    "columns": [
        { "label":"Source", "fieldName": "ssot__DataSourceId__c", "sortable": "true"},
        { "label":"Name", "fieldName":"ssot__Name__c", "sortable": "true"},
        { "label": "ID", "fieldName": "ssot__Id__c", "sortable": "true"},
        { "label": "City", "fieldName": "City__c", "sortable": "true"}
    ]
}
```

## Technical Details

This class implements only the `getData()` method of the **sfpegListQuery_SVC** interface class. 
This means that pagination is (currently) not supported.

It relies on the `queryAnsiSqlV2()` method of the standard **[ConnectApi.CdpQuery](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_ConnectAPI_CdpQuery_static_methods.htm#apex_ConnectAPI_CdpQuery_static_methods)** Apex class to manage SQL queries.

This class comes with its dedicated **sfpegDataCloudQueries_TST** test class.

ℹ️ Please refer to the [PEG_LIST Technical Details](https://github.com/pegros/PEG_LIST/blob/master/help/technical.md)
dedicated page to get more global information about the way the components have been implemented.