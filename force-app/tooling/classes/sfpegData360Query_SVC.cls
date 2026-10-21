/***
* @description  Service class to execute SQL queries to a connected
*               Data360 instance via the sfsqlquery namespace, 
*               returning normalized, grid-friendly results after
*               having applied some data masking (as configured in the
*               sfpegData360QueryMaskingRule__mdt metadata records) and 
*               and row count limitation (as configured in the
*               sfpegData360QuerySettings__c custom setting).
*               Part of the PEG_DC package extensions.
* @author       P-E GROS
* @date         Oct. 2026
* @see          sfpegData360Query_TST
* @see          sfpegData360QuerySettings__c
* @see          sfpegData360QueryMaskingRule__mdt
* @see          PEG_DC package (https://github.com/pegros/PEG_DC)
*
* Legal Notice
*
* MIT License
*
* Copyright (c) 2026 pegros
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
public with sharing class sfpegData360Query_SVC {
    
    /***
    * @description  Default row returned by each query, used also as default 
    *               if none set in the sfpegData360QuerySettings__c custom setting 
    *               (MaxRows__c field).
    ***/
    @TestVisible
    private static final Integer MAX_ROWS = 10000;

    /***
    * @description  Default dataspace to run the query if none provided when executing the query.
    ***/
    @TestVisible
    private static final String DEFAULT_DATASPACE = 'default';

    /***
    * @description  Custom permission enabling the calling user to bypass the data masking step.
    ***/
    @TestVisible
    private static final String BYPASS_MASKING_PERM = 'sfpegData360QueryBypassMasking';

    /***
    * @description  List of data masking rules to apply (if not bypassed), managed
    *               as a static variable to override rules for unit test purposes.
    ***/
    @TestVisible
    //private static List<sfpegData360QueryMaskingRule__mdt> rulesOverride;
    private static List<sfpegData360QueryMaskingRule__mdt> MASKING_RULES = [
        SELECT Pattern__c, Replacement__c, ColumnName__c, SortOrder__c
        FROM sfpegData360QueryMaskingRule__mdt
        WHERE Active__c = true
        WITH SYSTEM_MODE
        ORDER BY SortOrder__c ASC NULLS LAST, DeveloperName ASC
    ];

    /***
    * @description  Assignment status of the BYPASS_MASKING_PERM permission to the 
    *               current user, managed as a static variable to override assignment
    *               for unit test purposes.
    ***/
    @TestVisible
    //private static Boolean bypassMaskingOverride = FeatureManagement.checkPermission(BYPASS_MASKING_PERM);
    private static Boolean BYPASS_MASKING = FeatureManagement.checkPermission(BYPASS_MASKING_PERM);

    /**
     * Runs a Data 360 SQL query and returns the normalized result.
     * @param sql the ANSI SQL query pasted by the user (CTEs / JOIN / UNION ALL supported)
     * @return QueryResult with columns, rows, rowCount and truncated flag
     */
    @AuraEnabled(cacheable=false)
    public static QueryResult runQuery(String sql, String dataSpace) {
        System.debug('runQuery: START with query ' + sql);
        System.debug('runQuery: in dataspace ' + dataSpace);

        if (String.isBlank(sql)) {
            System.debug(LoggingLevel.WARN,'runQuery: END KO / Query is empty!');
            throw makeException('Query is empty. Paste a Data 360 SQL query and try again.');
        }

        Integer maxRows = resolveMaxRows();
        System.debug(LoggingLevel.FINE,'runQuery: maxRows resolved to ' + maxRows);

        string queryDataSpace = String.isBlank(dataSpace) ? DEFAULT_DATASPACE : dataSpace;
        System.debug(LoggingLevel.FINE,'runQuery: queryDataSpace resolved to ' + queryDataSpace);

        QueryResult result = new QueryResult();

        // Compile masking rules once per query (outside the row loop). Empty when the caller
        // may bypass masking or no active rules exist.
        List<MaskingRule> maskingRules = resolveMaskingRules();
        System.debug(LoggingLevel.FINE,'runQuery: maskingRules resolved to ' + maskingRules);

        result.maskingApplied = !maskingRules.isEmpty();
        System.debug(LoggingLevel.FINE,'runQuery: maskingApplied resolved to ' + result.maskingApplied);

        try {
            sfsqlquery.SqlRowIterator it =
                sfsqlquery.SqlStatement.create(sql, queryDataSpace).withWorkloadName('sfpegData360Query').execute();

            result.columns = buildColumns(it);
            System.debug(LoggingLevel.FINE,'runQuery: columns resolved to ' + result.columns);

            List<String> colNames = it.getColumnNames();
            while (it.hasNext()) {
                if (result.rowCount >= maxRows) {
                    System.debug('runQuery: max rows reached' + maxRows);
                    result.truncated = true;
                    break;
                }
                sfsqlquery.Row row = it.next();
                Map<String, Object> rowMap = new Map<String, Object>();
                for (String col : colNames) {
                    // getObject returns the raw typed value; safe for any column type and
                    // serializes cleanly for the grid + field inspector.
                    rowMap.put(col, maskValue(col, row.getObject(col), maskingRules));
                }
                result.rows.add(rowMap);
                result.rowCount++;
            }
        } catch (AuraHandledException e) {
            System.debug(LoggingLevel.WARN,'runQuery: END KO / Aura exception raised ' + e.getMessage());
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,'runQuery: END KO / Other exception raised ' + e.getMessage());
            // Surface Data Cloud query errors (bad SQL, unknown DMO, etc.) cleanly to the UI.
            throw makeException(e.getTypeName() + ': ' + e.getMessage());
        }

        return result;
    }

    /**
     * Fetches the list of active DataSpaces available on the Org.
     * @return list of DataSpace options (label = Name, value = DataSpaceApiName)
     */
    @AuraEnabled(cacheable=true)
    public static List<DataSpaceOption> getDataSpaces() {
        System.debug('getDataSpaces: START');

        List<DataSpaceOption> options = new List<DataSpaceOption>();
        for (DataSpace iter : [
            SELECT Id, Name, DataSpaceApiName
            FROM DataSpace
            WHERE Status = 'ACTIVE'
            ORDER BY Name ASC
        ]) {
            DataSpaceOption opt = new DataSpaceOption();
            opt.label = iter.Name;
            opt.value = iter.DataSpaceApiName;
            options.add(opt);
        }

        System.debug('getDataSpaces: END with #dataSpaces ' + options.size());
        return options;
    }

    //-------------------------------------------------------------------------
    // UTILITIES
    //-------------------------------------------------------------------------

    /***
    * @description  Utility method to evaluate the effective row cap: 
    *               the custom setting may lower it, but it is always clamped to
    *               MAX_ROWS so no configuration can turn this into a mass-export tool.
    ***/
    @TestVisible
    private static Integer resolveMaxRows() {
        sfpegData360QuerySettings__c settings = sfpegData360QuerySettings__c.getInstance();
        if (settings != null && settings.MaxRows__c != null && settings.MaxRows__c > 0) {
            return Math.min(Integer.valueOf(settings.MaxRows__c), MAX_ROWS);
        }
        return MAX_ROWS;
    }

    /***
    * @description  Utility method to resolves the active masking rules to apply for the current caller.
    *               Returns an empty list when the caller may bypass masking (LSI_Bypass_Masking custom
    *               permission) — trusted users see raw output. Otherwise compiles active
    *               sfpegData360QueryMaskingRule__mdt records, sorted by Sort_Order__c (nulls last), skipping any rule
    *               whose Pattern__c fails to compile.
    ***/
    private static List<MaskingRule> resolveMaskingRules() {
        system.debug(LoggingLevel.FINE,'resolveMaskingRules: START');
        /*
        if (canBypassMasking()) {
            return new List<MaskingRule>();
        }
        */
        if (BYPASS_MASKING) {
            system.debug(LoggingLevel.FINE,'resolveMaskingRules: END / rules bypassed');
            return new List<MaskingRule>();
        }

        /*
        List<sfpegData360QueryMaskingRule__mdt> records = (rulesOverride != null)
            ? rulesOverride
            : [
                SELECT Pattern__c, Replacement__c, Column_Name__c, Sort_Order__c
                FROM sfpegData360QueryMaskingRule__mdt
                WHERE Active__c = true
                ORDER BY Sort_Order__c ASC NULLS LAST, DeveloperName ASC
            ];
        */

        List<MaskingRule> compiled = new List<MaskingRule>();
        //for (sfpegData360QueryMaskingRule__mdt rec : records) {
        for (sfpegData360QueryMaskingRule__mdt iter : MASKING_RULES) {
            system.debug(LoggingLevel.FINE,'resolveMaskingRules: processing rule ' + iter);
            addCompiledRule(compiled, iter.Pattern__c, iter.Replacement__c, iter.ColumnName__c);
        }

        system.debug(LoggingLevel.FINE,'resolveMaskingRules: END with #rules compiled ' + compiled.size());
        return compiled;
    }

    /***
    * @description  Utility method to Compile one masking rule and appends it to the target.
    *               An invalid regex is skipped (logged), never fatal.
    ***/
    private static void addCompiledRule(
        List<MaskingRule> target,
        String patternStr,
        String replacement,
        String columnName
    ) {
        system.debug(LoggingLevel.FINE,'addCompiledRule: START for pattern ' + patternStr);

        if (String.isBlank(patternStr)) {
            system.debug(LoggingLevel.FINE,'addCompiledRule: END OK / ignoring blank pattern');
            return;
        }
        try {
            MaskingRule mr = new MaskingRule();
            mr.compiled = Pattern.compile(patternStr);
            // Precompute the literal-safe replacement once (escaping depends only on the rule):
            // escape \ then $ so regex group refs / back-refs in the mask text aren't honored.
            String replacementStr = (replacement == null) ? '' : replacement;
            mr.safeReplacement = replacementStr.replace('\\', '\\\\').replace('$', '\\$');
            // Precompute a lowercased+trimmed column filter for case-insensitive exact matching.
            mr.columnKey = String.isBlank(columnName) ? null : columnName.trim().toLowerCase();
            system.debug(LoggingLevel.FINE,'addCompiledRule: END OK / adding compiled pattern');
            target.add(mr);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,'addCompiledRule: END KO / pattern compilation error for "' + patternStr + '": ' + e.getMessage());
        }
    }

    /** True when the running user holds the bypass custom permission (test-overridable). */
    /*private static Boolean canBypassMasking() {
        if (bypassMaskingOverride != null) {
            return bypassMaskingOverride;
        }
        return FeatureManagement.checkPermission(BYPASS_MASKING_PERM);
    }*/

    /***
    * @description  Utility method to build column descriptors from the iterator's metadata
    *               (name + Data Cloud type).
    ***/
    private static List<Column> buildColumns(sfsqlquery.SqlRowIterator it) {
        List<Column> cols = new List<Column>();
        List<String> names = it.getColumnNames();
        List<ConnectApi.QuerySqlMetadataItem> meta = it.getMetadata();
        for (Integer i = 0; i < names.size(); i++) {
            Column c = new Column();
            c.name = names[i];
            c.type = (meta != null && i < meta.size() && meta[i].type != null)
                ? String.valueOf(meta[i].type)
                : 'Varchar';
            cols.add(c);
        }
        return cols;
    }

    /***
    * @description  Utility method to Apply the compiled rules to a single value. Rules match against the value's string form,
    *               so PII in numeric / date / other non-string typed columns is masked too (fail-safe for a
    *               PII control). null passes through untouched. A rule with a column filter applies only to the
    *               matching column (case-insensitive exact name, trimmed on both sides). The original typed
    *               value is preserved when no rule actually changes the text — only a masked value is coerced
    *               to String.
    ***/
    private static Object maskValue(String column, Object value, List<MaskingRule> rules) {
        if (rules == null || rules.isEmpty() || value == null) {
            return value;
        }
        String original = String.valueOf(value);
        String text = original;
        String colKey = (column == null) ? null : column.trim().toLowerCase();
        for (MaskingRule r : rules) {
            if (r.columnKey != null && r.columnKey != colKey) {
                continue;
            }
            text = r.compiled.matcher(text).replaceAll(r.safeReplacement);
        }
        // Untouched: hand back the original typed value so the grid keeps type/null fidelity.
        return (text == original) ? value : (Object) text;
    }

    /***
    * @description  Utility method to format any exception as a readable Aura exception.
    ***/
    private static AuraHandledException makeException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    //-------------------------------------------------------------------------
    // SUB-CLASSES
    //-------------------------------------------------------------------------

    /***
    * @description  Normalized query result the LWC binds to.
    ***/
    public class QueryResult {
        @AuraEnabled public List<Column> columns = new List<Column>();
        @AuraEnabled public List<Map<String, Object>> rows = new List<Map<String, Object>>();
        @AuraEnabled public Integer rowCount = 0;
        @AuraEnabled public Boolean truncated = false;
        // True when one or more masking rules were applied to this result (drives a UI badge).
        @AuraEnabled public Boolean maskingApplied = false;
    }

    /***
    * @description  One result column: name + Data Cloud data type (drives dynamic datatable columns).
    ***/
    public class Column {
        @AuraEnabled public String name;
        @AuraEnabled public String type;
    }

    /***
    * @description  One DataSpace option (label + API name) for the LWC DataSpace selector.
    ***/
    public class DataSpaceOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    /***
    * @description  One compiled masking rule: regex + literal-safe replacement + optional column scope.
    ***/
    private class MaskingRule {
        Pattern compiled;
        String safeReplacement; // $/\ pre-escaped so the mask text is treated literally
        String columnKey;       // lowercased+trimmed column name, or null for "all columns"
    }
}
