/***
* @author P-E GROS
* @date   Oct 2026
* @description  LWC Component providing access to the SFPEG Data360 Query Tool features.
* @see PEG_DC package (https://github.com/pegros/PEG_DC)
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

import { LightningElement, wire , api} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningPrompt from 'lightning/prompt';
import LightningConfirm from 'lightning/confirm';
import runQuery from '@salesforce/apex/sfpegData360Query_SVC.runQuery';
import getDataSpaces from '@salesforce/apex/sfpegData360Query_SVC.getDataSpaces';

// Custom labels (default values of the configurable texts)
import LABEL_QUERY_CARD_TITLE from '@salesforce/label/c.sfpegData360QueryCardTitle';
import LABEL_QUERY_CARD_LABEL from '@salesforce/label/c.sfpegData360QueryCardLabel';
import LABEL_QUERY_BUTTON_LABEL from '@salesforce/label/c.sfpegData360QueryRunButtonLabel';
import LABEL_QUERY_BUTTON_TITLE from '@salesforce/label/c.sfpegData360QueryRunButtonTitle';
import LABEL_RESULT_CARD_LABEL from '@salesforce/label/c.sfpegData360QueryResultCardLabel';
import LABEL_EXPORT_BUTTON_TITLE from '@salesforce/label/c.sfpegData360QueryExportButtonTitle';
import LABEL_COPY_BUTTON_TITLE from '@salesforce/label/c.sfpegData360QueryCopyButtonTitle';
import LABEL_FORMAT_BUTTON_TITLE from '@salesforce/label/c.sfpegData360QueryFormatButtonTitle';
import LABEL_SEARCH_PLACEHOLDER from '@salesforce/label/c.sfpegData360QuerySearchPlaceholder';
import LABEL_SAVED_QUERY_LABEL from '@salesforce/label/c.sfpegData360QuerySavedQueryLabel';
import LABEL_SAVE_QUERY_TITLE from '@salesforce/label/c.sfpegData360QuerySaveQueryTitle';
import LABEL_DELETE_QUERY_TITLE from '@salesforce/label/c.sfpegData360QueryDeleteQueryTitle';
import LABEL_DOWNLOAD_QUERIES_TITLE from '@salesforce/label/c.sfpegData360QueryDownloadQueriesTitle';
import LABEL_UPLOAD_QUERIES_TITLE from '@salesforce/label/c.sfpegData360QueryUploadQueriesTitle';
import LABEL_CLEAR_QUERIES_TITLE from '@salesforce/label/c.sfpegData360QueryClearQueriesTitle';

// Synthetic row key (Data360 query results have no guaranteed unique column)
const ROW_KEY = '_sfpegRowKey';
// DataSpace selected by default (same default as in the Apex controller)
const DEFAULT_DATASPACE = 'default';
// Number of result rows added to the datatable at each scroll to the bottom
const PAGE_SIZE = 100;
// Delay (in ms) before applying the local filter after the last search string change
const SEARCH_DELAY = 300;
// Base file name of the result export (extension set by the selected format)
const EXPORT_FILE_NAME = 'results';
// Formats available for the result copy / export
const FORMATS = {
    json: {label: 'JSON', shortLabel: 'JSON', extension: '.json'},
    csv: {label: 'CSV', shortLabel: 'CSV', separator: ',', extension: '.csv'},
    tsv: {label: 'Tab separated text', shortLabel: 'TSV', separator: '\t', extension: '.tsv'}
};
const DEFAULT_FORMAT = 'csv';
// Browser local storage key of the saved queries (list of {name, dataSpace, sql})
const SAVED_QUERIES_KEY = 'sfpegData360QueryTool.savedQueries';
// File name of the saved queries download
const SAVED_QUERIES_FILE_NAME = 'savedQueries.json';
// Data360 column types displayed as numbers in the datatable (others as text)
const NUMBER_TYPES = ['BIGINT','DECIMAL','DOUBLE','FLOAT','FLOAT4','FLOAT8','INTEGER','NUMBER','NUMERIC','REAL','SMALLINT','TINYINT'];
// Data360 column types displayed as dates / datetimes in the datatable
const DATE_TYPES = ['DATE'];
const DATETIME_TYPES = ['TIMESTAMP','TIMESTAMPTZ'];


export default class SfpegData360QueryToolCmp extends LightningElement {

    //################################################################
    // Component Properties
    //################################################################

    //----------------------------------------------------------------
    // Main configuration fields (for App Builder)
    //----------------------------------------------------------------
    @api wrapperClass;          // CSS Classes for the wrapping div
    @api queryCardTitle = LABEL_QUERY_CARD_TITLE;  // Title of the SQL query card
    @api queryCardLabel = LABEL_QUERY_CARD_LABEL;  // Label of the SQL query card
    @api queryButtonLabel = LABEL_QUERY_BUTTON_LABEL;  // Label of the query run button
    @api queryButtonTitle = LABEL_QUERY_BUTTON_TITLE;  // Title of the query run button
    @api resultCardLabel = LABEL_RESULT_CARD_LABEL;  // Label of the query results card
    @api exportButtontitle = LABEL_EXPORT_BUTTON_TITLE;  // Title prefix of the download button (followed by the selected format)
    @api copyButtonTitle = LABEL_COPY_BUTTON_TITLE;  // Title prefix of the copy to clipboard button (followed by the selected format)
    @api formatButtonTitle = LABEL_FORMAT_BUTTON_TITLE;  // Title of the copy / download format selector
    @api searchPlaceholder = LABEL_SEARCH_PLACEHOLDER;  // Placeholder of the local result filter input
    @api savedQueryLabel = LABEL_SAVED_QUERY_LABEL;  // Label of the saved query selector
    @api saveQueryTitle = LABEL_SAVE_QUERY_TITLE;  // Title of the save query button
    @api deleteQueryTitle = LABEL_DELETE_QUERY_TITLE;  // Title of the delete saved query button
    @api downloadQueriesTitle = LABEL_DOWNLOAD_QUERIES_TITLE;  // Title of the saved queries download button
    @api uploadQueriesTitle = LABEL_UPLOAD_QUERIES_TITLE;  // Title of the saved queries upload button
    @api clearQueriesTitle = LABEL_CLEAR_QUERIES_TITLE;  // Title of the clear all saved queries button
    @api isDebug = false;   // Merge Debug mode activation

    //----------------------------------------------------------------
    // Internal Properties
    //----------------------------------------------------------------
    isCollapsed = false;    // expand status of the query form
    sqlQuery;               // SQL query input
    dataSpace = DEFAULT_DATASPACE;  // DataSpace selected
    dataSpaceOptions = [];  // DataSpaces available on the Org
    isRunning = false;      // query execution in progress
    hasResults = false;
    rowCount = 0;
    isTruncated = false;
    truncatedWarning = 'Results were truncated to the maximum number of rows allowed!';
    isMaskingApplied = false;
    maskingAppliedWarning = 'One or more masking rules were applied to these results!';
    hasError = false;
    errorMessage;

    keyField = ROW_KEY;
    sortedBy;               // field currently sorted in the datatable
    sortedDirection;        // current sort direction ('asc' or 'desc')
    resultList = [];        // full (sorted) result list
    filteredList = [];      // subset of resultList matching the search string (resultList itself if none)
    displayedList = [];     // subset of filteredList displayed in the datatable (infinite scrolling)
    hasMoreRows = false;    // more rows of filteredList remain to be displayed
    searchString = '';      // local filter applied on all fields of the result rows
    searchTimeout;          // pending (debounced) filter application
    isFiltered = false;     // search filter currently applied on the result list
    tableInstances = [{key: 0}];    // single datatable instance, key changed to re-create it (scroll reset)
    resultColumns = [];
    columnWidths;           // current widths of the result columns (kept when column definitions are updated)
    inspectedCell;          // last clicked result cell ({label, value}) displayed in the inspection tile
    inspectDrag;            // ongoing horizontal drag of the inspection tile ({startX, startOffset, maxOffset})
    inspectLayout;          // last user defined layout of the inspection tile ({width, height, offset}), restored at reopening
    inspectObserver;        // observer of the inspection tile size (to fit its value area in it)
    observedBox;            // inspection tile element currently observed
    outputFormat = DEFAULT_FORMAT;  // format applied to copy / download operations
    savedQueries = [];      // queries saved in the browser local storage (sorted by name)
    selectedQueryName;      // name of the saved query last selected / saved

    //----------------------------------------------------------------
    // Custom Getters
    //----------------------------------------------------------------
    get resultCardTitle() {
        const totalCount = this.rowCount + (this.isTruncated ? '+' : '');
        return this.resultCardLabel + ' ('
            + (this.isFiltered ? this.filteredList.length + ' / ' + totalCount : totalCount) + ')';
    }
    get inspectedContent() {
        return this.formatInspectedValue(this.inspectedCell?.value);
    }
    get expandCollapseIcon() {
        return this.isCollapsed ? 'utility:expand_all' : 'utility:collapse_all';
    }

    get savedQueryOptions() {
        return this.savedQueries.map(item => ({label: item.name, value: item.name}));
    }
    get isSaveDisabled() {
        return !this.sqlQuery?.trim();
    }
    get isDownloadQueriesDisabled() {
        return this.savedQueries.length === 0;
    }
    get isDeleteDisabled() {
        return !this.selectedQueryName;
    }

    get formatOptions() {
        return Object.keys(FORMATS).map(key => ({value: key, label: FORMATS[key].label, checked: key === this.outputFormat}));
    }
    get formatLabel() {
        return FORMATS[this.outputFormat].shortLabel;
    }
    get exportTitle() {
        return this.exportButtontitle + ' ' + FORMATS[this.outputFormat].label;
    }
    get copyTitle() {
        return this.copyButtonTitle + ' ' + FORMATS[this.outputFormat].label;
    }

    //----------------------------------------------------------------
    // Component Lifecycle 
    //----------------------------------------------------------------

    connectedCallback() {
        if (this.isDebug) console.log('connected: START for QueryTool');
        //this.isDebug = true;
        this.savedQueries = this.loadSavedQueries();
        if (this.isDebug) console.log('connected: END for QueryTool');
    }

    // Last user defined layout re-applied to the inspection tile when (re)displayed
    // and (re)displayed tile observed to fit its value area to any size change
    renderedCallback() {
        const boxElement = this.refs?.inspectBox;
        if (!boxElement) return;
        if (this.inspectLayout && !boxElement.classList.contains('inspectBoxResized')) {
            this.applyInspectLayout(boxElement);
        }
        if (boxElement !== this.observedBox) {
            this.inspectObserver = this.inspectObserver || new ResizeObserver(() => this.fitInspectedValue());
            this.inspectObserver.disconnect();
            this.inspectObserver.observe(boxElement);
            this.observedBox = boxElement;
        }
    }

    disconnectedCallback() {
        clearTimeout(this.searchTimeout);
        this.inspectObserver?.disconnect();
        this.observedBox = null;
    }

    //----------------------------------------------------------------
    // Data Fetch
    //----------------------------------------------------------------
    @wire(getDataSpaces)
    wiredDataSpaces({ error, data }) {
        if (this.isDebug) console.log('wiredDataSpaces: START');
        if (data) {
            this.dataSpaceOptions = data;
            // Fallback to first available DataSpace if the selected one does not exist on the Org
            if ((data.length > 0) && !data.some(item => item.value === this.dataSpace)) {
                this.dataSpace = data[0].value;
            }
            if (this.isDebug) console.log('wiredDataSpaces: END OK with dataSpaces ',JSON.stringify(data));
        }
        else if (error) {
            console.warn('wiredDataSpaces: END KO with error ',JSON.stringify(error));
            this.dataSpaceOptions = [];
            this.hasError = true;
            this.errorMessage = 'DataSpace list fetch failed: ' + (error?.body?.message || JSON.stringify(error));
        }
    }

    //----------------------------------------------------------------
    // Event Handlers
    //----------------------------------------------------------------
    handleExpandCollapse(event) {
        if (this.isDebug) console.log('handleExpandCollapse: START with isCollapsed ',this.isCollapsed);
        this.isCollapsed = !this.isCollapsed;
        if (this.isDebug) console.log('handleExpandCollapse END with isCollapsed ',this.isCollapsed);
    }

    handleSqlChange(event) {
        this.sqlQuery = event.detail.value;
        // Saved query deselected as soon as the SQL no longer matches it
        if (this.selectedQueryName) {
            if (this.isDebug) console.log('handleSqlChange: deselecting saved query ',this.selectedQueryName);
            this.selectedQueryName = null;
        }
    }

    handleDataSpaceChange(event) {
        this.dataSpace = event.detail.value;
    }

    handleSavedQuerySelect(event) {
        if (this.isDebug) console.log('handleSavedQuerySelect: START with query ',event.detail.value);
        const savedQuery = this.savedQueries.find(item => item.name === event.detail.value);
        if (!savedQuery) return;
        this.selectedQueryName = savedQuery.name;
        this.sqlQuery = savedQuery.sql;
        this.dataSpace = savedQuery.dataSpace;
        if (this.isDebug) console.log('handleSavedQuerySelect: END with dataSpace ',this.dataSpace);
    }

    async handleSaveQueryClick(event) {
        if (this.isDebug) console.log('handleSaveQueryClick: START with current query ',this.selectedQueryName);
        const queryName = (await LightningPrompt.open({
            label: this.saveQueryTitle,
            message: 'Name of the query to save (with its DataSpace)',
            defaultValue: this.selectedQueryName || ''
        }))?.trim();
        if (!queryName) {
            if (this.isDebug) console.log('handleSaveQueryClick: END / save cancelled');
            return;
        }
        const existingIndex = this.savedQueries.findIndex(item => item.name === queryName);
        if ((existingIndex >= 0) && (queryName !== this.selectedQueryName)) {
            const doOverwrite = await LightningConfirm.open({
                label: this.saveQueryTitle,
                message: 'A query named "' + queryName + '" already exists. Overwrite it?',
                theme: 'warning'
            });
            if (!doOverwrite) {
                if (this.isDebug) console.log('handleSaveQueryClick: END / overwrite cancelled');
                return;
            }
        }
        const newQueries = this.savedQueries.filter(item => item.name !== queryName);
        newQueries.push({name: queryName, dataSpace: this.dataSpace, sql: this.sqlQuery});
        newQueries.sort((a, b) => a.name.localeCompare(b.name));
        if (this.storeSavedQueries(newQueries)) {
            this.selectedQueryName = queryName;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Query saved',
                message: 'Query "' + queryName + '" saved in the browser.',
                variant: 'success'
            }));
        }
        if (this.isDebug) console.log('handleSaveQueryClick: END with #queries ',this.savedQueries.length);
    }

    async handleDeleteQueryClick(event) {
        if (this.isDebug) console.log('handleDeleteQueryClick: START with query ',this.selectedQueryName);
        const queryName = this.selectedQueryName;
        const doDelete = await LightningConfirm.open({
            label: this.deleteQueryTitle,
            message: 'Delete the saved query "' + queryName + '"?',
            theme: 'warning'
        });
        if (!doDelete) {
            if (this.isDebug) console.log('handleDeleteQueryClick: END / deletion cancelled');
            return;
        }
        if (this.storeSavedQueries(this.savedQueries.filter(item => item.name !== queryName))) {
            this.selectedQueryName = null;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Query deleted',
                message: 'Saved query "' + queryName + '" deleted.',
                variant: 'success'
            }));
        }
        if (this.isDebug) console.log('handleDeleteQueryClick: END with #queries ',this.savedQueries.length);
    }

    async handleClearQueriesClick(event) {
        if (this.isDebug) console.log('handleClearQueriesClick: START with #queries ',this.savedQueries.length);
        const queryCount = this.savedQueries.length;
        const doClear = await LightningConfirm.open({
            label: this.clearQueriesTitle,
            message: 'Delete all ' + queryCount + ' saved queries from the browser?',
            theme: 'warning'
        });
        if (!doClear) {
            if (this.isDebug) console.log('handleClearQueriesClick: END / clearing cancelled');
            return;
        }
        if (this.storeSavedQueries([])) {
            this.selectedQueryName = null;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved queries cleared',
                message: queryCount + ' saved queries deleted.',
                variant: 'success'
            }));
        }
        if (this.isDebug) console.log('handleClearQueriesClick: END with #queries ',this.savedQueries.length);
    }

    handleDownloadQueriesClick(event) {
        if (this.isDebug) console.log('handleDownloadQueriesClick: START with #queries ',this.savedQueries.length);
        try {
            this.downloadFile(JSON.stringify(this.savedQueries, null, 2), SAVED_QUERIES_FILE_NAME);
            if (this.isDebug) console.log('handleDownloadQueriesClick: END OK');
        }
        catch (error) {
            console.warn('handleDownloadQueriesClick: END KO with error ',error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved queries download failed',
                message: error?.message || JSON.stringify(error),
                variant: 'error'
            }));
        }
    }

    handleUploadQueriesClick(event) {
        if (this.isDebug) console.log('handleUploadQueriesClick: START');
        this.refs.queriesFileInput.click();
    }

    // Upserts (by name) the saved queries of the selected JSON file, invalid entries being ignored
    async handleQueriesFileChange(event) {
        const file = event.target.files?.[0];
        if (this.isDebug) console.log('handleQueriesFileChange: START with file ',file?.name);
        if (!file) return;
        try {
            const uploadedQueries = JSON.parse(await file.text());
            if (!Array.isArray(uploadedQueries)) throw new Error('JSON content should be a list of queries.');
            const validQueries = uploadedQueries.filter(item =>
                (typeof item?.name === 'string') && item.name.trim() && (typeof item.sql === 'string'));
            const queryMap = new Map(this.savedQueries.map(item => [item.name, item]));
            let updateCount = 0;
            validQueries.forEach(item => {
                const name = item.name.trim();
                if (queryMap.has(name)) updateCount++;
                queryMap.set(name, {
                    name,
                    dataSpace: (typeof item.dataSpace === 'string' && item.dataSpace) ? item.dataSpace : DEFAULT_DATASPACE,
                    sql: item.sql
                });
            });
            const newQueries = [...queryMap.values()].sort((a, b) => a.name.localeCompare(b.name));
            if (this.storeSavedQueries(newQueries)) {
                const ignoredCount = uploadedQueries.length - validQueries.length;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Saved queries uploaded',
                    message: (validQueries.length - updateCount) + ' query(ies) added, ' + updateCount + ' updated'
                        + (ignoredCount ? ', ' + ignoredCount + ' invalid ignored.' : '.'),
                    variant: ignoredCount ? 'warning' : 'success'
                }));
            }
            if (this.isDebug) console.log('handleQueriesFileChange: END OK with #queries ',this.savedQueries.length);
        }
        catch (error) {
            console.warn('handleQueriesFileChange: END KO with error ',error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved queries upload failed',
                message: error?.message || JSON.stringify(error),
                variant: 'error'
            }));
        }
        finally {
            // Input reset to allow re-uploading the same file
            event.target.value = null;
        }
    }

    handleQueryButtonClick(event) {
        if (this.isDebug) console.log('handleQueryButtonClick: START with SQL ',this.sqlQuery);
        if (this.isDebug) console.log('handleQueryButtonClick: and dataSpace ',this.dataSpace);
        this.isRunning = true;
        this.isCollapsed = true;
        this.hasError = false;
        this.errorMessage = null;
        this.saveInspectLayout();
        this.inspectedCell = null;

        runQuery({sql: this.sqlQuery, dataSpace: this.dataSpace})
        .then(result => {
            if (this.isDebug) console.log('handleQueryButtonClick: result received ',JSON.stringify(result));
            this.resultColumns = (result.columns || []).map(item => this.buildColumn(item));
            this.columnWidths = null;
            const datetimeFields = this.resultColumns.filter(item => item.typeAttributes.displayType === 'date').map(item => item.fieldName);
            this.sortedBy = null;
            this.sortedDirection = null;
            this.resultList = (result.rows || []).map((item, index) => {
                const row = {...item, [ROW_KEY]: index};
                datetimeFields.forEach(field => { row[field] = this.normalizeDatetime(row[field]); });
                return row;
            });
            this.applyFilter();
            this.rowCount = result.rowCount || 0;
            this.isTruncated = result.truncated;
            this.isMaskingApplied = result.maskingApplied;
            if (this.isDebug) console.log('handleQueryButtonClick: END OK with #rows ',this.rowCount);
        }).catch(error => {
            console.warn('handleQueryButtonClick: END KO with error ',JSON.stringify(error));
            this.resultColumns = [];
            this.resultList = [];
            this.applyFilter();
            this.rowCount = 0;
            this.isTruncated = false;
            this.isMaskingApplied = false;
            this.hasError = true;
            this.errorMessage = error?.body?.message || error?.message || JSON.stringify(error);
        }).finally(() => {
            this.hasResults = true;
            this.isRunning = false;
        });
        if (this.isDebug) console.log('handleQueryButtonClick: query triggered');
    }

    handleCellInspect(event) {
        if (this.isDebug) console.log('handleCellInspect: START for column ',event.detail.label);
        // Tile closed when the clicked cell has no value to display
        const isEmpty = (this.formatInspectedValue(event.detail.value) === '');
        if (isEmpty) this.saveInspectLayout();
        this.inspectedCell = isEmpty ? null : {label: event.detail.label, value: event.detail.value};
    }

    handleInspectClose(event) {
        if (this.isDebug) console.log('handleInspectClose: START');
        this.saveInspectLayout();
        this.inspectedCell = null;
    }

    // Current tile size kept as explicit size at first interaction (e.g. resize handle drag)
    // to avoid any jump (and kept when other cells are inspected)
    handleInspectResize(event) {
        const boxElement = this.refs.inspectBox;
        if (!boxElement || boxElement.classList.contains('inspectBoxResized')) return;
        // tile title, action buttons and card internal header not considered as a layout customisation
        if (event.target.tagName === 'LIGHTNING-CARD' || event.target.closest('.inspectTitle, .inspectActions')) return;
        boxElement.style.height = boxElement.offsetHeight + 'px';
        boxElement.style.width = boxElement.offsetWidth + 'px';
        boxElement.classList.add('inspectBoxResized');
        this.fitInspectedValue();
        if (this.isDebug) console.log('handleInspectResize: size released at ',boxElement.style.width + ' x ' + boxElement.style.height);
    }

    // Horizontal drag of the tile via its title (pointer captured to keep receiving moves outside of it),
    // offset applied as left margin and bounded to keep the tile within the results card
    handleInspectDragStart(event) {
        if (event.button !== 0) return;
        const boxElement = this.refs.inspectBox;
        this.inspectDrag = {
            startX: event.clientX,
            startOffset: parseFloat(boxElement.style.marginLeft) || 0,
            maxOffset: Math.max(0, this.getInspectInnerWidth() - boxElement.offsetWidth)
        };
        event.currentTarget.setPointerCapture(event.pointerId);
        // avoids text selection while dragging
        event.preventDefault();
        if (this.isDebug) console.log('handleInspectDragStart: drag started with max offset ',this.inspectDrag.maxOffset);
    }

    handleInspectDragMove(event) {
        if (!this.inspectDrag) return;
        const offset = Math.min(Math.max(this.inspectDrag.startOffset + event.clientX - this.inspectDrag.startX, 0), this.inspectDrag.maxOffset);
        this.setInspectOffset(this.refs.inspectBox, offset);
    }

    handleInspectDragEnd(event) {
        if (!this.inspectDrag) return;
        if (this.isDebug) console.log('handleInspectDragEnd: drag ended at offset ',this.refs.inspectBox.style.marginLeft);
        this.inspectDrag = null;
    }

    handleInspectCopy(event) {
        if (this.isDebug) console.log('handleInspectCopy: START for column ',this.inspectedCell?.label);
        navigator.clipboard.writeText(this.inspectedContent)
        .then(() => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Value copied',
                message: 'Value of ' + this.inspectedCell.label + ' copied to clipboard.',
                variant: 'success'
            }));
        })
        .catch(error => this.handleCopyError(error));
    }

    // 'Wrap text' / 'Clip text' column header actions propagated to the column cells via their wrapText
    // type attribute (column widths being kept as initial widths when the column definitions are updated)
    handleHeaderAction(event) {
        const actionName = event.detail.action?.name;
        if ((actionName !== 'wrapText') && (actionName !== 'clipText')) return;
        const fieldName = event.detail.columnDefinition?.fieldName;
        const isWrapped = (actionName === 'wrapText');
        if (this.isDebug) console.log('handleHeaderAction: START with ' + actionName + ' on column ',fieldName);
        this.resultColumns = this.resultColumns.map((item, index) => {
            const column = {...item, typeAttributes: {...item.typeAttributes}};
            if (this.columnWidths?.[index]) column.initialWidth = this.columnWidths[index];
            if (item.fieldName === fieldName) {
                column.wrapText = isWrapped;
                column.typeAttributes.wrapText = isWrapped;
            }
            return column;
        });
        if (this.isDebug) console.log('handleHeaderAction: END with column widths ',JSON.stringify(this.columnWidths));
    }

    handleColumnResize(event) {
        this.columnWidths = event.detail.columnWidths;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        if (this.isDebug) console.log('handleSort: START with field ',fieldName);
        if (this.isDebug) console.log('handleSort: and direction ',sortDirection);
        const reverse = (sortDirection === 'asc') ? 1 : -1;
        // null / undefined values always sorted last, numbers compared numerically,
        // other values compared as (numeric-aware) strings
        this.resultList = [...this.resultList].sort((a, b) => {
            const valA = a[fieldName];
            const valB = b[fieldName];
            const isNullA = (valA === null || valA === undefined);
            const isNullB = (valB === null || valB === undefined);
            if (isNullA || isNullB) return (isNullA === isNullB) ? 0 : (isNullA ? 1 : -1);
            if ((typeof valA === 'number') && (typeof valB === 'number')) return reverse * (valA - valB);
            return reverse * String(valA).localeCompare(String(valB), undefined, {numeric: true});
        });
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;
        this.applyFilter();
        if (this.isDebug) console.log('handleSort: END');
    }

    handleSearchChange(event) {
        this.searchString = event.detail.value;
        if (this.isDebug) console.log('handleSearchChange: search string changed to ',this.searchString);
        // Debounced filter application to avoid filtering the whole result list at each keystroke
        clearTimeout(this.searchTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimeout = setTimeout(() => {
            this.searchTimeout = null;
            this.applyFilter();
        }, SEARCH_DELAY);
    }

    handleLoadMore(event) {
        if (this.isDebug) console.log('handleLoadMore: START with #rows displayed ',this.displayedList.length);
        if (!this.hasMoreRows) {
            if (this.isDebug) console.log('handleLoadMore: END / all rows already displayed');
            return;
        }
        this.displayedList = this.filteredList.slice(0, this.displayedList.length + PAGE_SIZE);
        this.hasMoreRows = this.displayedList.length < this.filteredList.length;
        if (this.isDebug) console.log('handleLoadMore: END with #rows displayed ',this.displayedList.length);
    }

    handleFormatSelect(event) {
        if (this.isDebug) console.log('handleFormatSelect: START with format ',event.detail.value);
        this.outputFormat = event.detail.value;
    }

    handleExportButtonClick(event) {
        if (this.isDebug) console.log('handleExportButtonClick: START with #rows ',this.filteredList.length);
        const format = FORMATS[this.outputFormat];
        try {
            // UTF-8 BOM prepended to delimited text for proper accented characters display in Excel
            const content = this.buildOutput();
            this.downloadFile((format.separator ? '\uFEFF' : '') + content, EXPORT_FILE_NAME + format.extension);
            if (this.isDebug) console.log('handleExportButtonClick: END OK with #rows ',this.filteredList.length);
        }
        catch (error) {
            console.warn('handleExportButtonClick: END KO with error ',error);
            this.hasError = true;
            this.errorMessage = format.label + ' export failed: ' + (error?.message || JSON.stringify(error));
        }
    }

    handleCopyButtonClick(event) {
        if (this.isDebug) console.log('handleCopyButtonClick: START with #rows ',this.filteredList.length);
        let content;
        try {
            content = this.buildOutput();
        }
        catch (error) {
            this.handleCopyError(error);
            return;
        }
        const rowCount = this.filteredList.length;
        navigator.clipboard.writeText(content)
        .then(() => {
            if (this.isDebug) console.log('handleCopyButtonClick: END OK with #rows ',rowCount);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Results copied',
                message: rowCount + ' row(s) copied to clipboard as ' + FORMATS[this.outputFormat].label + '.',
                variant: 'success'
            }));
        })
        .catch(error => this.handleCopyError(error));
    }

    //----------------------------------------------------------------
    // Utilities
    //----------------------------------------------------------------
    // Stores the current layout of the inspection tile (if customised by the user) before closing it
    saveInspectLayout() {
        const boxElement = this.refs?.inspectBox;
        if (!boxElement || !boxElement.classList.contains('inspectBoxResized')) return;
        this.inspectLayout = {
            width: boxElement.offsetWidth,
            height: boxElement.offsetHeight,
            offset: parseFloat(boxElement.style.marginLeft) || 0
        };
        if (this.isDebug) console.log('saveInspectLayout: layout saved ',JSON.stringify(this.inspectLayout));
    }

    // Applies the stored layout to the (re)displayed inspection tile, size and offset being
    // bounded to the current results card width (which may have changed since)
    applyInspectLayout(boxElement) {
        const innerWidth = this.getInspectInnerWidth();
        const width = Math.min(this.inspectLayout.width, innerWidth);
        boxElement.style.width = width + 'px';
        boxElement.style.height = this.inspectLayout.height + 'px';
        boxElement.classList.add('inspectBoxResized');
        this.setInspectOffset(boxElement, Math.min(this.inspectLayout.offset, Math.max(0, innerWidth - width)));
        this.fitInspectedValue();
        if (this.isDebug) console.log('applyInspectLayout: layout applied ',JSON.stringify(this.inspectLayout));
    }

    // Fits the value area height to the space remaining at the bottom of the (default or user sized) tile
    // (value area being nested within the lightning-card internal layout, out of reach of CSS flex sizing)
    fitInspectedValue() {
        const boxElement = this.refs?.inspectBox;
        const valueElement = this.refs?.inspectedValue;
        if (!boxElement || !valueElement) return;
        const boxStyle = getComputedStyle(boxElement);
        const bottomLimit = boxElement.getBoundingClientRect().bottom
            - parseFloat(boxStyle.paddingBottom) - parseFloat(boxStyle.borderBottomWidth);
        const height = Math.max(bottomLimit - valueElement.getBoundingClientRect().top, 24);
        valueElement.style.height = height + 'px';
    }

    // Sets the horizontal offset (left margin) of the inspection tile, its max width being
    // reduced accordingly to keep any later resize within the results card
    setInspectOffset(boxElement, offset) {
        boxElement.style.marginLeft = offset + 'px';
        boxElement.style.maxWidth = 'calc(100% - ' + offset + 'px)';
    }

    // Width available for the inspection tile (wrapper width without its padding)
    getInspectInnerWidth() {
        const tileElement = this.refs.inspectBox.parentElement;
        const tileStyle = getComputedStyle(tileElement);
        return tileElement.clientWidth - parseFloat(tileStyle.paddingLeft) - parseFloat(tileStyle.paddingRight);
    }

    // Triggers the download of a text content as a file
    // (generic binary MIME type used as 'text/csv' is not supported by Lightning Web Security,
    // the extension of the download file name driving the file type on the user side)
    downloadFile(content, fileName) {
        const fileBlob = new Blob([content], {type: 'application/octet-stream'});
        const fileUrl = URL.createObjectURL(fileBlob);
        const downloadLink = document.createElement('a');
        downloadLink.href = fileUrl;
        downloadLink.download = fileName;
        downloadLink.click();
        URL.revokeObjectURL(fileUrl);
    }

    // Reads the saved queries from the browser local storage (empty list if none or invalid)
    loadSavedQueries() {
        try {
            const savedQueries = JSON.parse(localStorage.getItem(SAVED_QUERIES_KEY) || '[]');
            if (this.isDebug) console.log('loadSavedQueries: #queries loaded ',savedQueries.length);
            return Array.isArray(savedQueries) ? savedQueries : [];
        }
        catch (error) {
            console.warn('loadSavedQueries: saved queries ignored with error ',error);
            return [];
        }
    }

    // Writes the saved queries in the browser local storage and updates the component list
    // (returns false and displays an error if storage is unavailable or full)
    storeSavedQueries(savedQueries) {
        try {
            localStorage.setItem(SAVED_QUERIES_KEY, JSON.stringify(savedQueries));
            this.savedQueries = savedQueries;
            return true;
        }
        catch (error) {
            console.warn('storeSavedQueries: KO with error ',error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved queries update failed',
                message: error?.message || JSON.stringify(error),
                variant: 'error'
            }));
            return false;
        }
    }

    // Displays a copy to clipboard error
    handleCopyError(error) {
        console.warn('handleCopyButtonClick: END KO with error ',error);
        this.hasError = true;
        this.errorMessage = 'Copy to clipboard failed: ' + (error?.message || JSON.stringify(error));
    }

    // Builds the text content of the complete filtered result list (in current sort order,
    // not only the displayed rows) in the selected format for export / copy:
    // JSON array of row objects (without internal row key) or delimited text lines (header + rows)
    buildOutput() {
        // Pending (debounced) filter applied first to stay consistent with the search string
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
            this.searchTimeout = null;
            this.applyFilter();
        }
        const fieldNames = this.resultColumns.map(item => item.fieldName);
        const separator = FORMATS[this.outputFormat].separator;
        if (!separator) {
            const rows = this.filteredList.map(row => {
                const jsonRow = {};
                fieldNames.forEach(item => { jsonRow[item] = row[item] ?? null; });
                return jsonRow;
            });
            return JSON.stringify(rows, null, 2);
        }
        const lines = [fieldNames.map(item => this.formatCsvValue(item, separator)).join(separator)];
        this.filteredList.forEach(row => {
            lines.push(fieldNames.map(item => this.formatCsvValue(row[item], separator)).join(separator));
        });
        return lines.join('\r\n');
    }

    // Filters the (sorted) result list with the search string (case insensitive match on all
    // fields converted to string) and resets the datatable display. resultList is never modified.
    applyFilter() {
        const searchKey = (this.searchString || '').trim().toLowerCase();
        if (searchKey) {
            const fieldNames = this.resultColumns.map(item => item.fieldName);
            this.filteredList = this.resultList.filter(row => fieldNames.some(field => {
                const value = row[field];
                if ((value === null) || (value === undefined)) return false;
                const valueStr = (typeof value === 'object') ? JSON.stringify(value) : String(value);
                return valueStr.toLowerCase().includes(searchKey);
            }));
        }
        else {
            this.filteredList = this.resultList;
        }
        this.isFiltered = !!searchKey;
        if (this.isDebug) console.log('applyFilter: #rows matching ',this.filteredList.length);
        this.resetDisplayedList();
    }

    // Resets the datatable display to the first PAGE_SIZE rows of the (sorted) filtered list.
    // The datatable is re-created (new key) to reset its scroll position to the top, as keeping
    // it scrolled down would otherwise immediately trigger loadmore events up to the previous row count.
    resetDisplayedList() {
        this.tableInstances = [{key: this.tableInstances[0].key + 1}];
        this.displayedList = this.filteredList.slice(0, PAGE_SIZE);
        this.hasMoreRows = this.displayedList.length < this.filteredList.length;
        if (this.isDebug) console.log('resetDisplayedList: #rows displayed ',this.displayedList.length);
    }

    // Formats a single value as a delimited field (RFC 4180): null as empty, objects as JSON,
    // values with separator / quotes / line breaks enclosed in double quotes (inner quotes doubled)
    formatCsvValue(value, separator) {
        if ((value === null) || (value === undefined)) return '';
        const valueStr = (typeof value === 'object') ? JSON.stringify(value) : String(value);
        const needsQuotes = valueStr.includes(separator) || /["\r\n]/.test(valueStr);
        return needsQuotes ? '"' + valueStr.replace(/"/g, '""') + '"' : valueStr;
    }

    // Builds a datatable column from a Data360 result column (name + type), as a clickable
    // 'inspectable' custom type cell formatted as per its displayType
    buildColumn(column) {
        const dataType = (column.type || '').toUpperCase();
        const dtColumn = {
            label: column.name, fieldName: column.name, type: 'inspectable', sortable: true,
            typeAttributes: {label: column.name, displayType: 'text'}
        };
        if (NUMBER_TYPES.includes(dataType)) {
            dtColumn.typeAttributes.displayType = 'number';
            dtColumn.cellAttributes = {alignment: 'right'};
        }
        else if (DATE_TYPES.includes(dataType)) {
            dtColumn.typeAttributes.displayType = 'date-local';
        }
        else if (DATETIME_TYPES.includes(dataType)) {
            dtColumn.typeAttributes.displayType = 'date';
        }
        return dtColumn;
    }

    // Formats a cell value for the inspection tile: objects and JSON strings (objects / arrays)
    // pretty printed, other values as raw text (null as empty)
    formatInspectedValue(value) {
        if ((value === null) || (value === undefined)) return '';
        if (typeof value === 'object') return JSON.stringify(value, null, 2);
        const valueStr = String(value);
        if (/^\s*[[{]/.test(valueStr)) {
            try {
                return JSON.stringify(JSON.parse(valueStr), null, 2);
            }
            catch (error) {
                // not valid JSON, displayed as is
            }
        }
        return valueStr;
    }

    // Normalizes a Data360 timestamp value into an ISO 8601 string reliably parsed by all browsers:
    // space separator replaced by 'T', fractional seconds truncated to milliseconds,
    // UTC ('Z') assumed when no timezone offset is provided (Data360 storing datetimes in UTC)
    normalizeDatetime(value) {
        if (typeof value !== 'string') return value;
        let normalized = value.trim().replace(' ', 'T').replace(/(\.\d{3})\d+/, '$1');
        if (/T\d{2}:\d{2}(:\d{2}(\.\d+)?)?$/.test(normalized)) normalized += 'Z';
        return normalized;
    }
}
