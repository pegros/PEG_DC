# ![Logo](/media/Logo.png) &nbsp; SFPEG **DC** Components


## Introduction

This package contains a set of tools to extend standard **Data360** capabilities
and better manage / monitor / audit Data360 configuration and data.

For the time being, it only provides a query tool extending standard **Query Editor** feature
to execute custom SQL queries, apply data masking, reformat JSON values (especially found in
AgentForce logs) and export / copy data. 

These components were built as contributions or examples for former and ongoing Advisory assignments by 
[Pierre-Emmanuel Gros](https://github.com/pegros). 

ℹ️ Additional Data360 utilities may also be found in the **[PEG_LIST_DC](https://github.com/pegros/PEG_LIST_DC)** repository.


## Repository Content

This repository contains a whole set of tools dedicated to **Data360** management:
* the **[sfpegData360QueryToolCmp](/help/sfpegData360QueryTool.md)** LWC component enables to run
any SQL query on **Data 360** from a Lightning App page and to explore, filter, inspect, copy or
download its results, with server-side data masking of sensitive values


## Installation

ℹ️ As the **ConnectApi** Apex class induces multiple implicit dependencies requiring **Data Cloud**
specific features on scratch Orgs, it is currently impossible to distribute the content of this
repository as an **unlocked package**.

⚠️ **Data360** should be active on your Org when you deploy this package and applicable
permissions granted to your user.

The following two options are therefore available for package installation:
* **Git** and **SF CLI** Deployment
* **Quick Direct Deploy** button


### **Git** and **SF CLI** Deployment

To retrieve the SFDX project, you may simply execute a git clone from the GitHub repository.
```
git clone git@github.com:pegros/PEG_DC.git
```

Via SFDX you may then deploy it on you Org
```
sfdx force:source:deploy -u <yourOrgAlias> -w 10 --verbose -p force-app
```

### Quick Direct Deploy

For a quick and easy deployment, you may alternatively use the following deploy button
leveraging the **[GitHub Salesforce Deploy Tool](https://github.com/afawcett/githubsfdeploy)**
implemented by [Andrew Fawcett](https://andyinthecloud.com/2013/09/24/deploy-direct-from-github-to-salesforce/).

To deploy only the whole package to your Org, you may use the following button.

<a href="https://githubsfdeploy.herokuapp.com?ref=master">
  <img alt="Deploy Package to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>


## Release Notes

ℹ️ As this repository is not distributed as **unlocked package**, there is no real
package version. This section however summarizes the timeline and contents of the main
evolutions made.

ℹ️ First versions included metadata now moved to the **[PEG_LIST_DC](https://github.com/pegros/PEG_LIST_DC)**
package to remove dependencies with the **[PEG_LIST](https://github.com/pegros/PEG_LIST)** package.

### January 2026 (with PEG_LIST_DC)

First version of the package.
* Transfer of the **[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md)** Apex class
from the **[PEG_LIST](https://github.com/pegros/PEG_LIST)** package to the **PEG_DC** package
for easier deployment
* Addition of the **[sfpegPromptQueries_SVC](/help/sfpegPromptQueries.md)** and 
**[sfpegPrompts_SVC](/help/sfpegPrompts.md)** Apex classes

### February 2026 (with PEG_LIST_DC)

Changes done:
* Added new `ESC_SINGLE(((...)))` rework function in the 
**[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md)** Apex class
to handle cases where single quotes need to be escaped properly in Data Cloud SQL queries (e.g. for Semantic Search).

### October 2026

Changes done:
* Addition of the **[sfpegDataCloudQueriesV3_SVC](/help/sfpegDataCloudQueriesV3.md)** Apex class,
new variant of the **[sfpegDataCloudQueries_SVC](/help/sfpegDataCloudQueries.md)** Apex class
relying on the new **sfsqlquery** Apex framework instead of **ConnectApi.CdpQuery**
(synchronous queries only).
* Addition of the **[sfpegData360QueryToolCmp](/help/sfpegData360QueryTool.md)** standalone
**Data 360** SQL query tool (with its **sfpegData360Query_SVC** Apex controller, data masking rules
and permission sets).
* Move of **[PEG_LIST](https://github.com/pegros/PEG_LIST)** specific metadata from this
**PEG_DC** into this **[PEG_LIST_DC](https://github.com/pegros/PEG_LIST_DC)** repository to
segregate deployment dependencies. 
