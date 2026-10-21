/***
* @description  Service class to execute a SQL queries to a connected
*               DataCloud instance via the sfsqlquery framework
*               (synchronous queries only)
*               Part of the PEG_LIST package extensions.
* @author       P-E GROS
* @date         October 2026
* @see          sfpegListQuery_SVC
* @see          sfpegDataCloudQueries_SVC
* @see          PEG_LIST package (https://github.com/pegros/PEG_LIST)
*
* Legal Notice
*
* MIT License
*
* Copyright (c) 2025 pegros
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
***/

@SuppressWarnings('PMD.ClassNamingConventions,PMD.FieldNamingConventions')
public with sharing class sfpegDataCloudQueriesV3_SVC extends sfpegListQuery_SVC {

    //#####################################################
    // Static Configuration
    //#####################################################

    /***
    * @description  Default data space on which SQL queries are executed.
    ***/
    @TestVisible
    private static final String DEFAULT_DATASPACE = 'default';

    /***
    * @description  Context property possibly overriding the default data space.
    ***/
    @TestVisible
    private static final String DATASPACE_KEY = 'd360ds';

    /***
    * @description  Default workload name attached to SQL queries (for Salesforce support debugging).
    ***/
    @TestVisible
    private static final String DEFAULT_WORKLOAD = 'sfpegDataCloudQueriesV3';

    /***
    * @description  Context property possibly overriding the default workload name.
    ***/
    @TestVisible
    private static final String WORKLOAD_KEY = 'd360wl';


    /***
    * @description  Override of the standard getdata() method to execute a SQL query
    *               to Data Cloud via the sfsqlquery framework (synchronously).
    *               Configuration of the SQL query is retrieved from the sfpegList
    *               metadata triggering its execution (via the sfpegList_CTL.CONFIG
    *               static property).
    ***/
    public override List<Object> getData(final Object context, final String queryName) {
        System.debug('getData: START sfpegDataCloudQueriesV3_SVC implementation');
        System.debug('getData: context provided ' + context);
        Map<Object,Object> contextMap = (Map<Object,Object>) context;
        if (contextMap == null) contextMap = new Map<Object,Object>();

        String sqlQuery = sfpegList_CTL.CONFIG.QuerySOQL__c;
        System.debug('getData: configuration fetched ' + sqlQuery);

        List<Object> results;
        try {
            results = executeSQL(sqlQuery,contextMap);
        }
        catch (Exception error) {
            System.debug(LoggingLevel.WARN,'getData: END KO / SQL query failed: ' + error.getMessage());
            throw new AuraHandledException('SQL Query failure: ' + error.getMessage());
        }
        System.debug('getData: END sfpegDataCloudQueriesV3_SVC implementation with #Items ' + results.size());
        return results;
    }


    //#####################################################
    // Private Utility Methods
    //#####################################################

    /***
    * @description  Private utility method to execute a SQL Query after having merged the context
    *               (within the WHERE clauses). It uses the sfsqlquery.SqlStatement class to
    *               execute the query synchronously on Data Cloud and iterates over the
    *               returned sfsqlquery.Row items via the sfsqlquery.SqlRowIterator class.
    ***/
    @TestVisible
    private List<Object> executeSQL(final String queryConfig,  Map<Object,Object> context) {
        System.debug('executeSQL: START');

        String mergedQuery = sfpegList_CTL.mergeQuery(queryConfig, context, sfpegList_CTL.CONFIG.BypassEscaping__c);
        System.debug(LoggingLevel.FINE,'executeSQL: SQL query merged ' + mergedQuery);

        mergedQuery = escapeSingleQuotes(mergedQuery);
        System.debug(LoggingLevel.FINE,'executeSQL: SQL query finalised ' + mergedQuery);

        String dataSpace = getDataSpace(context);
        System.debug(LoggingLevel.FINE,'executeSQL: data space used ' + dataSpace);

        String workload = getWorkload(context);
        System.debug(LoggingLevel.FINE,'executeSQL: workload name used ' + workload);

        sfsqlquery.SqlRowIterator queryIterator = sfsqlquery.SqlStatement.create(mergedQuery, dataSpace)
            .withWorkloadName(workload)
            .execute();
        System.debug(LoggingLevel.FINE,'executeSQL: SQL query executed');

        List<Object> results = new List<Object>();
        List<ConnectApi.QuerySqlMetadataItem> queryMetadata;
        while (queryIterator.hasNext()) {
            sfsqlquery.Row iterRow = queryIterator.next();
            System.debug(LoggingLevel.FINEST,'executeSQL: Processing row ' + iterRow);
            if (queryMetadata == null) {
                // Metadata only available once first page fetched
                queryMetadata = queryIterator.getMetadata();
                System.debug(LoggingLevel.FINEST,'executeSQL: metadata received ' + queryMetadata);
            }

            Map<String,Object> iterResult = new Map<String,Object>();
            for (Integer iterIndex = 0; iterIndex < queryMetadata.size(); iterIndex++) {
                ConnectApi.QuerySqlMetadataItem iterFieldDesc = queryMetadata.get(iterIndex);
                iterResult.put(iterFieldDesc.name, getFieldValue(iterRow, iterIndex, String.valueOf(iterFieldDesc.type)));
            }
            System.debug(LoggingLevel.FINEST,'executeSQL: registering row ' + iterResult);
            results.add(iterResult);
        }
        System.debug('executeSQL: END with #results ' + results.size());
        return results;
    }

    /***
    * @description  Private utility method to determine the data space on which the SQL query
    *               is executed, i.e. the non blank 'd360ds' context property value if any,
    *               the DEFAULT_DATASPACE default value otherwise.
    ***/
    @TestVisible
    private static String getDataSpace(final Map<Object,Object> context) {
        System.debug(LoggingLevel.FINEST,'getDataSpace: START searching property ' + DATASPACE_KEY);
        Object contextDataSpace = (context == null) ? null : context.get(DATASPACE_KEY);
        if ((contextDataSpace != null) && String.isNotBlank(String.valueOf(contextDataSpace))) {
            System.debug(LoggingLevel.FINEST,'getDataSpace: END with context value ' + contextDataSpace);
            return String.valueOf(contextDataSpace);
        }
        System.debug(LoggingLevel.FINEST,'getDataSpace: END with default value');
        return DEFAULT_DATASPACE;
    }

    /***
    * @description  Private utility method to determine the workload name attached to the SQL query,
    *               i.e. the non blank 'd360wl' context property value if any,
    *               the DEFAULT_WORKLOAD default value otherwise.
    ***/
    @TestVisible
    private static String getWorkload(final Map<Object,Object> context) {
        System.debug(LoggingLevel.FINEST,'getWorkload: START searching property ' + WORKLOAD_KEY);
        Object contextWorkload = (context == null) ? null : context.get(WORKLOAD_KEY);
        if ((contextWorkload != null) && String.isNotBlank(String.valueOf(contextWorkload))) {
            System.debug(LoggingLevel.FINEST,'getWorkload: END with context value ' + contextWorkload);
            return String.valueOf(contextWorkload);
        }
        System.debug(LoggingLevel.FINEST,'getWorkload: END with default value');
        return DEFAULT_WORKLOAD;
    }

    /***
    * @description  Private utility method to rework the ESC_SINGLE(((xxx))) directives
    *               within a merged SQL query, i.e. replacing single quotes (escaped or not)
    *               by two single quotes within the xxx value.
    ***/
    @TestVisible
    private static String escapeSingleQuotes(final String mergedQuery) {
        if (!mergedQuery.contains('ESC_SINGLE(((')) {
            System.debug(LoggingLevel.FINEST,'escapeSingleQuotes: No ESC_SINGLE to rework');
            return mergedQuery;
        }

        System.debug(LoggingLevel.FINEST,'escapeSingleQuotes: reworking ESC_SINGLE');
        Pattern quotePattern = Pattern.compile('ESC_SINGLE\\(\\(\\(([\\s\\S]*?)\\)\\)\\)');
        Matcher quoteMatcher = quotePattern.matcher(mergedQuery);
        String targetQuery = mergedQuery;
        while(quoteMatcher.find()) {
            System.debug(LoggingLevel.FINEST,'escapeSingleQuotes: processing match ' + quoteMatcher.group(0));
            System.debug(LoggingLevel.FINEST,'escapeSingleQuotes: with value ' + quoteMatcher.group(1));

            String newMatchValue = (quoteMatcher.group(1)).replaceAll('(\\\\\\\'|\')', '\'\'');
            System.debug(LoggingLevel.FINEST,'escapeSingleQuotes: with value ' + newMatchValue);

            targetQuery = targetQuery.replace(quoteMatcher.group(0), newMatchValue);
            System.debug(LoggingLevel.FINEST,'escapeSingleQuotes: targetQuery merged ' + targetQuery);
        }
        return targetQuery;
    }

    /***
    * @description  Private utility method to extract the value of a field from a sfsqlquery.Row
    *               via the typed getter matching the column type (date & time types being
    *               converted, other types returned as raw values).
    ***/
    @TestVisible
    private static Object getFieldValue(final sfsqlquery.Row row, final Integer index, final String fieldType) {
        switch on (fieldType?.toUpperCase()) {
            when 'DATE' {
                return row.getDate(index);
            }
            when 'TIMESTAMP', 'TIMESTAMPTZ' {
                return row.getDateTime(index);
            }
            when 'TIME' {
                return row.getTime(index);
            }
            when else {
                return row.getObject(index);
            }
        }
    }
}
