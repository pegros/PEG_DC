/***
* @description  Test class for the sfpegDataCloudQueriesV3_SVC class.
*               Part of the PEG_LIST package extensions.
* @author       P-E GROS
* @date         October 2026
* @see          sfpegDataCloudQueriesV3_SVC
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
@IsTest
public class  sfpegDataCloudQueriesV3_TST {

    @testSetup
	static void testSetup() {
		System.debug('testSetup: START');

		String currentUserId = UserInfo.getUserId();
		System.debug('testSetup: currentUserId fetched ' + currentUserId);

		Map<ID,PermissionSet> sfpegPSets = new Map<ID,PermissionSet>([SELECT Name FROM PermissionSet WHERE Name LIKE 'sfpeg%']);
		System.debug('testSetup: sfpegPSets fetched ' + sfpegPSets);

		List<PermissionSetAssignment> currentAssignments = [	select PermissionSetId from PermissionSetAssignment
																where AssigneeId = :currentUserId and PermissionSetId in :sfpegPSets.keySet()];
		System.debug('testSetup: currentAssignments fetched ' + currentAssignments);
		for (PermissionSetAssignment iter : currentAssignments) {
			System.debug('testSetup: removing PermissionSet ' + iter.PermissionSetId);
			sfpegPSets.remove(iter.PermissionSetId);
		}
		System.debug('testSetup: sfpegPSets revised ' + sfpegPSets);

		List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
		for (PermissionSet iter : sfpegPSets.values()) {
			System.debug('testSetup: sfpegPSets processing PSet ' + iter);
			newAssignments.add(new PermissionSetAssignment(AssigneeId = currentUserId, PermissionSetId = iter.Id));
		}
		System.debug('testSetup: newAssignments init ' + newAssignments);

		insert newAssignments;
		System.debug('testSetup: newAssignments inserted ' + newAssignments);

		System.debug('testSetup: END');
	}


	/***
	* @description  Test method for the sfpegDataCloudQueriesV3_SVC class, checking the "getData" method
	*               including all error cases (Data Cloud responses being mocked via sfsqlquery.SqlTester).
	* @see          sfpegDataCloudQueriesV3_SVC
	***/

	@IsTest
	static void testGetData() {
		System.debug('testGetData: ##### START #####');

		Test.startTest();

		// Testing Passing Cases
        Map<Object,Object> inputData = new Map<Object,Object>{'NAME' => 'Test \'1\'', 'PL' => 'P1', 'MPL' => 'MP1'};
		System.debug('testGetData: inputData init ' + inputData);

        System.debug('testGetData: ##### TEST 1 - Correct query #####');
		sfsqlquery.SqlTester.clearMocks();
		sfsqlquery.SqlTester.setMockMetadata(new List<ConnectApi.QuerySqlMetadataItem>{
			initColumn('ssot__Id__c', ConnectApi.TypeEnum.Varchar),
			initColumn('ssot__Name__c', ConnectApi.TypeEnum.Varchar),
			initColumn('Amount__c', ConnectApi.TypeEnum.Numeric)
		});
		sfsqlquery.SqlTester.setMockRows(new List<ConnectApi.QuerySqlRow>{
			initRow(new List<Object>{'ID001', 'Name001', 1000.00}),
			initRow(new List<Object>{'ID002', 'Name002', 2500.50})
		});
		try {
			List<Object> outputList = sfpegList_CTL.getData('sfpegTestDataCloudQueriesV3OK', (Object)inputData);
			System.debug('testGetData: returning outputList ' + outputList);
            Assert.areEqual(2,outputList.size(),'2 records should be returned when query is correct');
			Map<String,Object> firstRow = (Map<String,Object>) outputList[0];
			Assert.areEqual('ID001',firstRow.get('ssot__Id__c'),'Id of first row should be properly mapped');
			Assert.areEqual('Name001',firstRow.get('ssot__Name__c'),'Name of first row should be properly mapped');
			Assert.areEqual(1000.00,(Decimal)firstRow.get('Amount__c'),'Amount of first row should be properly mapped');
		}
		catch (Exception e) {
			System.debug(LoggingLevel.Error,'testGetData: exception raised when query is correct ' + e.getMessage());
			Assert.fail('No exception should be raised when query is correct');
		}

        System.debug('testGetData: ##### TEST 2 - Correct query with no result #####');
		sfsqlquery.SqlTester.clearMocks();
		sfsqlquery.SqlTester.setMockMetadata(new List<ConnectApi.QuerySqlMetadataItem>{
			initColumn('ssot__Id__c', ConnectApi.TypeEnum.Varchar)
		});
		sfsqlquery.SqlTester.setMockRows(new List<ConnectApi.QuerySqlRow>());
		try {
			List<Object> outputList = sfpegList_CTL.getData('sfpegTestDataCloudQueriesV3OK', (Object)inputData);
			System.debug('testGetData: returning outputList ' + outputList);
            Assert.areEqual(0,outputList.size(),'No record should be returned when no data is found');
		}
		catch (Exception e) {
			System.debug(LoggingLevel.Error,'testGetData: exception raised when no data is found ' + e.getMessage());
			Assert.fail('No exception should be raised when no data is found');
		}

        System.debug('testGetData: ##### TEST 3 - Correct query on overridden data space #####');
		Map<Object,Object> inputDataDS = new Map<Object,Object>(inputData);
		inputDataDS.put('d360ds', 'testDataSpace');
		System.debug('testGetData: inputDataDS init ' + inputDataDS);
		sfsqlquery.SqlTester.clearMocks();
		sfsqlquery.SqlTester.setMockMetadata(new List<ConnectApi.QuerySqlMetadataItem>{
			initColumn('ssot__Id__c', ConnectApi.TypeEnum.Varchar)
		});
		sfsqlquery.SqlTester.setMockRows(new List<ConnectApi.QuerySqlRow>{
			initRow(new List<Object>{'ID001'})
		});
		try {
			List<Object> outputList = sfpegList_CTL.getData('sfpegTestDataCloudQueriesV3OK', (Object)inputDataDS);
			System.debug('testGetData: returning outputList ' + outputList);
            Assert.areEqual(1,outputList.size(),'1 record should be returned when query is correct on overridden data space');
		}
		catch (Exception e) {
			System.debug(LoggingLevel.Error,'testGetData: exception raised when data space is overridden ' + e.getMessage());
			Assert.fail('No exception should be raised when data space is overridden');
		}

		// Error cases
        System.debug('testGetData: ##### TEST 4 - Inconsistent query result #####');
		sfsqlquery.SqlTester.clearMocks();
		sfsqlquery.SqlTester.setMockMetadata(new List<ConnectApi.QuerySqlMetadataItem>{
			initColumn('ssot__Id__c', ConnectApi.TypeEnum.Varchar),
			initColumn('ssot__Name__c', ConnectApi.TypeEnum.Varchar)
		});
		sfsqlquery.SqlTester.setMockRows(new List<ConnectApi.QuerySqlRow>{
			initRow(new List<Object>{'ID001'})
		});
		try {
			sfpegList_CTL.getData('sfpegTestDataCloudQueriesV3OK',inputData);
			System.debug(LoggingLevel.Error,'testGetData: no exception raised for inconsistent query result');
			Assert.fail('No exception raised for inconsistent query result');
		}
		catch (AuraHandledException e) {
			System.debug('testGetData: exception properly raised for inconsistent query result ' + e.getMessage());
		}

		Test.stopTest();
		System.debug('testGetData: ##### END #####');
	}

	/***
	* @description  Test method for the escapeSingleQuotes utility method of the
	*               sfpegDataCloudQueriesV3_SVC class (ESC_SINGLE directive).
	* @see          sfpegDataCloudQueriesV3_SVC
	***/

	@IsTest
	static void testEscapeSingleQuotes() {
		System.debug('testEscapeSingleQuotes: ##### START #####');

		Test.startTest();

		Assert.areEqual('SELECT Id__c FROM Test__dlm',
			sfpegDataCloudQueriesV3_SVC.escapeSingleQuotes('SELECT Id__c FROM Test__dlm'),
			'Query without ESC_SINGLE directive should remain unchanged');
		Assert.areEqual('SELECT Id__c FROM Test__dlm WHERE Name__c = \'O\'\'Maley\' AND City__c = \'L\'\'Isle\'',
			sfpegDataCloudQueriesV3_SVC.escapeSingleQuotes('SELECT Id__c FROM Test__dlm WHERE Name__c = \'ESC_SINGLE(((O\\\'Maley)))\' AND City__c = \'ESC_SINGLE(((L\'Isle)))\''),
			'Single quotes (escaped or not) within ESC_SINGLE directives should be doubled');

		Test.stopTest();
		System.debug('testEscapeSingleQuotes: ##### END #####');
	}

	/***
	* @description  Test method for the getDataSpace utility method of the
	*               sfpegDataCloudQueriesV3_SVC class ('d360ds' context override).
	* @see          sfpegDataCloudQueriesV3_SVC
	***/

	@IsTest
	static void testGetDataSpace() {
		System.debug('testGetDataSpace: ##### START #####');

		Test.startTest();

		Assert.areEqual(sfpegDataCloudQueriesV3_SVC.DEFAULT_DATASPACE,
			sfpegDataCloudQueriesV3_SVC.getDataSpace(null),
			'Default data space should be used when no context is provided');
		Assert.areEqual(sfpegDataCloudQueriesV3_SVC.DEFAULT_DATASPACE,
			sfpegDataCloudQueriesV3_SVC.getDataSpace(new Map<Object,Object>{'NAME' => 'Test'}),
			'Default data space should be used when no d360ds context property is provided');
		Assert.areEqual(sfpegDataCloudQueriesV3_SVC.DEFAULT_DATASPACE,
			sfpegDataCloudQueriesV3_SVC.getDataSpace(new Map<Object,Object>{'d360ds' => ' '}),
			'Default data space should be used when d360ds context property is blank');
		Assert.areEqual('testDataSpace',
			sfpegDataCloudQueriesV3_SVC.getDataSpace(new Map<Object,Object>{'d360ds' => 'testDataSpace'}),
			'd360ds context property should override the default data space');

		Test.stopTest();
		System.debug('testGetDataSpace: ##### END #####');
	}

	/***
	* @description  Test method for the getWorkload utility method of the
	*               sfpegDataCloudQueriesV3_SVC class ('d360wl' context override).
	* @see          sfpegDataCloudQueriesV3_SVC
	***/

	@IsTest
	static void testGetWorkload() {
		System.debug('testGetWorkload: ##### START #####');

		Test.startTest();

		Assert.areEqual(sfpegDataCloudQueriesV3_SVC.DEFAULT_WORKLOAD,
			sfpegDataCloudQueriesV3_SVC.getWorkload(null),
			'Default workload should be used when no context is provided');
		Assert.areEqual(sfpegDataCloudQueriesV3_SVC.DEFAULT_WORKLOAD,
			sfpegDataCloudQueriesV3_SVC.getWorkload(new Map<Object,Object>{'NAME' => 'Test'}),
			'Default workload should be used when no d360wl context property is provided');
		Assert.areEqual(sfpegDataCloudQueriesV3_SVC.DEFAULT_WORKLOAD,
			sfpegDataCloudQueriesV3_SVC.getWorkload(new Map<Object,Object>{'d360wl' => ' '}),
			'Default workload should be used when d360wl context property is blank');
		Assert.areEqual('testWorkload',
			sfpegDataCloudQueriesV3_SVC.getWorkload(new Map<Object,Object>{'d360wl' => 'testWorkload'}),
			'd360wl context property should override the default workload');

		Test.stopTest();
		System.debug('testGetWorkload: ##### END #####');
	}


	//#####################################################
	// Private Utility Methods
	//#####################################################

	private static ConnectApi.QuerySqlMetadataItem initColumn(final String name, final ConnectApi.TypeEnum type) {
		ConnectApi.QuerySqlMetadataItem column = new ConnectApi.QuerySqlMetadataItem();
		column.name = name;
		column.type = type;
		return column;
	}

	private static ConnectApi.QuerySqlRow initRow(final List<Object> values) {
		ConnectApi.QuerySqlRow row = new ConnectApi.QuerySqlRow();
		row.row = values;
		return row;
	}
}