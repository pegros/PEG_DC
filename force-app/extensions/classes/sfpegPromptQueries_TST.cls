/***
* @description  Test class for the sfpegPromptQueries_SVC class.
*               Mirrors the structure and checks used in sfpegDataCloudQueries_TST.
*               Part of the PEG_LIST package extensions.
* @author       P-E GROS
* @date         Jan 2026
* @see          sfpegPromptQueries_SVC
* @see          sfpegDataCloudQueries_TST
* @see          PEG_LIST package (https://github.com/pegros/PEG_LIST)
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
@isTest
public class sfpegPromptQueries_TST {

    @TestSetup
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
	* @description  Test method for the sfpegPromptQueries_SVC class, checking the "getData" method
	*               happy path (delegates to executePrompt) and configuration error behaviors.
	* @see          sfpegPromptQueries_SVC
	***/
	@IsTest
	static void testGetData() {
		System.debug('testGetData: ##### START #####');

        // context used by mergeQuery; keep keys aligned with templates used by sfpegList_CTL
        Map<Object,Object> inputData = new Map<Object,Object>{};

        Test.startTest();

        // Happy path: valid configuration should drive execution without throwing.
        System.debug('testGetData: ##### TEST 1 - Correct prompt execution #####');
        try {
            // Assumes a metadata list like sfpegTestPromptQueriesOK exists in the org/package.
            // Implementation returns List<Object> that may vary (JSON list, ALL, or raw generations).
            List<Object> outputList = sfpegList_CTL.getData('sfpegTestPromptQueriesOK', (Object)inputData);
            System.debug('testGetData: returning outputList ' + outputList);
            Assert.isTrue(true, 'Call should not raise an exception for valid template');
        }
        catch (Exception e) {
            System.debug(LoggingLevel.Error,'testGetData: exception raised when prompt execution is correct ' + e.getMessage());
            Assert.fail('No exception should be raised when configuration is correct');
        }

        // Error case: invalid config should raise exception (missing promptDevName, bad JSON, etc.)
        System.debug('testGetData: ##### TEST 2 - Invalid prompt execution configuration #####');
        try {
            sfpegList_CTL.getData('sfpegTestPromptQueriesKO', inputData);
            System.debug(LoggingLevel.Error,'testGetData: no exception raised for invalid prompt execution template');
            Assert.fail('An exception should be raised for invalid prompt execution template');
        }
        catch (Exception e) {
            System.debug('testGetData: exception properly raised for invalid prompt execution template ' + e.getMessage());
            Assert.isTrue(e.getMessage() != null, 'Exception should carry a message');
        }

        Test.stopTest();
        System.debug('testGetData: ##### END #####');
	}
}
