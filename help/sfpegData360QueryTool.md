# ![Logo](/media/Logo.png) &nbsp; **SFPEG Data360 Query Tool** Component

This component is part of the **[PEG_DC](/README.md)** repository.


## Introduction

The **sfpegData360QueryToolCmp** LWC component is a standalone tool enabling users to
specify and run any ANSI SQL query on **Data 360** (Data Cloud) data directly from a
Lightning page, and to explore, filter, inspect, copy or download the results.

It relies on the new **[sfsqlquery](https://developer.salesforce.com/docs/data/data-cloud-query-guide/guide/dc-apex-query.html)**
Apex framework (via its dedicated **sfpegData360Query_SVC** Apex controller) and provides
server-side **data masking** capabilities to prevent sensitive data (e.g. ID card or IBAN numbers)
from ever reaching the browser for standard users.

Typical use cases are:
* ad-hoc exploration of **Data 360** DMOs / DLOs by admins or business analysts,
without having to use the **Data 360** Query Editor
* investigation of **Agentforce** session tracing data (STDM / GenAI Gateway DMOs),
JSON payloads being displayed in a structured way
* quick extraction of query results for analysis in a spreadsheet.

![Data360 Query Tool](/media/sfpegData360QueryTool.png)

⚠️ Only **synchronous** queries are supported, i.e. the whole result set should fit within
the governor limits of a single Apex transaction. Results are in any case capped to a maximum
number of rows (see [Configuration](#configuration)), using a `LIMIT` clause being therefore recommended.


## Features

### Query Definition

The upper **SQL Query** card enables to:
* select the target **DataSpace** among the active ones on the Org (`default` being selected by default)
* input the **SQL** query to execute (text area being resizable)
* execute the query via the **Run** button.

The card may be collapsed (top right button) to give more room to the results, the **Run** button
remaining available in its header. It is automatically collapsed when a query is run.

### Saved Queries

Users may save their usual queries (with their DataSpace) in the browser local storage
to easily reuse them later, via the **Saved Queries** selector and its associated buttons:
* selecting a saved query fills in the **DataSpace** and **SQL** inputs
* the 💾 _save_ button saves the current query under a user provided name
(an existing name being overwritten after confirmation)
* the 🗑️ _delete_ button removes the selected saved query (after confirmation)
* the ⬇️ _download_ button downloads the whole set of saved queries as a `savedQueries.json` file
* the ⬆️ _upload_ button upserts (by name) the saved queries contained in a JSON file
(previously downloaded or prepared manually), invalid entries being ignored
* the ✖️ _clear_ button removes all saved queries from the browser (after confirmation).

The selected saved query is automatically deselected as soon as the user modifies the SQL query.

![Data360 Query Tool Saved Queries](/media/sfpegData360QueryToolSaved.png)

The JSON file format is a simple list of queries, e.g.
```
[
  {
    "name": "Latest Accounts",
    "dataSpace": "default",
    "sql": "SELECT ssot__Id__c, ssot__Name__c FROM ssot__Account__dlm LIMIT 100"
  }
]
```
ℹ️ `name` and `sql` properties are required, `dataSpace` defaulting to `default` when missing.

⚠️ Saved queries are stored in the local storage of the user's browser (for the current Org domain):
they are neither shared between users nor between browsers / devices. The download / upload features
may be used to transfer or share them (e.g. downloading them before clearing them).

### Results Display

The lower **Query Results** card displays the results in a datatable:
* the header provides the number of rows returned (with a `+` suffix when truncated) and, when a filter
is applied, the number of matching rows
* columns are formatted according to their **Data 360** type (number, date, datetime or text)
* all columns are sortable (null values being always sorted last)
* results are displayed by pages of 100 rows, more rows being added when scrolling down
* warnings are displayed when results have been truncated to the maximum number of rows
allowed or when masking rules have been applied.

The search input in the card header enables to filter the results locally
(case insensitive match on all columns).

### Cell Inspection

Clicking on any cell of the datatable opens an inspection tile, sticky at the bottom of the page,
displaying the full value of the cell with its column label:
* JSON content (objects, arrays or JSON strings) is pretty printed
* long texts are wrapped instead of being truncated, line breaks being preserved.

Clicking on another cell updates the tile content, clicking on an empty cell closes it.

The tile may be:
* resized (bottom right corner) horizontally and vertically
* moved left or right via its drag handle (when narrower than the results card)
* closed or its value copied to the clipboard via its actions menu.

Its layout (size and position) is kept when the tile is closed and redisplayed
(until the page is reloaded).

![Data360 Query Tool Cell Inspection](/media/sfpegData360QueryToolInspect.png)

### Copy & Download

The results card header provides:
* a format selector to choose between `JSON`, `CSV` (default) or `TSV` (tab separated text) formats
* a _copy_ button to copy the results to the clipboard in the selected format
(`TSV` being the most appropriate format to paste them directly in spreadsheet cells)
* a _download_ button to download the results as a `results.json`, `results.csv` or `results.tsv` file.

ℹ️ Both operations apply to all rows matching the current filter (not only the ones displayed),
in the current sort order. A UTF-8 BOM is added to CSV / TSV files for proper accented characters
display in Excel.


## Installation & Configuration

### Component Setup

The **sfpegData360QueryToolCmp** component is available in the App Builder for **App** pages
(`lightning__AppPage` target). It should be added to a dedicated Lightning App page, preferably
in a single wide column layout, which may then be added to any Lightning App.

All its labels and titles are initialized from **custom labels** (all named with a
`sfpegData360Query` prefix), which may be translated via the **Translation Workbench**.

### Permissions

The following permission sets are provided:
* **SFPEG Data360 Query User** (`sfpegData360QueryUser`) granting access to the
**sfpegData360Query_SVC** Apex controller and to the `sfpegData360QueryTab` tab
* **SFPEG Data360 Query Masking Bypass** (`sfpegData360QueryBypassMasking`) granting the
`sfpegData360QueryBypassMasking` custom permission to see raw (unmasked) results
(to be assigned in addition to the previous one, typically to admin users only).

⚠️ Users should also be granted the proper **Data 360** permissions (e.g. **Data Cloud User**)
to be able to query the **Data 360** data.

### Row Limit

The maximum number of rows returned by a query is capped to `10000`. This cap may be lowered
(but not raised) via the **Max Rows** field of the **Data360 Query Settings** (`sfpegData360QuerySettings__c`)
hierarchy custom setting, at Org, profile or user level.

### Data Masking

Masking rules are defined as **Data360 Query Data Masking Rule** (`sfpegData360QueryMaskingRule__mdt`)
custom metadata records, with the following properties:
* `Pattern` regular expression (Apex flavor) matched against each result value, e.g.
`\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b` for IBAN numbers (invalid patterns being ignored)
* `Replacement` text replacing each match, e.g. `[MASKED]` (blank removing the match,
`$` and `\` being considered as literals)
* `Column Name` to restrict the rule to a single result column (case insensitive),
the rule applying to all columns when left blank
* `Sort Order` defining the order in which rules are applied (ascending, blank ones last)
* `Active` to disable a rule without deleting it.

![Data360 Query Tool Masking Rule](/media/sfpegData360QueryToolMasking.png)

Active rules are applied server-side by the Apex controller to all result values (converted as text)
for all users not having the `sfpegData360QueryBypassMasking` custom permission.

ℹ️ The _masking applied_ warning is displayed whenever active masking rules are applicable to the user,
even if none of them actually matched any value in the results.


## Technical Details

The tool relies on the following components:
* **sfpegData360QueryToolCmp** main LWC component
* **sfpegData360DatatableCmp** LWC component extending the standard **lightning-datatable** with
an `inspectable` custom cell type, as **lightning-datatable** does not provide any cell click event
* **sfpegData360CellCmp** LWC component used by this custom cell type to display a formatted value
and notify the cell clicks
* **sfpegData360Query_SVC** Apex controller (with its **sfpegData360Query_TST** test class) providing
the `runQuery()` and `getDataSpaces()` methods.

The **sfpegData360Query_SVC** controller relies on the following elements:
* the **[sfsqlquery.SqlStatement](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_sfsqlquery_SqlStatement.htm)**
standard class to execute the SQL query synchronously, with the `sfpegData360Query` workload name
(to ease debugging by Salesforce support)
* the **[sfsqlquery.SqlRowIterator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_sfsqlquery_SqlRowIterator.htm)**
standard class to iterate over the results (up to the row limit) and fetch the column metadata
* the standard `DataSpace` object to list the active DataSpaces of the Org.

All filtering, sorting, copy and download operations are executed locally in the browser on the
results returned by the controller, no additional query being executed.