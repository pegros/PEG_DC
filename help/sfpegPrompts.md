# ![Logo](/media/Logo.png) &nbsp; **sfpegPrompts_SVC** Query Extension

This component is part of the **[PEG_DC](/README.md)** repository.


## Introduction

The **sfpegPrompts_SVC** Apex Class is an extension to the
**[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** 
component capabilities. It basically enables to execute a search on the list of
available **AI Prompts** available on the Org via the **ConnectApi** Apex class.

Typical use case is, for system admins, to sort and filter the list of **AI Prompts** on all possible fields (vs standard **Prompt Builder** setup page).


## Configuration

ℹ️ Please refer to the [PEG_LIST Component Configuration](https://github.com/pegros/PEG_LIST/blob/master/help/configuration.md)
dedicated page to get more general information about the way the included components may be configured. 

This Apex class may be leveraged within standard **[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** configuration.
In order to use it, the `sfpegList` metadata record should be configured as follows:
* `Query Type` should be set to `Apex`
* `Query Class` should be set to `sfpegPrompts_SVC` 
* `Query Input` set to fetch the proper context information
* `Query Template` should contain a JSON object with the following properties:
    * `query` for a filter on the **Prompt** name or label
    * `sortBy` for the default ordering of rows
    * `offset` for pagination
    * `pageLimit` to limit the number of records returned`
    * `fields` to specify the Prompt fields to return (null meaning all)
    * `type` to filter on a Prompt type
    * `relatedEntity` to filter on a Prompt related entity
    * `isActive` (boolean) for the Prompt status filtering (only active ones being returned if not set)

ℹ️ Please refer to the `getPromptTemplates()` method of the standard **[ConnectApi.EinsteinLLM](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_ConnectAPI_EinsteinLLM_static_methods.htm)** for more details about these properties.

⚠️ Please pay attention to the `Bypass Escaping` which should preferably
remain unchecked to ensure better protection against _code injection_.


## Configuration Example

The following example shows 2 **[sfpegListCmp](/help/sfpegListCmp.md)** 
components in a standard Lightning App page (`Prompt Templates`) listing
respectively the _active_ vs _inactive_ **AI Prompts** of the Org.

![Prompt Lists](/media/sfpegPrompts.png)

For this result, the **sfpegList** metadata record should be configured as follows:
* `Scope`set to `GLOBAL`
* `Query Type`set to `Apex`
* `Query Input` set to 
```
{}
```
* `Query Class` set to `sfpegPrompts_SVC`
* `Query Template` set to
```
{
    "sortBy":"MasterLabel",
    "offset":0,
    "pageLimit":500,
    "isActive":{{{CONTEXT}}}
}
```
* `Display Type` set to `DataTable`
* `Flatten Results?` set to `false`
* `Display Configuration` set to 
```
{
    "keyField":"id",
    "widthMode":"auto",
    "columns": [
        { "label": "API Name", "fieldName": "apiName","sortable":true},
        { "label": "Id", "fieldName": "id","sortable":true},
        { "label": "Standard?", "fieldName": "isStandard","sortable":true,"type":"boolean"},
        { "label": "Master Label", "fieldName": "MasterLabel","sortable":true},
        { "label": "Dev Name", "fieldName": "DeveloperName","sortable":true},
        { "label": "Active?", "fieldName": "IsActive","sortable":true,"type":"boolean"},
        { "label": "Type", "fieldName": "Type","sortable":true}
    ]
}
```

⚠️ On the Lightning App Page, the `Query Context` property should be respectiveli set to
`true` and `false` for the Active vs Inactive Prompt lists.


## Technical Details

This class implements only the `getData()` method of the **sfpegListQuery_SVC** interface class. 
This means that pagination is (currently) not supported.

It relies on the `getPromptTemplates()` method of the standard **[ConnectApi.EinsteinLLM](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_ConnectAPI_EinsteinLLM_static_methods.htm)** Apex class to query **AI Prompts**.

🚨 **TODO**: This class comes with its dedicated **sfpegPrompts_TST** test class.

ℹ️ Please refer to the [PEG_LIST Technical Details](https://github.com/pegros/PEG_LIST/blob/master/help/technical.md)
dedicated page to get more global information about the way the components have been implemented.