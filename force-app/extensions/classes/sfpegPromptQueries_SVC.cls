/***
* @description  Service class to invoke a prompt via the ConnectAPI
*               and return the results (JSON array expected) for 
*               display in a sfpegListCmp.
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
public with sharing class sfpegPromptQueries_SVC extends sfpegListQuery_SVC {
    
    /***
    * @description  Override of the standard getdata() method to execute a Prompt
    *               via the ConnectApi.EinsteinLLM class.
    *               Configuration of the SQL query is retrieved from the sfpegList
    *               metadata triggering its execution (via the sfpegList_CTL.CONFIG
    *               static property).
    ***/
    public override List<Object> getData(final Object context, final String queryName) {
        System.debug('getData: START sfpegPromptQueries_SVC implementation');
        System.debug('getData: context provided ' + context);
        Map<Object,Object> contextMap = (Map<Object,Object>) context;
        if (contextMap == null) contextMap = new Map<Object,Object>();

        String promptRequest = sfpegList_CTL.CONFIG.QuerySOQL__c;
        System.debug('getData: configuration fetched ' + promptRequest);

        List<Object> results;
            results = executePrompt(promptRequest,contextMap);
        /*try {
            results = executePrompt(promptRequest,contextMap);
        }
        catch (Exception error) {
            System.debug(LoggingLevel.WARN,'getData: END KO / Prompt invocation failed: ' + error.getMessage());
            throw new AuraHandledException('Prompt Invocation failure: ' + error.getMessage());
        }*/
        System.debug('getData: END sfpegPromptQueries_SVC implementation with #Items ' + results.size());
        return results;
    }


    //#####################################################
    // Private Utility Methods
    //#####################################################

    /***
    * @description  Private utility method to execute a PromptTemplates after having merged
    *               the context into its input parameters.
    *               It uses the generateMessagesForPromptTemplate() method of the
    *               ConnectApi.EinsteinLLM class to execute the prompt.
    ***/
    @TestVisible
    private List<Object> executePrompt(final String promptRequest,  Map<Object,Object> context) {
        System.debug('executePrompt: START');

        String mergedRequest = sfpegList_CTL.mergeQuery(promptRequest, context, sfpegList_CTL.CONFIG.BypassEscaping__c);
        System.debug('executePrompt: prompt request merged ' + mergedRequest);

        Map<String,Object> requestParameters = (Map<String,Object>)(JSON.deserializeUntyped(mergedRequest));
        System.debug('executePrompt: Prompt request parsed ' + requestParameters);

        String promptDevName = (String) requestParameters.get('promptDevName');
        System.debug('executePrompt: Prompt dev Name extracted ' + promptDevName);
        if (String.isBlank(promptDevName)) throw new AuraHandledException('Missing promptDevName property in configuration');

        Map<String,Object> promptInputMap = (Map<String,Object>)requestParameters.get('promptInput');
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        promptInput.citationMode = (String) promptInputMap.get('citationMode');
        System.debug('executePrompt: citationMode set ' + promptInput.citationMode);
        promptInput.isPreview = (Boolean) promptInputMap.get('isPreview');
        System.debug('executePrompt: isPreview set< ' + promptInput.isPreview);
        promptInput.outputLanguage = (String) promptInputMap.get('outputLanguage');
        System.debug('executePrompt: outputLanguage set ' + promptInput.outputLanguage);
        promptInput.inputParams = new Map<String, ConnectApi.WrappedValue>();
        Map<String,Object> promptInputParamsMap = (Map<String,Object>) promptInputMap.get('inputParams');
        if (promptInputParamsMap != null) {
            System.debug('executePrompt: analysing inputParams ' + promptInputParamsMap);
            for (String iterKey : promptInputParamsMap.keySet()) {
                System.debug('executePrompt: processing key ' + iterKey);
                ConnectApi.WrappedValue iterValue = new ConnectApi.WrappedValue();
                Map<String,String> iterValueMap = new Map<String,String>();
                Map<String,Object> iterPropertyMap = (Map<String,Object>)(promptInputParamsMap.get(iterKey));
                for (String iterProperty : iterPropertyMap.keySet()) {
                    System.debug('executePrompt: processing property ' + iterProperty);
                    iterValueMap.put(iterProperty,(String)(iterPropertyMap.get(iterProperty)));
                }
                System.debug('executePrompt: value reworked ' + iterValueMap);
                iterValue.value = iterValueMap;
                promptInput.inputParams.put(iterKey,iterValue);
            }
            System.debug('executePrompt: inputParams init ' + promptInput.inputParams);
        }
        promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        Map<String,Object> promptAddConfigMap = (Map<String,Object>) promptInputMap.get('additional​Config');
        (promptInput.additionalConfig).applicationName = (String) promptAddConfigMap.get('application​Name');
        System.debug('executePrompt: applicationName init ' + (promptInput.additionalConfig).applicationName);
        //ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = (ConnectApi.EinsteinPromptTemplateGenerationsInput) requestParameters.get('promptInput');
        System.debug('executePrompt: Prompt input extracted ' + promptInput);

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation promptOutput = (Test.isRunningTest() ? new ConnectApi.EinsteinPromptTemplateGenerationsRepresentation() : ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(promptDevName, promptInput));
        System.debug('executePrompt: Prompt executed  returning ' + promptOutput);

        String outputMode = (String) requestParameters.get('outputMode');
        System.debug('executePrompt: outputMode fetched ' + outputMode);

        List<Object> results = new List<Object>();
        if (Test.isRunningTest()) {
            System.debug('executePrompt: handling test prompt ' + promptDevName);
            if (promptDevName == 'PROMPT') {
                System.debug('executePrompt: handling correct test prompt');
                Map<String,Object> resultItem = new Map<String,Object>();
                resultItem.put('Id','ID001');
                resultItem.put('Name','Name001');
                resultItem.put('Type','Type001');
                resultItem.put('Status','Status001');
                results.add(resultItem);            
                System.debug('executePrompt: good test result init');
            }
            else {
        		System.debug(LoggingLevel.ERROR,'executePrompt: END KO / bad test prompt');
                throw new StringException('Prompt should be PROMPT');
            }
        }
        else if (String.isNotBlank(outputMode) && (outputMode == 'JSON')) {
            System.debug('executePrompt: returning JSON list');
            String resultString = promptOutput.generations[0].text.removeStart('```json').removeEnd('```');
            System.debug('executePrompt: resultString extracted ' + resultString);
            results = (List<Object>)JSON.deserializeUntyped(resultString);
            System.debug('executePrompt: JSON results parsed ' + results);
        }
        else {
            System.debug('executePrompt: returning raw results');
            results = (List<Object>) promptOutput.generations;
        }

        System.debug('executePrompt: END with #results ' + results.size());
        return results;        
    }
}