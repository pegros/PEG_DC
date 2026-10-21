
/***
* @description  Test class for the sfpegData360Query_SVC class.
*               Part of the PEG_DC package extensions.
*               Uses sfsqlquery.SqlTester to mock Data 360 SQL responses — no live Data Cloud required.
*               Covers: happy path + dynamic columns, the row-cap truncation, blank-query rejection,
 *              the sfpegData360QuerySettings__c cap override, and PII masking (rules, column scope,
*               bypass, invalid-pattern skip, non-string passthrough).
* @author       P-E GROS
* @date         Oct 2026
* @see          sfpegData360Query_SVC
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
@IsTest
private class sfpegData360Query_TST {
    private static final String SAMPLE_SQL =
        'SELECT ssot__ContentText__c AS ContextText FROM ssot__AiAgentInteractionMessage__dlm';

    /** Builds a metadata item with the given name and type. */
    private static ConnectApi.QuerySqlMetadataItem meta(String name, ConnectApi.TypeEnum type) {
        ConnectApi.QuerySqlMetadataItem m = new ConnectApi.QuerySqlMetadataItem();
        m.name = name;
        m.type = type;
        return m;
    }

    /** Builds a mock row from ordered column values. */
    private static ConnectApi.QuerySqlRow row(List<Object> values) {
        ConnectApi.QuerySqlRow r = new ConnectApi.QuerySqlRow();
        r.row = values;
        return r;
    }

    /** Registers a single-column mock with `count` rows of long-text content. */
    private static void mockRows(Integer count) {
        sfsqlquery.SqlTester.clearMocks();
        sfsqlquery.SqlTester.setMockMetadata(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('ContextText', ConnectApi.TypeEnum.VARCHAR) }
        );
        List<ConnectApi.QuerySqlRow> rows = new List<ConnectApi.QuerySqlRow>();
        for (Integer i = 0; i < count; i++) {
            rows.add(row(new List<Object>{ 'message ' + i }));
        }
        sfsqlquery.SqlTester.setMockRows(rows);
    }

    /**
     * Registers a mock with the given columns (name+type) and one row of values, so masking
     * tests can control both the column name and the raw value.
     */
    private static void mockSingleRow(List<ConnectApi.QuerySqlMetadataItem> cols, List<Object> values) {
        sfsqlquery.SqlTester.clearMocks();
        sfsqlquery.SqlTester.setMockMetadata(cols);
        sfsqlquery.SqlTester.setMockRows(new List<ConnectApi.QuerySqlRow>{ row(values) });
    }

    /** Builds an in-memory (no DML) masking rule CMT record. */
    private static sfpegData360QueryMaskingRule__mdt rule(
        String pattern,
        String replacement,
        String columnName,
        Decimal sortOrder
    ) {
        return new sfpegData360QueryMaskingRule__mdt(
            Pattern__c = pattern,
            Replacement__c = replacement,
            ColumnName__c = columnName,
            SortOrder__c = sortOrder,
            Active__c = true
        );
    }

    @IsTest
    static void returnsNormalizedResultWithColumns() {
        mockRows(3);

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,null);
        Test.stopTest();

        Assert.areEqual(1, result.columns.size(), 'one column expected');
        Assert.areEqual('ContextText', result.columns[0].name, 'column name from metadata');
        Assert.areEqual(3, result.rowCount, 'all rows returned');
        Assert.areEqual(3, result.rows.size(), 'row list matches count');
        Assert.isFalse(result.truncated, 'not truncated under the cap');
        Assert.areEqual('message 0', result.rows[0].get('ContextText'), 'value bound by column name');
    }

    @IsTest
    static void truncatesAtConfiguredCap() {
        // Cap at 5 via the custom setting; mock 8 rows -> expect 5 + truncated.
        sfpegData360QuerySettings__c s = sfpegData360QuerySettings__c.getOrgDefaults();
        s.MaxRows__c = 5;
        insert s;
        mockRows(8);

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'');
        Test.stopTest();

        Assert.areEqual(5, result.rowCount, 'stops at the cap');
        Assert.isTrue(result.truncated, 'flagged truncated');
    }

    @IsTest
    static void blankQueryIsRejected() {
        Boolean threw = false;
        Test.startTest();
        try {
            sfpegData360Query_SVC.runQuery('   ','default');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'blank query should throw AuraHandledException');
    }

    @IsTest
    static void defaultCapUsedWhenSettingUnset() {
        Assert.areEqual(
            10000,
            sfpegData360Query_SVC.resolveMaxRows(),
            'falls back to the ceiling when no custom setting row exists'
        );
    }

    @IsTest
    static void settingCannotRaiseCapAboveCeiling() {
        // An admin sets the cap far above the ceiling; it must be clamped to 10000.
        sfpegData360QuerySettings__c s = sfpegData360QuerySettings__c.getOrgDefaults();
        s.MaxRows__c = 50000;
        insert s;

        Assert.areEqual(
            10000,
            sfpegData360Query_SVC.resolveMaxRows(),
            'configured cap above the ceiling is clamped to 10000 (anti-mass-export)'
        );
    }

    @IsTest
    static void settingCanLowerCapBelowCeiling() {
        sfpegData360QuerySettings__c s = sfpegData360QuerySettings__c.getOrgDefaults();
        s.MaxRows__c = 250;
        insert s;

        Assert.areEqual(
            250,
            sfpegData360Query_SVC.resolveMaxRows(),
            'configured cap below the ceiling is honored'
        );
    }

    @IsTest
    static void emptyResultHandledGracefully() {
        // Metadata but zero rows: the controller returns an empty, non-null result (no error).
        // NOTE: sfsqlquery.SqlTester has no mock-exception hook, so the controller's generic
        // catch (Exception) branch (bad SQL / unknown DMO from live Data Cloud) is not unit
        // testable here; the AuraHandledException wrapping itself is covered by
        // blankQueryIsRejected(). This test covers the no-rows path.
        sfsqlquery.SqlTester.clearMocks();
        sfsqlquery.SqlTester.setMockMetadata(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('ContextText', ConnectApi.TypeEnum.VARCHAR) }
        );
        sfsqlquery.SqlTester.setMockRows(new List<ConnectApi.QuerySqlRow>());

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'default');
        Test.stopTest();

        Assert.isNotNull(result, 'result should not be null');
        Assert.areEqual(0, result.rowCount, 'no rows');
        Assert.isFalse(result.truncated, 'not truncated');
        Assert.isNotNull(result.columns, 'columns list is non-null even with no rows');
    }

    @IsTest
    static void maskingAppliedToMatchingValue() {
        // A rule with no column scope masks the IBAN wherever it appears.
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('\\bDE\\d{20}\\b', '[IBAN]', null, 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('Body', ConnectApi.TypeEnum.VARCHAR) },
            new List<Object>{ 'pay to DE89370400440532013000 now' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'');
        Test.stopTest();

        Assert.areEqual('pay to [IBAN] now', result.rows[0].get('Body'), 'IBAN masked');
        Assert.isTrue(result.maskingApplied, 'maskingApplied flag set when rules present');
    }

    @IsTest
    static void columnScopedRuleOnlyMasksNamedColumn() {
        // Rule scoped to "Secret" (case-insensitive) — the same value in "Public" is untouched.
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('\\d{4}', '****', 'secret', 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{
                meta('Secret', ConnectApi.TypeEnum.VARCHAR),
                meta('Public', ConnectApi.TypeEnum.VARCHAR)
            },
            new List<Object>{ 'pin 1234', 'code 5678' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,null);
        Test.stopTest();

        Assert.areEqual('pin ****', result.rows[0].get('Secret'), 'scoped column masked');
        Assert.areEqual('code 5678', result.rows[0].get('Public'), 'other column untouched');
    }

    @IsTest
    static void columnScopeMatchesDespiteWhitespace() {
        // Both sides are trimmed, so a scoped rule still matches a column whose name carries
        // surrounding whitespace (otherwise the targeted PII would leak).
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('\\d{4}', '****', '  Secret  ', 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta(' Secret ', ConnectApi.TypeEnum.VARCHAR) },
            new List<Object>{ 'pin 1234' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'default');
        Test.stopTest();

        Assert.areEqual('pin ****', result.rows[0].get(' Secret '), 'scoped rule matches trimmed name');
    }

    @IsTest
    static void bypassPermissionReturnsRawValues() {
        // A holder of LSI_Bypass_Masking sees raw output; rules are ignored entirely.
        sfpegData360Query_SVC.BYPASS_MASKING = true;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('\\bDE\\d{20}\\b', '[IBAN]', null, 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('Body', ConnectApi.TypeEnum.VARCHAR) },
            new List<Object>{ 'pay to DE89370400440532013000 now' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'');
        Test.stopTest();

        Assert.areEqual(
            'pay to DE89370400440532013000 now',
            result.rows[0].get('Body'),
            'bypass holder sees raw value'
        );
        Assert.isFalse(result.maskingApplied, 'maskingApplied false when bypassing');
    }

    @IsTest
    static void invalidPatternIsSkippedNotFatal() {
        // One rule has an uncompilable regex; it is skipped while a valid rule still applies.
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('[unclosed', 'X', null, 10),
            rule('\\d{4}', '****', null, 20)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('Body', ConnectApi.TypeEnum.VARCHAR) },
            new List<Object>{ 'pin 1234' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,null);
        Test.stopTest();

        Assert.areEqual('pin ****', result.rows[0].get('Body'), 'valid rule still applied');
        Assert.isTrue(result.maskingApplied, 'compiled rule counts as masking applied');
    }

    @IsTest
    static void nonStringPiiIsMaskedNullPassesThrough() {
        // A rule matching a numeric-typed column masks it too (PII in numeric columns must not
        // leak); null always passes through untouched.
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('\\d+', '#', null, 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{
                meta('Amount', ConnectApi.TypeEnum.INTEGER),
                meta('Note', ConnectApi.TypeEnum.VARCHAR)
            },
            new List<Object>{ 4242, null }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'default');
        Test.stopTest();

        Assert.areEqual('#', result.rows[0].get('Amount'), 'numeric PII masked via string form');
        Assert.isNull(result.rows[0].get('Note'), 'null value untouched');
    }

    @IsTest
    static void unmatchedNonStringKeepsItsType() {
        // A non-string value the rule does NOT match keeps its original type (no needless coercion).
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('[A-Z]{3}', 'XXX', null, 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('Amount', ConnectApi.TypeEnum.INTEGER) },
            new List<Object>{ 4242 }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'');
        Test.stopTest();

        Assert.areEqual(4242, result.rows[0].get('Amount'), 'unmatched numeric keeps Integer type');
    }

    @IsTest
    static void noRulesLeavesValuesUnchanged() {
        // No active rules -> passthrough and maskingApplied=false.
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>();
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('Body', ConnectApi.TypeEnum.VARCHAR) },
            new List<Object>{ 'DE89370400440532013000' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,null);
        Test.stopTest();

        Assert.areEqual('DE89370400440532013000', result.rows[0].get('Body'), 'value unchanged');
        Assert.isFalse(result.maskingApplied, 'no rules -> maskingApplied false');
    }

    @IsTest
    static void replacementWithDollarIsTreatedLiterally() {
        // A replacement containing $ / \ must not be interpreted as a regex group reference.
        sfpegData360Query_SVC.BYPASS_MASKING = false;
        sfpegData360Query_SVC.MASKING_RULES = new List<sfpegData360QueryMaskingRule__mdt>{
            rule('\\d{4}', '$0-\\1', null, 10)
        };
        mockSingleRow(
            new List<ConnectApi.QuerySqlMetadataItem>{ meta('Body', ConnectApi.TypeEnum.VARCHAR) },
            new List<Object>{ 'pin 1234' }
        );

        Test.startTest();
        sfpegData360Query_SVC.QueryResult result = sfpegData360Query_SVC.runQuery(SAMPLE_SQL,'default');
        Test.stopTest();

        Assert.areEqual('pin $0-\\1', result.rows[0].get('Body'), 'replacement kept literal');
    }

    @IsTest
    static void getDataSpacesReturnsOptions() {
        Test.startTest();
        List<sfpegData360Query_SVC.DataSpaceOption> options = sfpegData360Query_SVC.getDataSpaces();
        Test.stopTest();

        Assert.isNotNull(options, 'option list should never be null');
        for (sfpegData360Query_SVC.DataSpaceOption iter : options) {
            Assert.isNotNull(iter.label, 'option label set from DataSpace Name');
            Assert.isNotNull(iter.value, 'option value set from DataSpace API name');
        }
    }
}
