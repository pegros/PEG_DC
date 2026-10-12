# ![Logo](/media/Logo.png) &nbsp; **sfpegDataCloudQueriesV3_SVC** Query Extension

This component is part of the **[PEG_DC](/README.md)** repository.


## Introduction

The **sfpegDataCloudQueriesV3_SVC** Apex Class is an extension to the
**[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** 
component capabilities. It basically enables to execute an ANSI SQL query on **Data Cloud**
data via the new **[sfsqlquery](https://developer.salesforce.com/docs/data/data-cloud-query-guide/guide/dc-apex-query.html)**
Apex framework.

It is a new variant of the **[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md)** Apex Class
(relying on the **ConnectApi.CdpQuery** Apex class), with the same configuration and behaviour.
Salesforce now recommends the **sfsqlquery** framework for new developments,
**ConnectApi.CdpQuery** remaining available for backward compatibility.

Typical use case is to fetch contextualised detailed information available in **Data Cloud** and display
it as a related list in a record page.

⚠️ For the time being, only **synchronous** queries are supported, i.e. the whole result set
should fit within the governor limits of a single Apex transaction (using a `LIMIT` clause
is therefore recommended).


## Configuration

ℹ️ Please refer to the [PEG_LIST Component Configuration](https://github.com/pegros/PEG_LIST/blob/master/help/configuration.md)
dedicated page to get more general information about the way the included components may be configured. 

This Apex class may be leveraged within standard **[sfpegListCmp](https://github.com/pegros/PEG_LIST/blob/master/help/sfpegListCmp.md)** configuration.
In order to use it, the `sfpegList` metadata record should be configured as follows:
* `Query Type` should be set to `Apex`
* `Query Class` should be set to `sfpegDataCloudQueriesV3_SVC` 
* `Query Input` set to fetch the proper context information
* `Query Template` should contain a the ANSI SQL query contextualized with
the `{{{xxxx}}}` merge tags provided by the `Query Input`

⚠️ Please pay attention to the `Bypass Escaping` which should preferably
remain unchecked to ensure better protection against _code injection_.

ℹ️ Existing `sfpegList` metadata records configured for the
**[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md)** Apex Class
may be migrated to this new class by simply changing their `Query Class` property.


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
* `Query Class` set to `sfpegDataCloudQueriesV3_SVC`
* `Query Template` set to
```
SELECT ssot__Id__c, ssot__Name__c, ssot__DataSourceId__c, Global_Account_Parent_ID__c, City__c
FROM ssot__Account__dlm
LIMIT {{{LIMIT}}}
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

### Single Quotes Escaping

As for the **[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md)** Apex Class,
the `ESC_SINGLE(((xxx)))` directive may be used to escape single quotes (`'`) as two
single quotes (`''`) in the merged Data Cloud SQL queries.

If you have the `NAME` context parameter with `Henry O'Maley` value, the following
SQL query 
```
SELECT ssot__Id__c, ssot__Name__c, ssot__DataSourceId__c
FROM ssot__Account__dlm
WHERE Names__c = 'ESC_SINGLE((({{{NAME}}})))'
```
is merged as 
```
SELECT ssot__Id__c, ssot__Name__c, ssot__DataSourceId__c
FROM ssot__Account__dlm
WHERE Names__c = 'Henry O''Maley'
```
whatever the `Bypass Escaping?` option selected.

Please refer to the **[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md#single-quotes-escaping)**
documentation for more details.

### Data Space Override

By default, SQL queries are executed on the `default` data space. 

This may be overridden by setting the `d360ds` property in the `Query Input`
with the API name of the target data space, e.g.
```
{
    "LIMIT":"100",
    "d360ds":"myDataSpace"
}
```

ℹ️ The `d360ds` value may be static or fetched from the context
(e.g. a field of the current record or user), the `default` data space
being used whenever it is missing or blank.

### Workload Name Override

By default, SQL queries are tagged with the `sfpegDataCloudQueriesV3` workload name
(to ease debugging by Salesforce support).

This may be overridden by setting the `d360wl` property in the `Query Input`, e.g.
```
{
    "LIMIT":"100",
    "d360wl":"myWorkload"
}
```

ℹ️ As for `d360ds`, the `d360wl` value may be static or fetched from the context,
the default workload name being used whenever it is missing or blank.


## Technical Details

This class implements only the `getData()` method of the **sfpegListQuery_SVC** interface class. 
This means that pagination is (currently) not supported.

It relies on the following classes of the standard **sfsqlquery** Apex namespace to manage SQL queries:
* **[sfsqlquery.SqlStatement](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_sfsqlquery_SqlStatement.htm)**
to execute the SQL query synchronously
* **[sfsqlquery.SqlRowIterator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_sfsqlquery_SqlRowIterator.htm)**
to iterate over the results and fetch the column metadata
* **[sfsqlquery.Row](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_sfsqlquery_Row.htm)**
to fetch the value of each column

Additional implementation details:
* Queries are executed on the `default` data space (unless overridden via the `d360ds`
context property, see [Data Space Override](#data-space-override)), with the `sfpegDataCloudQueriesV3`
workload name (unless overridden via the `d360wl` context property, see
[Workload Name Override](#workload-name-override)).
* Each result row is returned as a map of column names to values, `Date`, `Timestamp`, `TimestampTZ`
and `Time` columns being converted into Apex `Date`, `Datetime` and `Time` values
(other column types being returned as raw values).

This class comes with its dedicated **sfpegDataCloudQueriesV3_TST** test class, which relies on the 
standard **[sfsqlquery.SqlTester](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_sfsqlquery_SqlTester.htm)**
class to mock Data Cloud responses, and on the `sfpegTestDataCloudQueriesV3OK` **sfpegList** test metadata record.

ℹ️ Please refer to the [PEG_LIST Technical Details](https://github.com/pegros/PEG_LIST/blob/master/help/technical.md)
dedicated page to get more global information about the way the components have been implemented.
