/***
* @description  Service class to fetch prompts availab le on an Org
*               via the ConnectAPI for display in a sfpegListCmp.
*               Part of the PEG_LIST package extensions.
* @author       P-E GROS
* @date         Jan 2026
* @see          sfpegListQuery_SVC
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
public with sharing class sfpegPrompts_SVC extends sfpegListQuery_SVC {
    
    /***
    * @description  Override of the standard getdata() method to query existing
    *               Prompts via the ConnectApi.EinsteinLLM class.
    *               Configuration of the SQL query is retrieved from the sfpegList
    *               metadata triggering its execution (via the sfpegList_CTL.CONFIG
    *               static property).
    ***/
    public override List<Object> getData(final Object context, final String queryName) {
        System.debug('getData: START sfpegPrompts_SVC implementation');
        System.debug('getData: context provided ' + context);
        Map<Object,Object> contextMap = (Map<Object,Object>) context;
        if (contextMap == null) contextMap = new Map<Object,Object>();

        String promptQuery = sfpegList_CTL.CONFIG.QuerySOQL__c;
        System.debug('getData: configuration fetched ' + promptQuery);

        List<Object> results;
        try {
            results = queryPrompts(promptQuery,contextMap);
        }
        catch (Exception error) {
            System.debug(LoggingLevel.WARN,'getData: END KO / Prompt query failed: ' + error.getMessage());
            throw new AuraHandledException('Prompt Invocation failure: ' + error.getMessage());
        }
        System.debug('getData: END sfpegPrompts_SVC implementation with #Items ' + results.size());
        return results;
    }


    //#####################################################
    // Private Utility Methods
    //#####################################################

    /***
    * @description  Private utility method to execute a PromptTemplates Query after having merged
    *               the context into a Map context containing its input parameters.
    *               It uses the getPromptTemplates() method of the
    *               ConnectApi.EinsteinLLM class to execute the query.
    ***/
    @TestVisible
    private List<Object> queryPrompts(final String queryConfig,  Map<Object,Object> context) {
        System.debug('queryPrompts: START');

        String mergedQuery = sfpegList_CTL.mergeQuery(queryConfig, context, sfpegList_CTL.CONFIG.BypassEscaping__c);
        System.debug(LoggingLevel.FINE,'queryPrompts: Prompt query merged ' + mergedQuery);

        Map<String,Object> queryParameters = (Map<String,Object>)(JSON.deserializeUntyped(mergedQuery));
        System.debug(LoggingLevel.FINE,'queryPrompts: Prompt query parsed ' + queryParameters);

        String queryQuery =(String) queryParameters.get('query');
        if (String.isBlank(queryQuery)) queryQuery = null;
        System.debug(LoggingLevel.FINE,'queryPrompts: query param init ' + queryQuery);
        String queryType = (String) queryParameters.get('type');
        if (String.isBlank(queryType)) queryType = null;
        System.debug(LoggingLevel.FINE,'queryPrompts: type param init ' + queryType);

        ConnectApi.EinsteinPromptRecordCollectionOutputRepresentation promptTemplateList = (Test.isRunningTest() ? new ConnectApi.EinsteinPromptRecordCollectionOutputRepresentation() : ConnectApi.EinsteinLLM.getPromptTemplates(queryQuery, (String) queryParameters.get('sortBy'), (Integer) queryParameters.get('offset'), (Integer) queryParameters.get('pageLimit'), (List<String>) queryParameters.get('fields'), queryType, (String) queryParameters.get('relatedEntity'), (Boolean) queryParameters.get('isActive')));
        System.debug(LoggingLevel.FINE,'queryPrompts: Prompt query executed ' + promptTemplateList);

        List<Object> results = new List<Object>();
        if (Test.isRunningTest()) {
            System.debug('queryPrompts: handling test query ' + queryQuery);
            if (queryQuery == 'TEST') {
                System.debug('queryPrompts: handling correct test query');
                Map<String,Object> resultItem = new Map<String,Object>();
                resultItem.put('Id','ID001');
                resultItem.put('Name','Name001');
                resultItem.put('Type','Type001');
                resultItem.put('Status','Status001');
                results.add(resultItem);            
                System.debug('queryPrompts: good test result init');
            }
            else {
        		System.debug(LoggingLevel.ERROR,'queryPrompts: END KO / bad test query');
                throw new StringException('Prompt Query should be TEST');
            }
        }
        else if (promptTemplateList != null && promptTemplateList.promptRecords != null) {
            System.debug('queryPrompts: processing #prompt templates: ' + promptTemplateList.promptRecords.size());
            Integer index = 0;
            for (ConnectApi.EinsteinPromptRecordRepresentation iterPrompt : promptTemplateList.promptRecords) {
                System.debug('queryPrompts: processing prompt ' + iterPrompt);
                Map<String,Object> iterPrompMap = new Map<String,Object>{'apiName' => iterPrompt.apiName, 'id' => (iterPrompt.id ?? ('index-' + index)), 'isStandard' => iterPrompt.isStandard};
                /*iterPrompMap.put('apiName',iterPrompt.apiName);
                iterPrompMap.put('id',iterPrompt.id ?? ('index-' + index));
                iterPrompMap.put('isStandard',iterPrompt.isStandard);*/
                for (String iterField : iterPrompt.fields?.keySet()) {
                    iterPrompMap.put(iterField,iterPrompt.fields.get(iterField).value);
                }
                results.add(iterPrompMap);
                index++;
            }
            System.debug('queryPrompts: all prompts extracted');
        }
        else {
            System.debug('queryPrompts: no prompt template found');
        }
        System.debug('queryPrompts: END / returning #results: ' + results?.size());
        return results;
    }
}