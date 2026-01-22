# ![Logo](/media/Logo.png) &nbsp; **sfpegPromptQueries_SVC** Query Extension

This component is part of the **[PEG_DC](/README.md)** repository.


## Introduction

The **sfpegPromptQueries_SVC** Apex Class is an extension to the
**[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** 
component capabilities. It basically enables to invoke an **AI Prompt** to fetch
data via the **ConnectApi** Apex class.

Typical use case is to fetch contextualised detailed recommendations from an **AI Prompt**
and display them as a related list in a record page.


## Configuration

ℹ️ Please refer to the [PEG_LIST Component Configuration](https://github.com/pegros/PEG_LIST/blob/master/help/configuration.md)
dedicated page to get more general information about the way the included components may be configured. 

This Apex class may be leveraged within standard **[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** configuration.
In order to use it, the `sfpegList` metadata record should be configured as follows:
* `Query Type` should be set to `Apex`
* `Query Class` should be set to `sfpegPromptQueries_SVC` 
* `Query Input` set to fetch the proper context information
* `Query Template` should contain a JSON object with the following properties:
    * `promptDevName` for a filter on the **Prompt** name or label
    * `promptInput` for the default ordering of rows as a JSON structure
    matching the standard `ConnectApi.​EinsteinPrompt​Template​GenerationsInput`
    structure (see [documentation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_connectapi_input_einstein_prompt_template_generations.htm))
    * `outputMode` to indicate how to process the output of the **AI Prompt**
        * `JSON`means that the output text should be parsed as a JSON array of objects
        * any other value (or omitted) returns the native `generations` records
    
ℹ️ Please refer to the `generate​MessagesFor​PromptTemplate()` method of the standard **[ConnectApi.EinsteinLLM](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_ConnectAPI_EinsteinLLM_static_methods.htm)** for more details about these properties.

⚠️ Please pay attention to the `Bypass Escaping` which should preferably
remain unchecked to ensure better protection against _code injection_.


## Configuration Example

The following example shows a **[sfpegListCmp](/help/sfpegListCmp.md)** 
component in a standard Lightning record page (`Contact`) providing
recommendations relative to the current record based on the output of
an **AI Prompt** leveraging a **RAG** index.

For this result, the **sfpegList** metadata record should be configured as follows:
* `Scope`set to `Contact`
* `Query Type`set to `Apex`
* `Query Input` set to 
```
{"RCD":"{{{GEN.recordId}}}"}
```
* `Query Class` set to `sfpegPromptQueries_SVC`
* `Query Template` set to
```
{
    "promptDevName":"{{{CONTEXT}}}",
    "promptInput": {
        "additional​Config":{
            "application​Name":"PromptTemplateGenerationsInvocable"
        },
        "inputParams":{
            "Input:Contact":{"id":"{{{RCD}}}"}
        },
        "citationMode":"off",
        "isPreview":false,
        "outputLanguage":"English"
    },
    "outputMode":"JSON"
}
```
* `Display Type` set to `CardList`
* `Flatten Results?` set to `false`
* `Display Configuration` set to 
```
{
    "keyField":"RecordId",
    "widthMode":"auto",
    "fieldNbr":2,
    "stacked":false,
    "title":{"fieldName":"Title","action":"previewJob","label":"View RAG Synthesis"},
    "columns": [
        { "label": "Title", "fieldName": "Title"}
    ],
    "details":[
        { "label": "City", "fieldName": "City","sortable":true,"type":"badge"},
        { "label": "ID", "fieldName": "RecordId","sortable":true},
        { "label": "Description", "fieldName": "Description","sortable":true,"size":12}
    ],
    "menu":[
        {"label":"Display Job DMO","icon":"utility:open","name":"displayJob"}
    ]
}
```

⚠️ On the Lightning App Page, the `Query Context` property should be set to
the `API Name` of the **AI Prompt** to invoke.

ℹ️ The `Display Configuration` configuration relies on the output format requested
in the Prompt. E.g. 
```
Output should be formatted as a JSON array of jobs
[
{
"Title":"Senior Portfolio Analyst",
"RecordId":"a0rcm00000SWkxZAAT",
"City":"Warwick",
"Description":"As a senior portfolio analyst, you will be in charge of analysing and monitoring the risks related to our main clients..."
},
{
"Title":"Portfolio Manager",
"RecordId":"a0rcm00000U4SR3AAN",
"City":"London",
"Description":"As a senior portfolio manager, you will be in charge of a team of analysts..."
}
]
```

## Technical Details

This class implements only the `getData()` method of the **sfpegListQuery_SVC** interface class. 
This means that pagination is (currently) not supported.

It relies on the `generate​MessagesFor​PromptTemplate()` method of the standard **[ConnectApi.EinsteinLLM](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_ConnectAPI_EinsteinLLM_static_methods.htm)** Apex class to invoke **AI Prompts**.

🚨 **TODO**: This class comes with its dedicated **sfpegPromptQueries_TST** test class.

ℹ️ Please refer to the [PEG_LIST Technical Details](https://github.com/pegros/PEG_LIST/blob/master/help/technical.md)
dedicated page to get more global information about the way the components have been implemented.